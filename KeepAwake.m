#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_setIdleTimerDisabled)(id, SEL, BOOL);

static void new_setIdleTimerDisabled(id self, SEL _cmd, BOOL disabled) {
    // Luôn ép thành YES, bất kể app yêu cầu gì
    orig_setIdleTimerDisabled(self, _cmd, YES);
}

static void keepAwakeNow(void) {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

__attribute__((constructor))
static void init(void) {
    Method m = class_getInstanceMethod([UIApplication class],
                                       @selector(setIdleTimerDisabled:));
    if (m) {
        orig_setIdleTimerDisabled = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)new_setIdleTimerDisabled);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        keepAwakeNow();
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *n) { keepAwakeNow(); }];
    });
}
