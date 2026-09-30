#import "MiOSContainerManager.h"
#import <objc/runtime.h>

static NSString *const kMiOSContainerBasePath = @"/var/mobile/Library/Preferences/MiOS";
static NSString *const kMiOSContainerDirName = @"___MiOS_Containers";
static NSString *const kMiOSPrefsFile = @"com.mios.containerprefs.plist";

@implementation MiOSContainerModel

- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name bundleID:(NSString *)bundleID {
    if (self = [super init]) {
        _identifier = [identifier copy];
        _name = [name copy];
        _bundleID = [bundleID copy];
        _isDefault = [identifier isEqualToString:@"DEFAULT"];
    }
    return self;
}

@end

@implementation MiOSContainerManager {
    NSMutableDictionary *_containerCache;
    NSMutableDictionary *_activeContainers;
}

+ (instancetype)sharedManager {
    static MiOSContainerManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MiOSContainerManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _containerCache = [NSMutableDictionary new];
        _activeContainers = [NSMutableDictionary new];
        [self loadPreferences];
    }
    return self;
}

- (void)loadPreferences {
    NSString *prefsPath = [kMiOSContainerBasePath stringByAppendingPathComponent:kMiOSPrefsFile];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
    if (prefs[@"activeContainers"]) {
        [_activeContainers setDictionary:prefs[@"activeContainers"]];
    }
}

- (void)savePreferences {
    NSString *prefsPath = [kMiOSContainerBasePath stringByAppendingPathComponent:kMiOSPrefsFile];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:kMiOSContainerBasePath]) {
        [fm createDirectoryAtPath:kMiOSContainerBasePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSDictionary *prefs = @{@"activeContainers": _activeContainers};
    [prefs writeToFile:prefsPath atomically:YES];
}

- (NSString *)containerBasePathForBundleID:(NSString *)bundleID {
    NSString *appDataPath = [self appDataPathForBundleID:bundleID];
    if (!appDataPath) return nil;
    return [appDataPath stringByAppendingPathComponent:kMiOSContainerDirName];
}

- (NSString *)appDataPathForBundleID:(NSString *)bundleID {
    NSString *containersPath = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:containersPath error:nil];
    for (NSString *uuid in contents) {
        NSString *metaPath = [[containersPath stringByAppendingPathComponent:uuid]
                              stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        if ([meta[@"MCMMetadataIdentifier"] isEqualToString:bundleID]) {
            return [containersPath stringByAppendingPathComponent:uuid];
        }
    }
    return nil;
}

- (NSArray<MiOSContainerModel *> *)containersForBundleID:(NSString *)bundleID {
    NSMutableArray *containers = [NSMutableArray new];
    MiOSContainerModel *defaultContainer = [[MiOSContainerModel alloc] initWithIdentifier:@"DEFAULT" name:@"Default" bundleID:bundleID];
    defaultContainer.path = [self appDataPathForBundleID:bundleID];
    [containers addObject:defaultContainer];

    NSString *basePath = [self containerBasePathForBundleID:bundleID];
    if (!basePath) return containers;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = [fm contentsOfDirectoryAtPath:basePath error:nil];
    for (NSString *dir in dirs) {
        NSString *containerPath = [basePath stringByAppendingPathComponent:dir];
        NSString *metaFile = [containerPath stringByAppendingPathComponent:@".mios_container_meta.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaFile];
        NSString *name = meta[@"name"] ?: dir;
        MiOSContainerModel *model = [[MiOSContainerModel alloc] initWithIdentifier:dir name:name bundleID:bundleID];
        model.path = containerPath;
        [containers addObject:model];
    }
    return containers;
}

- (MiOSContainerModel *)activeContainerForBundleID:(NSString *)bundleID {
    NSString *activeID = _activeContainers[bundleID];
    if (!activeID || [activeID isEqualToString:@"DEFAULT"]) {
        return [[MiOSContainerModel alloc] initWithIdentifier:@"DEFAULT" name:@"Default" bundleID:bundleID];
    }
    NSArray *containers = [self containersForBundleID:bundleID];
    for (MiOSContainerModel *c in containers) {
        if ([c.identifier isEqualToString:activeID]) return c;
    }
    return containers.firstObject;
}

- (MiOSContainerModel *)createContainerForBundleID:(NSString *)bundleID name:(NSString *)name {
    NSString *basePath = [self containerBasePathForBundleID:bundleID];
    if (!basePath) return nil;

    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *containerPath = [basePath stringByAppendingPathComponent:uuid];
    [self setupContainerDirectories:containerPath];

    NSDictionary *meta = @{@"name": name, @"createdAt": [NSDate date].description, @"bundleID": bundleID};
    NSString *metaFile = [containerPath stringByAppendingPathComponent:@".mios_container_meta.plist"];
    [meta writeToFile:metaFile atomically:YES];

    MiOSContainerModel *model = [[MiOSContainerModel alloc] initWithIdentifier:uuid name:name bundleID:bundleID];
    model.path = containerPath;
    return model;
}

- (void)setupContainerDirectories:(NSString *)containerPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *subdirs = @[@"Documents", @"Library", @"Library/Preferences", @"Library/Caches",
                         @"Library/Application Support", @"Library/SplashBoard", @"SystemData", @"tmp"];
    for (NSString *sub in subdirs) {
        [fm createDirectoryAtPath:[containerPath stringByAppendingPathComponent:sub]
      withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (BOOL)switchToContainer:(NSString *)containerID forBundleID:(NSString *)bundleID {
    _activeContainers[bundleID] = containerID;
    [self savePreferences];
    return YES;
}

- (BOOL)deleteContainer:(NSString *)containerID forBundleID:(NSString *)bundleID {
    if ([containerID isEqualToString:@"DEFAULT"]) return NO;
    NSString *basePath = [self containerBasePathForBundleID:bundleID];
    NSString *containerPath = [basePath stringByAppendingPathComponent:containerID];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    [fm removeItemAtPath:containerPath error:&error];
    if ([_activeContainers[bundleID] isEqualToString:containerID]) {
        _activeContainers[bundleID] = @"DEFAULT";
    }
    [self savePreferences];
    return error == nil;
}

- (NSDictionary *)spoofPrefsForBundleID:(NSString *)bundleID {
    MiOSContainerModel *active = [self activeContainerForBundleID:bundleID];
    if (!active) return @{};
    NSString *metaPath;
    if (active.isDefault) {
        NSString *appDataPath = [self appDataPathForBundleID:bundleID];
        if (!appDataPath) return @{};
        metaPath = [appDataPath stringByAppendingPathComponent:@".mios_spoof_prefs.plist"];
    } else {
        metaPath = [active.path stringByAppendingPathComponent:@".mios_spoof_prefs.plist"];
    }
    return [NSDictionary dictionaryWithContentsOfFile:metaPath] ?: @{};
}

- (NSString *)redirectedPathForPath:(NSString *)originalPath bundleID:(NSString *)bundleID {
    MiOSContainerModel *active = [self activeContainerForBundleID:bundleID];
    if (!active || active.isDefault) return originalPath;

    NSString *appDataPath = [self appDataPathForBundleID:bundleID];
    if (!appDataPath || ![originalPath hasPrefix:appDataPath]) return originalPath;

    NSString *relativePath = [originalPath substringFromIndex:appDataPath.length];
    if ([relativePath hasPrefix:@"/"]) relativePath = [relativePath substringFromIndex:1];

    if ([relativePath hasPrefix:kMiOSContainerDirName]) return originalPath;

    return [active.path stringByAppendingPathComponent:relativePath];
}

@end
