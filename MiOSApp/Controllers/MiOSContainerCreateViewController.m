#import "MiOSContainerCreateViewController.h"
#import "../Models/MiOSContainerConfig.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"
#import "../Models/MiOSAppInfo.h"
#import "../Models/MiOSDeviceDatabase.h"
#import "../Utils/MiOSColorExtractor.h"
#import "../Utils/MiOSDeviceImageRenderer.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@interface UIImage (MiOSPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

#pragma mark - App List Cell (Full-Width Row)

static NSString *const kAppCellReuseID = @"MiOSAppListCell";

@interface MiOSAppListCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleLabel;
@property (nonatomic, strong) UIImageView *checkmark;
@property (nonatomic, assign) BOOL isChecked;
@end

@implementation MiOSAppListCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupCell];
    }
    return self;
}

- (void)setupCell {
    self.contentView.backgroundColor = [MiOSTheme accentTintedCardBackground];
    self.contentView.layer.cornerRadius = 14;
    self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    self.contentView.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    self.contentView.layer.borderWidth = 1.0;
    self.contentView.clipsToBounds = YES;

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFill;
    _iconView.clipsToBounds = YES;
    _iconView.layer.cornerRadius = 10;
    _iconView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.contentView addSubview:_iconView];

    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2;

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [MiOSTheme headlineFont];
    _nameLabel.textColor = [MiOSTheme primaryText];
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [textStack addArrangedSubview:_nameLabel];

    _bundleLabel = [[UILabel alloc] init];
    _bundleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _bundleLabel.font = [MiOSTheme captionFont];
    _bundleLabel.textColor = [MiOSTheme secondaryText];
    _bundleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [textStack addArrangedSubview:_bundleLabel];

    [self.contentView addSubview:textStack];

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    _checkmark = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:cfg]];
    _checkmark.translatesAutoresizingMaskIntoConstraints = NO;
    _checkmark.tintColor = [MiOSTheme accentColor];
    _checkmark.hidden = YES;
    [self.contentView addSubview:_checkmark];

    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:48],
        [_iconView.heightAnchor constraintEqualToConstant:48],
        [textStack.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [textStack.trailingAnchor constraintEqualToAnchor:_checkmark.leadingAnchor constant:-8],
        [textStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_checkmark.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
        [_checkmark.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
    ]];
}

- (void)setIsChecked:(BOOL)isChecked {
    _isChecked = isChecked;
    _checkmark.hidden = !isChecked;
    self.contentView.layer.borderColor = isChecked
        ? [MiOSTheme accentColor].CGColor
        : [MiOSTheme accentBorderColor].CGColor;
    self.contentView.layer.borderWidth = isChecked ? 1.5 : 1.0;
    self.contentView.backgroundColor = isChecked
        ? [[MiOSTheme accentColor] colorWithAlphaComponent:0.08]
        : [MiOSTheme accentTintedCardBackground];
}

- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    self.contentView.layer.borderColor = _isChecked
        ? [MiOSTheme accentColor].CGColor
        : [MiOSTheme accentBorderColor].CGColor;
}

@end

#pragma mark - Main View Controller

@interface MiOSContainerCreateViewController () <UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout, UITextFieldDelegate, UISearchBarDelegate,
    MiOSToggleCellDelegate, MKMapViewDelegate, MKLocalSearchCompleterDelegate,
    UITableViewDataSource, UITableViewDelegate>

// Step views
@property (nonatomic, strong) UIView *step1View;
@property (nonatomic, strong) UIView *step2View;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, strong) CAGradientLayer *bgGradientLayer;

// Step 1 - App Selection
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UISearchBar *appSearchBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) NSArray<MiOSAppInfo *> *allAppsList;
@property (nonatomic, strong) NSArray<MiOSAppInfo *> *filteredApps;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedBundleIDs;

// Step 2 - Configuration
@property (nonatomic, strong) UIScrollView *step2Scroll;
@property (nonatomic, strong) UIStackView *step2Stack;
@property (nonatomic, strong) UIButton *randomSetupButton;

// GPS
@property (nonatomic, assign) BOOL gpsEnabled;
@property (nonatomic, strong) UIView *gpsMapContainer;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UISearchBar *locationSearchBar;
@property (nonatomic, strong) UITableView *locationSearchResultsTable;
@property (nonatomic, strong) MKPointAnnotation *mapPin;
@property (nonatomic, strong) UILabel *coordLabel;
@property (nonatomic, strong) MKLocalSearchCompleter *searchCompleter;
@property (nonatomic, strong) NSArray<MKLocalSearchCompletion *> *locationSearchResults;
@property (nonatomic, assign) double selectedLatitude;
@property (nonatomic, assign) double selectedLongitude;
@property (nonatomic, copy) NSString *selectedLocationName;

// Device spoof
@property (nonatomic, assign) BOOL deviceSpoofEnabled;
@property (nonatomic, strong) UIView *deviceCardContainer;
@property (nonatomic, strong) UIImageView *deviceIconView;
@property (nonatomic, strong) UILabel *deviceNameLabel;
@property (nonatomic, strong) UILabel *deviceIdentifierLabel;
@property (nonatomic, strong) UILabel *deviceSpecsLabel;
@property (nonatomic, strong) UIView *storagePillContainer;
@property (nonatomic, strong) UIButton *iosVersionButton;
@property (nonatomic, strong) UIView *deviceNavContainer;
@property (nonatomic, strong) NSArray<MiOSDeviceModel *> *deviceList;
@property (nonatomic, strong) NSArray<NSString *> *iosVersionList;
@property (nonatomic, assign) NSInteger selectedDeviceIndex;
@property (nonatomic, assign) NSInteger selectedIOSIndex;
@property (nonatomic, assign) NSInteger selectedStorageIndex;
@property (nonatomic, assign) BOOL spoofDeviceName;
@property (nonatomic, strong) UIView *customDeviceNameContainer;
@property (nonatomic, strong) UITextField *customDeviceNameField;
@property (nonatomic, strong) MiOSToggleCell *deviceNameToggle;

// Identifiers
@property (nonatomic, assign) BOOL spoofDeviceCheck;
@property (nonatomic, assign) BOOL spoofVendorID;
@property (nonatomic, copy) NSString *vendorID;
@property (nonatomic, strong) UIView *vendorIDContainer;
@property (nonatomic, strong) UILabel *vendorIDLabel;
@property (nonatomic, assign) BOOL spoofAdvertisingID;
@property (nonatomic, copy) NSString *advertisingID;
@property (nonatomic, strong) UIView *advertisingIDContainer;
@property (nonatomic, strong) UILabel *advertisingIDLabel;
@property (nonatomic, assign) BOOL spoofCloudToken;

@end

@implementation MiOSContainerCreateViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    self.modalPresentationStyle = UIModalPresentationPageSheet;

    [self addBackgroundGradient];

    _currentStep = 1;
    _selectedBundleIDs = [NSMutableSet set];
    _deviceList = [MiOSDeviceDatabase allDevices];
    _iosVersionList = [MiOSDeviceDatabase allIOSVersions];
    _selectedDeviceIndex = 0;
    _selectedIOSIndex = 0;
    _selectedStorageIndex = 0;
    _locationSearchResults = @[];

    [self setupSearchCompleter];
    [self loadApps];
    [self prefillFromEditing];
    [self buildStep1];
    [self buildStep2];
    [self showStep:1 animated:NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _bgGradientLayer.frame = self.view.bounds;
}

- (void)addBackgroundGradient {
    _bgGradientLayer = [CAGradientLayer layer];
    UIColor *base = [MiOSTheme primaryBackground];
    CGFloat r, g, b, a;
    [base getRed:&r green:&g blue:&b alpha:&a];
    UIColor *lighter = [UIColor colorWithRed:MIN(r + 0.03, 1.0) green:MIN(g + 0.03, 1.0) blue:MIN(b + 0.03, 1.0) alpha:a];
    _bgGradientLayer.colors = @[(id)lighter.CGColor, (id)base.CGColor];
    _bgGradientLayer.startPoint = CGPointMake(0.5, 0);
    _bgGradientLayer.endPoint = CGPointMake(0.5, 1);
    _bgGradientLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:_bgGradientLayer atIndex:0];
}

- (void)setupSearchCompleter {
    _searchCompleter = [[MKLocalSearchCompleter alloc] init];
    _searchCompleter.delegate = self;
    _searchCompleter.resultTypes = MKLocalSearchCompleterResultTypeAddress | MKLocalSearchCompleterResultTypePointOfInterest;
}

