#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

typedef struct __WiFiManagerClient *WiFiManagerClientRef;
extern WiFiManagerClientRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern Boolean WiFiManagerClientGetPower(WiFiManagerClientRef client);
extern void WiFiManagerClientSetPower(WiFiManagerClientRef client, Boolean power);

@interface WiFiToggleModule : CCUIToggleModule {
    BOOL _isTransitioning;
    BOOL _targetState;
}
@end

@implementation WiFiToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (instancetype)init {
    if ((self = [super init])) {
        _isTransitioning = NO;
        _targetState = NO;
    }
    return self;
}

// Icon Wi-Fi tỉ lệ chuẩn 1.0 (28pt) sắc nét vừa vặn hoàn hảo
- (UIImage *)iconGlyph {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightRegular];
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
    return 1.0;
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

// Kiểm tra trạng thái bật/tắt nguồn Wi-Fi siêu tốc
- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    if (_isTransitioning) {
        return _targetState;
    }

    // 1. Kiểm tra qua SBWiFiManager (SpringBoard native)
    Class sb = NSClassFromString(@"SBWiFiManager");
    if (sb) {
        id mgr = [sb performSelector:@selector(sharedInstance)];
        if (mgr && [mgr respondsToSelector:@selector(wiFiEnabled)]) {
            return (BOOL)((intptr_t)[mgr performSelector:@selector(wiFiEnabled)]);
        }
    }

    // 2. Dự phòng qua MobileWiFi API
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (h) {
        WiFiManagerClientRef (*pCreate)(CFAllocatorRef, int) = dlsym(h, "WiFiManagerClientCreate");
        Boolean (*pGetPower)(WiFiManagerClientRef) = dlsym(h, "WiFiManagerClientGetPower");
        if (pCreate && pGetPower) {
            WiFiManagerClientRef client = pCreate(kCFAllocatorDefault, 0);
            if (client) {
                Boolean power = pGetPower(client);
                CFRelease(client);
                return (BOOL)power;
            }
        }
    }

    return NO;
}

// Bật / Tắt Wi-Fi dứt khoát 1 chạm (Có trạng thái chuyển tiếp mượt mà, không giật lag)
- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    _isTransitioning = YES;
    _targetState = selected;

    // 1. Điều khiển qua SBWiFiManager (SpringBoard native)
    Class sb = NSClassFromString(@"SBWiFiManager");
    if (sb) {
        id mgr = [sb performSelector:@selector(sharedInstance)];
        if (mgr) {
            if ([mgr respondsToSelector:@selector(setWiFiEnabled:)]) {
                NSMethodSignature *sig = [mgr methodSignatureForSelector:@selector(setWiFiEnabled:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:mgr];
                [inv setSelector:@selector(setWiFiEnabled:)];
                BOOL val = selected;
                [inv setArgument:&val atIndex:2];
                [inv invoke];
            }
            if ([mgr respondsToSelector:@selector(setPowered:)]) {
                NSMethodSignature *sig = [mgr methodSignatureForSelector:@selector(setPowered:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:mgr];
                [inv setSelector:@selector(setPowered:)];
                BOOL val = selected;
                [inv setArgument:&val atIndex:2];
                [inv invoke];
            }
        }
    }

    // 2. Đồng bộ qua MobileWiFi API
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (h) {
        WiFiManagerClientRef (*pCreate)(CFAllocatorRef, int) = dlsym(h, "WiFiManagerClientCreate");
        void (*pSetPower)(WiFiManagerClientRef, Boolean) = dlsym(h, "WiFiManagerClientSetPower");
        if (pCreate && pSetPower) {
            WiFiManagerClientRef client = pCreate(kCFAllocatorDefault, 0);
            if (client) {
                pSetPower(client, selected ? 1 : 0);
                CFRelease(client);
            }
        }
    }

    [super refreshState];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isTransitioning = NO;
        [self refreshState];
    });
}

@end
