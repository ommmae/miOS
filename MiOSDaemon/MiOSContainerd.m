// miosd — privileged container daemon.
//
// Runs as root. Creates / switches / deletes REAL OS data containers via MobileContainerManager
// (the same engine Crane drives through cranehelperd). The app/tweak never redirects HOME in-process
// (that triggers the data-protection mach-port guard crash); instead this daemon reassigns the app's
// data container at the system level, and the app is relaunched into it.
//
// Trigger: the app writes a request plist and posts a Darwin notification; we execute and post back.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import <spawn.h>
#import <unistd.h>

extern char **environ;

// --- Private MobileContainerManager surface ---
@interface MCMContainer : NSObject
@property (readonly, nonatomic) NSUUID *uuid;
@property (readonly, nonatomic) NSURL *url;
- (instancetype)initWithIdentifier:(NSString *)identifier path:(NSString *)path
                uniquePathComponent:(NSString *)unique uuid:(NSUUID *)uuid
                personaUniqueString:(NSString *)persona error:(NSError **)error;
- (BOOL)recreateDefaultStructureWithError:(NSError **)error;
- (id)destroyContainerWithCompletion:(id)completion;
@end
@interface MCMAppDataContainer : MCMContainer @end
@interface MCMContainerManager : NSObject
+ (instancetype)defaultManager;
- (BOOL)replaceContainer:(id)a withContainer:(id)b error:(NSError **)error;
@end

static NSString *const kBase = @"/var/mobile/Library/Preferences/MiOS";
static NSString *const kAppDataRoot = @"/var/mobile/Containers/Data/Application";
static NSString *const kRequestNote = @"com.mios.containerd.request";

static Class MCMAppDataClass(void) {
    static Class c; static dispatch_once_t t;
    dispatch_once(&t, ^{
        if (!objc_getClass("MCMAppDataContainer"))
            dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
        c = objc_getClass("MCMAppDataContainer");
    });
    return c;
}

static NSString *reqPath(void)  { return [kBase stringByAppendingPathComponent:@"daemon_request.plist"]; }
static NSString *respPath(NSString *token) {
    return [kBase stringByAppendingPathComponent:[NSString stringWithFormat:@"daemon_response_%@.plist", token]];
}

#pragma mark - Mapping (bundleID -> { logicalID -> realUUID })

static NSString *prefsPath(void) { return [kBase stringByAppendingPathComponent:@"com.mios.containerprefs.plist"]; }

static NSString *storedRealUUID(NSString *bid, NSString *lid) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:prefsPath()];
    return p[@"realUUIDs"][bid][lid];
}

