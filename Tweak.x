#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <notify.h>

// LowPowerMode.framework (private)
@interface _PMLowPowerMode : NSObject
+ (instancetype)sharedInstance;
- (NSInteger)getPowerMode;
- (void)setPowerMode:(NSInteger)mode fromSource:(NSString *)source withCompletion:(void (^)(BOOL success, NSError *error))completion;
@end

#define LPM_NOTIFY      "com.apple.system.lowpowermode"
#define USER_OFF_NOTIFY "com.qn.plzkeeplpm/useroff"
#define KEEPLPM_SOURCE  @"PleaseKeepLPM"

static const CFTimeInterval kUserOffWindow = 3.0;  // how long a manual turn-off is respected
static const double kReenableDelay = 1.0;          // gives Settings' USER_OFF_NOTIFY time to arrive
static const float kMinBatteryLevel = 0.75f;       // UIDevice reports battery level in 5% steps

static BOOL gLastLPM;
static CFAbsoluteTime gUserOffUntil;

static _PMLowPowerMode *LPM(void) {
	Class cls = NSClassFromString(@"_PMLowPowerMode");
	return [cls respondsToSelector:@selector(sharedInstance)] ? [cls sharedInstance] : nil;
}

static BOOL isLPMOn(void) {
	_PMLowPowerMode *lpm = LPM();
	if ([lpm respondsToSelector:@selector(getPowerMode)]) return [lpm getPowerMode] == 1;
	return NSProcessInfo.processInfo.isLowPowerModeEnabled;
}

static void markUserOff(void) {
	gUserOffUntil = CFAbsoluteTimeGetCurrent() + kUserOffWindow;
}

// Control Center and Settings turn LPM off through this client API, while the
// system's auto-disable at 80% does not, so any turn-off seen here is manual.
%hook _PMLowPowerMode
- (void)setPowerMode:(NSInteger)mode fromSource:(NSString *)source withCompletion:(id)completion {
	if (mode == 0 && ![source isEqualToString:KEEPLPM_SOURCE]) {
		markUserOff();
		notify_post(USER_OFF_NOTIFY);
	}
	%orig;
}
%end

static void reenableIfNeeded(void) {
	if (isLPMOn()) return;
	if (CFAbsoluteTimeGetCurrent() < gUserOffUntil) return;

	UIDevice *dev = UIDevice.currentDevice;
	BOOL pluggedIn = dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull;
	if (!pluggedIn || dev.batteryLevel < kMinBatteryLevel) return;

	// The completion must be non-nil, otherwise NSXPCConnection throws and SpringBoard crashes
	@try {
		[LPM() setPowerMode:1 fromSource:KEEPLPM_SOURCE withCompletion:^(BOOL success, NSError *error) {}];
	} @catch (NSException *e) {}
}

static void onLPMChanged(void) {
	BOOL wasOn = gLastLPM;
	gLastLPM = isLPMOn();
	if (!wasOn || gLastLPM) return;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kReenableDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		reenableIfNeeded();
		gLastLPM = isLPMOn();
	});
}

%ctor {
	dlopen("/System/Library/PrivateFrameworks/LowPowerMode.framework/LowPowerMode", RTLD_LAZY);
	Class cls = NSClassFromString(@"_PMLowPowerMode");
	if (![cls instancesRespondToSelector:@selector(setPowerMode:fromSource:withCompletion:)]) return;
	%init;

	// Settings only needs the hook above; the rest runs in SpringBoard
	if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;

	dispatch_async(dispatch_get_main_queue(), ^{
		UIDevice.currentDevice.batteryMonitoringEnabled = YES;
		gLastLPM = isLPMOn();

		int token;
		notify_register_dispatch(LPM_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) {
			onLPMChanged();
		});
		notify_register_dispatch(USER_OFF_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) {
			markUserOff();
		});
	});
}
