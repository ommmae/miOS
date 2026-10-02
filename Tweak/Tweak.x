#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <sys/stat.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <errno.h>
#import "MiOSContainer.h"
#import "MiOSUI.h"

// miOS — Instagram-only, Blaze-parity edition.
// Single dylib injected into com.burbn.instagram. One floating button opens the
// in-sandbox manager with Spoof (fingerprint) / Location / Proxy / Containers / Settings.

static NSString *const kIGBundleID = @"com.burbn.instagram";

// MARK: - Private declarations

@interface DCDevice : NSObject
@property (class, readonly) DCDevice *currentDevice;
- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion;
@end

@interface ASIdentifierManager : NSObject
+ (ASIdentifierManager *)sharedManager;
- (NSUUID *)advertisingIdentifier;
- (BOOL)isAdvertisingTrackingEnabled;
@end

@interface CTCarrier : NSObject
- (NSString *)carrierName;
- (NSString *)mobileCountryCode;
- (NSString *)mobileNetworkCode;
- (NSString *)isoCountryCode;
- (BOOL)allowsVOIP;
@end
@interface CTTelephonyNetworkInfo : NSObject
- (NSString *)currentRadioAccessTechnology;
- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology;
@end

@interface CMAccelerometerData : NSObject @end
@interface CMGyroData : NSObject @end
@interface CMMotionManager : NSObject
- (void)startGyroUpdates;
- (void)startGyroUpdatesToQueue:(id)q withHandler:(void (^)(id, NSError *))h;
@end

@interface MFMailComposeViewController : NSObject + (BOOL)canSendMail; @end
@interface MFMessageComposeViewController : NSObject + (BOOL)canSendText; @end

typedef CFDictionaryRef (*CNCopyCurrentNetworkInfo_t)(CFStringRef interfaceName);

// MARK: - Shared runtime state (resolved once in the constructor)

static NSDictionary *gSpoof = nil;
static NSString *gContainerUUID = nil;


// Cached, allocation-free spoof values
static BOOL      gDeviceSpoofActive = NO;
static char     *gcMachine  = NULL;
static char     *gcModel    = NULL;
static uint64_t  gcMemsize  = 0;
static int       gcCPU      = 0;
static char     *gcKernelVersion = NULL;  // uname.release-style + full kern.version
static CFDictionaryRef gcWifiInfo     = NULL;
static CFStringRef gcMGProductType    = NULL;
static CFStringRef gcMGHWModel        = NULL;
static CFStringRef gcMGDeviceName     = NULL;
static CFStringRef gcMGProductVersion = NULL;
static CFTypeRef (*gRealMGCopyAnswer)(CFStringRef) = NULL;

// Access helpers
static NSString *spoofStr(NSString *key)   { id v = gSpoof[key]; return [v isKindOfClass:[NSString class]] ? v : @""; }
static BOOL      spoofBool(NSString *key)  { return [gSpoof[key] boolValue]; }
static NSInteger spoofInt(NSString *key)   { return [gSpoof[key] integerValue]; }
static double    spoofDbl(NSString *key)   { return [gSpoof[key] doubleValue]; }

// MARK: - Location

static BOOL locationSpoofEnabled(void) { return spoofBool(@"spoofLocation"); }
static CLLocationCoordinate2D spoofedCoordinate(void) {
    return CLLocationCoordinate2DMake(spoofDbl(@"latitude"), spoofDbl(@"longitude"));
}
static CLLocation *spoofedLocationObject(void) {
    double acc = spoofDbl(@"horizontalAccuracy"); if (acc <= 0) acc = 5.0;
    double alt = spoofDbl(@"altitude");
    double spd = spoofDbl(@"speed"); double crs = spoofDbl(@"course");
    return [[CLLocation alloc] initWithCoordinate:spoofedCoordinate()
                                         altitude:alt horizontalAccuracy:acc verticalAccuracy:acc
                                           course:(crs ?: -1) speed:(spd ?: -1) timestamp:[NSDate date]];
}

