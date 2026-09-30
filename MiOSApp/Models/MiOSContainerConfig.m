#import "MiOSContainerConfig.h"

static NSString *const kContainersPlistPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containers.plist";

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
        NSString *appDataPath = [self _findDataPathForBundleID:bundleID];
        if (appDataPath && self.identifier.length > 0) {
            NSString *containerDir = [[appDataPath stringByAppendingPathComponent:@"___MiOS_Containers"]
                                      stringByAppendingPathComponent:self.identifier];
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

- (void)applyToSystem {
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *bundleID in self.apps) {
        // 1. Write per-app plist to enable container
        NSString *appPlistDir = @"/var/mobile/Library/Preferences/MiOS/apps";
        [fm createDirectoryAtPath:appPlistDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *appPlistPath = [appPlistDir stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"%@.plist", bundleID]];
        NSDictionary *appPrefs = @{
            @"containerEnabled": @YES,
            @"enabled": @YES,
        };
        [appPrefs writeToFile:appPlistPath atomically:YES];

        // 2. Find the app's data container path
        NSString *appDataPath = [self _findDataPathForBundleID:bundleID];
        if (!appDataPath) continue;

        // 3. Create container directory structure
        NSString *containerBase = [appDataPath stringByAppendingPathComponent:@"___MiOS_Containers"];
        NSString *containerDir = [containerBase stringByAppendingPathComponent:self.identifier];

        NSArray *subdirs = @[
            @"Documents",
            @"Library",
            @"Library/Preferences",
            @"Library/Caches",
            @"Library/Application Support",
            @"Library/SplashBoard",
            @"SystemData",
            @"tmp",
        ];
        for (NSString *subdir in subdirs) {
            NSString *fullPath = [containerDir stringByAppendingPathComponent:subdir];
            [fm createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
        }

        // 4. Write container metadata plist
        NSString *metaPlistPath = [containerDir stringByAppendingPathComponent:@".mios_container_meta.plist"];
        NSDictionary *meta = @{
            @"name": self.name ?: @"",
            @"createdAt": [NSDate date].description,
            @"bundleID": bundleID,
        };
        [meta writeToFile:metaPlistPath atomically:YES];

        // 5. Write spoof preferences plist
        NSString *spoofPlistPath = [containerDir stringByAppendingPathComponent:@".mios_spoof_prefs.plist"];
        NSDictionary *spoofPrefs = @{
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
        [spoofPrefs writeToFile:spoofPlistPath atomically:YES];

        // 6. Update active containers mapping
        NSString *containerPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.containerprefs.plist";
        [fm createDirectoryAtPath:[containerPrefsPath stringByDeletingLastPathComponent]
      withIntermediateDirectories:YES attributes:nil error:nil];
        NSMutableDictionary *containerPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:containerPrefsPath] ?: [NSMutableDictionary dictionary];
        NSMutableDictionary *activeContainers = [NSMutableDictionary dictionaryWithDictionary:containerPrefs[@"activeContainers"] ?: @{}];
        activeContainers[bundleID] = self.identifier;
        containerPrefs[@"activeContainers"] = activeContainers;
        [containerPrefs writeToFile:containerPrefsPath atomically:YES];
    }

    // 7. Write device spoof prefs
    NSString *deviceSpoofPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.devicespoof.plist";
    [[self class] _ensureDirectoryForPath:deviceSpoofPath];
    NSDictionary *deviceSpoofPrefs = @{
        @"enabled": @(self.deviceSpoofEnabled),
        @"deviceIdentifier": self.deviceIdentifier ?: @"",
        @"deviceName": self.deviceName ?: @"",
        @"hwModel": self.hwModel ?: @"",
        @"iosVersion": self.iosVersion ?: @"",
        @"storageSizeGB": @(self.storageSizeGB),
        @"customDeviceName": self.customDeviceName ?: @"",
        @"spoofDeviceName": @(self.spoofDeviceName),
    };
    [deviceSpoofPrefs writeToFile:deviceSpoofPath atomically:YES];

    // 8. Write GPS prefs
    NSString *gpsPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.locationprefs.plist";
    [[self class] _ensureDirectoryForPath:gpsPrefsPath];
    NSDictionary *gpsPrefs = @{
        @"enabled": @(self.gpsEnabled),
        @"latitude": @(self.latitude),
        @"longitude": @(self.longitude),
    };
    [gpsPrefs writeToFile:gpsPrefsPath atomically:YES];
}

#pragma mark - Private Helpers

- (NSString *)_findDataPathForBundleID:(NSString *)bundleID {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *containersPath = @"/var/mobile/Containers/Data/Application";

    NSArray *uuids = [fm contentsOfDirectoryAtPath:containersPath error:nil];
    for (NSString *uuid in uuids) {
        NSString *uuidPath = [containersPath stringByAppendingPathComponent:uuid];
        NSString *metadataPath = [uuidPath stringByAppendingPathComponent:
                                  @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *identifier = metadata[@"MCMMetadataIdentifier"];
        if ([identifier isEqualToString:bundleID]) {
            return uuidPath;
        }
    }
    return nil;
}

@end
