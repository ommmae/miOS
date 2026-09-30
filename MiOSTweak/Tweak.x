#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import "MiOSContainerManager.h"
#import "MiOSLocationManager.h"

extern void libSandy_applyProfile(const char *profileName);

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

// MARK: - Constructor

%ctor {
    @autoreleasepool {
        if (!isMiOSEnabled()) return;

        NSString *bid = currentBundleID();
        if ([bid isEqualToString:@"com.mios.app"]) return;

        libSandy_applyProfile("MiOS-Profile");

        NSDictionary *prefs = appPrefs();
        BOOL containerEnabled = [prefs[@"containerEnabled"] boolValue];
        BOOL locationEnabled = [[MiOSLocationManager sharedManager] shouldSpoofForBundleID:bid];

        if (containerEnabled) {
            %init(ContainerHooks);
        }

        if (locationEnabled) {
            %init(LocationHooks);
        }
    }
}
