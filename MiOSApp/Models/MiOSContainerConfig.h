#import <Foundation/Foundation.h>

@interface MiOSContainerConfig : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableArray<NSString *> *apps;
// GPS
@property (nonatomic, assign) BOOL gpsEnabled;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, copy) NSString *locationName;
// Device
@property (nonatomic, assign) BOOL deviceSpoofEnabled;
@property (nonatomic, copy) NSString *deviceIdentifier;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *hwModel;
@property (nonatomic, copy) NSString *iosVersion;
@property (nonatomic, assign) NSInteger storageSizeGB;
@property (nonatomic, copy) NSString *customDeviceName;
@property (nonatomic, assign) BOOL spoofDeviceName;
// Identifiers
@property (nonatomic, assign) BOOL spoofDeviceCheck;
@property (nonatomic, assign) BOOL spoofVendorID;
@property (nonatomic, copy) NSString *vendorID;
@property (nonatomic, assign) BOOL spoofAdvertisingID;
@property (nonatomic, copy) NSString *advertisingID;
@property (nonatomic, assign) BOOL spoofCloudToken;

+ (NSArray<MiOSContainerConfig *> *)loadAll;
+ (void)saveAll:(NSArray<MiOSContainerConfig *> *)containers;
+ (NSString *)activeContainerID;
+ (void)setActiveContainerID:(NSString *)containerID;
// The container marked active, falling back to the first one.
+ (MiOSContainerConfig *)activeContainer;
// Deletes the container from the saved list and the system (mappings + data); picks a new active one if needed.
+ (void)removeContainerWithID:(NSString *)containerID;
- (NSDictionary *)toDictionary;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)applyToSystem;
@end
