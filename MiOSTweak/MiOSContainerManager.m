#import "MiOSContainerManager.h"

static NSString *const kMiOSBasePath = @"/var/mobile/Library/Preferences/MiOS";
static NSString *const kMiOSContainerPrefsFile = @"com.mios.containerprefs.plist";
static NSString *const kMiOSSpoofPrefsFile = @".mios_spoof_prefs.plist";

@implementation MiOSContainerManager

+ (instancetype)sharedManager {
    static MiOSContainerManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[MiOSContainerManager alloc] init]; });
    return shared;
}

- (NSString *)activeContainerUUIDForBundleID:(NSString *)bundleID {
    if (bundleID.length == 0) return nil;
    NSString *prefsPath = [kMiOSBasePath stringByAppendingPathComponent:kMiOSContainerPrefsFile];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
    NSDictionary *active = prefs[@"activeContainers"];
    NSString *uuid = active[bundleID];
    if (uuid.length == 0 || [uuid isEqualToString:@"DEFAULT"]) return nil;
    return uuid;
}

- (NSString *)containerDirForBundleID:(NSString *)bundleID uuid:(NSString *)uuid {
    return [[[kMiOSBasePath stringByAppendingPathComponent:@"Containers"]
             stringByAppendingPathComponent:bundleID]
            stringByAppendingPathComponent:uuid];
}

- (NSString *)homePathForBundleID:(NSString *)bundleID ensureCreated:(BOOL)create {
    NSString *uuid = [self activeContainerUUIDForBundleID:bundleID];
    if (!uuid) return nil;

    NSString *dir = [self containerDirForBundleID:bundleID uuid:uuid];
    if (create) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *subdirs = @[@"Documents", @"Library", @"Library/Preferences", @"Library/Caches",
                             @"Library/Application Support", @"Library/Cookies", @"Library/SplashBoard",
                             @"SystemData", @"tmp", @"StoreKit"];
        for (NSString *sub in subdirs) {
            [fm createDirectoryAtPath:[dir stringByAppendingPathComponent:sub]
          withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return dir;
}

- (NSDictionary *)spoofPrefsForBundleID:(NSString *)bundleID {
    NSString *uuid = [self activeContainerUUIDForBundleID:bundleID];
    if (!uuid) return @{};
    NSString *path = [[self containerDirForBundleID:bundleID uuid:uuid]
                      stringByAppendingPathComponent:kMiOSSpoofPrefsFile];
    return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
}

@end
