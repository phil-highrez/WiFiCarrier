//
//This file is for iOS 13+ Only
//

#include "Tweak.h"
#include "Version.h"

%group iOS13

	// For IOS13 status bar IN APP... Runs in SpringBoard; forwards status bar events to app
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
		if (enableGesture && recognizer.state == UIGestureRecognizerStateBegan) {
			ChangeState();
		}
	}
	%end // SBMainDisplaySceneLayoutStatusBarView

%end // iOS13StatusBar

%ctor {
	if (@available(iOS 13, *)) {
		%init(iOS13);
	}
}
