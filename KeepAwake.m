#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define SHOW_TOAST 1   // đổi thành 0 khi đã chạy ổn để ẩn thông báo

static void (*orig_setIdleTimerDisabled)(id, SEL, BOOL) = NULL;
static volatile int gOffAttempts = 0;

static void new_setIdleTimerDisabled(id self, SEL _cmd, BOOL disabled) {
    if (!disabled) {
        __sync_fetch_and_add(&gOffAttempts, 1);
    }
    if (orig_setIdleTimerDisabled) {
        orig_setIdleTimerDisabled(self, _cmd, YES);
    }
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

static void toast(UIWindow *w, NSString *text) {
    UILabel *l = [[UILabel alloc] initWithFrame:
        CGRectMake(20, 70, w.bounds.size.width - 40, 56)];
    l.text = text;
    l.numberOfLines = 2;
    l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = UIColor.whiteColor;
    l.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    l.layer.cornerRadius = 10;
    l.clipsToBounds = YES;
    [w addSubview:l];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{ [l removeFromSuperview]; });
}

// Thử hiện toast, nếu chưa có window thì thử lại mỗi giây (tối đa 10 lần)
static void showStatusToast(int attempt) {
#if SHOW_TOAST
    UIWindow *w = activeWindow();
    if (!w) {
        if (attempt < 10) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{ showStatusToast(attempt + 1); });
        }
        return;
    }
    BOOL on = [UIApplication sharedApplication].isIdleTimerDisabled;
    toast(w, [NSString stringWithFormat:@"KeepAwake: %@\nApp đã thử tắt: %d lần",
              on ? @"ON" : @"bị tắt", gOffAttempts]);
#endif
}

static void keepAwakeNow(BOOL reassert) {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return;
    if (reassert && orig_setIdleTimerDisabled) {
        // tắt rồi bật lại bằng hàm gốc để iOS nhận lại giá trị
        orig_setIdleTimerDisabled(app, @selector(setIdleTimerDisabled:), NO);
    }
    app.idleTimerDisabled = YES;   // đã bị swizzle nên luôn thành YES
}

__attribute__((constructor))
static void KeepAwakeInit(void) {
    Method m = class_getInstanceMethod([UIApplication class],
                                       @selector(setIdleTimerDisabled:));
    if (m) {
        orig_setIdleTimerDisabled =
            (void (*)(id, SEL, BOOL))method_getImplementation(m);
        method_setImplementation(m, (IMP)new_setIdleTimerDisabled);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        keepAwakeNow(YES);

        [NSTimer scheduledTimerWithTimeInterval:5
                                        repeats:YES
                                          block:^(NSTimer *t) { keepAwakeNow(NO); }];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        for (NSNotificationName n in @[UIApplicationDidBecomeActiveNotification,
                                       UIApplicationWillEnterForegroundNotification,
                                       UISceneDidActivateNotification]) {
            [nc addObserverForName:n
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(NSNotification *x) { keepAwakeNow(YES); }];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{ showStatusToast(0); });
    });
}
