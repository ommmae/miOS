#import <Foundation/Foundation.h>

// Mints real OS data containers (via MobileContainerManager) so each miOS container is a genuine
// stock-like container, instead of a subfolder inside the app's own container.
@interface MiOSContainerMint : NSObject
// Returns the real container home path for (bundleID, logical container id), minting a new OS
// container the first time and persisting the mapping. Returns nil on failure.
+ (NSString *)realHomeForBundle:(NSString *)bundleID logicalID:(NSString *)logicalID;
@end