- (void)prefillFromEditing {
    if (!_editingContainer) return;

    if (_editingContainer.apps) {
        [_selectedBundleIDs addObjectsFromArray:_editingContainer.apps];
    }
    _gpsEnabled = _editingContainer.gpsEnabled;
    _selectedLatitude = _editingContainer.latitude;
    _selectedLongitude = _editingContainer.longitude;
    _selectedLocationName = _editingContainer.locationName;
    _deviceSpoofEnabled = _editingContainer.deviceSpoofEnabled;
    _spoofDeviceName = _editingContainer.spoofDeviceName;
    _spoofDeviceCheck = _editingContainer.spoofDeviceCheck;
    _spoofVendorID = _editingContainer.spoofVendorID;
    _vendorID = _editingContainer.vendorID;
    _spoofAdvertisingID = _editingContainer.spoofAdvertisingID;
    _advertisingID = _editingContainer.advertisingID;
    _spoofCloudToken = _editingContainer.spoofCloudToken;

    // Find device index
    if (_editingContainer.deviceIdentifier) {
        for (NSInteger i = 0; i < (NSInteger)_deviceList.count; i++) {
            if ([_deviceList[i].identifier isEqualToString:_editingContainer.deviceIdentifier]) {
                _selectedDeviceIndex = i;
                break;
            }
        }
        [self updateIOSVersionsForDeviceQuiet];
        if (_editingContainer.iosVersion) {
            for (NSInteger i = 0; i < (NSInteger)_iosVersionList.count; i++) {
                if ([_iosVersionList[i] isEqualToString:_editingContainer.iosVersion]) {
                    _selectedIOSIndex = i;
                    break;
                }
            }
        }
        // Find storage index
        if (_editingContainer.storageSizeGB > 0 && _selectedDeviceIndex < (NSInteger)_deviceList.count) {
            MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
            for (NSInteger i = 0; i < (NSInteger)device.storageOptions.count; i++) {
                if (device.storageOptions[i].integerValue == _editingContainer.storageSizeGB) {
                    _selectedStorageIndex = i;
                    break;
                }
            }
        }
    }
}

- (void)loadApps {
    _allAppsList = [MiOSAppInfo allApps];
    [self filterApps];
    [self updateDynamicAccentFromSelection];
}

- (void)filterApps {
    NSString *searchText = _appSearchBar.text.lowercaseString ?: @"";
    NSInteger segment = _segmentedControl ? _segmentedControl.selectedSegmentIndex : 0;

    NSMutableArray<MiOSAppInfo *> *result = [NSMutableArray array];
    for (MiOSAppInfo *app in _allAppsList) {
        // Segment filter
        if (segment == 0) {
            if ([app.bundleID hasPrefix:@"com.apple."]) continue;
        } else if (segment == 1) {
            if (![app.bundleID hasPrefix:@"com.apple."]) continue;
        }
        // segment == 2 => All

        // Search filter
        if (searchText.length > 0) {
            NSString *nameLower = app.name.lowercaseString ?: @"";
            NSString *bundleLower = app.bundleID.lowercaseString ?: @"";
            if (![nameLower containsString:searchText] && ![bundleLower containsString:searchText]) {
                continue;
            }
        }

        [result addObject:app];
    }

    _filteredApps = [result copy];
    [_collectionView reloadData];
}

#pragma mark - Step Navigation

- (void)showStep:(NSInteger)step animated:(BOOL)animated {
    _currentStep = step;
    UIView *incoming = (step == 1) ? _step1View : _step2View;
    UIView *outgoing = (step == 1) ? _step2View : _step1View;
    BOOL forward = (step == 2);

    if (!animated) {
        incoming.hidden = NO;
        incoming.alpha = 1;
        incoming.transform = CGAffineTransformIdentity;
        outgoing.hidden = YES;
        return;
    }

    incoming.hidden = NO;
    incoming.alpha = 0;
    incoming.transform = CGAffineTransformMakeTranslation(forward ? self.view.bounds.size.width : -self.view.bounds.size.width, 0);

    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        incoming.alpha = 1;
        incoming.transform = CGAffineTransformIdentity;
        outgoing.alpha = 0;
        outgoing.transform = CGAffineTransformMakeTranslation(forward ? -self.view.bounds.size.width : self.view.bounds.size.width, 0);
    } completion:^(BOOL finished) {
        outgoing.hidden = YES;
    }];
}

- (void)nextTapped {
    NSString *name = [_nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        [self shakeView:_nameField];
        return;
    }
    if (_selectedBundleIDs.count == 0) {
        [self showValidationAlert:@"Please select at least one app."];
        return;
    }
    [self.view endEditing:YES];
    [self showStep:2 animated:YES];
}

- (void)backTapped {
    [self.view endEditing:YES];
    [self showStep:1 animated:YES];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shakeView:(UIView *)view {
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    anim.duration = 0.4;
    anim.values = @[@(-10), @(10), @(-8), @(8), @(-4), @(4), @(0)];
    [view.layer addAnimation:anim forKey:@"shake"];
}

- (void)showValidationAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Missing Info"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Gradient Button Helper

- (void)applyGradientToButton:(UIButton *)button {
    button.clipsToBounds = YES;
    // Remove any existing gradient sublayers
    NSArray *sublayers = [button.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect btnBounds = button.bounds;
        if (btnBounds.size.width < 1) {
            btnBounds = CGRectMake(0, 0, self.view.bounds.size.width - 32, button.bounds.size.height > 0 ? button.bounds.size.height : 50);
        }
        CAGradientLayer *grad = [MiOSTheme accentGradientForBounds:btnBounds];
        grad.cornerRadius = button.layer.cornerRadius;
        [button.layer insertSublayer:grad atIndex:0];
    });

    // Shadow
    button.layer.shadowColor = [MiOSTheme accentColor].CGColor;
    button.layer.shadowOpacity = 0.25;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    button.layer.shadowRadius = 8;
}

#pragma mark - Build Step 1

