#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import "MiOSContainerManager.h"
#import "MiOSLocationManager.h"

typedef int (*libSandy_applyProfile_t)(const char *profileName);
typedef CFTypeRef (*MGCopyAnswer_t)(CFStringRef key);

@interface DCDevice : NSObject
@property (class, readonly) DCDevice *currentDevice;
@property (nonatomic, readonly, getter=isSupported) BOOL supported;
- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion;
@end

@interface ASIdentifierManager : NSObject
+ (ASIdentifierManager *)sharedManager;
- (NSUUID *)advertisingIdentifier;
- (BOOL)isAdvertisingTrackingEnabled;
@end

static void applySandyProfile(const char *profileName) {
    static libSandy_applyProfile_t fn = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/usr/lib/libsandy.dylib", RTLD_LAZY);
        if (!handle) handle = dlopen("/var/jb/usr/lib/libsandy.dylib", RTLD_LAZY);
        if (handle) fn = (libSandy_applyProfile_t)dlsym(handle, "libSandy_applyProfile");
    });
    if (fn) fn(profileName);
}

static NSString *currentBundleID(void) {
    return [[NSBundle mainBundle] bundleIdentifier];
}

static BOOL isMiOSEnabled(void) {
    NSString *path = @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist";
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    return [prefs[@"enabled"] boolValue];
}

static NSDictionary *appPrefs(void) {
    NSString *bid = currentBundleID();
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/MiOS/apps/%@.plist", bid];
    return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
}

// MARK: - Device Spoof Data

static NSDictionary *cachedDeviceSpoofPrefs(void) {
    static NSDictionary *prefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/MiOS/com.mios.devicespoof.plist"] ?: @{};
    });
    return prefs;
}

static BOOL deviceSpoofEnabled(void) {
    return [cachedDeviceSpoofPrefs()[@"enabled"] boolValue];
}

static NSString *spoofedDeviceIdentifier(void) {
    return cachedDeviceSpoofPrefs()[@"deviceIdentifier"] ?: @"";
}

static NSString *spoofedDeviceName(void) {
    return cachedDeviceSpoofPrefs()[@"deviceName"] ?: @"";
}

static NSString *spoofedHWModel(void) {
    return cachedDeviceSpoofPrefs()[@"hwModel"] ?: @"";
}

static NSString *spoofedIOSVersion(void) {
    return cachedDeviceSpoofPrefs()[@"iosVersion"] ?: @"";
}

// MARK: - Per-container spoof prefs (like Ghost)

static NSDictionary *cachedContainerSpoofPrefs(void) {
    static NSDictionary *prefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefs = [[MiOSContainerManager sharedManager] spoofPrefsForBundleID:currentBundleID()];
    });
    return prefs;
}

// MARK: - Container Redirect Hooks

%group ContainerHooks

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected);
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected, isDirectory);
    return %orig;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected, error);
    return %orig;
}

- (NSData *)contentsAtPath:(NSString *)path {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected);
    return %orig;
}

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)flag attributes:(NSDictionary *)attrs error:(NSError **)error {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected, flag, attrs, error);
    return %orig;
}

%end

%hook NSData

+ (instancetype)dataWithContentsOfFile:(NSString *)path {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected);
    return %orig;
}

%end

%hook NSDictionary

+ (instancetype)dictionaryWithContentsOfFile:(NSString *)path {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected);
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected, flag);
    return %orig;
}

%end

%hook NSArray

+ (instancetype)arrayWithContentsOfFile:(NSString *)path {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected);
    return %orig;
}

%end

%hook NSString

+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (!isMiOSEnabled()) return %orig;
    NSString *redirected = [[MiOSContainerManager sharedManager] redirectedPathForPath:path bundleID:currentBundleID()];
    if (![redirected isEqualToString:path]) return %orig(redirected, enc, error);
    return %orig;
}

%end

%hook NSUserDefaults

- (instancetype)initWithSuiteName:(NSString *)suitename {
    if (!isMiOSEnabled()) return %orig;
    MiOSContainerModel *active = [[MiOSContainerManager sharedManager] activeContainerForBundleID:currentBundleID()];
    if (active && !active.isDefault && suitename) {
        NSString *containerPrefsPath = [active.path stringByAppendingPathComponent:@"Library/Preferences"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:containerPrefsPath]) {
            [fm createDirectoryAtPath:containerPrefsPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return %orig;
}

%end

%end // ContainerHooks

// MARK: - GPS Location Hooks

%group LocationHooks

%hook CLLocationManager

- (CLLocation *)location {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return [locMgr spoofedLocation];
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        id delegate = self.delegate;
        if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [delegate locationManager:self didUpdateLocations:@[[locMgr spoofedLocation]]];
            });
        }
    }
}

