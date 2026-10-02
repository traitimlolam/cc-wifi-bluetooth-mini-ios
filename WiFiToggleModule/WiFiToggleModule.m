#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

typedef struct __WiFiManagerClient *WiFiManagerClientRef;
typedef struct __WiFiDeviceClient *WiFiDeviceClientRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;

extern WiFiManagerClientRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern CFArrayRef WiFiManagerClientCopyDevices(WiFiManagerClientRef client);
extern void WiFiDeviceClientDisassociate(WiFiDeviceClientRef device);
extern Boolean WiFiManagerClientGetPower(WiFiManagerClientRef client);
extern void WiFiManagerClientSetPower(WiFiManagerClientRef client, Boolean power);

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAssociated;
- (BOOL)isPowered;
- (BOOL)wiFiEnabled;
- (void)setPowered:(BOOL)powered;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface WFControlCenterStateMonitor : NSObject
- (void)performAction;
@end

@interface UIImage (PrivateSF)
+ (UIImage *)_systemImageNamed:(NSString *)name;
+ (UIImage *)_systemImageNamed:(NSString *)name withConfiguration:(UIImageConfiguration *)configuration;
@end

@interface WiFiToggleModule : CCUIToggleModule
@end

@implementation WiFiToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (UIImage *)iconGlyph {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:19.0 weight:UIImageSymbolWeightRegular];
    UIImage *img = [UIImage systemImageNamed:@"wifi" withConfiguration:config];
    if (!img) {
        img = [UIImage systemImageNamed:@"wifi"];
    }
    if (!img) {
        img = [UIImage imageNamed:@"ModuleIcon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    }
    return img;
}

- (UIImage *)selectedIconGlyph {
    return [self iconGlyph];
}

- (double)glyphScale {
    return 0.65;
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

// Chế độ gốc của Apple: Nút sáng Xanh khi đang KẾT NỐI (associated) vào mạng Wi-Fi
- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    Class sbWifiClass = NSClassFromString(@"SBWiFiManager");
    if (sbWifiClass) {
        id wifiMgr = [sbWifiClass performSelector:@selector(sharedInstance)];
        if (wifiMgr && [wifiMgr respondsToSelector:@selector(isAssociated)]) {
            return (BOOL)((intptr_t)[wifiMgr performSelector:@selector(isAssociated)]);
        }
    }

    void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (h) {
        WiFiManagerClientRef (*pCreate)(CFAllocatorRef, int) = dlsym(h, "WiFiManagerClientCreate");
        Boolean (*pGetPower)(WiFiManagerClientRef) = dlsym(h, "WiFiManagerClientGetPower");
        if (pCreate && pGetPower) {
            WiFiManagerClientRef client = pCreate(kCFAllocatorDefault, 0);
            if (client) {
                Boolean p = pGetPower(client);
                CFRelease(client);
                return (BOOL)p;
            }
        }
    }
    return NO;
}

// Chế độ gốc của Apple: Bấm vào thì NGẮT KẾT NỐI (disconnect/disassociate) chứ KHÔNG tắt hẳn chip Wi-Fi
- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    // 1. Dùng trực tiếp WFControlCenterStateMonitor chuẩn gốc của Control Center
    dlopen("/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit", RTLD_NOW);
    Class monitorClass = NSClassFromString(@"WFControlCenterStateMonitor");
    if (monitorClass) {
        id monitor = [[monitorClass alloc] init];
        if (monitor && [monitor respondsToSelector:@selector(performAction)]) {
            [monitor performAction];
            [super refreshState];
            return;
        }
    }

    // 2. Dự phòng qua MobileWiFi: Ngắt kết nối mạng hiện tại (Disassociate)
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (h) {
        WiFiManagerClientRef (*pCreate)(CFAllocatorRef, int) = dlsym(h, "WiFiManagerClientCreate");
        CFArrayRef (*pCopyDevices)(WiFiManagerClientRef) = dlsym(h, "WiFiManagerClientCopyDevices");
        void (*pDisassociate)(WiFiDeviceClientRef) = dlsym(h, "WiFiDeviceClientDisassociate");
        if (pCreate && pCopyDevices && pDisassociate) {
            WiFiManagerClientRef client = pCreate(kCFAllocatorDefault, 0);
            if (client) {
                CFArrayRef devices = pCopyDevices(client);
                if (devices && CFArrayGetCount(devices) > 0) {
                    WiFiDeviceClientRef dev = (WiFiDeviceClientRef)CFArrayGetValueAtIndex(devices, 0);
                    if (!selected) {
                        // Bấm tắt: ngắt kết nối mạng hiện tại (chip Wi-Fi vẫn bật trong Settings)
                        pDisassociate(dev);
                    }
                }
                if (devices) CFRelease(devices);
                CFRelease(client);
            }
        }
    }

    [super refreshState];
}

@end
