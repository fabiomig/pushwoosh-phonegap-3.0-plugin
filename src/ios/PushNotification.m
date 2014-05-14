//
//  PushNotification.m
//
// Based on the Push Notifications Cordova Plugin by Olivier Louvignes on 06/05/12.
// Modified by Max Konev on 18/05/12.
//
// Pushwoosh Push Notifications Plugin for Cordova iOS
// www.pushwoosh.com
// (c) Pushwoosh 2012
//
// MIT Licensed

#import "PushNotification.h"
#import <CoreLocation/CoreLocation.h>
#import "AppDelegate.h"

@implementation PushNotification

@synthesize callbackIds = _callbackIds;
@synthesize pushManager, startPushData;

- (NSMutableDictionary*)callbackIds {
	if(_callbackIds == nil) {
		_callbackIds = [[NSMutableDictionary alloc] init];
	}
	return _callbackIds;
}

- (PushNotificationManager*)pushManager {
	if(pushManager == nil) {
		pushManager = [PushNotificationManager pushManager];
		pushManager.delegate = self;
		pushManager.showPushnotificationAlert = FALSE;
	}
	return pushManager;
}

- (void)getPushToken:(CDVInvokedUrlCommand*)command {
	NSString * token = [[PushNotificationManager pushManager] getPushToken];
	CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getPushwooshHWID:(CDVInvokedUrlCommand*)command {
	NSString * token = [[PushNotificationManager pushManager] getHWID];
	CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onDeviceReady:(CDVInvokedUrlCommand*)command {
	deviceReady = YES;

	NSDictionary *options = [command.arguments objectAtIndex:0];

	NSString *appid = [options objectForKey:@"pw_appid"];
	NSString *appname = [options objectForKey:@"appname"];
	
	if(!appid) {
		NSLog(@"PushNotification.registerDevice: Missing Pushwoosh App ID");
		return;
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:appid forKey:@"Pushwoosh_APPID"];
	if(appname) {
		[[NSUserDefaults standardUserDefaults] setObject:appname forKey:@"Pushwoosh_APPNAME"];
	}
	
	//we need to re-set APPID if it has been changed (on start we have initialized Push Manager with app id from NSUserDefaults)
	self.pushManager.appCode = appid;
	
	//and name if it has been provided
	if(appname)
	{
		self.pushManager.appName = appname;
	}

	AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	PushNotification *pushHandler = [delegate.viewController getCommandInstance:@"PushNotification"];
	if(pushHandler.startPushData) {
		NSString *jsStatement = [NSString stringWithFormat:@"window.plugins.pushNotification.notificationCallback(%@);", pushHandler.startPushData];
		[pushHandler writeJavascript:[NSString stringWithFormat:@"setTimeout(function() { %@; }, 0);", jsStatement]];
		pushHandler.startPushData = nil;
	}
}

- (void)registerDevice:(CDVInvokedUrlCommand*)command {
	[self.callbackIds setValue:command.callbackId forKey:@"registerDevice"];
	[[PushNotificationManager pushManager] registerForPushNotifications];

}

- (void)unregisterDevice:(CDVInvokedUrlCommand*)command {
	[[PushNotificationManager pushManager] unregisterForPushNotifications];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
}

- (void)setTags:(CDVInvokedUrlCommand*)command {
	[[PushNotificationManager pushManager] setTags:[command.arguments objectAtIndex:0]];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];

}

- (void)getTags:(CDVInvokedUrlCommand*)command {
	// The first argument in the arguments parameter is the callbackID.
	[self.callbackIds setValue:command.callbackId forKey:@"getTags"];
	
	[[PushNotificationManager pushManager] loadTags:
		^(NSDictionary *tags) {
			 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:tags];
			 [self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"getTags"]]];
		}
		error:^(NSError *error) {
			 NSMutableDictionary *results = [NSMutableDictionary dictionary];
			 [results setValue:[NSString stringWithFormat:@"%@", error] forKey:@"error"];

			 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
			 [self writeJavascript:[pluginResult toErrorCallbackString:[self.callbackIds valueForKey:@"getTags"]]];
		 }
	 ];
}

- (void)sendLocation:(CDVInvokedUrlCommand*)command {
	
	NSNumber * lat = [[command.arguments objectAtIndex:0] objectForKey:@"lat"];
	NSNumber * lon = [[command.arguments objectAtIndex:0] objectForKey:@"lon"];
	CLLocation * location = [[CLLocation alloc] initWithLatitude:[lat doubleValue] longitude:[lon doubleValue]];
	[[PushNotificationManager pushManager] sendLocation:location];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
	
}

- (void)startLocationTracking:(CDVInvokedUrlCommand*)command {
	
	[[PushNotificationManager pushManager] startLocationTracking];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
	
}