// (groups removed — flat hooks + single %init)
%hook CLLocationManager
- (CLLocation *)location {
    if (locationSpoofEnabled()) return spoofedLocationObject();
    return %orig;
}
- (void)startUpdatingLocation {
    %orig;
    if (!locationSpoofEnabled()) return;
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocationManager *mgr = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [delegate locationManager:mgr didUpdateLocations:@[spoofedLocationObject()]];
        });
    }
}
- (void)requestLocation {
    %orig;
    if (!locationSpoofEnabled()) return;
    id delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        CLLocationManager *mgr = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [delegate locationManager:mgr didUpdateLocations:@[spoofedLocationObject()]];
        });
    }
}
%end
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (locationSpoofEnabled()) return spoofedCoordinate();
    return %orig;
}
%end
// end LocationHooks

// MARK: - Device fingerprint (UIDevice / NSProcessInfo)

// group DeviceSpoofHooks
%hook UIDevice
- (NSString *)systemVersion {
    if (spoofBool(@"enableSpoofSoftwareVersion")) {
        NSString *ver = spoofStr(@"iosVersion");
        if (ver.length) return ver;
    }
    return %orig;
}
- (NSString *)name {
    if (spoofBool(@"enableSpoofDeviceName")) {
        NSString *name = spoofStr(@"deviceName");
        if (name.length) return name;
    }
    return %orig;
}
- (NSString *)model {
    if (spoofBool(@"enableSpoofDeviceModel")) {
        NSString *ident = spoofStr(@"deviceIdentifier");
        if ([ident hasPrefix:@"iPad"]) return @"iPad";
        if ([ident hasPrefix:@"iPod"]) return @"iPod touch";
        if ([ident hasPrefix:@"iPhone"]) return @"iPhone";
    }
    return %orig;
}
%end
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    if (spoofBool(@"enableSpoofSoftwareVersion")) {
        NSString *ver = spoofStr(@"iosVersion");
        if (ver.length) {
            NSArray *parts = [ver componentsSeparatedByString:@"."];
            NSOperatingSystemVersion v = {0, 0, 0};
            if (parts.count > 0) v.majorVersion = [parts[0] integerValue];
            if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
            if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
            return v;
        }
    }
    return %orig;
}
- (NSString *)operatingSystemVersionString {
    if (spoofBool(@"enableSpoofSoftwareVersion")) {
        NSString *ver = spoofStr(@"iosVersion");
        if (ver.length) return [NSString stringWithFormat:@"Version %@", ver];
    }
    return %orig;
}
- (unsigned long long)physicalMemory {
    return gcMemsize ? gcMemsize : %orig;
}
- (NSUInteger)processorCount {
    return gcCPU ? (NSUInteger)gcCPU : %orig;
}
- (NSUInteger)activeProcessorCount {
    return gcCPU ? (NSUInteger)gcCPU : %orig;
}
- (BOOL)isLowPowerModeEnabled {
    if (spoofBool(@"enableSpoofLowPowerMode")) return spoofBool(@"lowPowerModeEnabled");
    return %orig;
}
%end
// end DeviceSpoofHooks

// MARK: - Battery / Brightness / Orientation / Proximity

// group PhysicalHooks
%hook UIDevice
- (float)batteryLevel {
    if (spoofBool(@"enableSpoofBatteryLevel")) {
        NSInteger lvl = spoofInt(@"batteryLevel");
        if (lvl < 0) lvl = 0; if (lvl > 100) lvl = 100;
        return (float)lvl / 100.0f;
    }
    return %orig;
}
- (UIDeviceBatteryState)batteryState {
    if (spoofBool(@"enableSpoofBatteryState")) {
        NSInteger s = spoofInt(@"batteryState");
        if (s >= UIDeviceBatteryStateUnknown && s <= UIDeviceBatteryStateFull) return (UIDeviceBatteryState)s;
    }
    return %orig;
}
- (UIDeviceOrientation)orientation {
    if (spoofBool(@"enableSpoofOrientation")) {
        NSInteger o = spoofInt(@"orientation");
        return (UIDeviceOrientation)o;
    }
    return %orig;
}
- (BOOL)proximityState {
    if (spoofBool(@"enableSpoofProximity")) return spoofBool(@"proximityState");
    return %orig;
}
%end
%hook UIScreen
- (CGFloat)brightness {
    if (spoofBool(@"enableSpoofBrightness")) return (CGFloat)spoofDbl(@"brightnessLevel");
    return %orig;
}
%end
// end PhysicalHooks

