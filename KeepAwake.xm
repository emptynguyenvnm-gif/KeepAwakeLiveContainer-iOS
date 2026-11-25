#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

%hook UIApplication

- (void)setIdleTimerDisabled:(BOOL)disabled {
    %orig(YES);
}

%end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication]
            setIdleTimerDisabled:YES];
    });
}
