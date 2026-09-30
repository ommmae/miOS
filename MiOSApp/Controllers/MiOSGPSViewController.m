#import "MiOSGPSViewController.h"
#import "../Views/MiOSSectionCardView.h"
#import "../Views/MiOSToggleCell.h"
#import "../UI/MiOSTheme.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString *const kMiOSLocationPrefsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.locationprefs.plist";
static NSString *const kMiOSSavedLocationsPath = @"/var/mobile/Library/Preferences/MiOS/com.mios.savedlocations.plist";

@interface MiOSGPSViewController () <MKMapViewDelegate, MiOSToggleCellDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStack;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UILabel *coordLabel;
@property (nonatomic, strong) NSMutableDictionary *locationPrefs;
@property (nonatomic, strong) NSMutableDictionary *savedLocations;
@property (nonatomic, strong) UIStackView *savedStack;
@end

@implementation MiOSGPSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GPS Spoofer";
    self.view.backgroundColor = [MiOSTheme primaryBackground];
    [self loadPreferences];
    [self setupUI];
}

- (void)loadPreferences {
    _locationPrefs = [[NSMutableDictionary dictionaryWithContentsOfFile:kMiOSLocationPrefsPath] mutableCopy];
    if (!_locationPrefs) {
        _locationPrefs = [@{@"enabled": @NO, @"latitude": @(40.7128), @"longitude": @(-74.0060), @"altitude": @(0), @"accuracy": @(5)} mutableCopy];
    }
    _savedLocations = [[NSMutableDictionary dictionaryWithContentsOfFile:kMiOSSavedLocationsPath] mutableCopy];
    if (!_savedLocations) _savedLocations = [NSMutableDictionary new];
}

- (void)savePreferences {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [kMiOSLocationPrefsPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [_locationPrefs writeToFile:kMiOSLocationPrefsPath atomically:YES];
}

- (void)saveSavedLocations {
    [_savedLocations writeToFile:kMiOSSavedLocationsPath atomically:YES];
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

    [self buildToggleSection];
    [self buildMapSection];
    [self buildCoordinateSection];
    [self buildSavedLocationsSection];
    [self buildActionsSection];
}

- (void)buildToggleSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@""];

    MiOSToggleCell *enableCell = [[MiOSToggleCell alloc]
        initWithTitle:@"Enable GPS Spoof"
             subtitle:@"Override location for target apps"
                 icon:@"location.fill"
                color:[UIColor systemBlueColor]
                  key:@"enabled"];
    enableCell.isOn = [_locationPrefs[@"enabled"] boolValue];
    enableCell.delegate = self;
    [section addCellView:enableCell];

    [_mainStack addArrangedSubview:section];
}

- (void)buildMapSection {
    UIView *mapContainer = [[UIView alloc] init];
    mapContainer.translatesAutoresizingMaskIntoConstraints = NO;
    mapContainer.layer.cornerRadius = [MiOSTheme cardCornerRadius];
    mapContainer.layer.cornerCurve = kCACornerCurveContinuous;
    mapContainer.clipsToBounds = YES;
    mapContainer.layer.borderColor = [MiOSTheme separator].CGColor;
    mapContainer.layer.borderWidth = 0.5;

    _mapView = [[MKMapView alloc] init];
    _mapView.translatesAutoresizingMaskIntoConstraints = NO;
    _mapView.delegate = self;
    _mapView.showsUserLocation = NO;
    _mapView.mapType = MKMapTypeStandard;
    [mapContainer addSubview:_mapView];

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    searchBar.placeholder = @"Search location...";
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.delegate = self;
    searchBar.backgroundImage = [UIImage new];
    searchBar.backgroundColor = [[MiOSTheme cardBackground] colorWithAlphaComponent:0.9];
    [mapContainer addSubview:searchBar];

    [NSLayoutConstraint activateConstraints:@[
        [_mapView.topAnchor constraintEqualToAnchor:mapContainer.topAnchor],
        [_mapView.leadingAnchor constraintEqualToAnchor:mapContainer.leadingAnchor],
        [_mapView.trailingAnchor constraintEqualToAnchor:mapContainer.trailingAnchor],
        [_mapView.bottomAnchor constraintEqualToAnchor:mapContainer.bottomAnchor],
        [mapContainer.heightAnchor constraintEqualToConstant:280],
        [searchBar.topAnchor constraintEqualToAnchor:mapContainer.topAnchor constant:8],
        [searchBar.leadingAnchor constraintEqualToAnchor:mapContainer.leadingAnchor constant:8],
        [searchBar.trailingAnchor constraintEqualToAnchor:mapContainer.trailingAnchor constant:-8],
    ]];

    double lat = [_locationPrefs[@"latitude"] doubleValue];
    double lon = [_locationPrefs[@"longitude"] doubleValue];
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 5000, 5000);
    [_mapView setRegion:region animated:NO];

    _pin = [[MKPointAnnotation alloc] init];
    _pin.coordinate = coord;
    _pin.title = @"Spoofed Location";
    [_mapView addAnnotation:_pin];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [_mapView addGestureRecognizer:longPress];

    [_mainStack addArrangedSubview:mapContainer];
}

