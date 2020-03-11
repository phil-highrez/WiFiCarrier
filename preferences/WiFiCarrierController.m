#include "../Version.h"
#include "WiFiCarrierController.h"

@implementation WiFiCarrierController
MFMailComposeViewController *mMFComposer;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIBarButtonItem *applyButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStylePlain target:self action:@selector(save)];
    self.navigationItem.rightBarButtonItem = applyButton;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
	}

	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
	return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
	NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
	[settings setObject:value forKey:specifier.properties[@"key"]];
	[settings writeToFile:path atomically:YES];
	CFStringRef notificationName = (CFStringRef)specifier.properties[@"PostNotification"];
	if (notificationName) {
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
	}
}

-(void)paypal {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://paypal.me/PhilHighrez"] options:@{} completionHandler:nil];
}

-(void)emailDebug {
	NSString *messageBody = [NSString stringWithContentsOfFile:@"/tmp/WiFiCarrier.log" encoding:NSUTF8StringEncoding error:nil];
	if (messageBody!=nil && [messageBody length] > 0) {
		NSArray *toRecipents = [NSArray arrayWithObject:@"WiFiCarrier@highrez.co.uk"];
		mMFComposer = [[MFMailComposeViewController alloc] init];
		mMFComposer.mailComposeDelegate = self;
		[mMFComposer setSubject:@"WiFiCarrier Debug"];
		[mMFComposer setMessageBody:messageBody isHTML:NO];
		[mMFComposer setToRecipients:toRecipents];
		[self presentViewController:mMFComposer animated:YES completion:NULL];
	} else {
		UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"WiFiCarrier+"
                           message:@"The debug log is empty."
                           preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
							handler:^(UIAlertAction * action) {}];

		[alert addAction:defaultAction];
		[self presentViewController:alert animated:YES completion:nil];
	}		
}

- (void)mailComposeController:(MFMailComposeViewController *)controller 
          didFinishWithResult:(MFMailComposeResult)result 
                        error:(NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

-(void)save {
	[self.view endEditing:YES];
}

@end

@implementation WiFiCarrierLogo

- (id)initWithSpecifier:(PSSpecifier *)specifier
{
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Banner" specifier:specifier];
	if (self) {
		CGFloat width = 320;
		CGFloat height = 70;

		CGRect backgroundFrame = CGRectMake(-50, -35, width+50, height);
		background = [[UILabel alloc] initWithFrame:backgroundFrame];
		[background layoutIfNeeded];
		background.backgroundColor = [UIColor colorWithRed:0.31 green:0.57 blue:0.80 alpha:1.0];
		background.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

		CGRect tweakNameFrame = CGRectMake(0, -40, width, height);
		tweakName = [[UILabel alloc] initWithFrame:tweakNameFrame];
		[tweakName layoutIfNeeded];
		tweakName.numberOfLines = 1;
		tweakName.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		tweakName.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:40.0f];
		tweakName.textColor = [UIColor whiteColor];
		tweakName.text = @"WiFiCarrier+";
		tweakName.textAlignment = NSTextAlignmentCenter;

		CGRect versionFrame = CGRectMake(0, -5, width, height);
		version = [[UILabel alloc] initWithFrame:versionFrame];
		version.numberOfLines = 1;
		version.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		version.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:15.0f];
		version.textColor = [UIColor whiteColor];
		version.text = [NSString stringWithFormat:@"Version %@", _WFCVERSION_];
		version.backgroundColor = [UIColor clearColor];
		version.textAlignment = NSTextAlignmentCenter;

		[self addSubview:background];
		[self addSubview:tweakName];
		[self addSubview:version];
	}
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
	return 100.0f;
}
@end
