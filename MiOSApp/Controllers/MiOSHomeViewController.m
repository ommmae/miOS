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
#import "../Utils/MiOSColorExtractor.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface UIImage (MiOSPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

static NSString *const kMiOSCorePrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.core.plist";

@interface MiOSHomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) MiOSHeroBannerView *heroBanner;
@property (nonatomic, strong) NSMutableDictionary *corePrefs;
@property (nonatomic, strong) NSArray<MiOSContainerConfig *> *containers;
@property (nonatomic, copy) NSString *activeContainerID;
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _bgGradientLayer.frame = self.view.bounds;
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
    // Subtle gradient background
    _bgGradientLayer = [CAGradientLayer layer];
    _bgGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0].CGColor,
        (id)[MiOSTheme primaryBackground].CGColor,
    ];
    _bgGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    _bgGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    _bgGradientLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:_bgGradientLayer atIndex:0];

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
    emptyCard.backgroundColor = [MiOSTheme accentTintedCardBackground];
    emptyCard.layer.cornerRadius = 20;
    emptyCard.layer.cornerCurve = kCACornerCurveContinuous;
    emptyCard.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    emptyCard.layer.borderWidth = 1.0;

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

#pragma mark - App Icon Helpers

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    // Try private API first
    UIImage *img = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:0 scale:[UIScreen mainScreen].scale];
    if (img) return img;

    // Fallback: search through MiOSAppInfo
    NSArray<MiOSAppInfo *> *allApps = [MiOSAppInfo allApps];
    for (MiOSAppInfo *app in allApps) {
        if ([app.bundleID isEqualToString:bundleID]) {
            return app.icon;
        }
    }
    return nil;
}

