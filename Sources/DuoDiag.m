#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>

static NSString *const kDuoLogPath = @"/var/mobile/DuoRing.log";

static void DuoDiagLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void DuoDiagLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *line = [message stringByAppendingString:@"\n"];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kDuoLogPath];
    if (!handle) {
        [line writeToFile:kDuoLogPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

static BOOL DuoDiagHas(NSString *className, NSString *selectorName) {
    Class cls = NSClassFromString(className);
    return cls && class_getInstanceMethod(cls, NSSelectorFromString(selectorName)) != NULL;
}

static void DuoDiagWalk(UIView *view, int depth, int *budget) {
    if (!view || *budget <= 0 || depth > 14) return;
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"Battery"] || [name containsString:@"StatusBar"] ||
        [name containsString:@"Signal"] || [name containsString:@"Duo"] ||
        [name containsString:@"STUI"]) {
        (*budget)--;
        DuoDiagLog(@"  d%d %@ hidden=%d alpha=%.2f frame=%@", depth, name,
                   view.hidden, view.alpha, NSStringFromCGRect(view.frame));
    }
    for (UIView *sub in view.subviews) DuoDiagWalk(sub, depth + 1, budget);
}

static void DuoDiagScan(void) {
    DuoDiagLog(@"--- view scan (after 20s) ---");
    SEL selector = NSSelectorFromString(@"allWindowsIncludingInternalWindows:onlyVisibleWindows:");
    NSArray *windows = nil;
    if ([UIWindow respondsToSelector:selector]) {
        windows = ((id (*)(id, SEL, BOOL, BOOL))objc_msgSend)(UIWindow.class, selector, YES, NO);
    }
    DuoDiagLog(@"windows: %lu", (unsigned long)windows.count);
    int budget = 150;
    for (UIWindow *window in windows) {
        DuoDiagLog(@"window %@ level=%.0f", NSStringFromClass(window.class), window.windowLevel);
        DuoDiagWalk(window, 0, &budget);
    }
    DuoDiagLog(@"--- scan done ---");
}

static void DuoDiagClasses(void) {
    unsigned int count = 0;
    Class *list = objc_copyClassList(&count);
    int printed = 0;
    DuoDiagLog(@"--- matching classes ---");
    for (unsigned int i = 0; i < count && printed < 80; i++) {
        const char *name = class_getName(list[i]);
        if (strstr(name, "BatteryView") || strstr(name, "StatusBarSignal") ||
            strstr(name, "UIStatusBar") || strstr(name, "STUIStatusBar")) {
            DuoDiagLog(@"  %s", name);
            printed++;
        }
    }
    free(list);
}

__attribute__((constructor)) static void DuoDiagInit(void) {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (![bundleID isEqualToString:@"com.apple.springboard"]) return;
        [[NSData data] writeToFile:kDuoLogPath atomically:NO];
        NSOperatingSystemVersion v = NSProcessInfo.processInfo.operatingSystemVersion;
        DuoDiagLog(@"DuoRing diag: loaded in %@, iOS %ld.%ld.%ld", bundleID,
                   (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion);
        NSArray<NSString *> *names = @[@"_UIBatteryView", @"_UIStatusBarSignalView",
            @"_UIStatusBarWifiSignalView", @"_UIStatusBarCellularSignalView", @"_UIStatusBar",
            @"_UIStatusBarForegroundView", @"_UIStatusBarStringView", @"_UIStatusBarImageView",
            @"CCUIStatusBar", @"STUIStatusBar", @"STUIStatusBarForegroundView"];
        for (NSString *name in names) {
            DuoDiagLog(@"class %@ exists=%d", name, NSClassFromString(name) != Nil);
        }
        for (NSString *sel in @[@"chargePercent", @"chargingState", @"saverModeActive",
                                @"bodyColor", @"setChargePercent:", @"setChargingState:",
                                @"setSaverModeActive:", @"setBodyColor:"]) {
            DuoDiagLog(@"_UIBatteryView %@ = %d", sel, DuoDiagHas(@"_UIBatteryView", sel));
        }
        for (NSString *sel in @[@"numberOfBars", @"numberOfActiveBars", @"activeColor",
                                @"setNumberOfBars:", @"setNumberOfActiveBars:", @"setActiveColor:"]) {
            DuoDiagLog(@"_UIStatusBarSignalView %@ = %d", sel, DuoDiagHas(@"_UIStatusBarSignalView", sel));
        }
        DuoDiagLog(@"wifi _updateActiveBars = %d", DuoDiagHas(@"_UIStatusBarWifiSignalView", @"_updateActiveBars"));
        DuoDiagLog(@"cellular _updateActiveBars = %d", DuoDiagHas(@"_UIStatusBarCellularSignalView", @"_updateActiveBars"));
        DuoDiagClasses();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            DuoDiagScan();
        });
    }
}
