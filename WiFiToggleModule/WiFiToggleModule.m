#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

typedef void (*CCWiFiToggleActionFunc)(void);
typedef BOOL (*CCWiFiIsActiveFunc)(void);

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

// Icon Wi-Fi to gấp đôi (pointSize 38.0, glyphScale 1.25)
- (UIImage *)iconGlyph {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:38.0 weight:UIImageSymbolWeightRegular];
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
    return 1.25; // To gấp đôi so với 0.65 cũ
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    CCWiFiIsActiveFunc pIsActive = (CCWiFiIsActiveFunc)dlsym(RTLD_DEFAULT, "CCWiFiIsActive");
    if (pIsActive) {
        return pIsActive();
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

- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    CCWiFiToggleActionFunc pToggle = (CCWiFiToggleActionFunc)dlsym(RTLD_DEFAULT, "CCWiFiToggleAction");
    if (pToggle) {
        pToggle();
    } else {
        // Fallback trực tiếp nếu chưa tìm thấy hook
        Class sb = NSClassFromString(@"SBWiFiManager");
        if (sb) {
            id mgr = [sb performSelector:@selector(sharedInstance)];
            if (mgr && [mgr respondsToSelector:@selector(setWiFiEnabled:)]) {
                BOOL isEn = [mgr respondsToSelector:@selector(wiFiEnabled)] ? (BOOL)((intptr_t)[mgr performSelector:@selector(wiFiEnabled)]) : NO;
                NSMethodSignature *sig = [mgr methodSignatureForSelector:@selector(setWiFiEnabled:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:mgr];
                [inv setSelector:@selector(setWiFiEnabled:)];
                BOOL newVal = !isEn;
                [inv setArgument:&newVal atIndex:2];
                [inv invoke];
            }
        }
    }

    [super refreshState];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshState];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.80 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshState];
    });
}

@end
