#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <objc/runtime.h>

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

@interface CCUIConnectivityWifiViewController : UIViewController
- (void)buttonTapped:(id)sender;
- (void)_toggleState;
- (long long)_currentState;
- (BOOL)_enabledForState:(long long)state;
@end

@interface CCUIConnectivityModuleViewController : UIViewController
- (id)wifiButton;
@end

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAssociated;
- (BOOL)wiFiEnabled;
- (void)_powerStateDidChange;
- (void)_linkDidChange;
@end

static __weak CCUIConnectivityWifiViewController *g_nativeWifiVC = nil;

static CCUIConnectivityWifiViewController *findActiveWiFiViewController(void) {
    if (g_nativeWifiVC) return g_nativeWifiVC;
    
    // Traverse windows to find CCUIConnectivityWifiViewController
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIViewController *root = window.rootViewController;
        if (!root) continue;
        NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
        while (queue.count > 0) {
            UIViewController *vc = [queue firstObject];
            [queue removeObjectAtIndex:0];
            if (!vc) continue;
            
            if ([vc isKindOfClass:objc_getClass("CCUIConnectivityWifiViewController")]) {
                g_nativeWifiVC = (CCUIConnectivityWifiViewController *)vc;
                return (CCUIConnectivityWifiViewController *)vc;
            }
            if ([vc respondsToSelector:@selector(wifiButton)]) {
                id wb = [vc performSelector:@selector(wifiButton)];
                if (wb && [wb isKindOfClass:objc_getClass("CCUIConnectivityWifiViewController")]) {
                    g_nativeWifiVC = (CCUIConnectivityWifiViewController *)wb;
                    return (CCUIConnectivityWifiViewController *)wb;
                }
            }
            [queue addObjectsFromArray:vc.childViewControllers];
        }
    }
    return nil;
}

%hook CCUIConnectivityWifiViewController

- (void)viewDidLoad {
    %orig;
    g_nativeWifiVC = self;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_nativeWifiVC = self;
}

- (void)buttonTapped:(id)sender {
    %orig;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CCWiFiStateChangedNotification" object:nil];
}

%end

%hook CCUIConnectivityModuleViewController

- (void)viewDidLoad {
    %orig;
    if ([self respondsToSelector:@selector(wifiButton)]) {
        id wb = [self wifiButton];
        if (wb && [wb isKindOfClass:objc_getClass("CCUIConnectivityWifiViewController")]) {
            g_nativeWifiVC = (CCUIConnectivityWifiViewController *)wb;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([self respondsToSelector:@selector(wifiButton)]) {
        id wb = [self wifiButton];
        if (wb && [wb isKindOfClass:objc_getClass("CCUIConnectivityWifiViewController")]) {
            g_nativeWifiVC = (CCUIConnectivityWifiViewController *)wb;
        }
    }
}

%end

%hook SBWiFiManager

- (void)_powerStateDidChange {
    %orig;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CCWiFiStateChangedNotification" object:nil];
}

- (void)_linkDidChange {
    %orig;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CCWiFiStateChangedNotification" object:nil];
}

%end

__attribute__((visibility("default")))
void NativeWiFiButtonTap(void) {
    CCUIConnectivityWifiViewController *wifiVC = findActiveWiFiViewController();
    if (wifiVC) {
        if ([wifiVC respondsToSelector:@selector(buttonTapped:)]) {
            [wifiVC buttonTapped:nil];
            return;
        }
        if ([wifiVC respondsToSelector:@selector(_toggleState)]) {
            [wifiVC _toggleState];
            return;
        }
    }
}

__attribute__((visibility("default")))
BOOL NativeWiFiIsSelected(void) {
    CCUIConnectivityWifiViewController *wifiVC = findActiveWiFiViewController();
    if (wifiVC) {
        if ([wifiVC respondsToSelector:@selector(_currentState)] && [wifiVC respondsToSelector:@selector(_enabledForState:)]) {
            long long state = (long long)[wifiVC _currentState];
            return [wifiVC _enabledForState:state];
        }
    }
    Class sb = NSClassFromString(@"SBWiFiManager");
    if (sb) {
        id mgr = [sb performSelector:@selector(sharedInstance)];
        if (mgr && [mgr respondsToSelector:@selector(isAssociated)]) {
            return (BOOL)((intptr_t)[mgr performSelector:@selector(isAssociated)]);
        }
    }
    return NO;
}

static void ensureModulesActivated(void) {
    if (!isAuthorizedDevice()) return;

    NSArray *paths = @[
        @"/var/mobile/Library/ControlCenter/CCSupportModuleConfiguration.plist",
        @"/var/mobile/Library/ControlCenter/ModuleConfiguration.plist"
    ];

    for (NSString *plistPath in paths) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) continue;

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
        if (!dict) continue;

        NSMutableArray *userEnabled = [dict[@"user-enabled"] mutableCopy];
        if (!userEnabled) userEnabled = [NSMutableArray array];

        BOOL modified = NO;
        if (![userEnabled containsObject:@"com.nguyentronghieu.ccwifi"]) {
            [userEnabled addObject:@"com.nguyentronghieu.ccwifi"];
            modified = YES;
        }
        if (![userEnabled containsObject:@"com.nguyentronghieu.ccbluetooth"]) {
            [userEnabled addObject:@"com.nguyentronghieu.ccbluetooth"];
            modified = YES;
        }

        if (modified) {
            dict[@"user-enabled"] = userEnabled;
            [dict writeToFile:plistPath atomically:YES];
        }
    }
}

%ctor {
    if (!isAuthorizedDevice()) return;
    
    // Nạp ConnectivityModule.bundle trước để lớp CCUIConnectivityWifiViewController sẵn sàng
    [[NSBundle bundleWithPath:@"/System/Library/ControlCenter/Bundles/ConnectivityModule.bundle"] load];
    
    %init;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ensureModulesActivated();
    });
}
