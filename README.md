# WiFiCarrier
Tweak to display the WiFi SSID or IP address as carrier. 
It also allows you to customize the carrier (network operator) text in the iOS status bar and to detect when WiFi Calling is enabled allowing you append custom text to the SSID / Custom Carrier

This is updated to work on iOS 13 as the orriginal did not. 
It should (from version 1.0.3) work on iOS 12 and perhaps older (it is currently untested on anything older than 12.4).

__Based on NoisyFlake's orriginal version with added functionality.__

# 
### Settings Explained (version 1.0.3)

#### Enable
Enable the tweak generally - simply an on/off switch!

#### Status Bar Gesture
Turns on a gesture on the home screen status bar to cycle through enabled states by long pressing the status bar.
So if you have SSID, IP Address and Custom Carrier enabled, a long press will cycle through each display state (including the orriginal carrier text).
NOTE: On IOS 13 this gesture will work in apps with a status bar too (not on IOS 12).

#### Use WiFi SSID
Replace the carrier text with the WiFi Network Name (orriginal purpose of this tweak) when connected to WiFi.

#### Use IP Address
Replace the carrier text with your (internal) IP address on the WiFi network.

#### Public IP
Replace the carrier text with your public (exteral) IP address (WiFi/Cellular/VPN). 

**NOTE: A tiny data request is made to https://icanhazip.com/ to get this.**


### Custom Carrier
#### Enable
Enable custom carrier text (replace the carrier text with the specified Custom Carrier Text).

#### Custom Carrier Text
The text to replace the carrier text with. NOTE: This can be empty to clear the carrier text.


### WiFi Calling
WiFi Calling is available on some operators. It is an Apple feature that allows calls to be routed over WiFi when there is no cellular signal. Very handy for me as I get no signal at work!

#### Detect WiFi calling
Enable the detection of WiFi Calling. WiFi calling is simply detected by looking at the carrier text for certain content (Carrier WFC) and if that is there, WiFi calling is considered ON.

#### Carrier WFC:
The text to look for in the original carrier text. For example, my network, 3 (UK) normally show the carrier text "3" when on cellular. When on WiFi (and if WiFi calling is enabled in the Phone app), the carrier text changes to "Three WiFi Call" so you know that WiFi calling is on and working. Then calls and SMS work even with no service.

#### Add to SSID:
Text to append to the SSID (or IP address) when WiFi calling is enabled and the carrier text has been changed to the WiFi network name or IP adddress.

#### Add to Carrier:
Text to append to the SSID (or IP address) when WiFi calling is enabled and the SSID/IP Address options are disabled (thus just showing the custom carrier text). NOTE: You obviously still have to be on WiFi for WiFi calling to be on in the first place!


### Debugging
#### Enable
Write to a debug log file in the /tmp folder - this is really only useful during testing - it may be removed for release!

#### Send by Email
Send the debug log file by email to the developer (you can preview the content and redirect to someone else (like yourself) if you want to!

**NOTE: The debug log file is deleted if you disable debugging AND ALSO when an email is successfully sent.**