- (void)buildCoordinateSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Coordinates"];

    _coordLabel = [[UILabel alloc] init];
    _coordLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _coordLabel.font = [MiOSTheme monoFont];
    _coordLabel.textColor = [MiOSTheme accentColor];
    _coordLabel.textAlignment = NSTextAlignmentCenter;
    _coordLabel.numberOfLines = 0;
    [self updateCoordLabel];

    UIView *coordContainer = [[UIView alloc] init];
    coordContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [coordContainer addSubview:_coordLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_coordLabel.topAnchor constraintEqualToAnchor:coordContainer.topAnchor constant:16],
        [_coordLabel.leadingAnchor constraintEqualToAnchor:coordContainer.leadingAnchor constant:16],
        [_coordLabel.trailingAnchor constraintEqualToAnchor:coordContainer.trailingAnchor constant:-16],
        [_coordLabel.bottomAnchor constraintEqualToAnchor:coordContainer.bottomAnchor constant:-16],
    ]];
    [section addCellView:coordContainer];

    [_mainStack addArrangedSubview:section];
}

- (void)buildSavedLocationsSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@"Saved Locations"];

    _savedStack = [[UIStackView alloc] init];
    _savedStack.translatesAutoresizingMaskIntoConstraints = NO;
    _savedStack.axis = UILayoutConstraintAxisVertical;
    _savedStack.spacing = 0;

    [self rebuildSavedList];
    [section addCellView:_savedStack];

    MiOSNavigationCell *addCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"Save Current Location"
             subtitle:nil
                 icon:@"plus.circle.fill"
                color:[MiOSTheme success]];
    __weak typeof(self) weakSelf = self;
    addCell.tapAction = ^{ [weakSelf promptSaveLocation]; };
    [section addSeparator];
    [section addCellView:addCell];

    [_mainStack addArrangedSubview:section];
}

- (void)rebuildSavedList {
    for (UIView *v in _savedStack.arrangedSubviews) [v removeFromSuperview];

    __weak typeof(self) weakSelf = self;
    for (NSString *name in _savedLocations) {
        NSDictionary *loc = _savedLocations[name];
        double lat = [loc[@"latitude"] doubleValue];
        double lon = [loc[@"longitude"] doubleValue];
        NSString *sub = [NSString stringWithFormat:@"%.4f, %.4f", lat, lon];

        MiOSNavigationCell *cell = [[MiOSNavigationCell alloc]
            initWithTitle:name
                 subtitle:sub
                     icon:@"mappin.circle.fill"
                    color:[UIColor systemIndigoColor]];
        cell.tapAction = ^{
            weakSelf.locationPrefs[@"latitude"] = @(lat);
            weakSelf.locationPrefs[@"longitude"] = @(lon);
            [weakSelf savePreferences];
            [weakSelf updateMapPin];
            [weakSelf updateCoordLabel];
        };
        [_savedStack addArrangedSubview:cell];

        UIView *sep = [[UIView alloc] init];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [MiOSTheme separator];
        [_savedStack addArrangedSubview:sep];
        [sep.heightAnchor constraintEqualToConstant:0.5].active = YES;
    }

    if (_savedLocations.count == 0) {
        UILabel *empty = [[UILabel alloc] init];
        empty.translatesAutoresizingMaskIntoConstraints = NO;
        empty.text = @"No saved locations yet";
        empty.font = [MiOSTheme captionFont];
        empty.textColor = [MiOSTheme tertiaryText];
        empty.textAlignment = NSTextAlignmentCenter;

        UIView *emptyContainer = [[UIView alloc] init];
        emptyContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [emptyContainer addSubview:empty];
        [NSLayoutConstraint activateConstraints:@[
            [empty.topAnchor constraintEqualToAnchor:emptyContainer.topAnchor constant:20],
            [empty.centerXAnchor constraintEqualToAnchor:emptyContainer.centerXAnchor],
            [empty.bottomAnchor constraintEqualToAnchor:emptyContainer.bottomAnchor constant:-20],
        ]];
        [_savedStack addArrangedSubview:emptyContainer];
    }
}