// MARK: - Locale / TimeZone

// group LocaleHooks
%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    if (spoofBool(@"enableSpoofTimeZone")) {
        NSString *tz = spoofStr(@"timeZoneID");
        NSTimeZone *z = tz.length ? [NSTimeZone timeZoneWithName:tz] : nil;
        if (z) return z;
    }
    return %orig;
}
+ (NSTimeZone *)systemTimeZone {
    if (spoofBool(@"enableSpoofTimeZone")) {
        NSString *tz = spoofStr(@"timeZoneID");
        NSTimeZone *z = tz.length ? [NSTimeZone timeZoneWithName:tz] : nil;
        if (z) return z;
    }
    return %orig;
}
%end
%hook NSLocale
+ (NSLocale *)currentLocale {
    if (spoofBool(@"enableSpoofLocale")) {
        NSString *lid = spoofStr(@"localeID");
        if (lid.length) return [NSLocale localeWithLocaleIdentifier:lid];
    }
    return %orig;
}
+ (NSArray<NSString *> *)preferredLanguages {
    if (spoofBool(@"enableSpoofLocale")) {
        NSString *lid = spoofStr(@"localeID");
        if (lid.length) {
            NSString *lang = [[lid componentsSeparatedByString:@"_"] firstObject];
            if (lang.length) return @[lang];
        }
    }
    return %orig;
}
%end
// end LocaleHooks

// MARK: - Carrier / Cellular type

// group CarrierHooks
%hook CTCarrier
- (NSString *)carrierName {
    if (spoofBool(@"enableSpoofCarrier")) return spoofStr(@"carrierName");
    return %orig;
}
- (NSString *)mobileCountryCode {
    if (spoofBool(@"enableSpoofCarrier")) return spoofStr(@"carrierMCC");
    return %orig;
}
- (NSString *)mobileNetworkCode {
    if (spoofBool(@"enableSpoofCarrier")) return spoofStr(@"carrierMNC");
    return %orig;
}
- (NSString *)isoCountryCode {
    if (spoofBool(@"enableSpoofCarrier")) return spoofStr(@"carrierCountryCode");
    return %orig;
}
%end
%hook CTTelephonyNetworkInfo
- (NSString *)currentRadioAccessTechnology {
    if (spoofBool(@"enableSpoofCellularType")) {
        NSString *t = spoofStr(@"cellularType");
        if ([t isEqualToString:@"3G"]) return @"CTRadioAccessTechnologyWCDMA";
        if ([t isEqualToString:@"4G"]) return @"CTRadioAccessTechnologyLTE";
        if ([t isEqualToString:@"LTE"]) return @"CTRadioAccessTechnologyLTE";
        if ([t isEqualToString:@"5G"]) return @"CTRadioAccessTechnologyNRNSA";
    }
    return %orig;
}
- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology {
    if (spoofBool(@"enableSpoofCellularType")) {
        NSString *tech = [self currentRadioAccessTechnology];
        if (tech.length) return @{@"0000000100000001": tech};
    }
    return %orig;
}
%end
// end CarrierHooks

// MARK: - Identifiers (IDFV / IDFA / DeviceCheck / iCloud)

