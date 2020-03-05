@interface SBWiFiManager : NSObject
+(id)sharedInstance;
-(id)currentNetworkName;
@end

@interface STTelephonyStateProvider : NSObject
-(void)operatorNameChanged:(id)arg1 name:(id)arg2;
@end

@interface SBTelephonyManager : NSObject
+(id)sharedTelephonyManager;
-(STTelephonyStateProvider *)telephonyStateProvider;
-(void)operatorNameChanged:(id)arg1 name:(id)arg2;
@end

static void forceUpdate();
