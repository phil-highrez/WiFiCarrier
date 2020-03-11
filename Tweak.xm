#import "Tweak.h"
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <ifaddrs.h>
#include <arpa/inet.h>

typedef struct __WiFiNetwork *WiFiNetworkRef;
extern BOOL WiFiNetworkIsWPA(WiFiNetworkRef network);
extern BOOL WiFiNetworkIsEAP(WiFiNetworkRef network);

static NSString *strDebugFile = @"/tmp/WiFiCarrier.log";
static NSDateFormatter *dateFormatter = nil;

static BOOL hasFullyLoaded = NO;
static BOOL bLastVPN = NO;
static BOOL bIsGettingIP = NO;

// Original values from SBTelephonyManager
static NSString *originalName = @"";
static NSString *publicIP = @"";
static id subscriptionContext = nil;

//Reachability
//static SCNetworkReachabilityRef reachability;

// User settings
static BOOL enabled = false;
static BOOL enableDebug = false;
static BOOL enableCustomCarrier = false;
static BOOL enableSSID = false;
static BOOL enableIPADDR = false;
static BOOL enableExtIP = false;
static BOOL enableWFC = false;
static NSString *customCarrier = @"";
static NSString *srcWiFiCalling = @"";
static NSString *customWiFiCalling1 = @"";
static NSString *customWiFiCalling2 = @"";

%hook STTelephonyStateProvider
//The following is for IOS 13 support.
-(void)operatorNameChanged:(id)arg1 name:(id)arg2 {
	subscriptionContext = arg1;
	originalName = arg2;
	if (!enabled || !hasFullyLoaded) {
		%orig;
		return;
	}
	%orig(arg1, GetCarrierText(arg2));
}

-(void)currentDataSimChanged:(id)arg1 {
	%orig;
	if (enabled) {
		Debug([NSString stringWithFormat:@"currentDataSimChanged: '%@'", arg1]);
		publicIP = @"";
		forceUpdate();
	}
}
-(void)simStatusDidChange:(id)arg1 status:(id)arg2 {
	%orig;
	if (enabled) {
		Debug([NSString stringWithFormat:@"simStatusDidChange: '%@' - '%@'", arg1, arg2]);
		publicIP = @"";
		forceUpdate();
	}
}
//-(void)displayStatusChanged:(id)arg1 status:(id)arg2 {
//	%orig;
//	if (enabled) {
//		publicIP = @"";
//		forceUpdate();
//	}
//}
%end

%hook SBTelephonyManager
//The following is for IOS 12 (and 11?) support.
-(void)operatorNameChanged:(id)arg1 name:(id)arg2 {
	subscriptionContext = arg1;
	originalName = arg2;

	if (!enabled || !hasFullyLoaded) {
		%orig;
		return;
	}
	%orig(arg1, GetCarrierText(arg2));
}
-(BOOL)isUsingVPNConnection {
	BOOL bRes=%orig;
	if (enabled && bLastVPN!=bRes) {
		Debug([NSString stringWithFormat:@"isUsingVPNConnection: %@", bRes ? @"YES" : @"NO"]);
		bLastVPN = bRes;
		publicIP=@"";
		forceUpdate();
	}
	return bRes;
}
%end

%hook SBWiFiManager
-(void)_updateCurrentNetwork {
	%orig;
	if (enabled) {
		Debug(@"_updateCurrentNetwork:");
		publicIP=@"";
		forceUpdate();
	}
}
%end

