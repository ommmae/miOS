#import "MiOSHomeViewController.h"
#import "MiOSGPSViewController.h"
#import "MiOSContainerListViewController.h"
#import "MiOSContainerDetailViewController.h"
#import "MiOSAppListViewController.h"
#import "MiOSSettingsViewController.h"
#import "MiOSDeviceSpoofViewController.h"
#import "../Views/MiOSHeroBannerView.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"

static NSString *const kMiOSCorePrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist";

@interface MiOSHomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) MiOSHeroBannerView *heroBanner;
@property (nonatomic, strong) NSMutableDictionary *corePrefs;
@end

@implementation MiOSHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"miOS";
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    [MiOSTheme styleNavigationBar:self.navigationController.navigationBar];
    [self loadPreferences];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadPreferences];
    [_heroBanner setEnabled:[_corePrefs[@"enabled"] boolValue] animated:NO];
}

- (void)loadPreferences {
    _corePrefs = [[NSMutableDictionary dictionaryWithContentsOfFile:kMiOSCorePrefsPath] mutableCopy];
    if (!_corePrefs) {
        _corePrefs = [@{@"enabled": @YES} mutableCopy];
    }
}

- (void)savePreferences {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [kMiOSCorePrefsPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [_corePrefs writeToFile:kMiOSCorePrefsPath atomically:YES];
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _mainStack = [[UIStackView alloc] init];
    _mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mainStack.axis = UILayoutConstraintAxisVertical;
    _mainStack.spacing = 24;
    [_scrollView addSubview:_mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [_mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-32],
    ]];

    [self buildHeroBanner];
    [self buildNewContainerButton];
    [self buildModulesSection];
    [self buildInfoSection];
}

- (void)buildHeroBanner {
    _heroBanner = [[MiOSHeroBannerView alloc] init];
    [_heroBanner setEnabled:[_corePrefs[@"enabled"] boolValue] animated:NO];
    __weak typeof(self) weakSelf = self;
    _heroBanner.onToggle = ^(BOOL enabled) {
        weakSelf.corePrefs[@"enabled"] = @(enabled);
        [weakSelf savePreferences];
    };
    [_mainStack addArrangedSubview:_heroBanner];
}

- (void)buildNewContainerButton {
    UIView *btnContainer = [[UIView alloc] init];
    btnContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *btn = [[UIView alloc] init];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [MiOSTheme accentColor];
    btn.layer.cornerRadius = 14;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    [btnContainer addSubview:btn];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImageView *plusIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus" withConfiguration:config]];
    plusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    plusIcon.tintColor = [UIColor whiteColor];
    [btn addSubview:plusIcon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"New Container";
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    label.textColor = [UIColor whiteColor];
    [btn addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [btn.topAnchor constraintEqualToAnchor:btnContainer.topAnchor],
        [btn.leadingAnchor constraintEqualToAnchor:btnContainer.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:btnContainer.trailingAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:btnContainer.bottomAnchor],
        [btn.heightAnchor constraintEqualToConstant:50],
        [plusIcon.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:20],
        [plusIcon.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:plusIcon.trailingAnchor constant:8],
        [label.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(newContainerTapped:)];
    [btn addGestureRecognizer:tap];
    btn.userInteractionEnabled = YES;
    btn.tag = 100;

    [_mainStack addArrangedSubview:btnContainer];
}

- (void)newContainerTapped:(UITapGestureRecognizer *)sender {
    UIView *btn = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.97, 0.97);
        btn.alpha = 0.8;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            btn.transform = CGAffineTransformIdentity;
            btn.alpha = 1.0;
        } completion:nil];
    }];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Container"
                                                                  message:@"Select an app first to create a container for it."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Choose App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        MiOSContainerListViewController *vc = [[MiOSContainerListViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)buildModulesSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Modules"];

    __weak typeof(self) weakSelf = self;

    MiOSNavigationCell *gpsCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"GPS Spoofer"
             subtitle:@"Set custom location for apps"
                 icon:@"location.fill"
                color:[UIColor systemBlueColor]];
    gpsCell.tapAction = ^{
        MiOSGPSViewController *vc = [[MiOSGPSViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [section addCellView:gpsCell];
    [section addSeparator];

    MiOSNavigationCell *deviceCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"Device Spoof"
             subtitle:@"Change device model & iOS version"
                 icon:@"iphone.gen3"
                color:[UIColor systemTealColor]];
    deviceCell.tapAction = ^{
        MiOSDeviceSpoofViewController *vc = [[MiOSDeviceSpoofViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [section addCellView:deviceCell];
    [section addSeparator];

    MiOSNavigationCell *containerCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"Containers"
             subtitle:@"Manage app sandboxes and data"
                 icon:@"square.stack.3d.up.fill"
                color:[UIColor systemPurpleColor]];
    containerCell.tapAction = ^{
        MiOSContainerListViewController *vc = [[MiOSContainerListViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [section addCellView:containerCell];
    [section addSeparator];

    MiOSNavigationCell *appsCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"App Manager"
             subtitle:@"Choose apps to configure"
                 icon:@"square.grid.2x2.fill"
                color:[UIColor systemOrangeColor]];
    appsCell.tapAction = ^{
        MiOSAppListViewController *vc = [[MiOSAppListViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [section addCellView:appsCell];

    [_mainStack addArrangedSubview:section];
}

- (void)buildInfoSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@""];

    __weak typeof(self) weakSelf = self;

    MiOSNavigationCell *settingsCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"Settings"
             subtitle:nil
                 icon:@"gearshape.fill"
                color:[MiOSTheme secondaryText]];
    settingsCell.tapAction = ^{
        MiOSSettingsViewController *vc = [[MiOSSettingsViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    [section addCellView:settingsCell];

    [_mainStack addArrangedSubview:section];
}

@end
