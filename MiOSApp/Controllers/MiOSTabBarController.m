#import "MiOSTabBarController.h"
#import "MiOSHomeViewController.h"
#import "MiOSContainerListViewController.h"
#import "MiOSCloudViewController.h"
#import "MiOSProxiesViewController.h"
#import "MiOSSettingsViewController.h"
#import "../UI/MiOSTheme.h"

@implementation MiOSTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewControllers = @[
        [self wrap:[[MiOSHomeViewController alloc] init]
             title:@"Home" icon:@"house.fill"],
        [self wrap:[[MiOSContainerListViewController alloc] init]
             title:@"Containers" icon:@"folder.fill"],
        [self wrap:[[MiOSCloudViewController alloc] init]
             title:@"Cloud" icon:@"cloud.fill"],
        [self wrap:[[MiOSProxiesViewController alloc] init]
             title:@"Proxies" icon:@"wifi"],
        [self wrap:[[MiOSSettingsViewController alloc] init]
             title:@"Settings" icon:@"gearshape.fill"],
    ];

    [self styleTabBar];
}

- (UINavigationController *)wrap:(UIViewController *)vc title:(NSString *)title icon:(NSString *)icon {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.prefersLargeTitles = YES;
    nav.navigationBar.tintColor = [MiOSTheme accentColor];
    [MiOSTheme styleNavigationBar:nav.navigationBar];

    UIImage *img = [UIImage systemImageNamed:icon];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:img selectedImage:img];
    return nav;
}

- (void)styleTabBar {
    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    appearance.backgroundColor = [[MiOSTheme secondaryBackground] colorWithAlphaComponent:0.75];
    appearance.shadowColor = [MiOSTheme accentBorderColor];

    UIColor *accent = [MiOSTheme accentColor];
    UIColor *inactive = [MiOSTheme tertiaryText];

    void (^styleItem)(UITabBarItemAppearance *) = ^(UITabBarItemAppearance *item) {
        item.selected.iconColor = accent;
        item.selected.titleTextAttributes = @{
            NSForegroundColorAttributeName: accent,
            NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold],
        };
        item.normal.iconColor = inactive;
        item.normal.titleTextAttributes = @{
            NSForegroundColorAttributeName: inactive,
            NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium],
        };
    };
    styleItem(appearance.stackedLayoutAppearance);
    styleItem(appearance.inlineLayoutAppearance);
    styleItem(appearance.compactInlineLayoutAppearance);

    self.tabBar.standardAppearance = appearance;
    self.tabBar.scrollEdgeAppearance = appearance;
    self.tabBar.tintColor = accent;
    self.tabBar.unselectedItemTintColor = inactive;

    // Subtle top hairline + glow to give the textured floating look
    self.tabBar.layer.borderWidth = 0.5;
    self.tabBar.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    self.tabBar.layer.shadowColor = [MiOSTheme accentColor].CGColor;
    self.tabBar.layer.shadowOffset = CGSizeMake(0, -2);
    self.tabBar.layer.shadowRadius = 12;
    self.tabBar.layer.shadowOpacity = 0.12;
}

@end
