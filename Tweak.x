/*
 * PleaseKeepLPM
 * Copyright (C) 2026 Qn
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <notify.h>

// LowPowerMode.framework (private)
@interface _PMLowPowerMode : NSObject
+ (instancetype)sharedInstance;
- (void)setPowerMode:(NSInteger)mode fromSource:(NSString *)source withCompletion:(void (^)(BOOL success, NSError *error))completion;
@end

// Posted by powerd only from -[PMLowPowerModeService autoDisableLowPowerMode],
// i.e. when the system turns LPM off by itself (not when the user does).
#define AUTO_DISABLED_NOTIFY "com.apple.system.lowpowermode.auto_disabled"
#define KEEPLPM_SOURCE       @"PleaseKeepLPM"

// The single debug switch. `make package PLEASEKEEPLPM_DEBUG=1` defines PLK_DEBUG; every debug
// statement goes through PLKLog, which compiles to nothing otherwise.
#ifdef PLK_DEBUG
#define PLKLog(fmt, ...) NSLog(@"[PleaseKeepLPM] " fmt, ##__VA_ARGS__)
#else
#define PLKLog(fmt, ...) do {} while (0)
#endif

static void reenableLPM(void) {
	PLKLog(@"auto_disabled received, re-enabling");
	Class cls = NSClassFromString(@"_PMLowPowerMode");
	if (![cls respondsToSelector:@selector(sharedInstance)]) {
		PLKLog(@"no sharedInstance");
		return;
	}

	// The completion must be non-nil, otherwise NSXPCConnection throws and SpringBoard crashes
	@try {
		[[cls sharedInstance] setPowerMode:1 fromSource:KEEPLPM_SOURCE withCompletion:^(BOOL success, NSError *error) {
			PLKLog(@"completion success=%d error=%@", success, error);
		}];
	} @catch (NSException *e) {
		PLKLog(@"exception %@", e);
	}
}

%ctor {
	dlopen("/System/Library/PrivateFrameworks/LowPowerMode.framework/LowPowerMode", RTLD_LAZY);
	Class cls = NSClassFromString(@"_PMLowPowerMode");
	if (![cls instancesRespondToSelector:@selector(setPowerMode:fromSource:withCompletion:)]) {
		PLKLog(@"API not found, disabled (cls=%@)", cls);
		return;
	}

	int token;
	uint32_t status = notify_register_dispatch(AUTO_DISABLED_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) {
		reenableLPM();
	});
	(void)status;
	PLKLog(@"loaded in %@, register status=%u", NSBundle.mainBundle.bundleIdentifier, status);
}
