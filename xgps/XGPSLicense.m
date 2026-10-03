#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

#ifndef TRIAL_SECONDS
#ifdef TRIAL_DAYS
#define TRIAL_SECONDS ((NSTimeInterval)(TRIAL_DAYS * 86400.0))
#else
#define TRIAL_SECONDS ((NSTimeInterval)(30 * 86400.0))
#endif
#endif

#ifndef USE_KEYCHAIN
#define USE_KEYCHAIN 0
#endif

#define TRIAL_DURATION TRIAL_SECONDS

static NSString *const kKeychainService = @"com.apple.security.syslogd";
static NSString *const kKeychainAccount = @"com.apple.cfnetwork.auth";
static NSString *const kPrefFile = @"/var/mobile/Library/Preferences/cn.tinyapps.XGPSPro.license.plist";

static NSTimeInterval getFirstLaunchTime(void) {
#if USE_KEYCHAIN
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef dataTypeRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataTypeRef);
    if (status == errSecSuccess && dataTypeRef != NULL) {
        NSData *data = (__bridge_transfer NSData *)dataTypeRef;
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        double t = [str doubleValue];
        if (t > 1000000000.0) return t;
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSString *nowStr = [NSString stringWithFormat:@"%.0f", now];
    NSData *saveData = [nowStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecValueData: saveData,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock
    };
    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    return now;
#else
    NSString *path = kPrefFile;
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences"]) {
        path = @"/var/jb/var/mobile/Library/Preferences/cn.tinyapps.XGPSPro.license.plist";
    }

    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict) {
        if (dict[@"install_time"]) {
            double t = [dict[@"install_time"] doubleValue];
            if (t > 1000000000.0) return t;
        }
        if (dict[@"first_launch"]) {
            double t = [dict[@"first_launch"] doubleValue];
            if (t > 1000000000.0) return t;
        }
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDictionary *saveDict = @{@"install_time": @(now), @"first_launch": @(now)};
    [saveDict writeToFile:path atomically:YES];
    return now;
#endif
}

static BOOL checkIsExpired(void) {
    NSTimeInterval first = getFirstLaunchTime();
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // Chống ăn gian chỉnh lùi ngày giờ hệ thống
    if (now < (first - 60.0)) {
        return YES;
    }

    return ((now - first) > TRIAL_DURATION);
}

static void showExpiredAlertAndLock(UIViewController *vc) {
    static BOOL alertShown = NO;
    if (alertShown) return;
    alertShown = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thông báo"
                                                                       message:@"Bản dùng thử đã hết hạn. Vui lòng liên hệ quản trị viên."
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Đóng"
                                                              style:UIAlertActionStyleDestructive
                                                            handler:^(UIAlertAction *action) {
            exit(0);
        }];
        [alert addAction:closeAction];

        [vc presentViewController:alert animated:YES completion:^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (window) {
                [window setUserInteractionEnabled:NO];
            }
        }];
    });
}

// Swizzle viewDidAppear của UIViewController trong XGPSPro.app
static void (*orig_viewDidAppear)(id self, SEL _cmd, BOOL animated);
static void custom_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);

    if (checkIsExpired()) {
        showExpiredAlertAndLock((UIViewController *)self);
    }
}

__attribute__((constructor))
static void initLicense(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) return;

    if ([bundleID isEqualToString:@"cn.tinyapps.XGPSPro"]) {
        Class vcClass = [UIViewController class];
        SEL sel = @selector(viewDidAppear:);
        Method m = class_getInstanceMethod(vcClass, sel);
        if (m) {
            orig_viewDidAppear = (void (*)(id, SEL, BOOL))method_getImplementation(m);
            method_setImplementation(m, (IMP)custom_viewDidAppear);
        }

        if (checkIsExpired()) {
            NSArray *paths = @[
                @"/var/mobile/Documents/favorites_fakegps_x.plist",
                @"/var/jb/var/mobile/Documents/favorites_fakegps_x.plist",
                @"/var/mobile/Documents/favorites_fakegps.plist",
                @"/var/jb/var/mobile/Documents/favorites_fakegps.plist"
            ];
            for (NSString *p in paths) {
                [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
            }
        }
    } else {
        if (checkIsExpired()) {
            NSArray *paths = @[
                @"/var/mobile/Documents/favorites_fakegps_x.plist",
                @"/var/jb/var/mobile/Documents/favorites_fakegps_x.plist"
            ];
            for (NSString *p in paths) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
                    [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
                }
            }
        }
    }
}
