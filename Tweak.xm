#import "Tweak.h"

static BOOL hasFullyLoaded = NO;

// Original values from SBTelephonyManager
static NSString *originalName = @"";
static id subscriptionContext = nil;

// User settings
static BOOL enabled = false;
static BOOL enabledWiFi = false;
static BOOL enabledWFC = false;
static NSString *customCarrier = @"";
static NSString *srcWiFiCalling = @"";
static NSString *customWiFiCalling1 = @"";
static NSString *customWiFiCalling2 = @"";

%hook STTelephonyStateProvider
-(void)operatorNameChanged:(id)arg1 name:(id)arg2 {
subscriptionContext = arg1;
	originalName = arg2;

	if (!enabled || !hasFullyLoaded) {
		%orig;
		return;
	}
	

	SBWiFiManager *manager = [%c(SBWiFiManager) sharedInstance];
	NSString *networkName = [manager currentNetworkName];

	NSString* newNetwork = networkName;
	NSString* newCarrier = customCarrier;
        
	if (enabledWFC && [srcWiFiCalling length] > 0)
	{
		if ([originalName containsString:srcWiFiCalling])
		{
			newNetwork = [NSString stringWithFormat: @"%@ %@", networkName, customWiFiCalling1];
			newCarrier = [NSString stringWithFormat: @"%@ %@", newCarrier, customWiFiCalling2];
		}
	}

	if ([networkName length] > 0 && enabledWiFi) {
		%orig(arg1, newNetwork);
	} else if ([customCarrier length] > 0) {
		%orig(arg1, newCarrier);
	} else {
		%orig;
	}
}
%end

%hook SBTelephonyManager
-(void)operatorNameChanged:(id)arg1 name:(id)arg2 {
	subscriptionContext = arg1;
	originalName = arg2;

	if (!enabled || !hasFullyLoaded) {
		%orig;
		return;
	}

	SBWiFiManager *manager = [%c(SBWiFiManager) sharedInstance];
	NSString *networkName = [manager currentNetworkName];

	NSString* newNetwork = networkName;
	NSString* newCarrier = customCarrier;
    
	if (enabledWFC && [srcWiFiCalling length] > 0)
	{
		if ([originalName containsString:srcWiFiCalling])
		{
			newNetwork = [NSString stringWithFormat: @"%@ %@", networkName, customWiFiCalling1];
			newCarrier = [NSString stringWithFormat: @"%@ %@", newCarrier, customWiFiCalling2];
		}
	}

	if ([networkName length] > 0 && enabledWiFi) {
		%orig(arg1, newNetwork);
	} else if ([customCarrier length] > 0) {
		%orig(arg1, newCarrier);
	} else {
		%orig;
	}
}
%end

%hook SBWiFiManager
-(void)_updateCurrentNetwork {
	%orig;

	if (enabled) {
		forceUpdate();
	}
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
	%orig;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		hasFullyLoaded = YES;
		forceUpdate();
	});
}
%end

static void forceUpdate() {
	if (!hasFullyLoaded || subscriptionContext == nil) return;

	SBTelephonyManager *manager = [%c(SBTelephonyManager) sharedTelephonyManager];
	STTelephonyStateProvider *provider = [manager telephonyStateProvider];
	if (provider!=nil) {
		[provider operatorNameChanged:subscriptionContext name:originalName];
	} else {
		[manager operatorNameChanged:subscriptionContext name:originalName];
	}
}

// ===== PREFERENCE HANDLING ===== //

static void loadPrefs() {
  NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.highrez.wificarrier.plist"];

  if (prefs) {
    enabled = ( [prefs objectForKey:@"enabled"] ? [[prefs objectForKey:@"enabled"] boolValue] : YES );
	enabledWiFi = ( [prefs objectForKey:@"enableSSID"] ? [[prefs objectForKey:@"enableSSID"] boolValue] : YES );
	enabledWFC = ( [prefs objectForKey:@"detectWFC"] ? [[prefs objectForKey:@"detectWFC"] boolValue] : NO );
    customCarrier = ( [prefs objectForKey:@"customCarrier"] ? [[prefs objectForKey:@"customCarrier"] stringValue] : nil );
	srcWiFiCalling = ( [prefs objectForKey:@"srcWiFiCalling"] ? [[prefs objectForKey:@"srcWiFiCalling"] stringValue] : nil );
	customWiFiCalling1 = ( [prefs objectForKey:@"wifiCalling1"] ? [[prefs objectForKey:@"wifiCalling1"] stringValue] : nil );
	customWiFiCalling2 = ( [prefs objectForKey:@"wifiCalling2"] ? [[prefs objectForKey:@"wifiCalling2"] stringValue] : nil );
  }

}

static void refreshPrefs() {
  loadPrefs();
  forceUpdate();
}

static void initPrefs() {
  // Copy the default preferences file when the actual preference file doesn't exist
  NSString *path = @"/User/Library/Preferences/com.highrez.wificarrier.plist";
  NSString *pathDefault = @"/Library/PreferenceBundles/WiFiCarrier.bundle/defaults.plist";
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:path]) {
    [fileManager copyItemAtPath:pathDefault toPath:path error:nil];
  }
}

%ctor {
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshPrefs, CFSTR("com.highrez.wificarrier/prefsupdated"), NULL, CFNotificationSuspensionBehaviorCoalesce);
  initPrefs();
  loadPrefs();
}