- (void)requestLocation {
    %orig;
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        id delegate = self.delegate;
        if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [delegate locationManager:self didUpdateLocations:@[[locMgr spoofedLocation]]];
            });
        }
    }
}

- (void)startMonitoringSignificantLocationChanges {
    %orig;
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        id delegate = self.delegate;
        if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [delegate locationManager:self didUpdateLocations:@[[locMgr spoofedLocation]]];
            });
        }
    }
}

%end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return locMgr.spoofedCoordinate;
    }
    return %orig;
}

- (CLLocationDistance)altitude {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return locMgr.spoofedAltitude;
    }
    return %orig;
}

- (CLLocationSpeed)speed {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return locMgr.spoofedSpeed;
    }
    return %orig;
}

- (CLLocationDirection)course {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return locMgr.spoofedCourse;
    }
    return %orig;
}

- (CLLocationAccuracy)horizontalAccuracy {
    MiOSLocationManager *locMgr = [MiOSLocationManager sharedManager];
    if ([locMgr shouldSpoofForBundleID:currentBundleID()]) {
        return locMgr.spoofedAccuracy;
    }
    return %orig;
}

%end

%end // LocationHooks

// MARK: - Device Spoofing Hooks (like Ghost)

%group DeviceSpoofHooks

%hook UIDevice

- (NSString *)systemVersion {
    NSString *ver = spoofedIOSVersion();
    return ver.length > 0 ? ver : %orig;
}

- (NSString *)model {
    if (deviceSpoofEnabled() && spoofedDeviceName().length > 0) return @"iPhone";
    return %orig;
}

- (NSString *)localizedModel {
    if (deviceSpoofEnabled() && spoofedDeviceName().length > 0) return @"iPhone";
    return %orig;
}

- (NSString *)name {
    NSString *name = spoofedDeviceName();
    return name.length > 0 ? name : %orig;
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSString *ver = spoofedIOSVersion();
    if (ver.length > 0) {
        NSArray *parts = [ver componentsSeparatedByString:@"."];
        NSOperatingSystemVersion v;
        v.majorVersion = parts.count > 0 ? [parts[0] integerValue] : 0;
        v.minorVersion = parts.count > 1 ? [parts[1] integerValue] : 0;
        v.patchVersion = parts.count > 2 ? [parts[2] integerValue] : 0;
        return v;
    }
    return %orig;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    NSString *ver = spoofedIOSVersion();
    if (ver.length > 0) {
        NSOperatingSystemVersion spoofed = [self operatingSystemVersion];
        if (spoofed.majorVersion > version.majorVersion) return YES;
        if (spoofed.majorVersion < version.majorVersion) return NO;
        if (spoofed.minorVersion > version.minorVersion) return YES;
        if (spoofed.minorVersion < version.minorVersion) return NO;
        return spoofed.patchVersion >= version.patchVersion;
    }
    return %orig;
}

%end

%end // DeviceSpoofHooks

// MARK: - Identifier Spoofing Hooks (per-container, like Ghost)

%group IdentifierSpoofHooks

%hook UIDevice

- (NSUUID *)identifierForVendor {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofVendorID"] boolValue]) {
        NSString *vid = sp[@"vendorID"];
        if (vid.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:vid];
            if (uuid) return uuid;
        }
    }
    return %orig;
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofAdvertisingID"] boolValue]) {
        NSString *aid = sp[@"advertisingID"];
        if (aid.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:aid];
            if (uuid) return uuid;
        }
    }
    return %orig;
}

- (BOOL)isAdvertisingTrackingEnabled {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofAdvertisingID"] boolValue]) return NO;
    return %orig;
}

%end

%hook DCDevice

- (BOOL)isSupported {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofDeviceCheck"] boolValue]) return NO;
    return %orig;
}

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofDeviceCheck"] boolValue]) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"DCErrorDomain" code:1 userInfo:@{
                NSLocalizedDescriptionKey: @"DeviceCheck is not supported on this device"
            }];
            completion(nil, error);
        }
        return;
    }
    %orig;
}