// group IdentifierSpoofHooks
%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (spoofBool(@"enableSpoofVendorID")) {
        NSString *v = spoofStr(@"vendorID");
        NSUUID *u = v.length ? [[NSUUID alloc] initWithUUIDString:v] : nil;
        if (u) return u;
    }
    return %orig;
}
%end
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (spoofBool(@"enableSpoofAdvertisingID")) {
        NSString *v = spoofStr(@"advertisingID");
        NSUUID *u = v.length ? [[NSUUID alloc] initWithUUIDString:v] : nil;
        if (u) return u;
    }
    return %orig;
}
- (BOOL)isAdvertisingTrackingEnabled {
    if (spoofBool(@"enableSpoofAdvertisingID")) return NO;
    return %orig;
}
%end
%hook DCDevice
- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completion {
    if (spoofBool(@"enableSpoofDeviceCheck")) {
        if (completion) completion(nil, [NSError errorWithDomain:@"DCErrorDomain" code:1 userInfo:@{
            NSLocalizedDescriptionKey: @"DeviceCheck is not supported on this device"}]);
        return;
    }
    %orig;
}
%end
%hook NSFileManager
- (id)ubiquityIdentityToken {
    if (spoofBool(@"enableSpoofCloudToken")) return nil;
    return %orig;
}
%end
// end IdentifierSpoofHooks

// MARK: - Mail / Message availability

// group MailMessageHooks
%hook MFMailComposeViewController
+ (BOOL)canSendMail {
    if (spoofBool(@"enableSpoofMail")) return spoofBool(@"mailAvailable");
    return %orig;
}
%end
%hook MFMessageComposeViewController
+ (BOOL)canSendText {
    if (spoofBool(@"enableSpoofMessage")) return spoofBool(@"messageAvailable");
    return %orig;
}
%end
// end MailMessageHooks

// MARK: - Screenshot-detection suppression

// group ScreenshotHooks
%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)name object:(id)object userInfo:(NSDictionary *)userInfo {
    if (spoofBool(@"enableSpoofScreenshot") &&
        ([name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
         [name isEqualToString:@"UIScreenCapturedDidChangeNotification"])) return;
    %orig;
}
- (void)postNotificationName:(NSNotificationName)name object:(id)object {
    if (spoofBool(@"enableSpoofScreenshot") &&
        ([name isEqualToString:UIApplicationUserDidTakeScreenshotNotification] ||
         [name isEqualToString:@"UIScreenCapturedDidChangeNotification"])) return;
    %orig;
}
%end
// end ScreenshotHooks

// MARK: - Gyroscope randomization

// group GyroscopeHooks
%hook CMMotionManager
- (id)gyroData {
    id orig = %orig;
    if (spoofBool(@"enableSpoofGyroscope")) {
        struct { double x, y, z; } g = {
            ((double)arc4random() / UINT32_MAX - 0.5) * 4.0,
            ((double)arc4random() / UINT32_MAX - 0.5) * 4.0,
            ((double)arc4random() / UINT32_MAX - 0.5) * 4.0 };
        if (orig) {
            @try { [orig setValue:@(g.x) forKeyPath:@"rotationRate.x"]; } @catch (__unused id e) {}
            @try { [orig setValue:@(g.y) forKeyPath:@"rotationRate.y"]; } @catch (__unused id e) {}
            @try { [orig setValue:@(g.z) forKeyPath:@"rotationRate.z"]; } @catch (__unused id e) {}
        }
    }
    return orig;
}
%end
// end GyroscopeHooks

// MARK: - Anti-detection (hide common jailbreak probes)

static int (*orig_access)(const char *, int) = NULL;
static int (*orig_stat)(const char *, struct stat *) = NULL;
static int (*orig_lstat)(const char *, struct stat *) = NULL;
static FILE *(*orig_fopen)(const char *, const char *) = NULL;

static const char *gJailbreakPaths[] = {
    "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
    "/Library/MobileSubstrate", "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/usr/lib/libsubstrate.dylib", "/usr/lib/libsubstitute.dylib",
    "/usr/libexec/sftp-server", "/usr/sbin/sshd", "/bin/sh", "/bin/bash",
    "/var/jb", "/var/lib/apt", "/private/var/stash", "/private/var/lib/apt",
    "/etc/apt", "/etc/apt/sources.list.d",
    NULL
};
static BOOL miosIsJbPath(const char *p) {
    if (!p || !spoofBool(@"enableDisableDetection")) return NO;
    for (int i = 0; gJailbreakPaths[i]; i++) {
        if (strncmp(p, gJailbreakPaths[i], strlen(gJailbreakPaths[i])) == 0) return YES;
    }
    return NO;
}
static int hook_access(const char *p, int m) {
    if (miosIsJbPath(p)) { errno = ENOENT; return -1; }
    return orig_access(p, m);
}
static int hook_stat(const char *p, struct stat *s) {
    if (miosIsJbPath(p)) { errno = ENOENT; return -1; }
    return orig_stat(p, s);
}
static int hook_lstat(const char *p, struct stat *s) {
    if (miosIsJbPath(p)) { errno = ENOENT; return -1; }
    return orig_lstat(p, s);
}
static FILE *hook_fopen(const char *p, const char *m) {
    if (miosIsJbPath(p)) { errno = ENOENT; return NULL; }
    return orig_fopen(p, m);
}

// group DetectionHooks
%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url {
    if (spoofBool(@"enableDisableDetection")) {
        NSString *s = url.scheme.lowercaseString;
        if ([s isEqualToString:@"cydia"] || [s isEqualToString:@"sileo"] || [s isEqualToString:@"zbra"]) return NO;
    }
    return %orig;
}
%end
// end DetectionHooks

// (Keychain namespacing and filesystem isolation removed — Blaze model:
//  containers are spoof-config sets, not filesystem sandboxes.)

// MARK: - sysctl / uname / CNCopy… / getifaddrs (allocation-free)

static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_uname)(struct utsname *);
static int (*orig_getifaddrs)(struct ifaddrs **);
static CNCopyCurrentNetworkInfo_t orig_CNCopyCurrentNetworkInfo = NULL;