%hook NEVPNConnection
//I'm not sure this ever gets called - in theory I want it to be called when VPN connects/disconnects
-(void)setSession:(void*)arg1 {
	%orig;
	if (enabled) {
		Debug(@"_updateCurrentNetwork:");
		publicIP = @"";
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

//--------------------------------------------------//
// ===== Static functions local to this tweak ===== //

static inline NSString *GetCarrierText(id original) {
	NSString* newNetwork = @"";
	NSString* newCarrier = customCarrier;

	BOOL setNetwork = NO;
	NSString* networkName = GetNetworkNameOrIP(); 
	if (!IsEmpty(networkName)) {
		setNetwork = enableSSID || enableIPADDR;
		newNetwork = networkName;
	}

	//Check for WiFi Calling and if found, append our custom WFC text
	if (enableWFC && [srcWiFiCalling length] > 0)
	{
		if ([originalName containsString:srcWiFiCalling])
		{
			if ([newNetwork length] > 0)
				newNetwork = [NSString stringWithFormat: @"%@ %@", networkName, customWiFiCalling1];
			else
				newNetwork = customWiFiCalling1;
			
			if ([newCarrier length] > 0)
				newCarrier = [NSString stringWithFormat: @"%@ %@", newCarrier, customWiFiCalling2];
			else
				newCarrier = customWiFiCalling2;
		}
	}
	
	if ([newNetwork length] == 0)
		newNetwork=[NSString stringWithFormat:@"%C", 0x200D];
	if ([newCarrier length] == 0)
		newCarrier=[NSString stringWithFormat:@"%C", 0x200D];
	
	//Generate the new carrier text and return it....
	if (setNetwork) {
		Debug([NSString stringWithFormat: @"OperatorNameChange : Was: '%@' becomes Network: '%@'", originalName, newNetwork]);
		return newNetwork;
	} else if (enableCustomCarrier) {
		Debug([NSString stringWithFormat: @"OperatorNameChange : Was: '%@' becomes Carrier: '%@'", originalName, newCarrier]);
		return newCarrier;
	}
	return original;
}

static inline void forceUpdate() {
	if (!hasFullyLoaded || subscriptionContext == nil) return;

	SBTelephonyManager *manager = [%c(SBTelephonyManager) sharedTelephonyManager];
	if (manager != nil)
	{
		if ([manager respondsToSelector:@selector(telephonyStateProvider)])
		{
			//Must be IOS13
			STTelephonyStateProvider *provider = [manager telephonyStateProvider];
			if (provider!=nil) {
				[provider operatorNameChanged:subscriptionContext name:originalName];
			} 
		} else {
			//Must be before IOS13
			[manager operatorNameChanged:subscriptionContext name:originalName];
		}
	}
	else Debug(@"Unable to grab shared open telephony manager");
	
}

//static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
//{
//	forceUpdate();
//}

static inline NSString *GetNetworkNameOrIP()
{
	SBWiFiManager *manager = [%c(SBWiFiManager) sharedInstance];
	bool bAvailable = NO;

	if (enableIPADDR) {
		if (enableExtIP) {
			if (!bIsGettingIP) {
				bIsGettingIP = YES;
				//Get the public IP - only if the server is reachable....
				SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [@"icanhazip.com" UTF8String]);
				if (reachability) {
					SCNetworkReachabilityFlags flags;
					bool success = SCNetworkReachabilityGetFlags(reachability, &flags);
					bAvailable = (success && (flags & kSCNetworkFlagsReachable));
					if (bAvailable && IsEmpty(publicIP)) {
						GetPublicIP();
					}
					else bIsGettingIP = NO;
					CFRelease(reachability);
				}
				else bIsGettingIP = NO;
			}
		} else
		{
			publicIP = @"";
		}
		NSString* ip = GetIPAddress();
		if (enableExtIP) {
			if (IsEmpty(publicIP))
			{
				if (!IsEmpty(ip)) //We have a local IP but no public IP... Append ?! to front (ie. looking)
					return  [NSString stringWithFormat: @"🔍 %@", GetIPAddress()];
			}
			else
				return publicIP;
		}
		return ip;
	}
	else
	{
		//Clear the cached public IP
		publicIP = @"";
	}

	//Return the SSID
	NSString *networkName = [manager currentNetworkName];
	return networkName;
}

static inline NSString *GetIPAddress()
{
	NSString *result = nil;
	struct ifaddrs *interfaces;
	char str[INET_ADDRSTRLEN];
	if (getifaddrs(&interfaces))
		return nil;
	struct ifaddrs *test_addr = interfaces;
	while (test_addr) {
		if(test_addr->ifa_addr->sa_family == AF_INET) {
			if (strcmp(test_addr->ifa_name, "en0") == 0) {
				inet_ntop(AF_INET, &((struct sockaddr_in *)test_addr->ifa_addr)->sin_addr, str, INET_ADDRSTRLEN);
				result = [NSString stringWithUTF8String:str];
				break;
			}
		}
		test_addr = test_addr->ifa_next;
	}
	freeifaddrs(interfaces);
	return result;
}

static inline void GetPublicIP()
{
	NSURLSession *session = [NSURLSession sharedSession];
	[[session dataTaskWithURL:[NSURL URLWithString:@"https://icanhazip.com/"]
          completionHandler:^(NSData *data,
                              NSURLResponse *response,
                              NSError *error) {
            
			if (error==nil) {
				NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				if (!IsEmpty(result))
					result = [result stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]; // IP comes with a newline for some reason
				publicIP = result;
				forceUpdate();
				bIsGettingIP = NO;
			}
			else {
				publicIP = @"";
				bIsGettingIP = NO;
			}
	  }] resume];
}

static inline BOOL IsEmpty(id thing) {
	return thing == nil
	|| ([thing respondsToSelector:@selector(length)]
	&& [(NSData *)thing length] == 0)
	|| ([thing respondsToSelector:@selector(count)]
	&& [(NSArray *)thing count] == 0);
}

// ===== PREFERENCE HANDLING ===== //

static void loadPrefs() {
  Debug(@"Load preferences");
  NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.highrez.wificarrier.plist"];

  if (prefs) {
    enabled = ( [prefs objectForKey:@"enabled"] ? [[prefs objectForKey:@"enabled"] boolValue] : YES );
	enableDebug = ( [prefs objectForKey:@"enableDebug"] ? [[prefs objectForKey:@"enableDebug"] boolValue] : NO );
	if (!enableDebug) {
		//delete the debug file in the tmp folder (if it exists)
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if ([fileManager isDeletableFileAtPath: strDebugFile])
		{
			[fileManager removeItemAtPath:strDebugFile error:nil];
		}
	}
	
	enableSSID = ( [prefs objectForKey:@"enableSSID"] ? [[prefs objectForKey:@"enableSSID"] boolValue] : YES );
	enableIPADDR = ( [prefs objectForKey:@"enableIPADDR"] ? [[prefs objectForKey:@"enableIPADDR"] boolValue] : NO );
	enableExtIP = ( [prefs objectForKey:@"enableExtIP"] ? [[prefs objectForKey:@"enableExtIP"] boolValue] : YES );
	enableCustomCarrier = ( [prefs objectForKey:@"enableCustomCarrier"] ? [[prefs objectForKey:@"enableCustomCarrier"] boolValue] : NO );
    customCarrier = ( [prefs objectForKey:@"customCarrier"] ? [[prefs objectForKey:@"customCarrier"] stringValue] : nil );

	enableWFC = ( [prefs objectForKey:@"detectWFC"] ? [[prefs objectForKey:@"detectWFC"] boolValue] : NO );
	srcWiFiCalling = ( [prefs objectForKey:@"srcWiFiCalling"] ? [[prefs objectForKey:@"srcWiFiCalling"] stringValue] : nil );
	customWiFiCalling1 = ( [prefs objectForKey:@"wifiCalling1"] ? [[prefs objectForKey:@"wifiCalling1"] stringValue] : nil );
	customWiFiCalling2 = ( [prefs objectForKey:@"wifiCalling2"] ? [[prefs objectForKey:@"wifiCalling2"] stringValue] : nil );

	Debug([NSString stringWithFormat: @"enabled: %@", enabled ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"enableDebug: %@", enableDebug ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"enableSSID: %@", enableSSID ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"enableIPADDR: %@", enableIPADDR ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"enableExtIP: %@", enableExtIP ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"enableCustomCarrier: %@", enableCustomCarrier ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"CustomCarrierText: %@", customCarrier]);
	Debug([NSString stringWithFormat: @"enableWFC: %@", enableWFC ? @"YES" : @"NO"]);
	Debug([NSString stringWithFormat: @"srcWiFiCalling: %@", srcWiFiCalling]);
	Debug([NSString stringWithFormat: @"customWiFiCalling1: %@", customWiFiCalling1]);
	Debug([NSString stringWithFormat: @"customWiFiCalling2: %@", customWiFiCalling2]);
  }
  else {
	Debug(@"Unable to load preferences!");
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

static inline void Debug(id thing) {
	if (enableDebug && dateFormatter!=nil) {
		NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
		NSString *content = [NSString stringWithFormat:@"%@: %@\n",dateString, thing];
		
		NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:strDebugFile];
		if (fileHandle){
			[fileHandle seekToEndOfFile];
			[fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle closeFile];
		}
		else{
			[content writeToFile:strDebugFile
					  atomically:NO
						encoding:NSStringEncodingConversionAllowLossy
						   error:nil];
		}
	}
}

%ctor {
  dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  initPrefs();
  loadPrefs();
  
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshPrefs, CFSTR("com.highrez.wificarrier/prefsupdated"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}
