#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface WiFiCarrierController : PSListController <MFMailComposeViewControllerDelegate>
@end

@interface WiFiCarrierLogo : PSTableCell {
	UILabel *background;
	UILabel *tweakName;
	UILabel *version;
}
@end
