#import "DuoRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <math.h>

static NSString *const DuoPreferencesDomain = @"local.duoring";
static CFStringRef const DuoPreferencesNotification = CFSTR("local.duoring/preferences.changed");

@interface DuoRootListController ()
@property(nonatomic, strong) PSSpecifier *duoSizeSlider;
@property(nonatomic, strong) PSSpecifier *duoSizeLabel;
@end

@implementation DuoRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DuoRing";
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];

        PSSpecifier *display = [PSSpecifier groupSpecifierWithName:@"Appearance"];
        [display setProperty:@"Turn DuoRing off to restore the original status-bar icons. Changes take effect immediately."
                      forKey:@"footerText"];
        [items addObject:display];

        PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Enable DuoRing"
            target:self set:@selector(setPreferenceValue:specifier:)
            get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
        [enabled setProperty:DuoPreferencesDomain forKey:@"defaults"];
        [enabled setProperty:@"Enabled" forKey:@"key"];
        [enabled setProperty:@YES forKey:@"default"];
        [items addObject:enabled];

        PSSpecifier *sizeGroup = [PSSpecifier groupSpecifierWithName:@"DuoRing Size"];
        [sizeGroup setProperty:@"Move the slider to resize DuoRing. 100% matches the original size."
                        forKey:@"footerText"];
        [items addObject:sizeGroup];

        PSSpecifier *sizeValue = [PSSpecifier preferenceSpecifierNamed:@"Current Size"
            target:self set:NULL get:@selector(sizePercent:)
            detail:Nil cell:PSTitleValueCell edit:Nil];
        self.duoSizeLabel = sizeValue;
        [items addObject:sizeValue];

        PSSpecifier *sizeSlider = [PSSpecifier preferenceSpecifierNamed:nil
            target:self set:@selector(setPreferenceValue:specifier:)
            get:@selector(readPreferenceValue:) detail:Nil cell:PSSliderCell edit:Nil];
        [sizeSlider setProperty:DuoPreferencesDomain forKey:@"defaults"];
        [sizeSlider setProperty:@"SizeScale" forKey:@"key"];
        [sizeSlider setProperty:@(1.0) forKey:@"default"];
        [sizeSlider setProperty:@(0.70) forKey:@"min"];
        [sizeSlider setProperty:@(1.40) forKey:@"max"];
        [sizeSlider setProperty:@YES forKey:@"isSegmented"];
        [sizeSlider setProperty:@(15) forKey:@"segmentCount"];
        [sizeSlider setProperty:@YES forKey:@"isContinuous"];
        self.duoSizeSlider = sizeSlider;
        [items addObject:sizeSlider];

        PSSpecifier *resetSize = [PSSpecifier preferenceSpecifierNamed:@"Reset Size to 100%"
            target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
        resetSize.buttonAction = @selector(resetSize:);
        [items addObject:resetSize];

        PSSpecifier *about = [PSSpecifier groupSpecifierWithName:@"About DuoRing"];
        [about setProperty:@"A circular status-bar glyph that combines battery percentage and ring, Wi-Fi strength and four cellular dots. Port of DuoBar by RBx9 (MIT license) for iOS 16 to 18.7."
                    forKey:@"footerText"];
        [items addObject:about];

        PSSpecifier *version = [PSSpecifier preferenceSpecifierNamed:@"Version"
            target:self set:NULL get:@selector(versionName:)
            detail:Nil cell:PSTitleValueCell edit:Nil];
        [items addObject:version];

        PSSpecifier *developer = [PSSpecifier preferenceSpecifierNamed:@"Original Developer"
            target:self set:NULL get:@selector(developerName:)
            detail:Nil cell:PSTitleValueCell edit:Nil];
        [items addObject:developer];

        _specifiers = items;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    CFPreferencesAppSynchronize((__bridge CFStringRef)DuoPreferencesDomain);
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)DuoPreferencesDomain));
    return [value isKindOfClass:NSNumber.class] ? value : [specifier propertyForKey:@"default"];
}

- (NSString *)sizePercent:(PSSpecifier *)specifier {
    (void)specifier;
    NSNumber *size = [self readPreferenceValue:self.duoSizeSlider];
    CGFloat scale = [size respondsToSelector:@selector(doubleValue)] ? size.doubleValue : 1.0;
    return [NSString stringWithFormat:@"%ld%%", (long)lround(fmax(0.70, fmin(1.40, scale)) * 100.0)];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return;

    NSNumber *stored = nil;
    if ([key isEqualToString:@"SizeScale"]) {
        double number = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 1.0;
        if (!isfinite(number)) number = 1.0;
        // 15 discrete positions, 5% increments from 70% to 140%.
        number = fmax(0.70, fmin(1.40, round(number * 20.0) / 20.0));
        stored = @(number);
    } else {
        stored = @([value boolValue]);
    }

    NSNumber *previous = [self readPreferenceValue:specifier];
    if ([previous isKindOfClass:NSNumber.class] && fabs(previous.doubleValue - stored.doubleValue) < 0.0001) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)stored,
        (__bridge CFStringRef)DuoPreferencesDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)DuoPreferencesDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        DuoPreferencesNotification, NULL, NULL, YES);
    if ([key isEqualToString:@"SizeScale"] && self.duoSizeLabel) {
        [self reloadSpecifier:self.duoSizeLabel animated:NO];
    }
}

- (void)resetSize:(PSSpecifier *)specifier {
    (void)specifier;
    [self setPreferenceValue:@(1.0) specifier:self.duoSizeSlider];
    if (self.duoSizeSlider) [self reloadSpecifier:self.duoSizeSlider animated:NO];
    if (self.duoSizeLabel) [self reloadSpecifier:self.duoSizeLabel animated:NO];
}

- (NSString *)developerName:(PSSpecifier *)specifier {
    (void)specifier;
    return @"RBx9";
}

- (NSString *)versionName:(PSSpecifier *)specifier {
    (void)specifier;
    return @"1.0.0";
}

@end