- (void)buildStep1 {
    _step1View = [[UIView alloc] init];
    _step1View.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_step1View];

    [NSLayoutConstraint activateConstraints:@[
        [_step1View.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_step1View.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_step1View.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_step1View.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *closeCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:closeCfg] forState:UIControlStateNormal];
    closeBtn.tintColor = [MiOSTheme secondaryText];
    closeBtn.backgroundColor = [MiOSTheme accentTintedCardBackground];
    closeBtn.layer.cornerRadius = 16;
    [closeBtn addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step1View addSubview:closeBtn];

    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = _editingContainer ? @"Edit Container" : @"New Container";
    titleLabel.font = [MiOSTheme titleFont];
    titleLabel.textColor = [MiOSTheme primaryText];
    [_step1View addSubview:titleLabel];

    // Step indicator
    UILabel *stepLabel = [[UILabel alloc] init];
    stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stepLabel.text = @"Step 1 of 2 - Select Apps";
    stepLabel.font = [MiOSTheme captionFont];
    stepLabel.textColor = [MiOSTheme tertiaryText];
    [_step1View addSubview:stepLabel];

    // Name field
    _nameField = [[UITextField alloc] init];
    _nameField.translatesAutoresizingMaskIntoConstraints = NO;
    _nameField.placeholder = @"Container name...";
    _nameField.font = [MiOSTheme bodyFont];
    _nameField.textColor = [MiOSTheme primaryText];
    _nameField.backgroundColor = [MiOSTheme accentTintedCardBackground];
    _nameField.layer.cornerRadius = 14;
    _nameField.layer.cornerCurve = kCACornerCurveContinuous;
    _nameField.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    _nameField.layer.borderWidth = 1.0;
    _nameField.delegate = self;
    _nameField.returnKeyType = UIReturnKeyDone;
    _nameField.autocorrectionType = UITextAutocorrectionTypeNo;

    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _nameField.leftView = leftPad;
    _nameField.leftViewMode = UITextFieldViewModeAlways;
    UIView *rightPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 48)];
    _nameField.rightView = rightPad;
    _nameField.rightViewMode = UITextFieldViewModeAlways;

    if (_editingContainer) {
        _nameField.text = _editingContainer.name;
    }
    [_step1View addSubview:_nameField];

    // Segmented control
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"User Apps", @"System Apps", @"All"]];
    _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _segmentedControl.selectedSegmentIndex = 0;
    _segmentedControl.selectedSegmentTintColor = [MiOSTheme accentColor];
    [_segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    [_segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [MiOSTheme secondaryText]} forState:UIControlStateNormal];
    [_segmentedControl addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    [_step1View addSubview:_segmentedControl];

    // Search bar
    _appSearchBar = [[UISearchBar alloc] init];
    _appSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _appSearchBar.placeholder = @"Search apps...";
    _appSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    _appSearchBar.barTintColor = [UIColor clearColor];
    _appSearchBar.tintColor = [MiOSTheme accentColor];
    _appSearchBar.delegate = self;

    UITextField *searchField = _appSearchBar.searchTextField;
    searchField.backgroundColor = [MiOSTheme accentTintedCardBackground];
    searchField.textColor = [MiOSTheme primaryText];
    searchField.layer.cornerRadius = 10;
    searchField.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    searchField.layer.borderWidth = 1.0;
    [_step1View addSubview:_appSearchBar];

    // Collection view - full width list layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 6;
    layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.allowsMultipleSelection = YES;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_collectionView registerClass:[MiOSAppListCell class] forCellWithReuseIdentifier:kAppCellReuseID];
    [_step1View addSubview:_collectionView];

    // Next button - gradient
    _nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_nextButton setTitle:@"Next" forState:UIControlStateNormal];
    [_nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _nextButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _nextButton.layer.cornerRadius = 16;
    _nextButton.layer.cornerCurve = kCACornerCurveContinuous;
    [_nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step1View addSubview:_nextButton];

    [NSLayoutConstraint activateConstraints:@[
        [closeBtn.topAnchor constraintEqualToAnchor:_step1View.topAnchor constant:16],
        [closeBtn.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [closeBtn.widthAnchor constraintEqualToConstant:32],
        [closeBtn.heightAnchor constraintEqualToConstant:32],

        [titleLabel.topAnchor constraintEqualToAnchor:_step1View.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeBtn.leadingAnchor constant:-8],

        [stepLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [stepLabel.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],

        [_nameField.topAnchor constraintEqualToAnchor:stepLabel.bottomAnchor constant:16],
        [_nameField.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_nameField.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_nameField.heightAnchor constraintEqualToConstant:48],

        [_segmentedControl.topAnchor constraintEqualToAnchor:_nameField.bottomAnchor constant:12],
        [_segmentedControl.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_segmentedControl.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_segmentedControl.heightAnchor constraintEqualToConstant:32],

        [_appSearchBar.topAnchor constraintEqualToAnchor:_segmentedControl.bottomAnchor constant:8],
        [_appSearchBar.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:8],
        [_appSearchBar.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-8],

        [_collectionView.topAnchor constraintEqualToAnchor:_appSearchBar.bottomAnchor constant:4],
        [_collectionView.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_collectionView.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_collectionView.bottomAnchor constraintEqualToAnchor:_nextButton.topAnchor constant:-12],

        [_nextButton.leadingAnchor constraintEqualToAnchor:_step1View.leadingAnchor constant:16],
        [_nextButton.trailingAnchor constraintEqualToAnchor:_step1View.trailingAnchor constant:-16],
        [_nextButton.bottomAnchor constraintEqualToAnchor:_step1View.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [_nextButton.heightAnchor constraintEqualToConstant:52],
    ]];

    [self applyGradientToButton:_nextButton];
    [self updateNextButtonTitle];
}

- (void)updateNextButtonTitle {
    NSString *title = [NSString stringWithFormat:@"Next (%lu selected)", (unsigned long)_selectedBundleIDs.count];
    [_nextButton setTitle:title forState:UIControlStateNormal];
}

- (void)updateDynamicAccentFromSelection {
    if (_selectedBundleIDs.count == 0) {
        [MiOSTheme resetDynamicAccent];
        return;
    }

    NSString *firstBundleID = [[_selectedBundleIDs allObjects] sortedArrayUsingSelector:@selector(compare:)].firstObject;
    UIImage *icon = nil;

    for (MiOSAppInfo *app in _allAppsList) {
        if ([app.bundleID isEqualToString:firstBundleID]) {
            icon = app.icon;
            break;
        }
    }
    if (!icon) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:firstBundleID format:0 scale:[UIScreen mainScreen].scale];
    }

    if (icon) {
        UIColor *vibrant = [MiOSColorExtractor vibrantColorFromImage:icon];
        UIColor *gradEnd = [MiOSColorExtractor accentGradientEndFromColor:vibrant];
        [MiOSTheme setDynamicAccentColor:vibrant];
        [MiOSTheme setDynamicAccentGradientEnd:gradEnd];
    } else {
        [MiOSTheme resetDynamicAccent];
    }
}

- (void)dealloc {
    [MiOSTheme resetDynamicAccent];
}

#pragma mark - Build Step 2

- (void)buildStep2 {
    _step2View = [[UIView alloc] init];
    _step2View.translatesAutoresizingMaskIntoConstraints = NO;
    _step2View.hidden = YES;
    [self.view addSubview:_step2View];

    [NSLayoutConstraint activateConstraints:@[
        [_step2View.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_step2View.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_step2View.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_step2View.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Back button
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *backCfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [backBtn setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:backCfg] forState:UIControlStateNormal];
    [backBtn setTitle:@" Back" forState:UIControlStateNormal];
    backBtn.tintColor = [MiOSTheme accentColor];
    backBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [backBtn addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [_step2View addSubview:backBtn];

    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Configure";
    titleLabel.font = [MiOSTheme titleFont];
    titleLabel.textColor = [MiOSTheme primaryText];
    [_step2View addSubview:titleLabel];

    // Step indicator
    UILabel *stepLabel = [[UILabel alloc] init];
    stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
    stepLabel.text = @"Step 2 of 2 - Settings";
    stepLabel.font = [MiOSTheme captionFont];
    stepLabel.textColor = [MiOSTheme tertiaryText];
    [_step2View addSubview:stepLabel];

    // Scroll view
    _step2Scroll = [[UIScrollView alloc] init];
    _step2Scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _step2Scroll.showsVerticalScrollIndicator = NO;
    _step2Scroll.alwaysBounceVertical = YES;
    _step2Scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_step2View addSubview:_step2Scroll];

    _step2Stack = [[UIStackView alloc] init];
    _step2Stack.translatesAutoresizingMaskIntoConstraints = NO;
    _step2Stack.axis = UILayoutConstraintAxisVertical;
    _step2Stack.spacing = 20;
    [_step2Scroll addSubview:_step2Stack];

    [NSLayoutConstraint activateConstraints:@[
        [backBtn.topAnchor constraintEqualToAnchor:_step2View.topAnchor constant:16],
        [backBtn.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:8],

        [titleLabel.topAnchor constraintEqualToAnchor:backBtn.bottomAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],

        [stepLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [stepLabel.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],

        [_step2Scroll.topAnchor constraintEqualToAnchor:stepLabel.bottomAnchor constant:16],
        [_step2Scroll.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor],
        [_step2Scroll.trailingAnchor constraintEqualToAnchor:_step2View.trailingAnchor],
        [_step2Scroll.bottomAnchor constraintEqualToAnchor:_step2View.bottomAnchor],

        [_step2Stack.topAnchor constraintEqualToAnchor:_step2Scroll.topAnchor],
        [_step2Stack.leadingAnchor constraintEqualToAnchor:_step2View.leadingAnchor constant:16],
        [_step2Stack.trailingAnchor constraintEqualToAnchor:_step2View.trailingAnchor constant:-16],
        [_step2Stack.bottomAnchor constraintEqualToAnchor:_step2Scroll.bottomAnchor constant:-32],
    ]];

    [self buildRandomSetupButton];
    [self buildGPSSection];
    [self buildIdentifiersSection];
    [self buildDeviceSection];
    [self buildSaveButton];
}

#pragma mark - Random Setup Button

- (void)buildRandomSetupButton {
    _randomSetupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _randomSetupButton.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *diceCfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
    UIImage *diceIcon = [UIImage systemImageNamed:@"dice.fill" withConfiguration:diceCfg];
    [_randomSetupButton setImage:diceIcon forState:UIControlStateNormal];
    [_randomSetupButton setTitle:@"  Random Setup" forState:UIControlStateNormal];
    [_randomSetupButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _randomSetupButton.tintColor = [UIColor whiteColor];
    _randomSetupButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _randomSetupButton.layer.cornerRadius = 16;
    _randomSetupButton.layer.cornerCurve = kCACornerCurveContinuous;
    [_randomSetupButton addTarget:self action:@selector(randomSetupTapped) forControlEvents:UIControlEventTouchUpInside];
    [_randomSetupButton.heightAnchor constraintEqualToConstant:52].active = YES;

    [self applyGradientToButton:_randomSetupButton];
    [_step2Stack addArrangedSubview:_randomSetupButton];
}

- (void)randomSetupTapped {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [haptic impactOccurred];

    // Enable GPS and set random coordinates
    _gpsEnabled = YES;
    _selectedLatitude = (double)(arc4random_uniform(180000000)) / 1000000.0 - 90.0;
    _selectedLongitude = (double)(arc4random_uniform(360000000)) / 1000000.0 - 180.0;
    _selectedLocationName = nil;
    [self updateMapToCurrentCoordinates];
    [self updateCoordLabel];

    // Enable device spoof and pick random device
    _deviceSpoofEnabled = YES;
    if (_deviceList.count > 0) {
        _selectedDeviceIndex = arc4random_uniform((uint32_t)_deviceList.count);
        [self updateIOSVersionsForDeviceQuiet];

        // Pick random iOS version
        if (_iosVersionList.count > 0) {
            _selectedIOSIndex = arc4random_uniform((uint32_t)_iosVersionList.count);
        }

        // Pick random storage
        MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
        if (device.storageOptions.count > 0) {
            _selectedStorageIndex = arc4random_uniform((uint32_t)device.storageOptions.count);
        }
    }
    [self updateDeviceCardUI];
    [self rebuildStoragePills];
    [self updateIOSVersionButtonTitle];

    // Enable all identifier toggles
    _spoofDeviceCheck = YES;

    _spoofVendorID = YES;
    _vendorID = [[NSUUID UUID] UUIDString];
    _vendorIDLabel.text = _vendorID;
    _vendorIDContainer.hidden = NO;

    _spoofAdvertisingID = YES;
    _advertisingID = [[NSUUID UUID] UUIDString];
    _advertisingIDLabel.text = _advertisingID;
    _advertisingIDContainer.hidden = NO;

    _spoofCloudToken = YES;

    // Show all hidden containers
    _gpsMapContainer.hidden = NO;
    _deviceCardContainer.hidden = NO;

    // Rebuild step 2 to reflect toggle states
    // We need to rebuild the sections since toggle cells need isOn updated
    // Easiest: remove all from stack and rebuild
    for (UIView *v in _step2Stack.arrangedSubviews) {
        [v removeFromSuperview];
    }
    [self buildRandomSetupButton];
    [self buildGPSSection];
    [self buildIdentifiersSection];
    [self buildDeviceSection];
    [self buildSaveButton];

    // Animate a subtle flash
    UIView *flash = [[UIView alloc] initWithFrame:self.view.bounds];
    flash.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.08];
    [self.view addSubview:flash];
    [UIView animateWithDuration:0.5 animations:^{
        flash.alpha = 0;
    } completion:^(BOOL finished) {
        [flash removeFromSuperview];
    }];
}

#pragma mark - GPS Section

- (void)buildGPSSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"GPS Spoofing"];

    MiOSToggleCell *gpsToggle = [[MiOSToggleCell alloc]
        initWithTitle:@"Enable GPS Spoof"
             subtitle:@"Override device location"
                 icon:@"location.fill"
                color:[UIColor systemBlueColor]
                  key:@"gpsEnabled"];
    gpsToggle.isOn = _gpsEnabled;
    gpsToggle.delegate = self;
    [section addCellView:gpsToggle];

    // Map container
    _gpsMapContainer = [[UIView alloc] init];
    _gpsMapContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _gpsMapContainer.hidden = !_gpsEnabled;

    // Map wrapper with rounded corners
    UIView *mapWrapper = [[UIView alloc] init];
    mapWrapper.translatesAutoresizingMaskIntoConstraints = NO;
    mapWrapper.layer.cornerRadius = [MiOSTheme cardCornerRadius];
    mapWrapper.layer.cornerCurve = kCACornerCurveContinuous;
    mapWrapper.clipsToBounds = YES;
    mapWrapper.layer.borderColor = [MiOSTheme separator].CGColor;
    mapWrapper.layer.borderWidth = 0.5;
    [_gpsMapContainer addSubview:mapWrapper];

    _mapView = [[MKMapView alloc] init];
    _mapView.translatesAutoresizingMaskIntoConstraints = NO;
    _mapView.delegate = self;
    _mapView.mapType = MKMapTypeStandard;
    [mapWrapper addSubview:_mapView];

    // Search bar overlaid on map
    _locationSearchBar = [[UISearchBar alloc] init];
    _locationSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _locationSearchBar.placeholder = @"Search location...";
    _locationSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    _locationSearchBar.delegate = self;
    _locationSearchBar.backgroundImage = [UIImage new];
    _locationSearchBar.backgroundColor = [[MiOSTheme cardBackground] colorWithAlphaComponent:0.92];
    _locationSearchBar.layer.cornerRadius = 10;
    _locationSearchBar.clipsToBounds = YES;
    _locationSearchBar.tintColor = [MiOSTheme accentColor];
    _locationSearchBar.searchTextField.textColor = [MiOSTheme primaryText];
    [mapWrapper addSubview:_locationSearchBar];

    // Search results table overlaid on map
    _locationSearchResultsTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _locationSearchResultsTable.translatesAutoresizingMaskIntoConstraints = NO;
    _locationSearchResultsTable.dataSource = self;
    _locationSearchResultsTable.delegate = self;
    _locationSearchResultsTable.backgroundColor = [[MiOSTheme cardBackground] colorWithAlphaComponent:0.95];
    _locationSearchResultsTable.separatorColor = [MiOSTheme separator];
    _locationSearchResultsTable.rowHeight = 48;
    _locationSearchResultsTable.hidden = YES;
    _locationSearchResultsTable.layer.cornerRadius = 10;
    _locationSearchResultsTable.clipsToBounds = YES;
    [mapWrapper addSubview:_locationSearchResultsTable];

    [NSLayoutConstraint activateConstraints:@[
        [mapWrapper.topAnchor constraintEqualToAnchor:_gpsMapContainer.topAnchor constant:8],
        [mapWrapper.leadingAnchor constraintEqualToAnchor:_gpsMapContainer.leadingAnchor constant:12],
        [mapWrapper.trailingAnchor constraintEqualToAnchor:_gpsMapContainer.trailingAnchor constant:-12],
        [mapWrapper.heightAnchor constraintEqualToConstant:250],

        [_mapView.topAnchor constraintEqualToAnchor:mapWrapper.topAnchor],
        [_mapView.leadingAnchor constraintEqualToAnchor:mapWrapper.leadingAnchor],
        [_mapView.trailingAnchor constraintEqualToAnchor:mapWrapper.trailingAnchor],
        [_mapView.bottomAnchor constraintEqualToAnchor:mapWrapper.bottomAnchor],

        [_locationSearchBar.topAnchor constraintEqualToAnchor:mapWrapper.topAnchor constant:8],
        [_locationSearchBar.leadingAnchor constraintEqualToAnchor:mapWrapper.leadingAnchor constant:8],
        [_locationSearchBar.trailingAnchor constraintEqualToAnchor:mapWrapper.trailingAnchor constant:-8],

        [_locationSearchResultsTable.topAnchor constraintEqualToAnchor:_locationSearchBar.bottomAnchor constant:4],
        [_locationSearchResultsTable.leadingAnchor constraintEqualToAnchor:mapWrapper.leadingAnchor constant:8],
        [_locationSearchResultsTable.trailingAnchor constraintEqualToAnchor:mapWrapper.trailingAnchor constant:-8],
        [_locationSearchResultsTable.heightAnchor constraintLessThanOrEqualToConstant:192],
    ]];

    // Long press gesture for pin placement
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [_mapView addGestureRecognizer:longPress];

    // Tap gesture to dismiss search and place pin
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTap:)];
    [_mapView addGestureRecognizer:tap];

    // Set initial map region if we have coordinates
    if (_selectedLatitude != 0 || _selectedLongitude != 0) {
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(_selectedLatitude, _selectedLongitude);
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 5000, 5000);
        [_mapView setRegion:region animated:NO];
        _mapPin = [[MKPointAnnotation alloc] init];
        _mapPin.coordinate = coord;
        _mapPin.title = @"Spoofed Location";
        [_mapView addAnnotation:_mapPin];
    } else {
        // Default to a zoomed-out region so map tiles load instead of a blank world view.
        CLLocationCoordinate2D fallback = CLLocationCoordinate2DMake(37.7749, -122.4194);
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(fallback, 400000, 400000);
        [_mapView setRegion:region animated:NO];
    }

    // Coordinate label below map
    _coordLabel = [[UILabel alloc] init];
    _coordLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _coordLabel.font = [MiOSTheme monoFont];
    _coordLabel.textColor = [MiOSTheme accentColor];
    _coordLabel.textAlignment = NSTextAlignmentCenter;
    _coordLabel.numberOfLines = 1;
    [_gpsMapContainer addSubview:_coordLabel];
    [self updateCoordLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_coordLabel.topAnchor constraintEqualToAnchor:mapWrapper.bottomAnchor constant:10],
        [_coordLabel.leadingAnchor constraintEqualToAnchor:_gpsMapContainer.leadingAnchor constant:16],
        [_coordLabel.trailingAnchor constraintEqualToAnchor:_gpsMapContainer.trailingAnchor constant:-16],
        [_coordLabel.bottomAnchor constraintEqualToAnchor:_gpsMapContainer.bottomAnchor constant:-8],
    ]];

    [section addCellView:_gpsMapContainer];
    [_step2Stack addArrangedSubview:section];
}

