#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>
#import <objc/runtime.h>

@interface UIImage (PrivateSF)
+ (UIImage *)_systemImageNamed:(NSString *)name;
+ (UIImage *)_systemImageNamed:(NSString *)name withConfiguration:(UIImageConfiguration *)configuration;
@end

@interface BluetoothToggleModule : CCUIToggleModule {
    BOOL _isTransitioning;
    BOOL _targetState;
}
@end

@implementation BluetoothToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (instancetype)init {
    if ((self = [super init])) {
        _isTransitioning = NO;
        _targetState = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshState) name:@"BluetoothPowerChangedNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshState) name:@"BluetoothAvailabilityChangedNotification" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Icon Bluetooth chuẩn tỉ lệ 1.0 (28pt) TO BẰNG VÀ ĐẸP NHƯ WI-FI
- (UIImage *)iconGlyph {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightRegular];
    UIImage *img = nil;
    if ([UIImage respondsToSelector:@selector(_systemImageNamed:withConfiguration:)]) {
        img = [UIImage _systemImageNamed:@"bluetooth" withConfiguration:config];
    }
    if (!img) {
        img = [UIImage systemImageNamed:@"bluetooth" withConfiguration:config];
    }
    if (!img && [UIImage respondsToSelector:@selector(_systemImageNamed:)]) {
        img = [UIImage _systemImageNamed:@"bluetooth"];
    }
    if (!img) {
        img = [UIImage systemImageNamed:@"bluetooth"];
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

- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    if (_isTransitioning) {
        return _targetState;
    }

    dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
    Class btClass = NSClassFromString(@"BluetoothManager");
    if (btClass) {
        id btMgr = [btClass performSelector:@selector(sharedInstance)];
        if (btMgr && [btMgr respondsToSelector:@selector(powered)]) {
            return (BOOL)((intptr_t)[btMgr performSelector:@selector(powered)]);
        }
    }
    return NO;
}

// Bật / Tắt Bluetooth dứt khoát 1 chạm (Có trạng thái chuyển tiếp mượt mà, không bị bật lại tắt)
- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    _isTransitioning = YES;
    _targetState = selected;

    dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
    Class btClass = NSClassFromString(@"BluetoothManager");
    if (btClass) {
        id btMgr = [btClass performSelector:@selector(sharedInstance)];
        if (btMgr) {
            if (selected) {
                // Khi BẬT: Bắt buộc kích hoạt Enabled trước, sau đó kích hoạt Powered
                if ([btMgr respondsToSelector:@selector(setEnabled:)]) {
                    NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setEnabled:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:btMgr];
                    [inv setSelector:@selector(setEnabled:)];
                    BOOL val = YES;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
                if ([btMgr respondsToSelector:@selector(setPowered:)]) {
                    NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setPowered:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:btMgr];
                    [inv setSelector:@selector(setPowered:)];
                    BOOL val = YES;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
            } else {
                // Khi TẮT: Hạ Powered trước, sau đó hạ Enabled
                if ([btMgr respondsToSelector:@selector(setPowered:)]) {
                    NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setPowered:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:btMgr];
                    [inv setSelector:@selector(setPowered:)];
                    BOOL val = NO;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
                if ([btMgr respondsToSelector:@selector(setEnabled:)]) {
                    NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setEnabled:)];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:btMgr];
                    [inv setSelector:@selector(setEnabled:)];
                    BOOL val = NO;
                    [inv setArgument:&val atIndex:2];
                    [inv invoke];
                }
            }
        }
    }

    [super refreshState];

    // Giữ trạng thái chuyển tiếp 0.6s để phần cứng Bluetooth nạp điện xong, sau đó đồng bộ thực tế
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_isTransitioning = NO;
        [self refreshState];
    });
}

@end
