#import <Foundation/Foundation.h>

// The injected, in-Instagram control surface: a draggable floating button that opens the
// container manager (list / create-with-fingerprint+location / switch / delete).
@interface MiOSUI : NSObject
+ (void)install;     // safe to call once from the constructor; attaches when the UI is up
+ (void)present;     // open the manager over Instagram's current screen
@end