- (UIView *)appIconsRowForBundleIDs:(NSArray<NSString *> *)bundleIDs maxIcons:(NSUInteger)maxIcons iconSize:(CGFloat)iconSize {
    UIStackView *iconsStack = [[UIStackView alloc] init];
    iconsStack.translatesAutoresizingMaskIntoConstraints = NO;
    iconsStack.axis = UILayoutConstraintAxisHorizontal;
    iconsStack.spacing = 6;
    iconsStack.alignment = UIStackViewAlignmentCenter;

    NSUInteger showCount = MIN(bundleIDs.count, maxIcons);
    for (NSUInteger i = 0; i < showCount; i++) {
        NSString *bid = bundleIDs[i];
        UIImage *appIcon = [self iconForBundleID:bid];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFill;
        iconView.clipsToBounds = YES;
        iconView.layer.cornerRadius = iconSize * 0.22;
        iconView.layer.cornerCurve = kCACornerCurveContinuous;
        iconView.backgroundColor = [[MiOSTheme secondaryBackground] colorWithAlphaComponent:0.5];

        if (appIcon) {
            iconView.image = appIcon;
        } else {
            // Placeholder: SF Symbol for a generic app
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:iconSize * 0.5 weight:UIImageSymbolWeightRegular];
            iconView.image = [UIImage systemImageNamed:@"app.fill" withConfiguration:cfg];
            iconView.tintColor = [MiOSTheme tertiaryText];
            iconView.contentMode = UIViewContentModeCenter;
        }

        [NSLayoutConstraint activateConstraints:@[
            [iconView.widthAnchor constraintEqualToConstant:iconSize],
            [iconView.heightAnchor constraintEqualToConstant:iconSize],
        ]];

        [iconsStack addArrangedSubview:iconView];
    }

    // "+N" label if more apps than shown
    if (bundleIDs.count > maxIcons) {
        UILabel *moreLabel = [[UILabel alloc] init];
        moreLabel.translatesAutoresizingMaskIntoConstraints = NO;
        moreLabel.text = [NSString stringWithFormat:@"+%lu", (unsigned long)(bundleIDs.count - maxIcons)];
        moreLabel.font = [UIFont systemFontOfSize:(iconSize < 24 ? 10 : 12) weight:UIFontWeightMedium];
        moreLabel.textColor = [MiOSTheme secondaryText];
        [iconsStack addArrangedSubview:moreLabel];
    }

    return iconsStack;
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

    UIColor *cardAccent = [MiOSTheme accentColor];
    if (active.apps.count > 0) {
        UIImage *firstIcon = [self iconForBundleID:active.apps.firstObject];
        if (firstIcon) {
            UIColor *extracted = [MiOSColorExtractor vibrantColorFromImage:firstIcon];
            if (extracted) cardAccent = extracted;
        }
    }

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat cr, cg, cb, ca;
    [cardAccent getRed:&cr green:&cg blue:&cb alpha:&ca];
    card.backgroundColor = [UIColor colorWithRed:0.10 + cr * 0.05
                                           green:0.10 + cg * 0.05
                                            blue:0.14 + cb * 0.05
                                           alpha:0.90];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [cardAccent colorWithAlphaComponent:0.20].CGColor;

    // Active badge
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.backgroundColor = [cardAccent colorWithAlphaComponent:0.25];
    badge.layer.cornerRadius = 10;
    badge.layer.shadowColor = cardAccent.CGColor;
    badge.layer.shadowOffset = CGSizeZero;
    badge.layer.shadowRadius = 4;
    badge.layer.shadowOpacity = 0.3;
    [card addSubview:badge];

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.text = @"ACTIVE";
    badgeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    badgeLabel.textColor = cardAccent;
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

    // App icons row (up to 5 icons, 28x28)
    UIView *appIconsRow = nil;
    if (active.apps.count > 0) {
        appIconsRow = [self appIconsRowForBundleIDs:active.apps maxIcons:5 iconSize:28];
        [card addSubview:appIconsRow];
    }

    // Status indicators
    UIStackView *statusStack = [[UIStackView alloc] init];
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    statusStack.axis = UILayoutConstraintAxisHorizontal;
    statusStack.spacing = 8;

    if (active.gpsEnabled) [statusStack addArrangedSubview:[self statusPillWithIcon:@"location.fill" text:@"GPS" color:cardAccent]];
    if (active.deviceSpoofEnabled) [statusStack addArrangedSubview:[self statusPillWithIcon:@"iphone" text:@"Device" color:cardAccent]];
    if (active.spoofVendorID || active.spoofAdvertisingID || active.spoofDeviceCheck || active.spoofCloudToken) {
        [statusStack addArrangedSubview:[self statusPillWithIcon:@"shield.fill" text:@"IDs" color:cardAccent]];
    }
    [card addSubview:statusStack];

    // Device info row (if device spoof enabled)
    UIView *deviceInfoRow = nil;
    if (active.deviceSpoofEnabled) {
        deviceInfoRow = [self buildDeviceInfoRowWithName:active.deviceName iosVersion:active.iosVersion];
        [card addSubview:deviceInfoRow];
    }

    // Chevron
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = [MiOSTheme tertiaryText];
    [card addSubview:chevron];

    // Determine the bottom anchor chain
    // Layout order: badge -> name -> appIcons -> status -> deviceInfo -> bottom
    UIView *bottomElement = statusStack;

    // Constraints
    NSMutableArray *constraints = [NSMutableArray array];

    // Badge
    [constraints addObjectsFromArray:@[
        [badge.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [badge.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [badgeLabel.topAnchor constraintEqualToAnchor:badge.topAnchor constant:4],
        [badgeLabel.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-4],
        [badgeLabel.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:10],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-10],
    ]];

    // Name
    [constraints addObjectsFromArray:@[
        [nameLabel.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:10],
        [nameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [nameLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
    ]];

    // Apps count
    [constraints addObjectsFromArray:@[
        [appsLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [appsLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
    ]];

    // App icons row
    if (appIconsRow) {
        [constraints addObjectsFromArray:@[
            [appIconsRow.topAnchor constraintEqualToAnchor:appsLabel.bottomAnchor constant:10],
            [appIconsRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        ]];
        // Status stack anchors below app icons
        [constraints addObjectsFromArray:@[
            [statusStack.topAnchor constraintEqualToAnchor:appIconsRow.bottomAnchor constant:10],
            [statusStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        ]];
    } else {
        // Status stack anchors below apps label
        [constraints addObjectsFromArray:@[
            [statusStack.topAnchor constraintEqualToAnchor:appsLabel.bottomAnchor constant:12],
            [statusStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        ]];
    }

    // Device info row
    if (deviceInfoRow) {
        [constraints addObjectsFromArray:@[
            [deviceInfoRow.topAnchor constraintEqualToAnchor:statusStack.bottomAnchor constant:10],
            [deviceInfoRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [deviceInfoRow.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
        ]];
        bottomElement = deviceInfoRow;
    }

    // Bottom
    [constraints addObject:[bottomElement.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]];

    // Chevron
    [constraints addObjectsFromArray:@[
        [chevron.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:constraints];

    card.layer.shadowColor = cardAccent.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 4);
    card.layer.shadowRadius = 20;
    card.layer.shadowOpacity = 0.20;
    card.clipsToBounds = NO;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activeContainerTapped:)];
    card.userInteractionEnabled = YES;
    card.tag = 0;
    objc_setAssociatedObject(card, "containerID", active.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addGestureRecognizer:tap];

    [_mainStack addArrangedSubview:card];
}

- (UIView *)buildDeviceInfoRowWithName:(NSString *)deviceName iosVersion:(NSString *)iosVersion {
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 6;
    row.alignment = UIStackViewAlignmentCenter;

    // iPhone SF symbol icon
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    UIImageView *deviceIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"iphone" withConfiguration:cfg]];
    deviceIcon.translatesAutoresizingMaskIntoConstraints = NO;
    deviceIcon.tintColor = [MiOSTheme accentColor];
    [row addArrangedSubview:deviceIcon];

    // Device name text
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = deviceName.length > 0 ? deviceName : @"Unknown Device";
    nameLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    nameLabel.textColor = [MiOSTheme secondaryText];
    [nameLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:nameLabel];

    // iOS version badge pill
    if (iosVersion.length > 0) {
        UIView *iosPill = [[UIView alloc] init];
        iosPill.translatesAutoresizingMaskIntoConstraints = NO;
        iosPill.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.15];
        iosPill.layer.cornerRadius = 7;

        UILabel *iosLabel = [[UILabel alloc] init];
        iosLabel.translatesAutoresizingMaskIntoConstraints = NO;
        iosLabel.text = [NSString stringWithFormat:@"iOS %@", iosVersion];
        iosLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        iosLabel.textColor = [MiOSTheme accentColor];
        [iosPill addSubview:iosLabel];

        [NSLayoutConstraint activateConstraints:@[
            [iosLabel.topAnchor constraintEqualToAnchor:iosPill.topAnchor constant:3],
            [iosLabel.bottomAnchor constraintEqualToAnchor:iosPill.bottomAnchor constant:-3],
            [iosLabel.leadingAnchor constraintEqualToAnchor:iosPill.leadingAnchor constant:7],
            [iosLabel.trailingAnchor constraintEqualToAnchor:iosPill.trailingAnchor constant:-7],
        ]];

        [row addArrangedSubview:iosPill];
    }

    // Spacer to push content to the left
    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:spacer];

    return row;
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

        // Add app icons row to the cell (up to 3, small 22x22)
        if (c.apps.count > 0) {
            UIView *cellIconsRow = [self appIconsRowForBundleIDs:c.apps maxIcons:3 iconSize:22];
            [cell addSubview:cellIconsRow];
            [NSLayoutConstraint activateConstraints:@[
                [cellIconsRow.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-32],
                [cellIconsRow.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        }

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
