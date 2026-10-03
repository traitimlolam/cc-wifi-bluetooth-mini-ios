#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

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

@interface CCUIWiFiModuleViewController : UIViewController
- (void)buttonTapped:(id)sender forEvent:(id)event;
- (void)_toggleState;
- (long long)_currentState;
- (BOOL)_enabledForState:(long long)state;
@end

@interface CCUIConnectivityModuleViewController : UIViewController
- (id)wifiButton;
- (id)wifiModuleViewController;
@end

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAssociated;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
- (void)_powerStateDidChange;
- (void)_linkDidChange;
@end

static __weak id g_nativeWifiController = nil;

%hook CCUIConnectivityWifiViewController

- (void)viewDidLoad {
    %orig;
    g_nativeWifiController = self;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_nativeWifiController = self;
}

%end

%hook CCUIWiFiModuleViewController

- (void)viewDidLoad {
    %orig;
    g_nativeWifiController = self;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_nativeWifiController = self;
}

%end

%hook CCUIConnectivityModuleViewController

- (void)viewDidLoad {
    %orig;
    if ([self respondsToSelector:@selector(wifiButton)]) {
        id wb = [self wifiButton];
        if (wb) g_nativeWifiController = wb;
    } else if ([self respondsToSelector:@selector(wifiModuleViewController)]) {
        id wb = [self wifiModuleViewController];
        if (wb) g_nativeWifiController = wb;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (!g_nativeWifiController) {
        if ([self respondsToSelector:@selector(wifiButton)]) {
            id wb = [self wifiButton];
            if (wb) g_nativeWifiController = wb;
        } else if ([self respondsToSelector:@selector(wifiModuleViewController)]) {
            id wb = [self wifiModuleViewController];
            if (wb) g_nativeWifiController = wb;
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
void CCWiFiToggleAction(void) {
    if (g_nativeWifiController) {
        if ([g_nativeWifiController respondsToSelector:@selector(buttonTapped:)]) {
            [g_nativeWifiController buttonTapped:nil];
            return;
        }
        if ([g_nativeWifiController respondsToSelector:@selector(buttonTapped:forEvent:)]) {
            [g_nativeWifiController buttonTapped:nil forEvent:nil];
            return;
        }
        if ([g_nativeWifiController respondsToSelector:@selector(_toggleState)]) {
            [g_nativeWifiController _toggleState];
            return;
        }
    }

    // Direct fallback via CCUIConnectivityManager
    Class cmClass = NSClassFromString(@"CCUIConnectivityManager");
    if (cmClass) {
        id cm = [cmClass performSelector:@selector(sharedInstance)];
        if (cm && [cm respondsToSelector:@selector(wifiStateMonitor)]) {
            id monitor = [cm performSelector:@selector(wifiStateMonitor)];
            if (monitor && [monitor respondsToSelector:@selector(performAction)]) {
                [monitor performAction];
                return;
            }
        }
    }

    // Direct fallback via SBWiFiManager
    Class sb = NSClassFromString(@"SBWiFiManager");
    if (sb) {
        id mgr = [sb performSelector:@selector(sharedInstance)];
        if (mgr && [mgr respondsToSelector:@selector(setWiFiEnabled:)]) {
            BOOL enabled = [mgr respondsToSelector:@selector(wiFiEnabled)] ? (BOOL)((intptr_t)[mgr performSelector:@selector(wiFiEnabled)]) : NO;
            NSMethodSignature *sig = [mgr methodSignatureForSelector:@selector(setWiFiEnabled:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:mgr];
            [inv setSelector:@selector(setWiFiEnabled:)];
            BOOL newVal = !enabled;
            [inv setArgument:&newVal atIndex:2];
            [inv invoke];
        }
    }
}

__attribute__((visibility("default")))
BOOL CCWiFiIsActive(void) {
    if (g_nativeWifiController) {
        if ([g_nativeWifiController respondsToSelector:@selector(_currentState)] && [g_nativeWifiController respondsToSelector:@selector(_enabledForState:)]) {
            long long state = (long long)[g_nativeWifiController _currentState];
            return [g_nativeWifiController _enabledForState:state];
        }
    }

    Class cmClass = NSClassFromString(@"CCUIConnectivityManager");
    if (cmClass) {
        id cm = [cmClass performSelector:@selector(sharedInstance)];
        if (cm && [cm respondsToSelector:@selector(wifiStateMonitor)]) {
            id monitor = [cm performSelector:@selector(wifiStateMonitor)];
            if (monitor && [monitor respondsToSelector:@selector(state)]) {
                long long s = (long long)[monitor performSelector:@selector(state)];
                return (s == 3 || s == 4);
            }
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
    if (!isAuthorizedDevice()) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ensureModulesActivated();
    });
}
