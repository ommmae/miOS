#import "MiOSContainerMint.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// Minimal private MobileContainerManager surface (classdump, iOS 13-17 stable).
@interface MCMContainer : NSObject
@property (readonly, nonatomic) NSUUID *uuid;
@property (readonly, nonatomic) NSURL *url;
- (instancetype)initWithIdentifier:(NSString *)identifier path:(NSString *)path
                uniquePathComponent:(NSString *)unique uuid:(NSUUID *)uuid
                personaUniqueString:(NSString *)persona error:(NSError **)error;
- (BOOL)recreateDefaultStructureWithError:(NSError **)error;
+ (instancetype)containerWithIdentifier:(NSString *)identifier createIfNecessary:(BOOL)create
                                existed:(BOOL *)existed error:(NSError **)error;
@end
@interface MCMAppDataContainer : MCMContainer
@end

static NSString *const kBasePath = @"/var/mobile/Library/Preferences/MiOS";
static NSString *const kContainerPrefsFile = @"com.mios.containerprefs.plist";
static NSString *const kAppDataRoot = @"/var/mobile/Containers/Data/Application";

@implementation MiOSContainerMint

+ (Class)appDataContainerClass {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!objc_getClass("MCMAppDataContainer")) {
            dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
        }
        cls = objc_getClass("MCMAppDataContainer");
    });
    return cls;
}

#pragma mark - Mapping persistence (central, libSandy-granted)

+ (NSString *)prefsPath {
    return [kBasePath stringByAppendingPathComponent:kContainerPrefsFile];
}

+ (NSString *)storedRealUUIDForBundle:(NSString *)bundleID logicalID:(NSString *)logicalID {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self prefsPath]];
    NSDictionary *realMap = prefs[@"realUUIDs"];       // { bundleID: { logicalID: realUUID } }
    return realMap[bundleID][logicalID];
}

+ (void)storeRealUUID:(NSString *)realUUID forBundle:(NSString *)bundleID logicalID:(NSString *)logicalID {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:[self prefsPath]] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *realMap = [prefs[@"realUUIDs"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *perApp = [realMap[bundleID] mutableCopy] ?: [NSMutableDictionary dictionary];
    perApp[logicalID] = realUUID;
    realMap[bundleID] = perApp;
    prefs[@"realUUIDs"] = realMap;
    [prefs writeToFile:[self prefsPath] atomically:YES];
}

#pragma mark - Minting

+ (NSString *)realHomeForBundle:(NSString *)bundleID logicalID:(NSString *)logicalID {
    if (bundleID.length == 0 || logicalID.length == 0) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    // Reuse the previously-minted real container if it still exists.
    NSString *known = [self storedRealUUIDForBundle:bundleID logicalID:logicalID];
    if (known.length > 0) {
        NSString *path = [kAppDataRoot stringByAppendingPathComponent:known];
        if ([fm fileExistsAtPath:path]) return path;
    }

    Class cls = [self appDataContainerClass];
    if (!cls) return nil;

    // Mint a brand-new OS container at a fresh UUID path and let containermanagerd lay it out.
    NSUUID *uuid = [NSUUID UUID];
    NSString *uuidStr = uuid.UUIDString;
    NSString *path = [kAppDataRoot stringByAppendingPathComponent:uuidStr];

    NSError *err = nil;
    MCMContainer *container = ((MCMContainer *(*)(id, SEL, id, id, id, id, id, NSError **))objc_msgSend)(
        [cls alloc],
        @selector(initWithIdentifier:path:uniquePathComponent:uuid:personaUniqueString:error:),
        bundleID, path, uuidStr, uuid, nil, &err);
    if (!container) return nil;

    BOOL ok = ((BOOL(*)(id, SEL, NSError **))objc_msgSend)(
        container, @selector(recreateDefaultStructureWithError:), &err);

    NSString *finalPath = container.url.path ?: path;
    NSString *finalUUID = container.uuid.UUIDString ?: uuidStr;
    if (!ok && ![fm fileExistsAtPath:finalPath]) return nil;

    [self storeRealUUID:finalUUID forBundle:bundleID logicalID:logicalID];
    return finalPath;
}

@end
