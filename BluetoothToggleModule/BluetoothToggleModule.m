#import "CCUIToggleModule.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <dlfcn.h>

@interface BluetoothToggleModule : CCUIToggleModule
@end

@implementation BluetoothToggleModule

static BOOL isAuthorizedDevice(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    return (strcmp(systemInfo.machine, "iPhone14,4") == 0);
}

- (UIImage *)iconGlyph {
    UIImage *img = [UIImage imageNamed:@"ModuleIcon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    if (!img) {
        img = [UIImage systemImageNamed:@"bluetooth"];
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

- (void)setSelected:(BOOL)selected {
    if (!isAuthorizedDevice()) return;

    dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
    Class btClass = NSClassFromString(@"BluetoothManager");
    if (btClass) {
        id btMgr = [btClass performSelector:@selector(sharedInstance)];
        if (btMgr) {
            if ([btMgr respondsToSelector:@selector(setPowered:)]) {
                NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setPowered:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:btMgr];
                [inv setSelector:@selector(setPowered:)];
                BOOL val = selected;
                [inv setArgument:&val atIndex:2];
                [inv invoke];
            }
            if ([btMgr respondsToSelector:@selector(setEnabled:)]) {
                NSMethodSignature *sig = [btMgr methodSignatureForSelector:@selector(setEnabled:)];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:btMgr];
                [inv setSelector:@selector(setEnabled:)];
                BOOL val = selected;
                [inv setArgument:&val atIndex:2];
                [inv invoke];
            }
        }
    }

    [super refreshState];
}

@end
