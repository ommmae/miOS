#import <Foundation/Foundation.h>

@interface MiOSContainerModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, assign) BOOL isDefault;
@property (nonatomic, copy) NSString *path;
- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name bundleID:(NSString *)bundleID;
@end

@interface MiOSContainerManager : NSObject
+ (instancetype)sharedManager;
- (NSArray<MiOSContainerModel *> *)containersForBundleID:(NSString *)bundleID;
- (MiOSContainerModel *)activeContainerForBundleID:(NSString *)bundleID;
- (MiOSContainerModel *)createContainerForBundleID:(NSString *)bundleID name:(NSString *)name;
- (BOOL)switchToContainer:(NSString *)containerID forBundleID:(NSString *)bundleID;
- (BOOL)deleteContainer:(NSString *)containerID forBundleID:(NSString *)bundleID;
- (NSString *)redirectedPathForPath:(NSString *)originalPath bundleID:(NSString *)bundleID;
- (void)setupContainerDirectories:(NSString *)containerPath;
- (NSDictionary *)spoofPrefsForBundleID:(NSString *)bundleID;
@end
