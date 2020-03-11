//
//This file is for iOS 13+ Only
//

#include "Tweak.h"
#include "Version.h"

%group iOS13

	// Runs in SpringBoard; forwards status bar events to app
	%hook SBMainDisplaySceneLayoutStatusBarView
	- (void)_addStatusBarIfNeeded {
		%orig;
		UIView *statusBar = [self valueForKey:@"_statusBar"];
		[statusBar addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
			initWithTarget:self action:@selector(wfcGestureHandler:)
		]];
	}

	%new
	- (void)wfcGestureHandler:(UILongPressGestureRecognizer  *)recognizer {
		if (recognizer.state == UIGestureRecognizerStateBegan) {
			ChangeState();
		}
	}
	%end // SBMainDisplaySceneLayoutStatusBarView

	// Runs in apps; receives status bar events
	%hook UIStatusBarManager
	- (void)handleTapAction:(UIStatusBarTapAction *)action {
		Debug(@"UIStatusBarManager handleTapAction");
		if (action.type == kWFCTapGesture) {
			ChangeState();
		} else {
			%orig(action);
		}
	}
	%end // UIStatusBarManager
%end // iOS13StatusBar

%ctor {
	if (@available(iOS 13, *)) {
		%init(iOS13);
	}
}