static int replyCString(void *oldp, size_t *oldlenp, const char *cstr) {
    size_t need = strlen(cstr) + 1;
    if (!oldp) { if (oldlenp) *oldlenp = need; return 0; }
    if (oldlenp && *oldlenp < need) { errno = ENOMEM; return -1; }
    memcpy(oldp, cstr, need); if (oldlenp) *oldlenp = need; return 0;
}
static int copyIntOut(void *oldp, size_t *oldlenp, unsigned long long value) {
    if (*oldlenp >= 8) { *(uint64_t *)oldp = (uint64_t)value; *oldlenp = 8; }
    else if (*oldlenp >= 4) { *(uint32_t *)oldp = (uint32_t)value; *oldlenp = 4; }
    return 0;
}
static int hook_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && gDeviceSpoofActive) {
        if (gcMachine && strcmp(name, "hw.machine") == 0) return replyCString(oldp, oldlenp, gcMachine);
        if (gcModel   && strcmp(name, "hw.model")   == 0) return replyCString(oldp, oldlenp, gcModel);
        if (gcKernelVersion && (strcmp(name, "kern.version") == 0 || strcmp(name, "kern.osrelease") == 0))
            return replyCString(oldp, oldlenp, gcKernelVersion);
        if ((gcMemsize || gcCPU) && oldp && oldlenp) {
            int r = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
            if (r != 0) return r;
            if (gcMemsize && strcmp(name, "hw.memsize") == 0) return copyIntOut(oldp, oldlenp, gcMemsize);
            if (gcCPU && (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.logicalcpu") == 0 ||
                strcmp(name, "hw.logicalcpu_max") == 0 || strcmp(name, "hw.activecpu") == 0 ||
                strcmp(name, "hw.physicalcpu") == 0 || strcmp(name, "hw.physicalcpu_max") == 0))
                return copyIntOut(oldp, oldlenp, (unsigned long long)gcCPU);
            return r;
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}
static int hook_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && namelen >= 2 && gDeviceSpoofActive && name[0] == CTL_HW) {
        if (gcMachine && name[1] == HW_MACHINE) return replyCString(oldp, oldlenp, gcMachine);
        if (gcModel   && name[1] == HW_MODEL)   return replyCString(oldp, oldlenp, gcModel);
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}
static int hook_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (r != 0 || !buf) return r;
    if (gDeviceSpoofActive && gcMachine) {
        strncpy(buf->machine, gcMachine, sizeof(buf->machine) - 1); buf->machine[sizeof(buf->machine)-1] = '\0';
    }
    if (gcKernelVersion) {
        strncpy(buf->release, gcKernelVersion, sizeof(buf->release) - 1); buf->release[sizeof(buf->release)-1] = '\0';
        strncpy(buf->version, gcKernelVersion, sizeof(buf->version) - 1); buf->version[sizeof(buf->version)-1] = '\0';
    }
    return r;
}
static CFDictionaryRef hook_CNCopyCurrentNetworkInfo(CFStringRef iface) {
    if (gcWifiInfo) return (CFDictionaryRef)CFRetain(gcWifiInfo);
    return orig_CNCopyCurrentNetworkInfo ? orig_CNCopyCurrentNetworkInfo(iface) : NULL;
}

