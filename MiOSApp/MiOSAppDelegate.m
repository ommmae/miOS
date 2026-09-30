#import "MiOSAppDelegate.h"
#import "Views/MiOSLoadingView.h"
#import "Controllers/MiOSHomeViewController.h"

@implementation MiOSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    MiOSHomeViewController *homeVC = [[MiOSHomeViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    nav.navigationBar.prefersLargeTitles = YES;
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.tintColor = [UIColor systemCyanColor];

    self.window.rootViewController = nav;
    self.window.tintColor = [UIColor systemCyanColor];
    [self.window makeKeyAndVisible];

    // Add loading view on top of everything
    MiOSLoadingView *loadingView = [[MiOSLoadingView alloc] initWithFrame:self.window.bounds];
    loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.window addSubview:loadingView];

    __weak typeof(loadingView) weakLoading = loadingView;
    loadingView.onComplete = ^{
        [weakLoading removeFromSuperview];
    };

    [loadingView startAnimation];

    return YES;
}

@end