- (void)buildActionsSection {
    MiOSSectionCardView *section = [[MiOSSectionCardView alloc] initWithTitle:@""];

    __weak typeof(self) weakSelf = self;

    MiOSNavigationCell *resetCell = [[MiOSNavigationCell alloc]
        initWithTitle:@"Reset to Real Location"
             subtitle:nil
                 icon:@"arrow.counterclockwise"
                color:[MiOSTheme destructive]];
    resetCell.tapAction = ^{
        weakSelf.locationPrefs[@"enabled"] = @NO;
        [weakSelf savePreferences];
        [weakSelf viewDidLoad];
    };
    [section addCellView:resetCell];

    [_mainStack addArrangedSubview:section];
}

- (void)updateCoordLabel {
    double lat = [_locationPrefs[@"latitude"] doubleValue];
    double lon = [_locationPrefs[@"longitude"] doubleValue];
    _coordLabel.text = [NSString stringWithFormat:@"Lat: %.6f\nLon: %.6f", lat, lon];
}

- (void)updateMapPin {
    double lat = [_locationPrefs[@"latitude"] doubleValue];
    double lon = [_locationPrefs[@"longitude"] doubleValue];
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
    _pin.coordinate = coord;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coord, 5000, 5000);
    [_mapView setRegion:region animated:YES];
}

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    CGPoint point = [gesture locationInView:_mapView];
    CLLocationCoordinate2D coord = [_mapView convertPoint:point toCoordinateFromView:_mapView];

    _locationPrefs[@"latitude"] = @(coord.latitude);
    _locationPrefs[@"longitude"] = @(coord.longitude);
    [self savePreferences];

    _pin.coordinate = coord;
    [self updateCoordLabel];

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [haptic impactOccurred];
}

- (void)promptSaveLocation {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Location"
                                                                  message:@"Enter a name for this location"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Location name...";
    }];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;
        double lat = [weakSelf.locationPrefs[@"latitude"] doubleValue];
        double lon = [weakSelf.locationPrefs[@"longitude"] doubleValue];
        weakSelf.savedLocations[name] = @{@"latitude": @(lat), @"longitude": @(lon)};
        [weakSelf saveSavedLocations];
        [weakSelf rebuildSavedList];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - MiOSToggleCellDelegate

- (void)toggleCell:(id)cell didChangeValue:(BOOL)value forKey:(NSString *)key {
    _locationPrefs[key] = @(value);
    [self savePreferences];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (query.length == 0) return;

    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    __weak typeof(self) weakSelf = self;
    [geocoder geocodeAddressString:query completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        CLPlacemark *place = placemarks.firstObject;
        if (!place) return;
        CLLocationCoordinate2D coord = place.location.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.locationPrefs[@"latitude"] = @(coord.latitude);
            weakSelf.locationPrefs[@"longitude"] = @(coord.longitude);
            [weakSelf savePreferences];
            [weakSelf updateMapPin];
            [weakSelf updateCoordLabel];
        });
    }];
}

@end