// getifaddrs: rewrite the IPv4 of en0 (Wi-Fi) and pdp_ip0 (cellular) if spoofing is on.
static void miosRewriteIfaIPv4(struct ifaddrs *ifa, const char *addr) {
    if (!addr || !ifa || !ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) return;
    struct sockaddr_in *in = (struct sockaddr_in *)ifa->ifa_addr;
    struct in_addr tmp; if (inet_pton(AF_INET, addr, &tmp) == 1) in->sin_addr = tmp;
}
static int hook_getifaddrs(struct ifaddrs **ifap) {
    int r = orig_getifaddrs(ifap);
    if (r != 0 || !ifap || !*ifap) return r;
    BOOL spoofWiFi = spoofBool(@"enableSpoofWiFi");
    BOOL spoofCel  = spoofBool(@"enableSpoofCellular");
    if (!spoofWiFi && !spoofCel) return r;
    NSString *wifiIP = spoofStr(@"wifiAddress");
    NSString *celIP  = spoofStr(@"cellularAddress");
    for (struct ifaddrs *i = *ifap; i; i = i->ifa_next) {
        if (!i->ifa_name) continue;
        if (spoofWiFi && wifiIP.length && strcmp(i->ifa_name, "en0") == 0)
            miosRewriteIfaIPv4(i, wifiIP.UTF8String);
        else if (spoofCel && celIP.length && strncmp(i->ifa_name, "pdp_ip", 6) == 0)
            miosRewriteIfaIPv4(i, celIP.UTF8String);
    }
    return r;
}

// MARK: - MGCopyAnswer via dlsym (never patches the real function)

static CFTypeRef mios_MGCopyAnswer(CFStringRef key) {
    if (gDeviceSpoofActive && key) {
        if (gcMGProductType && (CFEqual(key, CFSTR("ProductType")) || CFEqual(key, CFSTR("HWModelStr"))))
            return CFRetain(gcMGProductType);
        if (gcMGDeviceName && (CFEqual(key, CFSTR("DeviceName")) || CFEqual(key, CFSTR("marketing-name")) || CFEqual(key, CFSTR("UserAssignedDeviceName"))))
            return CFRetain(gcMGDeviceName);
        if (gcMGHWModel && CFEqual(key, CFSTR("HardwarePlatform")))
            return CFRetain(gcMGHWModel);
        if (gcMGProductVersion && CFEqual(key, CFSTR("ProductVersion")))
            return CFRetain(gcMGProductVersion);
    }
    return gRealMGCopyAnswer ? gRealMGCopyAnswer(key) : NULL;
}
static void *(*orig_dlsym)(void *, const char *) = NULL;
static void *new_dlsym(void *handle, const char *symbol) {
    if (symbol && gDeviceSpoofActive && strcmp(symbol, "MGCopyAnswer") == 0 &&
        (gcMGProductType || gcMGProductVersion || gcMGDeviceName || gcMGHWModel))
        return (void *)mios_MGCopyAnswer;
    return orig_dlsym ? orig_dlsym(handle, symbol) : NULL;
}

// MARK: - Per-container HTTPS proxy (NSURLSessionConfiguration)

