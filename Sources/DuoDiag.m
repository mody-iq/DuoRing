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

static void DuoDiagDumpMembers(Class cls) {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        const char *type = ivar_getTypeEncoding(ivars[i]);
        DuoDiagLog(@"    ivar %s (%s)", name ? name : "", type ? type : "");
    }
    free(ivars);
    objc_property_t *props = class_copyPropertyList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = property_getName(props[i]);
        const char *attrs = property_getAttributes(props[i]);
        DuoDiagLog(@"    prop %s [%s]", name ? name : "", attrs ? attrs : "");
    }
    free(props);
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        DuoDiagLog(@"    method %s", sel_getName(method_getName(methods[i])));
    }
    free(methods);
}

static void DuoDiagDumpClass(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) {
        DuoDiagLog(@"== %@ : MISSING", name);
        return;
    }
    NSMutableString *chain = [NSMutableString string];
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        [chain appendFormat:@"%s > ", class_getName(c)];
    }
    DuoDiagLog(@"== %@ chain: %@", name, chain);
    for (Class c = cls; c && c != UIView.class && c != NSObject.class; c = class_getSuperclass(c)) {
        DuoDiagLog(@"  -- members of %s", class_getName(c));
        DuoDiagDumpMembers(c);
    }
}

static void DuoDiagWalkAll(UIView *view, int depth, int *budget) {
    if (!view || *budget <= 0 || depth > 8) return;
    (*budget)--;
    NSString *indent = [@"" stringByPaddingToLength:(NSUInteger)(depth * 2) withString:@" " startingAtIndex:0];
    NSMutableString *line = [NSMutableString stringWithFormat:@"%@%@ frame=%@ hidden=%d alpha=%.2f layers=%lu",
        indent, NSStringFromClass(view.class), NSStringFromCGRect(view.frame),
        view.hidden, view.alpha, (unsigned long)view.layer.sublayers.count];
    NSArray<NSString *> *keys = @[@"chargePercent", @"chargingState", @"saverModeActive",
        @"bodyColor", @"numberOfBars", @"numberOfActiveBars", @"activeColor", @"text",
        @"batteryLevel", @"percentage", @"state"];
    for (NSString *key in keys) {
        SEL selector = NSSelectorFromString(key);
        if (![view respondsToSelector:selector]) continue;
        id value = nil;
        @try { value = [view valueForKey:key]; } @catch (__unused NSException *e) { value = @"<exception>"; }
        [line appendFormat:@" %@=%@", key, value];
    }
    DuoDiagLog(@"%@", line);
    for (UIView *sub in view.subviews) DuoDiagWalkAll(sub, depth + 1, budget);
}

static void DuoDiagScan(void) {
    DuoDiagLog(@"--- status bar view scan (after 20s) ---");
    SEL selector = NSSelectorFromString(@"allWindowsIncludingInternalWindows:onlyVisibleWindows:");
    NSArray *windows = nil;
    if ([UIWindow respondsToSelector:selector]) {
        windows = ((id (*)(id, SEL, BOOL, BOOL))objc_msgSend)(UIWindow.class, selector, YES, NO);
    }
    for (UIWindow *window in windows) {
        if ([NSStringFromClass(window.class) isEqualToString:@"SBStatusBarWindow"]) {
            int budget = 150;
            DuoDiagWalkAll(window, 0, &budget);
        }
    }
    DuoDiagLog(@"--- scan done ---");
}

__attribute__((constructor)) static void DuoDiagInit(void) {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (![bundleID isEqualToString:@"com.apple.springboard"]) return;
        [[NSData data] writeToFile:kDuoLogPath atomically:NO];
        NSOperatingSystemVersion v = NSProcessInfo.processInfo.operatingSystemVersion;
        DuoDiagLog(@"DuoRing diag v2: iOS %ld.%ld.%ld", (long)v.majorVersion,
                   (long)v.minorVersion, (long)v.patchVersion);
        NSArray<NSString *> *targets = @[
            @"STUIStatusBarBatteryView", @"STUIStatusBarWifiSignalView",
            @"STUIStatusBarDualCellularSignalView", @"STUIStatusBarCellularSmallSignalView",
            @"STUIStatusBarCellularFlatSignalView", @"STUIStatusBarForegroundView",
            @"STUIStatusBar", @"STUIStatusBarBatteryItem", @"STUIStatusBarWifiItem",
            @"STUIStatusBarCellularItem"
        ];
        for (NSString *name in targets) DuoDiagDumpClass(name);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            DuoDiagScan();
        });
    }
}
