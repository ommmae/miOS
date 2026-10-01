#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import "MiOSContainerManager.h"
#import "MiOSContainerMint.h"

// MARK: - Private declarations

typedef int (*libSandy_applyProfile_t)(const char *profileName);
typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef key);

@interface DCDevice : NSObject
@property (class, readonly) DCDevice *currentDevice;
- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion;
@end

@interface ASIdentifierManager : NSObject
+ (ASIdentifierManager *)sharedManager;
- (NSUUID *)advertisingIdentifier;
- (BOOL)isAdvertisingTrackingEnabled;
@end

// MARK: - Shared runtime state (resolved once, in the constructor)

static NSString *gBundleID = nil;
static NSString *gContainerHome = nil;         // redirected HOME, or nil for the default container
static NSString *gContainerTmp = nil;
static NSDictionary *gSpoof = nil;             // per-container spoof prefs
static NSString *gSpoofSerial = nil;           // derived, stable per container
static NSString *gSpoofUDID = nil;
static NSString *gKcPrefix = nil;              // per-container keychain namespace prefix
static BOOL gKeychainIsolation = NO;           // opt-in (core plist); validate the core redirect first
static BOOL gPrefsIsolation = NO;

static BOOL isMiOSEnabled(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist"];
    return [prefs[@"enabled"] boolValue];
}

static NSDictionary *appPrefs(NSString *bid) {
    NSString *path = [NSString stringWithFormat:
        @"/var/mobile/Library/Preferences/MiOS/apps/%@.plist", bid];
    return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
}

static BOOL deviceSpoofEnabled(void) {
    return [gSpoof[@"deviceSpoofEnabled"] boolValue];
}

static NSString *spoofStr(NSString *key) {
    id v = gSpoof[key];
    return [v isKindOfClass:[NSString class]] ? v : @"";
}

// MARK: - Home-directory redirect hooks
//
// setenv(HOME/CFFIXED_USER_HOME) alone is not enough from an injected tweak: by the time our
// constructor runs the home path may already be cached, so we also force NSHomeDirectory/
// NSTemporaryDirectory to the container. (These hooks are safe at launch; the earlier splash
// hang came from the device-spoof hooks, not these.)
static NSString *(*orig_NSHomeDirectory)(void);
static NSString *hook_NSHomeDirectory(void) {
    return gContainerHome ?: orig_NSHomeDirectory();
}
static NSString *(*orig_NSTemporaryDirectory)(void);
static NSString *hook_NSTemporaryDirectory(void) {
    return gContainerTmp ?: orig_NSTemporaryDirectory();
}

// MARK: - GPS Location Hooks (per container)

static BOOL locationSpoofEnabled(void) {
    return [gSpoof[@"gpsEnabled"] boolValue];
}

static CLLocationCoordinate2D spoofedCoordinate(void) {
    return CLLocationCoordinate2DMake([gSpoof[@"latitude"] doubleValue], [gSpoof[@"longitude"] doubleValue]);
}

static CLLocation *spoofedLocationObject(void) {
    return [[CLLocation alloc] initWithCoordinate:spoofedCoordinate()
                                         altitude:0
                               horizontalAccuracy:5.0
                                 verticalAccuracy:5.0
                                           course:-1
                                            speed:-1
                                        timestamp:[NSDate date]];
}

%group LocationHooks

%hook CLLocationManager

- (CLLocation *)location {
    if (locationSpoofEnabled()) return spoofedLocationObject();
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (!locationSpoofEnabled()) return;
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocationManager *mgr = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [delegate locationManager:mgr didUpdateLocations:@[spoofedLocationObject()]];
        });
    }
}

- (void)requestLocation {
    %orig;
    if (!locationSpoofEnabled()) return;
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocationManager *mgr = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [delegate locationManager:mgr didUpdateLocations:@[spoofedLocationObject()]];
        });
    }
}

%end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (locationSpoofEnabled()) return spoofedCoordinate();
    return %orig;
}

%end

%end // LocationHooks

// MARK: - Device model spoofing (per container)

%group DeviceSpoofHooks

%hook UIDevice

- (NSString *)systemVersion {
    NSString *ver = spoofStr(@"iosVersion");
    return ver.length > 0 ? ver : %orig;
}