- (void)updateCoordLabel {
    _coordLabel.text = [NSString stringWithFormat:@"Lat: %.6f  |  Lon: %.6f", _selectedLatitude, _selectedLongitude];
}

- (void)updateMapToCurrentCoordinates {
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(_selectedLatitude, _selectedLongitude);

    if (!_mapPin) {
        _mapPin = [[MKPointAnnotation alloc] init];
        _mapPin.title = @"Spoofed Location";
        [_mapView addAnnotation:_mapPin];
    }
    _mapPin.coordinate = coord;

    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 5000, 5000);
    [_mapView setRegion:region animated:YES];
}

- (void)setMapLocationToCoordinate:(CLLocationCoordinate2D)coord {
    _selectedLatitude = coord.latitude;
    _selectedLongitude = coord.longitude;

    if (!_mapPin) {
        _mapPin = [[MKPointAnnotation alloc] init];
        _mapPin.title = @"Spoofed Location";
        [_mapView addAnnotation:_mapPin];
    }
    _mapPin.coordinate = coord;
    [self updateCoordLabel];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
}

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    CGPoint point = [gesture locationInView:_mapView];
    CLLocationCoordinate2D coord = [_mapView convertPoint:point toCoordinateFromView:_mapView];
    [self setMapLocationToCoordinate:coord];
}

