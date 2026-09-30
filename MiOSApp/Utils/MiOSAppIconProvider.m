#import "MiOSAppIconProvider.h"
#import "MiOSColorExtractor.h"
#import "../Models/MiOSAppInfo.h"
#import "../UI/MiOSTheme.h"

@interface UIImage (MiOSIconPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@implementation MiOSAppIconProvider

+ (NSCache *)iconCache {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
    return cache;
}

+ (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (bundleID.length == 0) return nil;
    UIImage *img = [[self iconCache] objectForKey:bundleID];
    if (img) return img;

    img = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:[UIScreen mainScreen].scale];
    if (!img) {
        for (MiOSAppInfo *app in [MiOSAppInfo allApps]) {
            if ([app.bundleID isEqualToString:bundleID]) {
                img = app.icon;
                break;
            }
        }
    }
    if (img) [[self iconCache] setObject:img forKey:bundleID];
    return img;
}

+ (UIColor *)accentForBundleIDs:(NSArray<NSString *> *)bundleIDs {
    UIImage *icon = bundleIDs.count > 0 ? [self iconForBundleID:bundleIDs.firstObject] : nil;
    UIColor *color = icon ? [MiOSColorExtractor vibrantColorFromImage:icon] : nil;
    return color ?: [MiOSTheme accentColor];
}

@end
