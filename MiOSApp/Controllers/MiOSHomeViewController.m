#import "MiOSHomeViewController.h"
#import "MiOSGPSViewController.h"
#import "MiOSContainerListViewController.h"
#import "MiOSAppListViewController.h"
#import "MiOSSettingsViewController.h"
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
        _corePrefs = [@{@"enabled": @YES, @"mode": @"local"} mutableCopy];
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
    [self buildModulesSection];
    [self buildQuickActionsSection];
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

- (void)buildQuickActionsSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Mode"];

    UISegmentedControl *modeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Local", @"Global"]];
    modeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    modeSegment.selectedSegmentIndex = [_corePrefs[@"mode"] isEqualToString:@"global"] ? 1 : 0;
    [modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];

    UIView *segmentContainer = [[UIView alloc] init];
    segmentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [segmentContainer addSubview:modeSegment];

    [NSLayoutConstraint activateConstraints:@[
        [modeSegment.topAnchor constraintEqualToAnchor:segmentContainer.topAnchor constant:12],
        [modeSegment.leadingAnchor constraintEqualToAnchor:segmentContainer.leadingAnchor constant:16],
        [modeSegment.trailingAnchor constraintEqualToAnchor:segmentContainer.trailingAnchor constant:-16],
        [modeSegment.bottomAnchor constraintEqualToAnchor:segmentContainer.bottomAnchor constant:-12],
        [modeSegment.heightAnchor constraintEqualToConstant:36],
    ]];
    [section addCellView:segmentContainer];
    [section addSeparator];

    UILabel *modeDesc = [[UILabel alloc] init];
    modeDesc.translatesAutoresizingMaskIntoConstraints = NO;
    modeDesc.font = [MiOSTheme captionFont];
    modeDesc.textColor = [MiOSTheme secondaryText];
    modeDesc.numberOfLines = 0;
    modeDesc.text = @"Local: configure per-app containers with separate data. Global: apply settings to all selected apps.";

    UIView *descContainer = [[UIView alloc] init];
    descContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [descContainer addSubview:modeDesc];
    [NSLayoutConstraint activateConstraints:@[
        [modeDesc.topAnchor constraintEqualToAnchor:descContainer.topAnchor constant:8],
        [modeDesc.leadingAnchor constraintEqualToAnchor:descContainer.leadingAnchor constant:16],
        [modeDesc.trailingAnchor constraintEqualToAnchor:descContainer.trailingAnchor constant:-16],
        [modeDesc.bottomAnchor constraintEqualToAnchor:descContainer.bottomAnchor constant:-12],
    ]];
    [section addCellView:descContainer];

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

- (void)modeChanged:(UISegmentedControl *)sender {
    _corePrefs[@"mode"] = sender.selectedSegmentIndex == 1 ? @"global" : @"local";
    [self savePreferences];
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

@end