// group ProxyHooks
%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *c = %orig;
    NSString *host = spoofStr(@"proxyHost"); NSInteger port = spoofInt(@"proxyPort");
    if (host.length && port > 0) {
        c.connectionProxyDictionary = @{
            @"HTTPSEnable": @YES,
            @"HTTPSProxy":  host,
            @"HTTPSPort":   @(port),
            @"HTTPEnable":  @YES,
            @"HTTPProxy":   host,
            @"HTTPPort":    @(port),
        };
    }
    return c;
}
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *c = %orig;
    NSString *host = spoofStr(@"proxyHost"); NSInteger port = spoofInt(@"proxyPort");
    if (host.length && port > 0) {
        c.connectionProxyDictionary = @{
            @"HTTPSEnable": @YES, @"HTTPSProxy": host, @"HTTPSPort": @(port),
            @"HTTPEnable":  @YES, @"HTTPProxy":  host, @"HTTPPort":  @(port),
        };
    }
    return c;
}
%end
// end ProxyHooks

// MARK: - Build the allocation-free cache

static char *dupCString(NSString *s) { return s.length ? strdup(s.UTF8String ?: "") : NULL; }
static CFStringRef retainedCF(NSString *s) { return s.length ? (__bridge_retained CFStringRef)[s copy] : NULL; }

static void miosBuildSpoofCache(void) {
    gDeviceSpoofActive = spoofBool(@"enableSpoofDeviceModel") || spoofBool(@"enableSpoofSoftwareVersion") ||
                         spoofBool(@"enableSpoofMemory") || spoofBool(@"enableSpoofProcessor") ||
                         spoofBool(@"enableSpoofKernelVersion") || spoofBool(@"enableSpoofDeviceName");
    if (spoofBool(@"enableSpoofDeviceModel")) {
        gcMachine = dupCString(spoofStr(@"deviceIdentifier"));
        gcModel   = dupCString(spoofStr(@"deviceHardwareModel"));
        gcMGProductType = retainedCF(spoofStr(@"deviceIdentifier"));
        gcMGHWModel     = retainedCF(spoofStr(@"deviceHardwareModel"));
        gcMGDeviceName  = retainedCF(spoofStr(@"deviceDisplayName"));
    }
    if (spoofBool(@"enableSpoofSoftwareVersion"))
        gcMGProductVersion = retainedCF(spoofStr(@"iosVersion"));
    if (spoofBool(@"enableSpoofMemory")) {
        NSInteger gb = spoofInt(@"ramGB"); if (gb > 0)
            gcMemsize = (unsigned long long)gb * 1024ULL * 1024ULL * 1024ULL;
    }
    if (spoofBool(@"enableSpoofProcessor")) {
        NSInteger n = spoofInt(@"cpuCores"); if (n > 0) gcCPU = (int)n;
    }
    if (spoofBool(@"enableSpoofKernelVersion")) {
        NSString *kv = spoofStr(@"kernelVersion"); if (kv.length) gcKernelVersion = dupCString(kv);
    }
    if (spoofBool(@"enableSpoofWiFi")) {
        NSString *ssid = spoofStr(@"wifiSSID"); NSString *bssid = spoofStr(@"wifiBSSID");
        if (ssid.length && bssid.length) {
            NSDictionary *info = @{
                @"SSID": ssid, @"BSSID": bssid,
                @"SSIDDATA": [ssid dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data],
            };
            gcWifiInfo = (__bridge_retained CFDictionaryRef)[info copy];
        }
    }
}

// (App Group wipe / Mach-O parser removed — Blaze does not wipe App Group state.)

