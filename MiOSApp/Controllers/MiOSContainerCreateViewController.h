#import <UIKit/UIKit.h>

@class MiOSContainerConfig;

@interface MiOSContainerCreateViewController : UIViewController
@property (nonatomic, strong) MiOSContainerConfig *editingContainer;
@property (nonatomic, copy) void (^onSave)(void);
@end
