#import <UIKit/UIKit.h>

@interface MiOSAppIconProvider : NSObject
+ (UIImage *)iconForBundleID:(NSString *)bundleID;
// Vibrant color from the first app's icon, or the theme accent.
+ (UIColor *)accentForBundleIDs:(NSArray<NSString *> *)bundleIDs;
@end