- (NSString *)name {
    NSString *custom = spoofStr(@"customDeviceName");
    if ([gSpoof[@"spoofDeviceName"] boolValue] && custom.length > 0) return custom;
    NSString *name = spoofStr(@"deviceName");
    return name.length > 0 ? name : %orig;
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSString *ver = spoofStr(@"iosVersion");
    if (ver.length > 0) {
        NSArray *parts = [ver componentsSeparatedByString:@"."];
        NSOperatingSystemVersion v = {0, 0, 0};
        if (parts.count > 0) v.majorVersion = [parts[0] integerValue];
        if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
        if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
        return v;
    }
    return %orig;
}

%end

%end // DeviceSpoofHooks

// MARK: - Identifier spoofing (per container)

%group IdentifierSpoofHooks

%hook UIDevice

- (NSUUID *)identifierForVendor {
    if ([gSpoof[@"spoofVendorID"] boolValue]) {
        NSString *vid = spoofStr(@"vendorID");
        NSUUID *uuid = vid.length > 0 ? [[NSUUID alloc] initWithUUIDString:vid] : nil;
        if (uuid) return uuid;
    }
    return %orig;
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if ([gSpoof[@"spoofAdvertisingID"] boolValue]) {
        NSString *aid = spoofStr(@"advertisingID");
        NSUUID *uuid = aid.length > 0 ? [[NSUUID alloc] initWithUUIDString:aid] : nil;
        if (uuid) return uuid;
    }
    return %orig;
}

- (BOOL)isAdvertisingTrackingEnabled {
    if ([gSpoof[@"spoofAdvertisingID"] boolValue]) return NO;
    return %orig;
}

%end

%hook DCDevice

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion {
    if ([gSpoof[@"spoofDeviceCheck"] boolValue]) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"DCErrorDomain" code:1 userInfo:@{
                NSLocalizedDescriptionKey: @"DeviceCheck is not supported on this device"}]);
        }
        return;
    }
    %orig;
}

%end

%hook NSFileManager

- (id)ubiquityIdentityToken {
    if ([gSpoof[@"spoofCloudToken"] boolValue]) return nil;
    return %orig;
}

%end

%end // IdentifierSpoofHooks

// MARK: - Keychain namespacing (per container, Crane-style)
//
// We inject into the real app, so we cannot switch to a private access group the way
// LiveContainer does. Instead we namespace items inside the app's own access group by
// prefixing the service-like key fields with a per-container tag, and strip the prefix
// back out of returned attributes so the app never sees it.

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef);

static NSArray *kcPrefixedKeys(void) {
    return @[(__bridge id)kSecAttrService, (__bridge id)kSecAttrServer];
}

// Returns a copy of dict with service-like fields prefixed; sets *modified if anything changed.
static NSDictionary *kcApplyPrefix(CFDictionaryRef dict, BOOL *modified) {
    if (!dict) return nil;
    NSMutableDictionary *copy = [(__bridge NSDictionary *)dict mutableCopy];
    BOOL changed = NO;
    for (id key in kcPrefixedKeys()) {
        id value = copy[key];
        if ([value isKindOfClass:[NSString class]] && ![value hasPrefix:gKcPrefix]) {
            copy[key] = [gKcPrefix stringByAppendingString:value];
            changed = YES;
        }
    }
    if (modified) *modified = changed;
    return copy;
}

static id kcStripObject(id obj) {
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray arrayWithCapacity:[obj count]];
        for (id item in obj) [out addObject:kcStripObject(item)];
        return out;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [obj mutableCopy];
        for (id key in kcPrefixedKeys()) {
            id value = out[key];
            if ([value isKindOfClass:[NSString class]] && [value hasPrefix:gKcPrefix]) {
                out[key] = [value substringFromIndex:gKcPrefix.length];
            }
        }
        return out;
    }
    return obj;
}

static void kcStripResult(CFTypeRef *result) {
    if (!result || !*result) return;
    id obj = (__bridge id)*result;
    if (![obj isKindOfClass:[NSArray class]] && ![obj isKindOfClass:[NSDictionary class]]) return;
    id stripped = kcStripObject(obj);
    CFRelease(*result);
    *result = (__bridge_retained CFTypeRef)stripped;
}