static void storeRealUUID(NSString *bid, NSString *lid, NSString *real) {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath()] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *m = [p[@"realUUIDs"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *per = [m[bid] mutableCopy] ?: [NSMutableDictionary dictionary];
    per[lid] = real; m[bid] = per; p[@"realUUIDs"] = m;
    [p writeToFile:prefsPath() atomically:YES];
}

#pragma mark - MCM helpers

// Current assigned container for a bundle id (nil if none / createIfNecessary NO).
static MCMContainer *currentContainer(NSString *bid, BOOL create) {
    Class cls = MCMAppDataClass();
    if (!cls) return nil;
    BOOL existed = NO; NSError *err = nil;
    MCMContainer *(*send)(id, SEL, id, BOOL, BOOL *, NSError **) = (void *)objc_msgSend;
    return send(cls, @selector(containerWithIdentifier:createIfNecessary:existed:error:), bid, create, &existed, &err);
}

// Build a container object for a specific UUID/path (constructing its on-disk structure if new).
static MCMContainer *containerForUUID(NSString *bid, NSString *uuidStr, BOOL createStructure) {
    Class cls = MCMAppDataClass();
    if (!cls) return nil;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
    NSString *path = [kAppDataRoot stringByAppendingPathComponent:uuidStr];
    NSError *err = nil;
    MCMContainer *c = [[cls alloc] initWithIdentifier:bid path:path uniquePathComponent:uuidStr
                                                 uuid:uuid personaUniqueString:nil error:&err];
    if (c && createStructure) [c recreateDefaultStructureWithError:&err];
    return c;
}

#pragma mark - Operations

// Mint a brand-new empty real container; returns its UUID.
static NSString *opCreate(NSString *bid, NSString *lid) {
    NSString *uuidStr = [NSUUID UUID].UUIDString;
    MCMContainer *c = containerForUUID(bid, uuidStr, YES);
    if (!c) return nil;
    NSString *real = c.uuid.UUIDString ?: uuidStr;
    storeRealUUID(bid, lid, real);
    return real;
}

// Make a saved container the app's active (assigned) container by replacing the current one.
static BOOL opSwitch(NSString *bid, NSString *lid) {
    NSString *real = storedRealUUID(bid, lid);
    if (!real) real = opCreate(bid, lid);
    if (!real) return NO;

    MCMContainer *cur = currentContainer(bid, YES);
    MCMContainer *target = containerForUUID(bid, real, NO);
    if (!cur || !target) return NO;
    if ([cur.uuid.UUIDString isEqualToString:real]) return YES; // already active

    NSError *err = nil;
    MCMContainerManager *mgr = ((id (*)(id, SEL))objc_msgSend)(objc_getClass("MCMContainerManager"), @selector(defaultManager));
    return [mgr replaceContainer:cur withContainer:target error:&err];
}

static BOOL opDelete(NSString *bid, NSString *lid) {
    NSString *real = storedRealUUID(bid, lid);
    if (!real) return YES;
    MCMContainer *c = containerForUUID(bid, real, NO);
    if (c) [c destroyContainerWithCompletion:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[kAppDataRoot stringByAppendingPathComponent:real] error:nil];
    return YES;
}

#pragma mark - Request handling

static void relaunchApp(NSString *bid) {
    // Best-effort: kill the app so it relaunches into the reassigned container.
    const char *killall = "/var/jb/usr/bin/killall";
    if (access(killall, X_OK) != 0) killall = "/usr/bin/killall";
    pid_t pid; const char *args[] = { killall, bid.UTF8String, NULL };
    posix_spawn(&pid, killall, NULL, NULL, (char *const *)args, environ);
}

static void handleRequest(void) {
    @autoreleasepool {
        NSDictionary *req = [NSDictionary dictionaryWithContentsOfFile:reqPath()];
        if (!req) return;
        NSString *token = req[@"token"] ?: @"0";
        NSString *op = req[@"op"];
        NSString *lid = req[@"logicalID"];
        NSArray *apps = [req[@"apps"] isKindOfClass:[NSArray class]] ? req[@"apps"] : @[];
        BOOL relaunch = [req[@"relaunch"] boolValue];

        BOOL ok = (apps.count > 0);
        for (NSString *bid in apps) {
            if (![bid isKindOfClass:[NSString class]]) continue;
            if ([op isEqualToString:@"create"]) {
                ok = (opCreate(bid, lid) != nil) && ok;
            } else if ([op isEqualToString:@"switch"]) {
                BOOL s = opSwitch(bid, lid);
                ok = s && ok;
                if (s && relaunch) relaunchApp(bid);
            } else if ([op isEqualToString:@"delete"]) {
                ok = opDelete(bid, lid) && ok;
            }
        }

        NSDictionary *resp = @{ @"ok": @(ok), @"op": op ?: @"" };
        [resp writeToFile:respPath(token) atomically:YES];
        notify_post([NSString stringWithFormat:@"com.mios.containerd.done.%@", token].UTF8String);
    }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        int token = 0;
        notify_register_dispatch(kRequestNote.UTF8String, &token, dispatch_get_main_queue(), ^(int t) {
            handleRequest();
        });
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
