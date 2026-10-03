#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (void)_powerStateDidChange;
- (void)_linkDidChange;
@end

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