- (void)handleMapTap:(UITapGestureRecognizer *)gesture {
    if (!_locationSearchResultsTable.hidden) {
        _locationSearchResultsTable.hidden = YES;
        [_locationSearchBar resignFirstResponder];
        return;
    }

    CGPoint point = [gesture locationInView:_mapView];
    CLLocationCoordinate2D coord = [_mapView convertPoint:point toCoordinateFromView:_mapView];
    [self setMapLocationToCoordinate:coord];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;

    MKMarkerAnnotationView *marker = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
    if (!marker) {
        marker = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
    }
    marker.annotation = annotation;
    marker.markerTintColor = [MiOSTheme accentColor];
    marker.animatesWhenAdded = YES;
    return marker;
}

#pragma mark - MKLocalSearchCompleterDelegate

- (void)completerDidUpdateResults:(MKLocalSearchCompleter *)completer {
    _locationSearchResults = completer.results;
    _locationSearchResultsTable.hidden = (_locationSearchResults.count == 0);
    [_locationSearchResultsTable reloadData];
}

- (void)completer:(MKLocalSearchCompleter *)completer didFailWithError:(NSError *)error {
    // Silently handle
}

#pragma mark - Device Section

- (void)buildDeviceSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Device Spoofing"];

    MiOSToggleCell *deviceToggle = [[MiOSToggleCell alloc]
        initWithTitle:@"Enable Device Spoof"
             subtitle:@"Spoof device model and iOS version"
                 icon:@"iphone.gen3"
                color:[UIColor systemTealColor]
                  key:@"deviceSpoofEnabled"];
    deviceToggle.isOn = _deviceSpoofEnabled;
    deviceToggle.delegate = self;
    [section addCellView:deviceToggle];

    // Device card container (hidden when toggle is off)
    _deviceCardContainer = [[UIView alloc] init];
    _deviceCardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _deviceCardContainer.hidden = !_deviceSpoofEnabled;

    // -- Device display card --
    UIView *deviceCard = [[UIView alloc] init];
    deviceCard.translatesAutoresizingMaskIntoConstraints = NO;
    deviceCard.backgroundColor = [MiOSTheme accentTintedCardBackground];
    deviceCard.layer.cornerRadius = 14;
    deviceCard.layer.cornerCurve = kCACornerCurveContinuous;
    deviceCard.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    deviceCard.layer.borderWidth = 1.0;
    [_deviceCardContainer addSubview:deviceCard];

    // Device icon (SF Symbol)
    _deviceIconView = [[UIImageView alloc] init];
    _deviceIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _deviceIconView.contentMode = UIViewContentModeScaleAspectFit;
    _deviceIconView.tintColor = [MiOSTheme accentColor];
    [deviceCard addSubview:_deviceIconView];

    // Device name
    _deviceNameLabel = [[UILabel alloc] init];
    _deviceNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _deviceNameLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _deviceNameLabel.textColor = [MiOSTheme primaryText];
    _deviceNameLabel.numberOfLines = 1;
    [deviceCard addSubview:_deviceNameLabel];

    // Device identifier
    _deviceIdentifierLabel = [[UILabel alloc] init];
    _deviceIdentifierLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _deviceIdentifierLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    _deviceIdentifierLabel.textColor = [MiOSTheme secondaryText];
    [deviceCard addSubview:_deviceIdentifierLabel];

    // Specs label
    _deviceSpecsLabel = [[UILabel alloc] init];
    _deviceSpecsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _deviceSpecsLabel.font = [MiOSTheme captionFont];
    _deviceSpecsLabel.textColor = [MiOSTheme tertiaryText];
    _deviceSpecsLabel.numberOfLines = 0;
    [deviceCard addSubview:_deviceSpecsLabel];

    [NSLayoutConstraint activateConstraints:@[
        [deviceCard.topAnchor constraintEqualToAnchor:_deviceCardContainer.topAnchor constant:8],
        [deviceCard.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:12],
        [deviceCard.trailingAnchor constraintEqualToAnchor:_deviceCardContainer.trailingAnchor constant:-12],

        [_deviceIconView.leadingAnchor constraintEqualToAnchor:deviceCard.leadingAnchor constant:12],
        [_deviceIconView.centerYAnchor constraintEqualToAnchor:deviceCard.centerYAnchor],
        [_deviceIconView.widthAnchor constraintEqualToConstant:80],
        [_deviceIconView.heightAnchor constraintEqualToConstant:100],

        [_deviceNameLabel.topAnchor constraintEqualToAnchor:deviceCard.topAnchor constant:16],
        [_deviceNameLabel.leadingAnchor constraintEqualToAnchor:_deviceIconView.trailingAnchor constant:16],
        [_deviceNameLabel.trailingAnchor constraintEqualToAnchor:deviceCard.trailingAnchor constant:-16],

        [_deviceIdentifierLabel.topAnchor constraintEqualToAnchor:_deviceNameLabel.bottomAnchor constant:4],
        [_deviceIdentifierLabel.leadingAnchor constraintEqualToAnchor:_deviceNameLabel.leadingAnchor],
        [_deviceIdentifierLabel.trailingAnchor constraintEqualToAnchor:_deviceNameLabel.trailingAnchor],

        [_deviceSpecsLabel.topAnchor constraintEqualToAnchor:_deviceIdentifierLabel.bottomAnchor constant:6],
        [_deviceSpecsLabel.leadingAnchor constraintEqualToAnchor:_deviceNameLabel.leadingAnchor],
        [_deviceSpecsLabel.trailingAnchor constraintEqualToAnchor:_deviceNameLabel.trailingAnchor],
        [_deviceSpecsLabel.bottomAnchor constraintEqualToAnchor:deviceCard.bottomAnchor constant:-16],
    ]];

    // -- Navigation arrows row --
    _deviceNavContainer = [[UIView alloc] init];
    _deviceNavContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_deviceCardContainer addSubview:_deviceNavContainer];

    UIButton *prevBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    prevBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *arrowCfg = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold];
    [prevBtn setImage:[UIImage systemImageNamed:@"chevron.left.circle.fill" withConfiguration:arrowCfg] forState:UIControlStateNormal];
    prevBtn.tintColor = [MiOSTheme accentColor];
    [prevBtn addTarget:self action:@selector(prevDeviceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_deviceNavContainer addSubview:prevBtn];

    UIButton *chooseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    chooseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [chooseBtn setTitle:@"Choose Device" forState:UIControlStateNormal];
    chooseBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [chooseBtn setTitleColor:[MiOSTheme accentColor] forState:UIControlStateNormal];
    chooseBtn.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.15];
    chooseBtn.layer.cornerRadius = 12;
    chooseBtn.layer.cornerCurve = kCACornerCurveContinuous;
    chooseBtn.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    chooseBtn.layer.borderWidth = 1.0;
    chooseBtn.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
    [chooseBtn addTarget:self action:@selector(chooseDeviceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_deviceNavContainer addSubview:chooseBtn];

    UIButton *nextDevBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    nextDevBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [nextDevBtn setImage:[UIImage systemImageNamed:@"chevron.right.circle.fill" withConfiguration:arrowCfg] forState:UIControlStateNormal];
    nextDevBtn.tintColor = [MiOSTheme accentColor];
    [nextDevBtn addTarget:self action:@selector(nextDeviceTapped) forControlEvents:UIControlEventTouchUpInside];
    [_deviceNavContainer addSubview:nextDevBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_deviceNavContainer.topAnchor constraintEqualToAnchor:deviceCard.bottomAnchor constant:12],
        [_deviceNavContainer.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:12],
        [_deviceNavContainer.trailingAnchor constraintEqualToAnchor:_deviceCardContainer.trailingAnchor constant:-12],
        [_deviceNavContainer.heightAnchor constraintEqualToConstant:36],

        [prevBtn.leadingAnchor constraintEqualToAnchor:_deviceNavContainer.leadingAnchor],
        [prevBtn.centerYAnchor constraintEqualToAnchor:_deviceNavContainer.centerYAnchor],

        [chooseBtn.centerXAnchor constraintEqualToAnchor:_deviceNavContainer.centerXAnchor],
        [chooseBtn.centerYAnchor constraintEqualToAnchor:_deviceNavContainer.centerYAnchor],

        [nextDevBtn.trailingAnchor constraintEqualToAnchor:_deviceNavContainer.trailingAnchor],
        [nextDevBtn.centerYAnchor constraintEqualToAnchor:_deviceNavContainer.centerYAnchor],
    ]];

    // -- Storage pills section --
    UILabel *storageLabel = [[UILabel alloc] init];
    storageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    storageLabel.text = @"STORAGE";
    storageLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    storageLabel.textColor = [MiOSTheme tertiaryText];
    [_deviceCardContainer addSubview:storageLabel];

    _storagePillContainer = [[UIView alloc] init];
    _storagePillContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_deviceCardContainer addSubview:_storagePillContainer];

    UIScrollView *storagePillScroll = [[UIScrollView alloc] init];
    storagePillScroll.translatesAutoresizingMaskIntoConstraints = NO;
    storagePillScroll.showsHorizontalScrollIndicator = NO;
    storagePillScroll.tag = 500;
    [_storagePillContainer addSubview:storagePillScroll];

    [NSLayoutConstraint activateConstraints:@[
        [storageLabel.topAnchor constraintEqualToAnchor:_deviceNavContainer.bottomAnchor constant:16],
        [storageLabel.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:16],

        [_storagePillContainer.topAnchor constraintEqualToAnchor:storageLabel.bottomAnchor constant:8],
        [_storagePillContainer.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:12],
        [_storagePillContainer.trailingAnchor constraintEqualToAnchor:_deviceCardContainer.trailingAnchor constant:-12],
        [_storagePillContainer.heightAnchor constraintEqualToConstant:38],

        [storagePillScroll.topAnchor constraintEqualToAnchor:_storagePillContainer.topAnchor],
        [storagePillScroll.leadingAnchor constraintEqualToAnchor:_storagePillContainer.leadingAnchor],
        [storagePillScroll.trailingAnchor constraintEqualToAnchor:_storagePillContainer.trailingAnchor],
        [storagePillScroll.bottomAnchor constraintEqualToAnchor:_storagePillContainer.bottomAnchor],
    ]];

    // -- iOS Version button --
    UILabel *iosLabel = [[UILabel alloc] init];
    iosLabel.translatesAutoresizingMaskIntoConstraints = NO;
    iosLabel.text = @"iOS VERSION";
    iosLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    iosLabel.textColor = [MiOSTheme tertiaryText];
    [_deviceCardContainer addSubview:iosLabel];

    _iosVersionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _iosVersionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _iosVersionButton.titleLabel.font = [MiOSTheme bodyFont];
    [_iosVersionButton setTitleColor:[MiOSTheme primaryText] forState:UIControlStateNormal];
    _iosVersionButton.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.08];
    _iosVersionButton.layer.cornerRadius = 10;
    _iosVersionButton.layer.cornerCurve = kCACornerCurveContinuous;
    _iosVersionButton.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    _iosVersionButton.layer.borderWidth = 1.0;
    _iosVersionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _iosVersionButton.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    UIImage *chevDown = [UIImage systemImageNamed:@"chevron.down" withConfiguration:chevCfg];
    [_iosVersionButton setImage:chevDown forState:UIControlStateNormal];
    _iosVersionButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _iosVersionButton.imageEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    _iosVersionButton.tintColor = [MiOSTheme secondaryText];
    [_iosVersionButton addTarget:self action:@selector(iosVersionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_deviceCardContainer addSubview:_iosVersionButton];

    [NSLayoutConstraint activateConstraints:@[
        [iosLabel.topAnchor constraintEqualToAnchor:_storagePillContainer.bottomAnchor constant:16],
        [iosLabel.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:16],

        [_iosVersionButton.topAnchor constraintEqualToAnchor:iosLabel.bottomAnchor constant:8],
        [_iosVersionButton.leadingAnchor constraintEqualToAnchor:_deviceCardContainer.leadingAnchor constant:12],
        [_iosVersionButton.trailingAnchor constraintEqualToAnchor:_deviceCardContainer.trailingAnchor constant:-12],
        [_iosVersionButton.heightAnchor constraintEqualToConstant:44],
    ]];

    // -- Device name spoofing --
    [section addSeparator];

    _deviceNameToggle = [[MiOSToggleCell alloc]
        initWithTitle:@"Custom Device Name"
             subtitle:@"Override reported device name"
                 icon:@"pencil.line"
                color:[UIColor systemPurpleColor]
                  key:@"spoofDeviceName"];
    _deviceNameToggle.isOn = _spoofDeviceName;
    _deviceNameToggle.delegate = self;

    _customDeviceNameContainer = [[UIView alloc] init];
    _customDeviceNameContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _customDeviceNameContainer.hidden = !_spoofDeviceName;

    _customDeviceNameField = [self createStyledTextFieldWithPlaceholder:@"Custom device name..." keyboardType:UIKeyboardTypeDefault];
    if (_editingContainer.customDeviceName.length > 0) {
        _customDeviceNameField.text = _editingContainer.customDeviceName;
    }
    [_customDeviceNameContainer addSubview:_customDeviceNameField];

    [NSLayoutConstraint activateConstraints:@[
        [_customDeviceNameField.topAnchor constraintEqualToAnchor:_customDeviceNameContainer.topAnchor constant:4],
        [_customDeviceNameField.leadingAnchor constraintEqualToAnchor:_customDeviceNameContainer.leadingAnchor constant:16],
        [_customDeviceNameField.trailingAnchor constraintEqualToAnchor:_customDeviceNameContainer.trailingAnchor constant:-16],
        [_customDeviceNameField.heightAnchor constraintEqualToConstant:44],
        [_customDeviceNameField.bottomAnchor constraintEqualToAnchor:_customDeviceNameContainer.bottomAnchor constant:-8],
    ]];

    // Finalize bottom constraint of device card container
    // The iOS version button is the last element before the device name toggle
    [_iosVersionButton.bottomAnchor constraintEqualToAnchor:_deviceCardContainer.bottomAnchor constant:-12].active = YES;

    [section addCellView:_deviceCardContainer];
    [section addCellView:_deviceNameToggle];
    [section addCellView:_customDeviceNameContainer];

    [_step2Stack addArrangedSubview:section];

    // Populate initial values
    [self updateDeviceCardUI];
    [self rebuildStoragePills];
    [self updateIOSVersionButtonTitle];
}

