#import "MiOSHomeViewController.h"
#import "MiOSContainerCreateViewController.h"
#import "MiOSContainerDetailViewController.h"
#import "MiOSSettingsViewController.h"
#import "../Models/MiOSContainerConfig.h"
#import "../Models/MiOSAppInfo.h"
#import "../Views/MiOSHeroBannerView.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"
#import <objc/runtime.h>

static NSString *const kMiOSCorePrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist";

@interface MiOSHomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) MiOSHeroBannerView *heroBanner;
@property (nonatomic, strong) NSMutableDictionary *corePrefs;
@property (nonatomic, strong) NSArray<MiOSContainerConfig *> *containers;
@property (nonatomic, copy) NSString *activeContainerID;
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
    [self reloadContainers];
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

- (void)reloadContainers {
    _containers = [MiOSContainerConfig loadAll];
    _activeContainerID = [MiOSContainerConfig activeContainerID];
    [self rebuildContent];
}

#pragma mark - UI Setup

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _mainStack = [[UIStackView alloc] init];
    _mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    _mainStack.axis = UILayoutConstraintAxisVertical;
    _mainStack.spacing = 20;
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
    [self reloadContainers];
}

- (void)rebuildContent {
    NSArray *arranged = [_mainStack.arrangedSubviews copy];
    for (UIView *v in arranged) {
        if (v == _heroBanner) continue;
        [_mainStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    if (_containers.count == 0) {
        [self buildEmptyState];
    } else {
        [self buildActiveContainerCard];
        if (_containers.count > 1) {
            [self buildOtherContainers];
        }
    }

    [self buildNewContainerButton];
    [self buildSettingsSection];
}

#pragma mark - Hero Banner

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

#pragma mark - Empty State

- (void)buildEmptyState {
    UIView *emptyCard = [[UIView alloc] init];
    emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
    emptyCard.backgroundColor = [MiOSTheme cardBackground];
    emptyCard.layer.cornerRadius = 20;
    emptyCard.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightThin];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.stack.3d.up.slash" withConfiguration:cfg]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [MiOSTheme tertiaryText];
    [emptyCard addSubview:icon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"No Containers Yet";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    titleLabel.textColor = [MiOSTheme primaryText];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [emptyCard addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = @"Create a container to isolate app data,\nspoof GPS, device info, and identifiers.";
    subtitleLabel.font = [UIFont systemFontOfSize:14];
    subtitleLabel.textColor = [MiOSTheme secondaryText];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    [emptyCard addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [emptyCard.heightAnchor constraintEqualToConstant:200],
        [icon.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [icon.topAnchor constraintEqualToAnchor:emptyCard.topAnchor constant:32],
        [titleLabel.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:emptyCard.centerXAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:emptyCard.leadingAnchor constant:24],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:emptyCard.trailingAnchor constant:-24],
    ]];

    [_mainStack addArrangedSubview:emptyCard];
}

#pragma mark - Active Container Card

- (void)buildActiveContainerCard {
    MiOSContainerConfig *active = nil;
    for (MiOSContainerConfig *c in _containers) {
        if ([c.identifier isEqualToString:_activeContainerID]) {
            active = c;
            break;
        }
    }
    if (!active && _containers.count > 0) {
        active = _containers.firstObject;
    }
    if (!active) return;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [MiOSTheme cardBackground];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.5;
    card.layer.borderColor = [MiOSTheme accentColor].CGColor;

    // Active badge
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.15];
    badge.layer.cornerRadius = 10;
    [card addSubview:badge];

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.text = @"ACTIVE";
    badgeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    badgeLabel.textColor = [MiOSTheme accentColor];
    [badge addSubview:badgeLabel];

    // Container name
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = active.name.length > 0 ? active.name : @"Container";
    nameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    nameLabel.textColor = [MiOSTheme primaryText];
    [card addSubview:nameLabel];

    // Apps count
    UILabel *appsLabel = [[UILabel alloc] init];
    appsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appsLabel.text = [NSString stringWithFormat:@"%lu app%@", (unsigned long)active.apps.count, active.apps.count == 1 ? @"" : @"s"];
    appsLabel.font = [UIFont systemFontOfSize:14];
    appsLabel.textColor = [MiOSTheme secondaryText];
    [card addSubview:appsLabel];

    // Status indicators
    UIStackView *statusStack = [[UIStackView alloc] init];
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusStack.axis = UILayoutConstraintAxisHorizontal;
    statusStack.spacing = 8;

    if (active.gpsEnabled) [statusStack addArrangedSubview:[self statusPillWithIcon:@"location.fill" text:@"GPS" color:[UIColor systemBlueColor]]];
    if (active.deviceSpoofEnabled) [statusStack addArrangedSubview:[self statusPillWithIcon:@"iphone" text:@"Device" color:[UIColor systemTealColor]]];
    if (active.spoofVendorID || active.spoofAdvertisingID || active.spoofDeviceCheck || active.spoofCloudToken) {
        [statusStack addArrangedSubview:[self statusPillWithIcon:@"shield.fill" text:@"IDs" color:[UIColor systemPurpleColor]]];
    }
    [card addSubview:statusStack];

    // Chevron
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = [MiOSTheme tertiaryText];
    [card addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [badge.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [badge.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [badgeLabel.topAnchor constraintEqualToAnchor:badge.topAnchor constant:4],
        [badgeLabel.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-4],
        [badgeLabel.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:10],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-10],
        [nameLabel.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:10],
        [nameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [nameLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
        [appsLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [appsLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [statusStack.topAnchor constraintEqualToAnchor:appsLabel.bottomAnchor constant:12],
        [statusStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [statusStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeContainerTapped:)];
    card.userInteractionEnabled = YES;
    card.tag = 0;
    objc_setAssociatedObject(card, "containerID", active.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addGestureRecognizer:tap];

    [_mainStack addArrangedSubview:card];
}

- (UIView *)statusPillWithIcon:(NSString *)icon text:(NSString *)text color:(UIColor *)color {
    UIView *pill = [[UIView alloc] init];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.backgroundColor = [color colorWithAlphaComponent:0.12];
    pill.layer.cornerRadius = 8;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightMedium];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon withConfiguration:cfg]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = color;
    [pill addSubview:iconView];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    lbl.textColor = color;
    [pill addSubview:lbl];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:8],
        [iconView.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [lbl.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:4],
        [lbl.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-8],
        [lbl.centerYAnchor constraintEqualToAnchor:pill.centerYAnchor],
        [pill.heightAnchor constraintEqualToConstant:26],
    ]];

    return pill;
}

- (void)activeContainerTapped:(UITapGestureRecognizer *)sender {
    NSString *containerID = objc_getAssociatedObject(sender.view, "containerID");
    [self editContainerWithID:containerID];
}

#pragma mark - Other Containers

- (void)buildOtherContainers {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"All Containers"];

    for (NSInteger i = 0; i < (NSInteger)_containers.count; i++) {
        MiOSContainerConfig *c = _containers[i];
        BOOL isActive = [c.identifier isEqualToString:_activeContainerID];

        NSString *subtitle = [NSString stringWithFormat:@"%lu app%@", (unsigned long)c.apps.count, c.apps.count == 1 ? @"" : @"s"];
        MiOSNavigationCell *cell = [[MiOSNavigationCell alloc]
            initWithTitle:c.name.length > 0 ? c.name : @"Container"
                 subtitle:subtitle
                     icon:isActive ? @"checkmark.circle.fill" : @"square.stack.3d.up.fill"
                    color:isActive ? [MiOSTheme accentColor] : [UIColor systemPurpleColor]];

        if (isActive) cell.badgeText = @"Active";

        __weak typeof(self) weakSelf = self;
        NSString *cid = c.identifier;
        cell.tapAction = ^{
            [weakSelf editContainerWithID:cid];
        };

        [section addCellView:cell];
        if (i < (NSInteger)_containers.count - 1) [section addSeparator];
    }

    [_mainStack addArrangedSubview:section];
}

#pragma mark - New Container Button

- (void)buildNewContainerButton {
    UIView *btnContainer = [[UIView alloc] init];
    btnContainer.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *btn = [[UIView alloc] init];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.layer.cornerRadius = 14;
    btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.clipsToBounds = YES;
    [btnContainer addSubview:btn];

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[
        (id)[MiOSTheme accentColor].CGColor,
        (id)[MiOSTheme accentGradientEnd].CGColor,
    ];
    grad.startPoint = CGPointMake(0, 0.5);
    grad.endPoint = CGPointMake(1, 0.5);
    grad.cornerRadius = 14;
    [btn.layer insertSublayer:grad atIndex:0];
    btn.tag = 100;

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
        [btn.heightAnchor constraintEqualToConstant:52],
        [plusIcon.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:20],
        [plusIcon.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:plusIcon.trailingAnchor constant:8],
        [label.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(newContainerTapped:)];
    [btn addGestureRecognizer:tap];
    btn.userInteractionEnabled = YES;

    [_mainStack addArrangedSubview:btnContainer];

    dispatch_async(dispatch_get_main_queue(), ^{
        grad.frame = btn.bounds;
    });
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

    MiOSContainerCreateViewController *vc = [[MiOSContainerCreateViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf reloadContainers];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Edit Container

- (void)editContainerWithID:(NSString *)containerID {
    MiOSContainerConfig *config = nil;
    for (MiOSContainerConfig *c in _containers) {
        if ([c.identifier isEqualToString:containerID]) {
            config = c;
            break;
        }
    }
    if (!config) return;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    MiOSContainerCreateViewController *vc = [[MiOSContainerCreateViewController alloc] init];
    vc.editingContainer = config;
    __weak typeof(self) weakSelf = self;
    vc.onSave = ^{
        [weakSelf reloadContainers];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Settings

- (void)buildSettingsSection {
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