// MARK: - Constructor

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSString *exeName = [[[NSBundle mainBundle] executablePath] lastPathComponent] ?: @"";

        NSString *low = bundleID.lowercaseString;
        BOOL isInstagram = ([low containsString:@"burbn"] ||
                            [low containsString:@"instagram"] ||
                            [exeName isEqualToString:@"Instagram"]);
        if (!isInstagram) return;

        NSString *home = [NSHomeDirectory() copy];

        // Diagnostic marker — proves the dylib loaded.
        @try {
            NSString *diag = [NSString stringWithFormat:
                @"miOS loaded at %@\nbundleID=%@\nexecutable=%@\nhome=%@\n",
                [NSDate date], bundleID, exeName, home];
            NSArray<NSString *> *paths = @[
                [[home stringByAppendingPathComponent:@"Documents"]
                    stringByAppendingPathComponent:@"mios-loaded.txt"],
                [NSTemporaryDirectory() stringByAppendingPathComponent:@"mios-loaded.txt"],
            ];
            for (NSString *path in paths) {
                [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                          withIntermediateDirectories:YES attributes:nil error:nil];
                [diag writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
        } @catch (__unused id e) {}

        [MiOSUI install];

        MiOSContainer *active = [MiOSContainer activeContainer];
        if (!active || !active.enableSpoof) return;

        gContainerUUID = [active.identifier copy];
        gSpoof = [[active spoofPrefs] copy];

        // Blaze model: containers are spoof-config sets. No filesystem isolation,
        // no keychain namespacing, no App Group wipes.

        // Build allocation-free spoof cache + install Logos hooks.
        miosBuildSpoofCache();
        %init;

        // Low-level C hooks.
        if (gDeviceSpoofActive) {
            MSHookFunction((void *)sysctlbyname, (void *)hook_sysctlbyname, (void **)&orig_sysctlbyname);
            MSHookFunction((void *)sysctl, (void *)hook_sysctl, (void **)&orig_sysctl);
            MSHookFunction((void *)uname, (void *)hook_uname, (void **)&orig_uname);
            if (gcMGProductType || gcMGProductVersion || gcMGDeviceName || gcMGHWModel) {
                void *mgH = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
                if (!mgH) mgH = dlopen("/var/jb/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
                if (mgH) gRealMGCopyAnswer = (CFTypeRef(*)(CFStringRef))dlsym(mgH, "MGCopyAnswer");
                MSHookFunction((void *)dlsym, (void *)new_dlsym, (void **)&orig_dlsym);
            }
        }

        if (gcWifiInfo) {
            void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_LAZY);
            if (sc) {
                CNCopyCurrentNetworkInfo_t fn = (CNCopyCurrentNetworkInfo_t)dlsym(sc, "CNCopyCurrentNetworkInfo");
                if (fn) MSHookFunction((void *)fn, (void *)hook_CNCopyCurrentNetworkInfo, (void **)&orig_CNCopyCurrentNetworkInfo);
            }
        }

        if (spoofBool(@"enableSpoofWiFi") || spoofBool(@"enableSpoofCellular"))
            MSHookFunction((void *)getifaddrs, (void *)hook_getifaddrs, (void **)&orig_getifaddrs);

        if (spoofBool(@"enableDisableDetection")) {
            MSHookFunction((void *)access, (void *)hook_access, (void **)&orig_access);
            MSHookFunction((void *)stat,   (void *)hook_stat,   (void **)&orig_stat);
            MSHookFunction((void *)lstat,  (void *)hook_lstat,  (void **)&orig_lstat);
            MSHookFunction((void *)fopen,  (void *)hook_fopen,  (void **)&orig_fopen);
        }

        // Diagnostic dump: write all active spoof values so the user can verify.
        @try {
            NSString *debugPath = [MiOSBaseDir() stringByAppendingPathComponent:@"spoof-debug.plist"];
            NSMutableDictionary *dump = [NSMutableDictionary dictionary];
            dump[@"containerID"] = gContainerUUID ?: @"";
            dump[@"containerName"] = active.name ?: @"";
            dump[@"timestamp"] = [NSDate date].description;
            dump[@"deviceSpoofActive"] = @(gDeviceSpoofActive);
            dump[@"gcMachine"] = gcMachine ? @(gcMachine) : @"(none)";
            dump[@"gcModel"] = gcModel ? @(gcModel) : @"(none)";
            dump[@"gcMemsize"] = @(gcMemsize);
            dump[@"gcCPU"] = @(gcCPU);
            dump[@"gcKernelVersion"] = gcKernelVersion ? @(gcKernelVersion) : @"(none)";
            dump[@"locationSpoofEnabled"] = @(locationSpoofEnabled());
            if (locationSpoofEnabled()) {
                dump[@"latitude"] = @(spoofDbl(@"latitude"));
                dump[@"longitude"] = @(spoofDbl(@"longitude"));
            }
            dump[@"allSpoofPrefs"] = gSpoof ?: @{};
            [dump writeToFile:debugPath atomically:YES];
        } @catch (__unused id e) {}
    }
}
