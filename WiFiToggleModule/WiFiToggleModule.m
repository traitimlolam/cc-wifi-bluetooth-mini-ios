#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

typedef struct __WiFiManagerClient *WiFiManagerClientRef;
extern WiFiManagerClientRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern Boolean WiFiManagerClientGetPower(WiFiManagerClientRef client);
extern void WiFiManagerClientSetPower(WiFiManagerClientRef client, Boolean power);

@interface WiFiToggleModule : CCUIToggleModule
@end

@implementation WiFiToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (UIImage *)iconGlyph {
    UIImage *img = [UIImage imageNamed:@"ModuleIcon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    if (!img) {
        img = [UIImage systemImageNamed:@"wifi"];
    }
    return img;
}

- (UIImage *)selectedIconGlyph {
    return [self iconGlyph];
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

- (BOOL)isSelected {
    if (!isAuthorizedDevice()) return NO;

    Class sbWifiClass = NSClassFromString(@"SBWiFiManager");
    if (sbWifiClass) {
        id wifiMgr = [sbWifiClass performSelector:@selector(sharedInstance)];
        if ([wifiMgr respondsToSelector:@selector(isPowered)]) {
            return (BOOL)((intptr_t)[wifiMgr performSelector:@selector(isPowered)]);
        } else if ([wifiMgr respondsToSelector:@selector(wiFiEnabled)]) {
            return (BOOL)((intptr_t)[wifiMgr performSelector:@selector(wiFiEnabled)]);
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

- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    Class sbWifiClass = NSClassFromString(@"SBWiFiManager");
    if (sbWifiClass) {
        id wifiMgr = [sbWifiClass performSelector:@selector(sharedInstance)];
        if ([wifiMgr respondsToSelector:@selector(setPowered:)]) {
            NSMethodSignature *sig = [wifiMgr methodSignatureForSelector:@selector(setPowered:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:wifiMgr];
            [inv setSelector:@selector(setPowered:)];
            BOOL val = selected;
            [inv setArgument:&val atIndex:2];
            [inv invoke];
        } else if ([wifiMgr respondsToSelector:@selector(setWiFiEnabled:)]) {
            NSMethodSignature *sig = [wifiMgr methodSignatureForSelector:@selector(setWiFiEnabled:)];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:wifiMgr];
            [inv setSelector:@selector(setWiFiEnabled:)];
            BOOL val = selected;
            [inv setArgument:&val atIndex:2];
            [inv invoke];
        }
    }

    void *h = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (h) {
        WiFiManagerClientRef (*pCreate)(CFAllocatorRef, int) = dlsym(h, "WiFiManagerClientCreate");
        void (*pSetPower)(WiFiManagerClientRef, Boolean) = dlsym(h, "WiFiManagerClientSetPower");
        if (pCreate && pSetPower) {
            WiFiManagerClientRef client = pCreate(kCFAllocatorDefault, 0);
            if (client) {
                pSetPower(client, (Boolean)selected);
                CFRelease(client);
            }
        }
    }

    [super refreshState];
}

@end
