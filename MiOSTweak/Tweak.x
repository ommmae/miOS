#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import "MiOSContainerManager.h"

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

// MARK: - Home-directory redirect hooks (belt-and-suspenders; CFFIXED_USER_HOME does most of it)

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
        } else if (gSpoofSerial && ([k isEqualToString:@"SerialNumber"])) {
            return (__bridge_retained CFTypeRef)[gSpoofSerial copy];
        } else if (gSpoofUDID && ([k isEqualToString:@"UniqueDeviceID"] || [k isEqualToString:@"UniqueDeviceIDData"])) {
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

        // 1. Redirect the whole home directory into the container (the Crane/LiveContainer core).
        if (containerEnabled && uuid) {
            NSString *home = [mgr homePathForBundleID:gBundleID ensureCreated:YES];
            if (home.length > 0) {
                gContainerHome = home;
                gContainerTmp = [home stringByAppendingPathComponent:@"tmp"];
                setenv("CFFIXED_USER_HOME", home.UTF8String, 1);
                setenv("HOME", home.UTF8String, 1);
                setenv("TMPDIR", gContainerTmp.UTF8String, 1);
                MSHookFunction((void *)NSHomeDirectory, (void *)hook_NSHomeDirectory, (void **)&orig_NSHomeDirectory);
                MSHookFunction((void *)NSTemporaryDirectory, (void *)hook_NSTemporaryDirectory, (void **)&orig_NSTemporaryDirectory);
            }
        }

        // 2. Per-container spoof: device model, identifiers, GPS.
        gSpoof = [mgr spoofPrefsForBundleID:gBundleID];
        if (uuid) {
            gSpoofSerial = derivedHex(uuid, @"serial", 11);
            gSpoofUDID = derivedHex(uuid, @"udid", 25);
        }

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