- (void)stopLocationTracking:(CDVInvokedUrlCommand*)command {
	[[PushNotificationManager pushManager] stopLocationTracking];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:nil];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
	
}

- (void)onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token {

    NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];
    [results setValue:token forKey:@"deviceToken"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:[self.callbackIds valueForKey:@"registerDevice"]]];
}

- (void)onDidFailToRegisterForRemoteNotificationsWithError:(NSError*)error {

	NSMutableDictionary *results = [NSMutableDictionary dictionary];
	[results setValue:[NSString stringWithFormat:@"%@", error] forKey:@"error"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:results];
	[self writeJavascript:[pluginResult toErrorCallbackString:[self.callbackIds valueForKey:@"registerDevice"]]];
}


- (void) onPushAccepted:(PushNotificationManager *)manager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart{
	//reset badge counter
	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
	
	NSMutableDictionary *pn = [NSMutableDictionary dictionaryWithDictionary:pushNotification];

	//pase JSON string in custom data to JSON Object
	NSString* u = [pushNotification objectForKey:@"u"];
    
	if (u) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[u dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:NSJSONReadingMutableContainers
                                                               error:nil];
		
		if (dict) {
			[pn setObject:dict forKey:@"u"];
		}
	}
	
	[pn setValue:[NSNumber numberWithBool:onStart] forKey:@"onStart"];
	
    NSData *json = [NSJSONSerialization dataWithJSONObject:pn options:NSJSONWritingPrettyPrinted error:nil];
	NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    
	if(!deviceReady){
		//the webview is not loaded yet, keep it for the callback
		AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		PushNotification *pushHandler = [delegate.viewController getCommandInstance:@"PushNotification"];

		pushHandler.startPushData = jsonString;
	}
	else {
		//send it to the webview
		NSString *jsStatement = [NSString stringWithFormat:@"window.plugins.pushNotification.notificationCallback(%@);", jsonString];
		[self writeJavascript:[NSString stringWithFormat:@"setTimeout(function() { %@; }, 0);", jsStatement]];
	}
}

+ (NSMutableDictionary*)getRemoteNotificationStatus {

    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    NSUInteger type = 0;
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = @"0";
    NSString *pushAlert = @"0";
    NSString *pushSound = @"0";

#if !TARGET_IPHONE_SIMULATOR

    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];

    // Check what Registered Types are turned on. This is a bit tricky since if two are enabled, and one is off, it will return a number 2... not telling you which
    // one is actually disabled. So we are literally checking to see if rnTypes matches what is turned on, instead of by number. The "tricky" part is that the
    // single notification types will only match if they are the ONLY one enabled.  Likewise, when we are checking for a pair of notifications, it will only be
    // true if those two notifications are on.  This is why the code is written this way
    if(type == UIRemoteNotificationTypeBadge){
        pushBadge = @"1";
    }
    else if(type == UIRemoteNotificationTypeAlert) {
        pushAlert = @"1";
    }
    else if(type == UIRemoteNotificationTypeSound) {
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
        pushBadge = @"1";
        pushAlert = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushAlert = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushAlert = @"1";
        pushSound = @"1";
    }

#endif

    // Affect results
    [results setValue:[NSString stringWithFormat:@"%d", type] forKey:@"type"];
	[results setValue:[NSString stringWithFormat:@"%d", type != UIRemoteNotificationTypeNone] forKey:@"enabled"];
    [results setValue:pushBadge forKey:@"pushBadge"];
    [results setValue:pushAlert forKey:@"pushAlert"];
    [results setValue:pushSound forKey:@"pushSound"];

    return results;

}

- (void)getRemoteNotificationStatus:(CDVInvokedUrlCommand*)command {

	NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
}

- (void)setApplicationIconBadgeNumber:(CDVInvokedUrlCommand*)command {

    int badge = [[[command.arguments objectAtIndex:0] objectForKey:@"badge"] intValue] ?: 0;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
	[results setValue:[NSNumber numberWithInt:badge] forKey:@"badge"];
    [results setValue:[NSNumber numberWithInt:1] forKey:@"success"];

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
}

- (void)cancelAllLocalNotifications:(CDVInvokedUrlCommand*)command {

	[[UIApplication sharedApplication] cancelAllLocalNotifications];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	[self writeJavascript:[pluginResult toSuccessCallbackString:command.callbackId]];
}

- (void) dealloc {
	self.pushManager = nil;
	self.startPushData = nil;
}

@end

@implementation UIApplication(InternalPushRuntime)
- (BOOL) pushwooshUseRuntimeMagic {
	return YES;
}

- (NSObject<PushNotificationDelegate> *)getPushwooshDelegate {
	AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	PushNotification *pushHandler = [delegate.viewController getCommandInstance:@"PushNotification"];
	return pushHandler;
}
@end
