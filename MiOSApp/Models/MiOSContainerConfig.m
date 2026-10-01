#import "MiOSContainerConfig.h"

static NSString *const kContainersPlistPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containers.plist";

@interface MiOSContainerConfig ()
+ (NSString *)basePath;
+ (NSString *)containerDirForBundleID:(NSString *)bundleID uuid:(NSString *)uuid;
- (void)removeFromSystem;
- (NSDictionary *)spoofPrefsDictionary;
@end

@implementation MiOSContainerConfig

#pragma mark - Class Methods

+ (NSString *)_ensureDirectoryForPath:(NSString *)path {
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}

+ (NSDictionary *)_readPlist {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:kContainersPlistPath]) {
        return [NSDictionary dictionaryWithContentsOfFile:kContainersPlistPath] ?: @{};
    }
    return @{};
}

+ (void)_writePlist:(NSDictionary *)dict {
    [self _ensureDirectoryForPath:kContainersPlistPath];
    [dict writeToFile:kContainersPlistPath atomically:YES];
}

+ (NSArray<MiOSContainerConfig *> *)loadAll {
    NSDictionary *plist = [self _readPlist];
    NSArray *containerDicts = plist[@"containers"] ?: @[];

    NSMutableArray<MiOSContainerConfig *> *result = [NSMutableArray array];
    for (NSDictionary *dict in containerDicts) {
        MiOSContainerConfig *config = [[MiOSContainerConfig alloc] initWithDictionary:dict];
        [result addObject:config];
    }
    return [result copy];
}

+ (void)saveAll:(NSArray<MiOSContainerConfig *> *)containers {
    NSMutableArray *dicts = [NSMutableArray array];
    for (MiOSContainerConfig *config in containers) {
        [dicts addObject:[config toDictionary]];
    }

    NSDictionary *plist = [self _readPlist];
    NSMutableDictionary *updated = [plist mutableCopy];
    updated[@"containers"] = dicts;
    [self _writePlist:updated];
}

+ (NSString *)activeContainerID {
    NSDictionary *plist = [self _readPlist];
    return plist[@"activeContainerID"];
}

+ (void)setActiveContainerID:(NSString *)containerID {
    NSMutableDictionary *plist = [[self _readPlist] mutableCopy];
    if (containerID) {
        plist[@"activeContainerID"] = containerID;
    } else {
        [plist removeObjectForKey:@"activeContainerID"];
    }
    [self _writePlist:plist];
}

+ (MiOSContainerConfig *)activeContainer {
    NSArray<MiOSContainerConfig *> *all = [self loadAll];
    NSString *activeID = [self activeContainerID];
    for (MiOSContainerConfig *c in all) {
        if ([c.identifier isEqualToString:activeID]) return c;
    }
    return all.firstObject;
}

+ (void)removeContainerWithID:(NSString *)containerID {
    if (containerID.length == 0) return;
    NSMutableArray<MiOSContainerConfig *> *all = [[self loadAll] mutableCopy];
    MiOSContainerConfig *removed = nil;
    for (MiOSContainerConfig *c in all) {
        if ([c.identifier isEqualToString:containerID]) {
            removed = c;
            break;
        }
    }
    if (!removed) return;

    [removed removeFromSystem];
    [all removeObject:removed];
    [self saveAll:all];

    if ([[self activeContainerID] isEqualToString:containerID]) {
        MiOSContainerConfig *next = all.firstObject;
        [self setActiveContainerID:next.identifier];
        [next applyToSystem];
    }
}

- (void)removeFromSystem {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *containerPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containerprefs.plist";
    NSMutableDictionary *containerPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:containerPrefsPath];
    NSMutableDictionary *activeContainers = [NSMutableDictionary dictionaryWithDictionary:containerPrefs[@"activeContainers"] ?: @{}];

    for (NSString *bundleID in self.apps) {
        if ([activeContainers[bundleID] isEqualToString:self.identifier]) {
            [activeContainers removeObjectForKey:bundleID];
        }
        if (self.identifier.length > 0) {
            NSString *containerDir = [[self class] containerDirForBundleID:bundleID uuid:self.identifier];
            [fm removeItemAtPath:containerDir error:nil];
        }
    }

    if (containerPrefs) {
        containerPrefs[@"activeContainers"] = activeContainers;
        [containerPrefs writeToFile:containerPrefsPath atomically:YES];
    }
}