%end

%hook NSFileManager

- (id)ubiquityIdentityToken {
    NSDictionary *sp = cachedContainerSpoofPrefs();
    if ([sp[@"spoofCloudToken"] boolValue]) return nil;
    return %orig;
}

%end

%end // IdentifierSpoofHooks

// MARK: - sysctlbyname hook for hw.machine / hw.model

static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

static int hook_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (ret != 0 || !oldp || !oldlenp || !deviceSpoofEnabled()) return ret;

    if (strcmp(name, "hw.machine") == 0) {
        NSString *ident = spoofedDeviceIdentifier();
        if (ident.length > 0) {
            const char *cstr = [ident UTF8String];
            size_t len = strlen(cstr) + 1;
            if (*oldlenp >= len) {
                memcpy(oldp, cstr, len);
                *oldlenp = len;
            }
        }
    } else if (strcmp(name, "hw.model") == 0) {
        NSString *hw = spoofedHWModel();
        if (hw.length > 0) {
            const char *cstr = [hw UTF8String];
            size_t len = strlen(cstr) + 1;
            if (*oldlenp >= len) {
                memcpy(oldp, cstr, len);
                *oldlenp = len;
            }
        }
    }
    return ret;
}

// MARK: - MobileGestalt hook

static MGCopyAnswer_t orig_MGCopyAnswer = NULL;

static CFTypeRef hook_MGCopyAnswer(CFStringRef key) {
    if (deviceSpoofEnabled() && key) {
        NSString *k = (__bridge NSString *)key;

        if ([k isEqualToString:@"ProductType"] || [k isEqualToString:@"HWModelStr"]) {
            NSString *ident = spoofedDeviceIdentifier();
            if (ident.length > 0) return (__bridge_retained CFTypeRef)[ident copy];
        }
        if ([k isEqualToString:@"DeviceName"] || [k isEqualToString:@"marketing-name"] || [k isEqualToString:@"UserAssignedDeviceName"]) {
            NSString *name = spoofedDeviceName();
            if (name.length > 0) return (__bridge_retained CFTypeRef)[name copy];
        }
        if ([k isEqualToString:@"HardwarePlatform"]) {
            NSString *hw = spoofedHWModel();
            if (hw.length > 0) return (__bridge_retained CFTypeRef)[hw copy];
        }
        if ([k isEqualToString:@"ProductVersion"]) {
            NSString *ver = spoofedIOSVersion();
            if (ver.length > 0) return (__bridge_retained CFTypeRef)[ver copy];
        }
    }
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(key) : NULL;
}

// MARK: - Constructor

%ctor {
    @autoreleasepool {
        if (!isMiOSEnabled()) return;

        NSString *bid = currentBundleID();
        if ([bid isEqualToString:@"com.mios.app"]) return;

        applySandyProfile("MiOS-Profile");

        NSDictionary *prefs = appPrefs();
        BOOL containerEnabled = [prefs[@"containerEnabled"] boolValue];
        BOOL locationEnabled = [[MiOSLocationManager sharedManager] shouldSpoofForBundleID:bid];

        if (containerEnabled) {
            %init(ContainerHooks);
        }

        if (locationEnabled) {
            %init(LocationHooks);
        }

        if (deviceSpoofEnabled()) {
            %init(DeviceSpoofHooks);

            MSHookFunction((void *)sysctlbyname, (void *)hook_sysctlbyname, (void **)&orig_sysctlbyname);

            void *mgHandle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
            if (!mgHandle) mgHandle = dlopen("/var/jb/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
            if (mgHandle) {
                MGCopyAnswer_t mgFn = (MGCopyAnswer_t)dlsym(mgHandle, "MGCopyAnswer");
                if (mgFn) {
                    MSHookFunction((void *)mgFn, (void *)hook_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
                }
            }
        }

        NSDictionary *containerSpoof = cachedContainerSpoofPrefs();
        BOOL needIdHooks = [containerSpoof[@"spoofVendorID"] boolValue] ||
                           [containerSpoof[@"spoofAdvertisingID"] boolValue] ||
                           [containerSpoof[@"spoofDeviceCheck"] boolValue] ||
                           [containerSpoof[@"spoofCloudToken"] boolValue];
        if (needIdHooks) {
            %init(IdentifierSpoofHooks);
        }
    }
}