static OSStatus new_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    BOOL modified = NO;
    NSDictionary *copy = kcApplyPrefix(attributes, &modified);
    if (!modified) return orig_SecItemAdd(attributes, result);
    OSStatus status = orig_SecItemAdd((__bridge CFDictionaryRef)copy, result);
    if (status == errSecParam) return orig_SecItemAdd(attributes, result);
    return status;
}

static OSStatus new_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    BOOL modified = NO;
    NSDictionary *copy = kcApplyPrefix(query, &modified);
    if (!modified) return orig_SecItemCopyMatching(query, result);
    OSStatus status = orig_SecItemCopyMatching((__bridge CFDictionaryRef)copy, result);
    if (status == errSecParam) return orig_SecItemCopyMatching(query, result);
    if (status == errSecSuccess) kcStripResult(result);
    return status;
}

static OSStatus new_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    BOOL modified = NO;
    NSDictionary *copy = kcApplyPrefix(query, &modified);
    // Prefix the update payload too, so a changed service stays namespaced.
    NSDictionary *attrCopy = kcApplyPrefix(attributesToUpdate, NULL);
    if (!modified) return orig_SecItemUpdate(query, attributesToUpdate);
    OSStatus status = orig_SecItemUpdate((__bridge CFDictionaryRef)copy, (__bridge CFDictionaryRef)attrCopy);
    if (status == errSecParam) return orig_SecItemUpdate(query, attributesToUpdate);
    return status;
}

static OSStatus new_SecItemDelete(CFDictionaryRef query) {
    BOOL modified = NO;
    NSDictionary *copy = kcApplyPrefix(query, &modified);
    if (!modified) return orig_SecItemDelete(query);
    OSStatus status = orig_SecItemDelete((__bridge CFDictionaryRef)copy);
    if (status == errSecParam) return orig_SecItemDelete(query);
    return status;
}

static void miosInitKeychainNamespace(void) {
    MSHookFunction((void *)SecItemAdd, (void *)new_SecItemAdd, (void **)&orig_SecItemAdd);
    MSHookFunction((void *)SecItemCopyMatching, (void *)new_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching);
    MSHookFunction((void *)SecItemUpdate, (void *)new_SecItemUpdate, (void **)&orig_SecItemUpdate);
    MSHookFunction((void *)SecItemDelete, (void *)new_SecItemDelete, (void **)&orig_SecItemDelete);
}

// MARK: - Preferences redirect (per container, like LiveContainer)
//
// Swizzle the private CFPrefsPlistSource initializer and force its container path to the
// redirected HOME for non-Apple domains, so NSUserDefaults/CFPreferences read and write
// <container>/Library/Preferences/<domain>.plist instead of the real container's.

static BOOL miosIsAppleDomain(NSString *domain) {
    return [domain hasPrefix:@"com.apple."] || [domain hasPrefix:@"group.com.apple."]
        || [domain hasPrefix:@"systemgroup.com.apple."];
}

@interface MiOSPrefsSourceShim : NSObject
@end
@implementation MiOSPrefsSourceShim
- (id)mios_initWithDomain:(CFStringRef)domain user:(CFStringRef)user byHost:(bool)host
            containerPath:(CFStringRef)containerPath containingPreferences:(id)prefs {
    if (gContainerHome.length == 0 || miosIsAppleDomain((__bridge NSString *)domain)) {
        return [self mios_initWithDomain:domain user:user byHost:host containerPath:containerPath containingPreferences:prefs];
    }
    if (user == kCFPreferencesAnyUser) user = kCFPreferencesCurrentUser;
    return [self mios_initWithDomain:domain user:user byHost:host
                       containerPath:(__bridge CFStringRef)gContainerHome containingPreferences:prefs];
}
@end

static void miosInitPrefsRedirect(void) {
    Class src = NSClassFromString(@"CFPrefsPlistSource");
    SEL orig = NSSelectorFromString(@"initWithDomain:user:byHost:containerPath:containingPreferences:");
    SEL repl = @selector(mios_initWithDomain:user:byHost:containerPath:containingPreferences:);
    Method origM = src ? class_getInstanceMethod(src, orig) : NULL;
    Method replM = class_getInstanceMethod([MiOSPrefsSourceShim class], repl);
    if (!origM || !replM) return; // private API moved; skip rather than crash

    class_addMethod(src, repl, method_getImplementation(replM), method_getTypeEncoding(replM));
    Method added = class_getInstanceMethod(src, repl);
    if (added) method_exchangeImplementations(origM, added);
}

