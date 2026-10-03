#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

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

// Icon Wi-Fi glyphScale đặt về 1.0 theo đúng chỉ định của Sếp
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
    return 1.0; // Đặt về 1.0 theo đúng yêu cầu
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

// Trạng thái: Sáng XANH khi đang kết nối Wi-Fi (isPowered == YES && userAutoJoinState == YES)
- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    dlopen("/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit", RTLD_NOW);
    Class clientClass = NSClassFromString(@"WFClient");
    if (clientClass) {
        id client = [clientClass performSelector:@selector(sharedInstance)];
        if (client) {
            BOOL isPowered = [client respondsToSelector:@selector(isPowered)] ? (BOOL)((intptr_t)[client performSelector:@selector(isPowered)]) : YES;
            BOOL autoJoin = [client respondsToSelector:@selector(userAutoJoinState)] ? (BOOL)((intptr_t)[client performSelector:@selector(userAutoJoinState)]) : YES;
            return isPowered && autoJoin;
        }
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

// Hành vi: TẮT BẬT NHƯ NÚT WI-FI THẬT CỦA CONTROL CENTER (Ngắt kết nối/kết nối lại, KHÔNG tắt hẳn chip Wi-Fi)
- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    dlopen("/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit", RTLD_NOW);
    Class clientClass = NSClassFromString(@"WFClient");
    if (clientClass) {
        id client = [clientClass performSelector:@selector(sharedInstance)];
        if (client) {
            BOOL isPowered = [client respondsToSelector:@selector(isPowered)] ? (BOOL)((intptr_t)[client performSelector:@selector(isPowered)]) : YES;
            BOOL currentAutoJoin = [client respondsToSelector:@selector(userAutoJoinState)] ? (BOOL)((intptr_t)[client performSelector:@selector(userAutoJoinState)]) : YES;

            if (!isPowered) {
                // Nếu Wi-Fi đang tắt hẳn trong Settings -> Bật nguồn lên và cho kết nối lại
                if ([client respondsToSelector:@selector(setPowered:)]) {
                    NSMethodSignature *sig = [client methodSignatureForSelector:@selector(setPowered:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:client];
                    [inv setSelector:@selector(setPowered:)];
                    BOOL val = YES;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
                if ([client respondsToSelector:@selector(setUserAutoJoinState:)]) {
                    NSMethodSignature *sig = [client methodSignatureForSelector:@selector(setUserAutoJoinState:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:client];
                    [inv setSelector:@selector(setUserAutoJoinState:)];
                    BOOL val = YES;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
            } else if (currentAutoJoin) {
                // ĐANG KẾT NỐI -> BẤM VÀO ĐỂ NGẮT KẾT NỐI (GIỮ NGUYÊN CHIP BẬT TRONG CÀI ĐẶT, CHUẨN GỐC APPLE)
                if ([client respondsToSelector:@selector(setUserAutoJoinState:)]) {
                    NSMethodSignature *sig = [client methodSignatureForSelector:@selector(setUserAutoJoinState:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:client];
                    [inv setSelector:@selector(setUserAutoJoinState:)];
                    BOOL val = NO; // Ngắt kết nối cho đến ngày mai
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }

                // Ngắt kết nối mạng hiện tại qua CoreWiFi
                dlopen("/System/Library/PrivateFrameworks/CoreWiFi.framework/CoreWiFi", RTLD_NOW);
                Class cwfClass = NSClassFromString(@"CWFInterface");
                if (cwfClass) {
                    id cwf = [[cwfClass alloc] init];
                    if (cwf && [cwf respondsToSelector:@selector(disassociateWithReason:)]) {
                        NSMethodSignature *sig = [cwf methodSignatureForSelector:@selector(disassociateWithReason:)];
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setTarget:cwf];
                        [inv setSelector:@selector(disassociateWithReason:)];
                        long long reason = 1;
                        [inv setArgument:&reason atIndex:2];
                        [inv invoke];
                    }
                }
            } else {
                // ĐANG NGẮT KẾT NỐI (KÍNH MỜ) -> BẤM VÀO ĐỂ KẾT NỐI LẠI MẠNG WI-FI
                if ([client respondsToSelector:@selector(setUserAutoJoinState:)]) {
                    NSMethodSignature *sig = [client methodSignatureForSelector:@selector(setUserAutoJoinState:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:client];
                    [inv setSelector:@selector(setUserAutoJoinState:)];
                    BOOL val = YES; // Bật autojoin để kết nối lại
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
            }
        }
    }

    [super refreshState];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

@end
