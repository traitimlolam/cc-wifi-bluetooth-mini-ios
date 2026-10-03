#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

typedef void (*NativeWiFiButtonTapFunc)(void);
typedef BOOL (*NativeWiFiIsSelectedFunc)(void);

@interface WiFiToggleModule : CCUIToggleModule
@end

@implementation WiFiToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (instancetype)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshState) name:@"CCWiFiStateChangedNotification" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Icon Wi-Fi tỉ lệ glyphScale = 1.0 chuẩn đẹp theo đúng chỉ định của Sếp
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
    return 1.0; // Đúng chuẩn 1.0 theo yêu cầu
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

// Trạng thái đồng bộ 100% với nút Wi-Fi thật của Control Center
- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    NativeWiFiIsSelectedFunc pIsSel = (NativeWiFiIsSelectedFunc)dlsym(RTLD_DEFAULT, "NativeWiFiIsSelected");
    if (pIsSel) {
        return pIsSel();
    }

    Class sbWifiClass = NSClassFromString(@"SBWiFiManager");
    if (sbWifiClass) {
        id wifiMgr = [sbWifiClass performSelector:@selector(sharedInstance)];
        if (wifiMgr && [wifiMgr respondsToSelector:@selector(isAssociated)]) {
            return (BOOL)((intptr_t)[wifiMgr performSelector:@selector(isAssociated)]);
        }
    }
    return NO;
}

// Kích hoạt chuẩn xác phương thức nút Wi-Fi thật của Apple:
// - Đang kết nối -> Bấm vào ngắt kết nối (giữ chip Wi-Fi bật trong Cài đặt)
// - Đang ngắt kết nối -> Bấm vào tự kết nối lại ngay lập tức
// - Không đơ, không treo, không tự respring!
- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    NativeWiFiButtonTapFunc pTap = (NativeWiFiButtonTapFunc)dlsym(RTLD_DEFAULT, "NativeWiFiButtonTap");
    if (pTap) {
        pTap();
    }

    [super refreshState];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

@end
