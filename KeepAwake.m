#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_setIdleTimerDisabled)(id, SEL, BOOL);
static volatile int gOffAttempts = 0;

static void new_setIdleTimerDisabled(id self, SEL _cmd, BOOL disabled) {
    if (!disabled) {
        __sync_fetch_and_add(&gOffAttempts, 1);
    }
    orig_setIdleTimerDisabled(self, _cmd, YES);
}

static UIWindow *activeWindow(void) {
    UIWindow *fallback = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) return w;
                if (!fallback) fallback = w;
            }
        }
    }
    return fallback;
}

static void toast(NSString *text) {
    UIWindow *w = activeWindow();
    if (!w) return;
    UILabel *l = [[UILabel alloc] initWithFrame:
        CGRectMake(20, 70, w.bounds.size.width - 40, 56)];
    l.text = text;
    l.numberOfLines = 2;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = UIColor.whiteColor;
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    l.layer.cornerRadius = 10;
    l.clipsToBounds = YES;
    [w addSubview:l];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{ [l removeFromSuperview]; });
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

        [NSTimer scheduledTimerWithTimeInterval:5
                                        repeats:YES
                                          block:^(NSTimer *t) { keepAwakeNow(); }];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        for (NSNotificationName n in @[UIApplicationDidBecomeActiveNotification,
                                       UIApplicationWillEnterForegroundNotification]) {
            [nc addObserverForName:n
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *x) { keepAwakeNow(); }];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            BOOL on = [UIApplication sharedApplication].isIdleTimerDisabled;
            toast([NSString stringWithFormat:@"KeepAwake: %@\nApp đã thử tắt: %d lần",
                   on ? @"ON" : @"bị tắt", gOffAttempts]);
        });
    });
}