- (void)updateDeviceCardUI {
    if (_selectedDeviceIndex >= (NSInteger)_deviceList.count) return;

    MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];

    // Rendered device image
    _deviceIconView.image = [MiOSDeviceImageRenderer renderDeviceForName:device.displayName
                                                                    size:CGSizeMake(80, 100)
                                                             accentColor:[MiOSTheme accentColor]];

    // Name and identifier
    _deviceNameLabel.text = device.displayName;
    _deviceIdentifierLabel.text = device.identifier;

    // Specs
    NSString *specs = [NSString stringWithFormat:@"%@ | %ld GB RAM | %ld Cores",
                       device.chipName ?: @"Unknown",
                       (long)device.ramGB,
                       (long)device.cpuCores];
    _deviceSpecsLabel.text = specs;
}

- (void)rebuildStoragePills {
    UIScrollView *scrollView = [_storagePillContainer viewWithTag:500];
    for (UIView *v in scrollView.subviews) {
        [v removeFromSuperview];
    }

    if (_selectedDeviceIndex >= (NSInteger)_deviceList.count) return;

    MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
    NSArray<NSNumber *> *options = device.storageOptions;
    if (!options || options.count == 0) return;

    // Clamp selected index
    if (_selectedStorageIndex >= (NSInteger)options.count) {
        _selectedStorageIndex = 0;
    }

    CGFloat x = 0;
    CGFloat pillHeight = 32;
    CGFloat spacing = 8;

    for (NSInteger i = 0; i < (NSInteger)options.count; i++) {
        NSInteger gb = options[i].integerValue;
        NSString *title = [NSString stringWithFormat:@"%ldGB", (long)gb];

        UIButton *pill = [UIButton buttonWithType:UIButtonTypeSystem];
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.tag = 600 + i;
        [pill setTitle:title forState:UIControlStateNormal];
        pill.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        pill.layer.cornerRadius = pillHeight / 2.0;
        pill.layer.cornerCurve = kCACornerCurveContinuous;
        pill.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        [pill addTarget:self action:@selector(storagePillTapped:) forControlEvents:UIControlEventTouchUpInside];

        if (i == _selectedStorageIndex) {
            pill.backgroundColor = [MiOSTheme accentColor];
            [pill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            pill.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.12];
            [pill setTitleColor:[MiOSTheme accentColor] forState:UIControlStateNormal];
        }

        [pill sizeToFit];
        CGFloat w = pill.intrinsicContentSize.width + 32;
        pill.frame = CGRectMake(x, 0, w, pillHeight);
        [scrollView addSubview:pill];
        x += w + spacing;
    }

    scrollView.contentSize = CGSizeMake(x, pillHeight);
}

