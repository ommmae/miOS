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
        [self buildContainerGrid];
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

#pragma mark - Container Grid

- (void)buildContainerGrid {
    // Section header
    UILabel *sectionHeader = [[UILabel alloc] init];
    sectionHeader.translatesAutoresizingMaskIntoConstraints = NO;
    sectionHeader.text = @"CONTAINERS";
    sectionHeader.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    sectionHeader.textColor = [MiOSTheme accentColor];
    [_mainStack addArrangedSubview:sectionHeader];

    // Build rows of 2 cards each
    for (NSInteger i = 0; i < (NSInteger)_containers.count; i += 2) {
        UIView *rowView = [[UIView alloc] init];
        rowView.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *leftCard = [self buildGridCardForContainer:_containers[i]];
        [rowView addSubview:leftCard];

        [NSLayoutConstraint activateConstraints:@[
            [leftCard.topAnchor constraintEqualToAnchor:rowView.topAnchor],
            [leftCard.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor],
            [leftCard.bottomAnchor constraintLessThanOrEqualToAnchor:rowView.bottomAnchor],
        ]];

        if (i + 1 < (NSInteger)_containers.count) {
            UIView *rightCard = [self buildGridCardForContainer:_containers[i + 1]];
            [rowView addSubview:rightCard];

            [NSLayoutConstraint activateConstraints:@[
                [rightCard.topAnchor constraintEqualToAnchor:rowView.topAnchor],
                [rightCard.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
                [rightCard.bottomAnchor constraintLessThanOrEqualToAnchor:rowView.bottomAnchor],
                [leftCard.widthAnchor constraintEqualToAnchor:rightCard.widthAnchor],
                [leftCard.trailingAnchor constraintEqualToAnchor:rightCard.leadingAnchor constant:-12],
            ]];
        } else {
            // Single card in last row — constrain width to ~half
            [NSLayoutConstraint activateConstraints:@[
                [leftCard.widthAnchor constraintEqualToAnchor:rowView.widthAnchor multiplier:0.5 constant:-6],
            ]];
        }

        [_mainStack addArrangedSubview:rowView];
    }
}

- (UIView *)buildGridCardForContainer:(MiOSContainerConfig *)container {
    BOOL isActive = [container.identifier isEqualToString:_activeContainerID];

    UIColor *cardAccent = [MiOSTheme accentColor];
    if (container.apps.count > 0) {
        UIImage *firstIcon = [self iconForBundleID:container.apps.firstObject];
        if (firstIcon) {
            UIColor *extracted = [MiOSColorExtractor vibrantColorFromImage:firstIcon];
            if (extracted) cardAccent = extracted;
        }
    }

    CGFloat cr, cg, cb, ca;
    [cardAccent getRed:&cr green:&cg blue:&cb alpha:&ca];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithRed:0.10 + cr * 0.06
                                           green:0.10 + cg * 0.06
                                            blue:0.14 + cb * 0.06
                                           alpha:0.90];
    card.layer.cornerRadius = 16;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = isActive ? 1.5 : 0.5;
    card.layer.borderColor = isActive
        ? [cardAccent colorWithAlphaComponent:0.35].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;

    card.layer.shadowColor = cardAccent.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = isActive ? 12 : 6;
    card.layer.shadowOpacity = isActive ? 0.20 : 0.08;
    card.clipsToBounds = NO;

    // App icon or placeholder
    UIImageView *appIconView = [[UIImageView alloc] init];
    appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    appIconView.contentMode = UIViewContentModeScaleAspectFill;
    appIconView.clipsToBounds = YES;
    appIconView.layer.cornerRadius = 12;
    appIconView.layer.cornerCurve = kCACornerCurveContinuous;

    if (container.apps.count > 0) {
        UIImage *icon = [self iconForBundleID:container.apps.firstObject];
        if (icon) {
            appIconView.image = icon;
        } else {
            appIconView.image = [UIImage systemImageNamed:@"app.fill"];
            appIconView.tintColor = [MiOSTheme tertiaryText];
            appIconView.contentMode = UIViewContentModeCenter;
            appIconView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        }
    } else {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
        appIconView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill" withConfiguration:cfg];
        appIconView.tintColor = cardAccent;
        appIconView.contentMode = UIViewContentModeCenter;
        appIconView.backgroundColor = [cardAccent colorWithAlphaComponent:0.10];
    }

    // Glow on icon
    appIconView.layer.shadowColor = cardAccent.CGColor;
    appIconView.layer.shadowOffset = CGSizeZero;
    appIconView.layer.shadowRadius = 6;
    appIconView.layer.shadowOpacity = 0.25;
    [card addSubview:appIconView];

    // Active indicator dot
    UIView *activeDot = nil;
    if (isActive) {
        activeDot = [[UIView alloc] init];
        activeDot.translatesAutoresizingMaskIntoConstraints = NO;
        activeDot.backgroundColor = cardAccent;
        activeDot.layer.cornerRadius = 4;
        activeDot.layer.shadowColor = cardAccent.CGColor;
        activeDot.layer.shadowOffset = CGSizeZero;
        activeDot.layer.shadowRadius = 4;
        activeDot.layer.shadowOpacity = 0.6;
        [card addSubview:activeDot];
    }

    // Container name
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = container.name.length > 0 ? container.name : @"Container";
    nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    nameLabel.textColor = [MiOSTheme primaryText];
    nameLabel.numberOfLines = 1;
    [card addSubview:nameLabel];

    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *subParts = [NSString stringWithFormat:@"%lu app%@",
        (unsigned long)container.apps.count, container.apps.count == 1 ? @"" : @"s"];
    subtitleLabel.text = subParts;
    subtitleLabel.font = [UIFont systemFontOfSize:11];
    subtitleLabel.textColor = [MiOSTheme secondaryText];
    [card addSubview:subtitleLabel];

    // Feature indicators (small dots)
    UIStackView *dotsStack = [[UIStackView alloc] init];
    dotsStack.translatesAutoresizingMaskIntoConstraints = NO;
    dotsStack.axis = UILayoutConstraintAxisHorizontal;
    dotsStack.spacing = 4;

    if (container.gpsEnabled) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    if (container.deviceSpoofEnabled) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    if (container.spoofVendorID || container.spoofAdvertisingID) [dotsStack addArrangedSubview:[self featureDotWithColor:cardAccent]];
    [card addSubview:dotsStack];

    NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
        [appIconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [appIconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [appIconView.widthAnchor constraintEqualToConstant:44],
        [appIconView.heightAnchor constraintEqualToConstant:44],
        [nameLabel.topAnchor constraintEqualToAnchor:appIconView.bottomAnchor constant:10],
        [nameLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
        [dotsStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8],
        [dotsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [dotsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
    ]];

    if (activeDot) {
        [constraints addObjectsFromArray:@[
            [activeDot.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
            [activeDot.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
            [activeDot.widthAnchor constraintEqualToConstant:8],
            [activeDot.heightAnchor constraintEqualToConstant:8],
        ]];
    }

    [NSLayoutConstraint activateConstraints:constraints];

    // Tap
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gridCardTapped:)];
    card.userInteractionEnabled = YES;
    objc_setAssociatedObject(card, "containerID", container.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addGestureRecognizer:tap];

    return card;
}

- (UIView *)featureDotWithColor:(UIColor *)color {
    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = [color colorWithAlphaComponent:0.5];
    dot.layer.cornerRadius = 3;
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:6],
        [dot.heightAnchor constraintEqualToConstant:6],
    ]];
    return dot;
}

- (void)gridCardTapped:(UITapGestureRecognizer *)sender {
    UIView *card = sender.view;
    [UIView animateWithDuration:0.08 animations:^{
        card.transform = CGAffineTransformMakeScale(0.96, 0.96);
        card.alpha = 0.7;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            card.transform = CGAffineTransformIdentity;
            card.alpha = 1.0;
        } completion:nil];
    }];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    NSString *containerID = objc_getAssociatedObject(card, "containerID");
    [self editContainerWithID:containerID];
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