// MARK: - sysctlbyname (hw.machine / hw.model)

static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

static int copyStringOut(void *oldp, size_t *oldlenp, NSString *value) {
    const char *cstr = [value UTF8String];
    size_t len = strlen(cstr) + 1;
    if (*oldlenp >= len) {
        memcpy(oldp, cstr, len);
        *oldlenp = len;
    }
    return 0;
}

static int hook_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (ret != 0 || !oldp || !oldlenp || !deviceSpoofEnabled()) return ret;

    if (strcmp(name, "hw.machine") == 0 && spoofStr(@"deviceIdentifier").length > 0) {
        return copyStringOut(oldp, oldlenp, spoofStr(@"deviceIdentifier"));
    } else if (strcmp(name, "hw.model") == 0 && spoofStr(@"hwModel").length > 0) {
        return copyStringOut(oldp, oldlenp, spoofStr(@"hwModel"));
    }
    return ret;
}

// MARK: - MobileGestalt

static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef hook_MGCopyAnswer(CFStringRef key) {
    if (deviceSpoofEnabled() && key) {
        NSString *k = (__bridge NSString *)key;
        if ([k isEqualToString:@"ProductType"] || [k isEqualToString:@"HWModelStr"]) {
            if (spoofStr(@"deviceIdentifier").length > 0) return (__bridge_retained CFTypeRef)[spoofStr(@"deviceIdentifier") copy];
        } else if ([k isEqualToString:@"DeviceName"] || [k isEqualToString:@"marketing-name"] || [k isEqualToString:@"UserAssignedDeviceName"]) {
            if (spoofStr(@"deviceName").length > 0) return (__bridge_retained CFTypeRef)[spoofStr(@"deviceName") copy];
        } else if ([k isEqualToString:@"HardwarePlatform"]) {
            if (spoofStr(@"hwModel").length > 0) return (__bridge_retained CFTypeRef)[spoofStr(@"hwModel") copy];
        } else if ([k isEqualToString:@"ProductVersion"]) {
            if (spoofStr(@"iosVersion").length > 0) return (__bridge_retained CFTypeRef)[spoofStr(@"iosVersion") copy];
        } else if (gSpoofSerial && [k isEqualToString:@"SerialNumber"]) {
            return (__bridge_retained CFTypeRef)[gSpoofSerial copy];
        } else if (gSpoofUDID && [k isEqualToString:@"UniqueDeviceID"]) {
            // Only the string form; UniqueDeviceIDData expects CFData, so leave it untouched.
            return (__bridge_retained CFTypeRef)[gSpoofUDID copy];
        }
    }
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(key) : NULL;
}

// MARK: - Derived unique-device identifiers (stable per container)

static NSString *derivedHex(NSString *seed, NSString *salt, NSUInteger length) {
    NSString *combined = [NSString stringWithFormat:@"%@-%@", seed ?: @"", salt];
    unsigned long hash = 1469598103934665603UL; // FNV-1a-ish, deterministic
    const char *bytes = combined.UTF8String;
    for (NSUInteger i = 0; bytes[i]; i++) { hash ^= (unsigned char)bytes[i]; hash *= 1099511628211UL; }
    NSMutableString *out = [NSMutableString string];
    const char *alphabet = "0123456789ABCDEF";
    for (NSUInteger i = 0; i < length; i++) {
        [out appendFormat:@"%c", alphabet[(hash >> ((i % 15) * 4)) & 0xF]];
        hash = hash * 6364136223846793005UL + 1442695040888963407UL;
    }
    return out;
}

// MARK: - Constructor