- (void)storagePillTapped:(UIButton *)sender {
    NSInteger idx = sender.tag - 600;
    _selectedStorageIndex = idx;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    [self rebuildStoragePills];
}

- (void)updateIOSVersionButtonTitle {
    NSString *ver = @"Select...";
    if (_selectedIOSIndex < (NSInteger)_iosVersionList.count) {
        ver = [NSString stringWithFormat:@"iOS %@", _iosVersionList[_selectedIOSIndex]];
    }
    [_iosVersionButton setTitle:ver forState:UIControlStateNormal];
}

- (void)iosVersionButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select iOS Version"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSInteger i = 0; i < (NSInteger)_iosVersionList.count; i++) {
        NSString *ver = _iosVersionList[i];
        NSString *title = [NSString stringWithFormat:@"iOS %@", ver];
        if (i == _selectedIOSIndex) {
            title = [NSString stringWithFormat:@"iOS %@ (current)", ver];
        }
        __weak typeof(self) weakSelf = self;
        NSInteger idx = i;
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            weakSelf.selectedIOSIndex = idx;
            [weakSelf updateIOSVersionButtonTitle];
            UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [h impactOccurred];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = _iosVersionButton;
        alert.popoverPresentationController.sourceRect = _iosVersionButton.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)prevDeviceTapped {
    if (_deviceList.count == 0) return;
    _selectedDeviceIndex--;
    if (_selectedDeviceIndex < 0) {
        _selectedDeviceIndex = (NSInteger)_deviceList.count - 1;
    }
    [self deviceSelectionChanged];
}

- (void)nextDeviceTapped {
    if (_deviceList.count == 0) return;
    _selectedDeviceIndex++;
    if (_selectedDeviceIndex >= (NSInteger)_deviceList.count) {
        _selectedDeviceIndex = 0;
    }
    [self deviceSelectionChanged];
}

- (void)deviceSelectionChanged {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    [self updateIOSVersionsForDeviceQuiet];
    _selectedStorageIndex = 0;
    [self updateDeviceCardUI];
    [self rebuildStoragePills];
    [self updateIOSVersionButtonTitle];
}

- (void)chooseDeviceTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Choose Device"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)_deviceList.count; i++) {
        MiOSDeviceModel *dev = _deviceList[i];
        NSString *title = dev.displayName;
        if (i == _selectedDeviceIndex) {
            title = [NSString stringWithFormat:@"%@ (current)", dev.displayName];
        }
        NSInteger idx = i;
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            weakSelf.selectedDeviceIndex = idx;
            [weakSelf deviceSelectionChanged];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = _deviceNavContainer;
        alert.popoverPresentationController.sourceRect = _deviceNavContainer.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Identifiers Section

- (void)buildIdentifiersSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Identity & Privacy"];

    // DeviceCheck
    MiOSToggleCell *deviceCheckCell = [[MiOSToggleCell alloc]
        initWithTitle:@"DeviceCheck Bypass"
             subtitle:@"Block DeviceCheck token generation"
                 icon:@"checkmark.shield.fill"
                color:[UIColor systemRedColor]
                  key:@"spoofDeviceCheck"];
    deviceCheckCell.isOn = _spoofDeviceCheck;
    deviceCheckCell.delegate = self;
    [section addCellView:deviceCheckCell];
    [section addSeparator];

    // Vendor ID
    MiOSToggleCell *vendorCell = [[MiOSToggleCell alloc]
        initWithTitle:@"Vendor ID Spoof"
             subtitle:@"Spoof identifierForVendor"
                 icon:@"person.badge.key.fill"
                color:[UIColor systemIndigoColor]
                  key:@"spoofVendorID"];
    vendorCell.isOn = _spoofVendorID;
    vendorCell.delegate = self;
    [section addCellView:vendorCell];

    UILabel *vendorLabelOut = nil;
    _vendorIDContainer = [self buildUUIDRowWithValue:_vendorID ?: @"Not generated"
                                           labelOut:&vendorLabelOut
                                        generateSel:@selector(generateVendorID)];
    _vendorIDLabel = vendorLabelOut;
    _vendorIDContainer.hidden = !_spoofVendorID;
    [section addCellView:_vendorIDContainer];
    [section addSeparator];

    // Advertising ID
    MiOSToggleCell *adCell = [[MiOSToggleCell alloc]
        initWithTitle:@"Advertising ID Spoof"
             subtitle:@"Spoof advertisingIdentifier"
                 icon:@"megaphone.fill"
                color:[UIColor systemOrangeColor]
                  key:@"spoofAdvertisingID"];
    adCell.isOn = _spoofAdvertisingID;
    adCell.delegate = self;
    [section addCellView:adCell];

    UILabel *adLabelOut = nil;
    _advertisingIDContainer = [self buildUUIDRowWithValue:_advertisingID ?: @"Not generated"
                                               labelOut:&adLabelOut
                                            generateSel:@selector(generateAdvertisingID)];
    _advertisingIDLabel = adLabelOut;
    _advertisingIDContainer.hidden = !_spoofAdvertisingID;
    [section addCellView:_advertisingIDContainer];
    [section addSeparator];

    // iCloud Token
    MiOSToggleCell *cloudCell = [[MiOSToggleCell alloc]
        initWithTitle:@"iCloud Token Spoof"
             subtitle:@"Return nil for ubiquityIdentityToken"
                 icon:@"icloud.slash.fill"
                color:[UIColor systemGrayColor]
                  key:@"spoofCloudToken"];
    cloudCell.isOn = _spoofCloudToken;
    cloudCell.delegate = self;
    [section addCellView:cloudCell];

    [_step2Stack addArrangedSubview:section];
}

