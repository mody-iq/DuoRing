#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "DuoGlyphView.h"

// Hides the stock network-type text (LTE, 5G...) and the stock "62%" text in
// Control Center while DuoRing is visible, and hands the network type to the glyph.

static NSHashTable<UIView *> *DuoExtraHidden;

static NSString *DuoExtraText(UIView *view) {
    SEL selector = NSSelectorFromString(@"text");
    if (![view respondsToSelector:selector]) return nil;
    id value = nil;
    @try {
        value = ((id (*)(id, SEL))objc_msgSend)(view, selector);
    } @catch (__unused NSException *exception) {
        value = nil;
    }
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static BOOL DuoExtraIsPercent(NSString *text) {
    if (!text) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (![trimmed hasSuffix:@"%"] || trimmed.length < 2 || trimmed.length > 4) return NO;
    NSString *digits = [trimmed substringToIndex:trimmed.length - 1];
    return [digits rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
}

static BOOL DuoExtraIsNetworkType(NSString *text) {
    if (!text) return NO;
    NSString *value = [[text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (value.length == 0 || value.length > 6) return NO;
    static NSRegularExpression *expression;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        expression = [NSRegularExpression regularExpressionWithPattern:
            @"^(LTE\\+?|LTE-A|E|EDGE|GPRS|1X|[2-5]G\\+?( ?(UC|UW|E))?)$" options:0 error:nil];
    });
    return [expression numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] > 0;
}

static NSArray<UIView *> *DuoExtraViews(UIView *root, UIView *skip, NSUInteger limit) {
    NSMutableArray<UIView *> *result = [NSMutableArray array];
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count && result.count < limit) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if (view == skip) continue;
        [result addObject:view];
        [stack addObjectsFromArray:view.subviews];
    }
    return result;
}

static void DuoExtraHide(UIView *view) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if ([DuoExtraHidden containsObject:view]) {
        if (!view.layer.hidden) view.layer.hidden = YES;
    } else if (!view.layer.hidden) {
        [DuoExtraHidden addObject:view];
        view.layer.hidden = YES;
    }
    [CATransaction commit];
}

static void DuoExtraRestore(UIView *view) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.hidden = NO;
    [DuoExtraHidden removeObject:view];
    [CATransaction commit];
}

static void DuoExtraTick(void) {
    NSMutableSet<UIView *> *matched = [NSMutableSet set];
    BOOL anyVisible = NO;
    for (DuoGlyphView *glyph in [DuoGlyphView liveGlyphs]) {
        UIView *container = glyph.superview;
        if (!glyph.window || !container || glyph.hidden || glyph.alpha < 0.01) {
            glyph.networkType = nil;
            continue;
        }
        anyVisible = YES;

        NSString *type = nil;
        for (UIView *view in DuoExtraViews(container, glyph, 120)) {
            NSString *text = DuoExtraText(view);
            if (DuoExtraIsNetworkType(text)) {
                type = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                DuoExtraHide(view);
                [matched addObject:view];
            }
        }
        glyph.networkType = type;

        for (UIView *view in DuoExtraViews(glyph.window, glyph, 900)) {
            if (DuoExtraIsPercent(DuoExtraText(view))) {
                DuoExtraHide(view);
                [matched addObject:view];
            }
        }
    }
    for (UIView *view in DuoExtraHidden.allObjects) {
        if (!anyVisible || ![matched containsObject:view]) DuoExtraRestore(view);
    }
}

__attribute__((constructor)) static void DuoExtrasInit(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            DuoExtraHidden = [NSHashTable weakObjectsHashTable];
            NSTimer *timer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *firedTimer) {
                (void)firedTimer;
                DuoExtraTick();
            }];
            [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        });
    }
}