%ctor {
    @autoreleasepool {
        gBundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (gBundleID.length == 0 || [gBundleID isEqualToString:@"com.mios.app"]) return;

        // Grant the sandbox extension first so the central MiOS folder is reachable.
        void *sandyHandle = dlopen("/usr/lib/libsandy.dylib", RTLD_LAZY);
        if (!sandyHandle) sandyHandle = dlopen("/var/jb/usr/lib/libsandy.dylib", RTLD_LAZY);
        if (sandyHandle) {
            libSandy_applyProfile_t applyProfile = (libSandy_applyProfile_t)dlsym(sandyHandle, "libSandy_applyProfile");
            if (applyProfile) applyProfile("MiOS-Profile");
        }

        if (!isMiOSEnabled()) return;

        MiOSContainerManager *mgr = [MiOSContainerManager sharedManager];
        BOOL containerEnabled = [appPrefs(gBundleID)[@"containerEnabled"] boolValue];
        NSString *uuid = [mgr activeContainerUUIDForBundleID:gBundleID];

        NSDictionary *corePrefs = [NSDictionary dictionaryWithContentsOfFile:
            @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist"];
        // Opt-in isolation layers (core plist). Default off so the core redirect is validated first.
        gKeychainIsolation = [corePrefs[@"keychainIsolation"] boolValue];
        gPrefsIsolation = [corePrefs[@"prefsIsolation"] boolValue];
        // File-level containerization (HOME redirect) is still experimental and currently crashes
        // some apps, so it is opt-in. Default OFF means apps launch normally (spoof-only).
        BOOL fileIsolation = [corePrefs[@"fileIsolation"] boolValue];

        // 1. Redirect the whole home directory into the container (the Crane/LiveContainer core).
        //    Data lives inside the app's OWN data container, so the sandbox always allows it.
        if (fileIsolation && containerEnabled && uuid) {
            // Mint / reuse a REAL OS data container (stock-like), not a subfolder. A subfolder is
            // not a genuine container and triggers the mach-port/data-protection guard crash.
            NSString *home = [MiOSContainerMint realHomeForBundle:gBundleID logicalID:uuid];
            // Probe that we can actually write there before committing; otherwise leave the app alone.
            BOOL writable = NO;
            if (home.length > 0) {
                NSString *probe = [home stringByAppendingPathComponent:@".mios_write_probe"];
                writable = [@"ok" writeToFile:probe atomically:YES encoding:NSUTF8StringEncoding error:nil];
                if (writable) [[NSFileManager defaultManager] removeItemAtPath:probe error:nil];
            }
            if (writable) {
                gContainerHome = home;
                gContainerTmp = [home stringByAppendingPathComponent:@"tmp"];
                setenv("CFFIXED_USER_HOME", home.UTF8String, 1);
                setenv("HOME", home.UTF8String, 1);
                // Force the cached home/tmp too — setenv alone is too late in an injected tweak.
                MSHookFunction((void *)NSHomeDirectory, (void *)hook_NSHomeDirectory, (void **)&orig_NSHomeDirectory);
                MSHookFunction((void *)NSTemporaryDirectory, (void *)hook_NSTemporaryDirectory, (void **)&orig_NSTemporaryDirectory);

                // Per-container preferences and keychain (opt-in; so each container is its own account).
                if (gPrefsIsolation) miosInitPrefsRedirect();
                if (gKeychainIsolation) {
                    gKcPrefix = [NSString stringWithFormat:@"__mios_%@_", uuid];
                    miosInitKeychainNamespace();
                }
            }
        }

        // 2. Per-container spoof: device model, identifiers, GPS. Only for container apps.
        if (!uuid) return;
        gSpoof = [mgr spoofPrefsForBundleID:gBundleID];
        gSpoofSerial = derivedHex(uuid, @"serial", 11);
        gSpoofUDID = derivedHex(uuid, @"udid", 25);

        if (locationSpoofEnabled()) {
            %init(LocationHooks);
        }

        %init(IdentifierSpoofHooks);

        if (deviceSpoofEnabled()) {
            %init(DeviceSpoofHooks);

            MSHookFunction((void *)sysctlbyname, (void *)hook_sysctlbyname, (void **)&orig_sysctlbyname);

            void *mgHandle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
            if (!mgHandle) mgHandle = dlopen("/var/jb/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
            if (mgHandle) {
                MGCopyAnswer_t mgFn = (MGCopyAnswer_t)dlsym(mgHandle, "MGCopyAnswer");
                if (mgFn) MSHookFunction((void *)mgFn, (void *)hook_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
            }
        }
    }
}