- (UIView *)buildUUIDRowWithValue:(NSString *)value labelOut:(UILabel **)outLabel generateSel:(SEL)sel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = value;
    valueLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    valueLabel.textColor = [MiOSTheme secondaryText];
    valueLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [row addSubview:valueLabel];
    if (outLabel) *outLabel = valueLabel;

    UIButton *genBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    genBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [genBtn setTitle:@"Generate" forState:UIControlStateNormal];
    genBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [genBtn setTitleColor:[MiOSTheme accentColor] forState:UIControlStateNormal];
    genBtn.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.12];
    genBtn.layer.cornerRadius = 8;
    genBtn.layer.cornerCurve = kCACornerCurveContinuous;
    genBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    [genBtn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:genBtn];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:44],
        [valueLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [valueLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:genBtn.leadingAnchor constant:-8],
        [genBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [genBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];

    return row;
}

- (void)generateVendorID {
    _vendorID = [[NSUUID UUID] UUIDString];
    _vendorIDLabel.text = _vendorID;
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

- (void)generateAdvertisingID {
    _advertisingID = [[NSUUID UUID] UUIDString];
    _advertisingIDLabel.text = _advertisingID;
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
}

#pragma mark - Save Button

- (void)buildSaveButton {
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn setTitle:@"Save Container" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    saveBtn.layer.cornerRadius = 16;
    saveBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [saveBtn.heightAnchor constraintEqualToConstant:52].active = YES;

    [self applyGradientToButton:saveBtn];
    [_step2Stack addArrangedSubview:saveBtn];
}

- (void)saveTapped {
    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [haptic impactOccurred];

    MiOSContainerConfig *config = _editingContainer ?: [[MiOSContainerConfig alloc] init];

    // If new, generate UUID
    if (!_editingContainer) {
        config.identifier = [[NSUUID UUID] UUIDString];
    }

    config.name = [_nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    config.apps = [[_selectedBundleIDs allObjects] mutableCopy];

    // GPS
    config.gpsEnabled = _gpsEnabled;
    config.latitude = _selectedLatitude;
    config.longitude = _selectedLongitude;
    config.locationName = _selectedLocationName;

    // Device
    config.deviceSpoofEnabled = _deviceSpoofEnabled;
    if (_deviceSpoofEnabled && _selectedDeviceIndex < (NSInteger)_deviceList.count) {
        MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
        config.deviceIdentifier = device.identifier;
        config.deviceName = device.displayName;
        config.hwModel = device.hwModel;

        // Storage
        if (_selectedStorageIndex < (NSInteger)device.storageOptions.count) {
            config.storageSizeGB = device.storageOptions[_selectedStorageIndex].integerValue;
        }
    }
    if (_deviceSpoofEnabled && _selectedIOSIndex < (NSInteger)_iosVersionList.count) {
        config.iosVersion = _iosVersionList[_selectedIOSIndex];
    }

    // Custom device name
    config.spoofDeviceName = _spoofDeviceName;
    if (_spoofDeviceName) {
        config.customDeviceName = [_customDeviceNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    // Identifiers
    config.spoofDeviceCheck = _spoofDeviceCheck;
    config.spoofVendorID = _spoofVendorID;
    config.vendorID = _vendorID;
    config.spoofAdvertisingID = _spoofAdvertisingID;
    config.advertisingID = _advertisingID;
    config.spoofCloudToken = _spoofCloudToken;

    // Apply to system
    [config applyToSystem];

    // Save to list
    NSMutableArray<MiOSContainerConfig *> *all = [[MiOSContainerConfig loadAll] mutableCopy] ?: [NSMutableArray array];
    if (_editingContainer) {
        for (NSUInteger i = 0; i < all.count; i++) {
            if ([all[i].identifier isEqualToString:config.identifier]) {
                [all replaceObjectAtIndex:i withObject:config];
                break;
            }
        }
    } else {
        [all addObject:config];
    }
    [MiOSContainerConfig saveAll:all];
    [MiOSContainerConfig setActiveContainerID:config.identifier];

    if (_onSave) {
        _onSave();
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helper: Styled Text Field

- (UITextField *)createStyledTextFieldWithPlaceholder:(NSString *)placeholder keyboardType:(UIKeyboardType)type {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.font = [MiOSTheme bodyFont];
    field.textColor = [MiOSTheme primaryText];
    field.backgroundColor = [[MiOSTheme accentColor] colorWithAlphaComponent:0.06];
    field.layer.cornerRadius = 10;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.layer.borderColor = [MiOSTheme accentBorderColor].CGColor;
    field.layer.borderWidth = 1.0;
    field.keyboardType = type;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;

    UIView *lpad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.leftView = lpad;
    field.leftViewMode = UITextFieldViewModeAlways;
    UIView *rpad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    field.rightView = rpad;
    field.rightViewMode = UITextFieldViewModeAlways;

    return field;
}

#pragma mark - Device Picker Helpers

- (void)updateIOSVersionsForDeviceQuiet {
    if (_selectedDeviceIndex < (NSInteger)_deviceList.count) {
        MiOSDeviceModel *device = _deviceList[_selectedDeviceIndex];
        _iosVersionList = [MiOSDeviceDatabase supportedIOSVersionsForDevice:device];
    } else {
        _iosVersionList = [MiOSDeviceDatabase allIOSVersions];
    }
    if (_selectedIOSIndex >= (NSInteger)_iosVersionList.count) {
        _selectedIOSIndex = 0;
    }
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)_filteredApps.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MiOSAppListCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kAppCellReuseID
                                                                      forIndexPath:indexPath];
    MiOSAppInfo *app = _filteredApps[indexPath.item];
    cell.iconView.image = app.icon;
    cell.nameLabel.text = app.name;
    cell.bundleLabel.text = app.bundleID;
    cell.isChecked = [_selectedBundleIDs containsObject:app.bundleID];
    return cell;
}

#pragma mark - UICollectionView Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];

    MiOSAppInfo *app = _filteredApps[indexPath.item];
    if ([_selectedBundleIDs containsObject:app.bundleID]) {
        [_selectedBundleIDs removeObject:app.bundleID];
    } else {
        [_selectedBundleIDs addObject:app.bundleID];
    }

    MiOSAppListCell *cell = (MiOSAppListCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.isChecked = [_selectedBundleIDs containsObject:app.bundleID];

    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];

    [self updateNextButtonTitle];
    [self updateDynamicAccentFromSelection];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = collectionView.bounds.size.width;
    return CGSizeMake(width, 72);
}

#pragma mark - MiOSToggleCellDelegate

- (void)toggleCell:(id)cell didChangeValue:(BOOL)value forKey:(NSString *)key {
    if ([key isEqualToString:@"gpsEnabled"]) {
        _gpsEnabled = value;
        _gpsMapContainer.hidden = !value;
    } else if ([key isEqualToString:@"deviceSpoofEnabled"]) {
        _deviceSpoofEnabled = value;
        _deviceCardContainer.hidden = !value;
    } else if ([key isEqualToString:@"spoofDeviceName"]) {
        _spoofDeviceName = value;
        _customDeviceNameContainer.hidden = !value;
    } else if ([key isEqualToString:@"spoofDeviceCheck"]) {
        _spoofDeviceCheck = value;
    } else if ([key isEqualToString:@"spoofVendorID"]) {
        _spoofVendorID = value;
        _vendorIDContainer.hidden = !value;
        if (value && !_vendorID) {
            _vendorID = [[NSUUID UUID] UUIDString];
            _vendorIDLabel.text = _vendorID;
        }
    } else if ([key isEqualToString:@"spoofAdvertisingID"]) {
        _spoofAdvertisingID = value;
        _advertisingIDContainer.hidden = !value;
        if (value && !_advertisingID) {
            _advertisingID = [[NSUUID UUID] UUIDString];
            _advertisingIDLabel.text = _advertisingID;
        }
    } else if ([key isEqualToString:@"spoofCloudToken"]) {
        _spoofCloudToken = value;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchBar == _appSearchBar) {
        [self filterApps];
    } else if (searchBar == _locationSearchBar) {
        if (searchText.length == 0) {
            _locationSearchResults = @[];
            _locationSearchResultsTable.hidden = YES;
            [_locationSearchResultsTable reloadData];
            return;
        }
        _searchCompleter.queryFragment = searchText;
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if (searchBar == _appSearchBar) {
        [searchBar resignFirstResponder];
    } else if (searchBar == _locationSearchBar) {
        [searchBar resignFirstResponder];
        _locationSearchResultsTable.hidden = YES;

        NSString *query = searchBar.text;
        if (query.length == 0) return;

        MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
        request.naturalLanguageQuery = query;
        MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
        __weak typeof(self) weakSelf = self;
        [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
            MKMapItem *item = response.mapItems.firstObject;
            if (!item) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setMapLocationToCoordinate:item.placemark.coordinate];
                weakSelf.selectedLocationName = item.name;
                MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(item.placemark.coordinate, 5000, 5000);
                [weakSelf.mapView setRegion:region animated:YES];
                searchBar.text = @"";
            });
        }];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    if (searchBar == _locationSearchBar) {
        searchBar.showsCancelButton = YES;
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if (searchBar == _locationSearchBar) {
        searchBar.text = @"";
        searchBar.showsCancelButton = NO;
        [searchBar resignFirstResponder];
        _locationSearchResults = @[];
        _locationSearchResultsTable.hidden = YES;
        [_locationSearchResultsTable reloadData];
    }
}

#pragma mark - UITableViewDataSource / Delegate (Location Search Results)

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MIN((NSInteger)_locationSearchResults.count, 5);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"locResult"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"locResult"];
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = [MiOSTheme primaryText];
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    cell.detailTextLabel.textColor = [MiOSTheme secondaryText];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];

    MKLocalSearchCompletion *result = _locationSearchResults[indexPath.row];
    cell.textLabel.text = result.title;
    cell.detailTextLabel.text = result.subtitle;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    cell.imageView.image = [UIImage systemImageNamed:@"mappin.circle.fill" withConfiguration:cfg];
    cell.imageView.tintColor = [MiOSTheme accentColor];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    MKLocalSearchCompletion *completion = _locationSearchResults[indexPath.row];
    NSString *displayName = completion.title;
    NSString *queryString = completion.subtitle.length > 0
        ? [NSString stringWithFormat:@"%@ %@", completion.title, completion.subtitle]
        : completion.title;

    // Dismiss the search UI immediately so the selection feels instant.
    _locationSearchBar.text = @"";
    _locationSearchBar.showsCancelButton = NO;
    [_locationSearchBar resignFirstResponder];
    _locationSearchResults = @[];
    _locationSearchResultsTable.hidden = YES;
    [_locationSearchResultsTable reloadData];

    __weak typeof(self) weakSelf = self;
    void (^applyCoord)(CLLocationCoordinate2D) = ^(CLLocationCoordinate2D coord) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setMapLocationToCoordinate:coord];
            weakSelf.selectedLocationName = displayName;
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 5000, 5000);
            [weakSelf.mapView setRegion:region animated:YES];
        });
    };

    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] initWithCompletion:completion];
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        MKMapItem *item = response.mapItems.firstObject;
        if (item) {
            applyCoord(item.placemark.coordinate);
            return;
        }
        // Fallback: resolve the completion text via geocoder so a pick always sets a location.
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder geocodeAddressString:queryString completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *geoErr) {
            CLLocation *loc = placemarks.firstObject.location;
            if (loc) applyCoord(loc.coordinate);
        }];
    }];
}

#pragma mark - Segmented Control

- (void)segmentChanged {
    [self filterApps];
}

@end