#pragma mark - Serialization

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _identifier = dict[@"id"] ?: [[NSUUID UUID] UUIDString];
        _name = dict[@"name"] ?: @"Untitled";
        _apps = [NSMutableArray arrayWithArray:dict[@"apps"] ?: @[]];

        // GPS
        _gpsEnabled = [dict[@"gpsEnabled"] boolValue];
        _latitude = [dict[@"latitude"] doubleValue];
        _longitude = [dict[@"longitude"] doubleValue];
        _locationName = dict[@"locationName"] ?: @"";

        // Device
        _deviceSpoofEnabled = [dict[@"deviceSpoofEnabled"] boolValue];
        _deviceIdentifier = dict[@"deviceIdentifier"] ?: @"";
        _deviceName = dict[@"deviceName"] ?: @"";
        _hwModel = dict[@"hwModel"] ?: @"";
        _iosVersion = dict[@"iosVersion"] ?: @"";
        _storageSizeGB = [dict[@"storageSizeGB"] integerValue];
        _customDeviceName = dict[@"customDeviceName"] ?: @"";
        _spoofDeviceName = [dict[@"spoofDeviceName"] boolValue];

        // Identifiers
        _spoofDeviceCheck = [dict[@"spoofDeviceCheck"] boolValue];
        _spoofVendorID = [dict[@"spoofVendorID"] boolValue];
        _vendorID = dict[@"vendorID"] ?: @"";
        _spoofAdvertisingID = [dict[@"spoofAdvertisingID"] boolValue];
        _advertisingID = dict[@"advertisingID"] ?: @"";
        _spoofCloudToken = [dict[@"spoofCloudToken"] boolValue];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"id": self.identifier ?: @"",
        @"name": self.name ?: @"",
        @"apps": self.apps ?: @[],
        @"gpsEnabled": @(self.gpsEnabled),
        @"latitude": @(self.latitude),
        @"longitude": @(self.longitude),
        @"locationName": self.locationName ?: @"",
        @"deviceSpoofEnabled": @(self.deviceSpoofEnabled),
        @"deviceIdentifier": self.deviceIdentifier ?: @"",
        @"deviceName": self.deviceName ?: @"",
        @"hwModel": self.hwModel ?: @"",
        @"iosVersion": self.iosVersion ?: @"",
        @"storageSizeGB": @(self.storageSizeGB),
        @"customDeviceName": self.customDeviceName ?: @"",
        @"spoofDeviceName": @(self.spoofDeviceName),
        @"spoofDeviceCheck": @(self.spoofDeviceCheck),
        @"spoofVendorID": @(self.spoofVendorID),
        @"vendorID": self.vendorID ?: @"",
        @"spoofAdvertisingID": @(self.spoofAdvertisingID),
        @"advertisingID": self.advertisingID ?: @"",
        @"spoofCloudToken": @(self.spoofCloudToken),
    };
}

#pragma mark - Apply to System

+ (NSString *)basePath {
    return @"/var/mobile/Library/Preferences/MiOS";
}

// Central, sandbox-reachable location (libSandy grants RW to the MiOS base path).
+ (NSString *)containerDirForBundleID:(NSString *)bundleID uuid:(NSString *)uuid {
    return [[[[self basePath] stringByAppendingPathComponent:@"Containers"]
             stringByAppendingPathComponent:bundleID]
            stringByAppendingPathComponent:uuid];
}

- (NSDictionary *)spoofPrefsDictionary {
    return @{
        @"spoofDeviceCheck": @(self.spoofDeviceCheck),
        @"spoofVendorID": @(self.spoofVendorID),
        @"vendorID": self.vendorID ?: @"",
        @"spoofAdvertisingID": @(self.spoofAdvertisingID),
        @"advertisingID": self.advertisingID ?: @"",
        @"spoofCloudToken": @(self.spoofCloudToken),
        @"gpsEnabled": @(self.gpsEnabled),
        @"latitude": @(self.latitude),
        @"longitude": @(self.longitude),
        @"deviceSpoofEnabled": @(self.deviceSpoofEnabled),
        @"deviceIdentifier": self.deviceIdentifier ?: @"",
        @"deviceName": self.deviceName ?: @"",
        @"hwModel": self.hwModel ?: @"",
        @"iosVersion": self.iosVersion ?: @"",
        @"storageSizeGB": @(self.storageSizeGB),
        @"customDeviceName": self.customDeviceName ?: @"",
        @"spoofDeviceName": @(self.spoofDeviceName),
    };
}

- (void)applyToSystem {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [[self class] basePath];
    NSString *appPlistDir = [base stringByAppendingPathComponent:@"apps"];
    [fm createDirectoryAtPath:appPlistDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *containerPrefsPath = [base stringByAppendingPathComponent:@"com.mios.containerprefs.plist"];
    NSMutableDictionary *containerPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:containerPrefsPath] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *activeContainers = [NSMutableDictionary dictionaryWithDictionary:containerPrefs[@"activeContainers"] ?: @{}];

    NSDictionary *spoofPrefs = [self spoofPrefsDictionary];

    for (NSString *bundleID in self.apps) {
        // Mark the app as managed by MiOS.
        NSString *appPlistPath = [appPlistDir stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"%@.plist", bundleID]];
        [@{@"containerEnabled": @YES, @"enabled": @YES} writeToFile:appPlistPath atomically:YES];

        // Create the container skeleton centrally (the tweak redirects HOME here).
        NSString *containerDir = [[self class] containerDirForBundleID:bundleID uuid:self.identifier];
        NSArray *subdirs = @[@"Documents", @"Library", @"Library/Preferences", @"Library/Caches",
                             @"Library/Application Support", @"Library/Cookies", @"Library/SplashBoard",
                             @"SystemData", @"tmp", @"StoreKit"];
        for (NSString *subdir in subdirs) {
            [fm createDirectoryAtPath:[containerDir stringByAppendingPathComponent:subdir]
          withIntermediateDirectories:YES attributes:nil error:nil];
        }

        [@{@"name": self.name ?: @"", @"createdAt": [NSDate date].description, @"bundleID": bundleID}
            writeToFile:[containerDir stringByAppendingPathComponent:@".mios_container_meta.plist"] atomically:YES];
        [spoofPrefs writeToFile:[containerDir stringByAppendingPathComponent:@".mios_spoof_prefs.plist"] atomically:YES];

        activeContainers[bundleID] = self.identifier;
    }

    containerPrefs[@"activeContainers"] = activeContainers;
    [containerPrefs writeToFile:containerPrefsPath atomically:YES];
}

@end
