#import <Foundation/Foundation.h>

@interface SpringBoard : NSObject
- (void)applicationDidFinishLaunching:(id)application;
@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[HelloMody] loaded");
}

%end
