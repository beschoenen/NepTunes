//
//  UserNotificationsController.m
//  NepTunes
//
//  Created by rurza on 01/02/16.
//  Copyright © 2016 micropixels. All rights reserved.
//

#import "UserNotificationsController.h"
#import "SettingsController.h"
#import "LastFm.h"
#import "AppDelegate.h"
#import "MenuController.h"
#import "MusicScrobbler.h"
#import "OfflineScrobbler.h"
#import "Track.h"

@interface UserNotificationsController () <NSUserNotificationCenterDelegate>
@property (nonatomic) BOOL doISentANotificationThatLastFmIsDown;
@property (nonatomic) BOOL doISentANotificationThatUserWasLoggedOut;
@end
@implementation UserNotificationsController

+(UserNotificationsController *)sharedNotificationsController
{
    static UserNotificationsController *notificationsController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notificationsController = [[UserNotificationsController alloc] init];
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = notificationsController;
    });
    return notificationsController;
}

#pragma mark - That can be hidden
-(void)displayNotificationThatInternetConnectionIsDown
{
    if (self.displayNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = NSLocalizedString(@"Yikes!", nil);
        notification.subtitle = NSLocalizedString(@"Looks like there is no connection to the Internet.", nil);
        notification.informativeText = NSLocalizedString(@"Don't worry, I'm going to scrobble anyway.", nil);
        [notification setDeliveryDate:[NSDate dateWithTimeInterval:0 sinceDate:[NSDate date]]];
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    }
}

-(void)displayNotificationThatInternetConnectionIsBack
{
    if (self.displayNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = NSLocalizedString(@"Yay! 😁", nil);
        notification.subtitle = NSLocalizedString(@"Your Mac is online now.", nil);
        notification.informativeText = NSLocalizedString(@"Now I'm going to scrobble tracks played offline.", nil);
        [notification setDeliveryDate:[NSDate dateWithTimeInterval:0 sinceDate:[NSDate date]]];
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    }
}

-(void)displayNotificationThatAllTracksAreScrobbled
{
    if (self.displayNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = NSLocalizedString(@"Woohoo!", nil);
        notification.subtitle = NSLocalizedString(@"All tracks listened earlier are scrobbled!", nil);
        [notification setDeliveryDate:[NSDate dateWithTimeInterval:5 sinceDate:[NSDate date]]];
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    }
}

-(void)displayNotificationThatTrackWasLoved:(Track *)track withArtwork:(NSImage *)artwork;
{
    if (self.displayNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        [notification setTitle:[NSString stringWithFormat:@"%@", track.artist]];
        [notification setInformativeText:[NSString stringWithFormat:@"%@ ❤️ at Last.fm", track.trackName]];
        [notification setDeliveryDate:[NSDate dateWithTimeInterval:0 sinceDate:[NSDate date]]];
        if (artwork) {
            notification.contentImage = artwork;
        }
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    }
}

#pragma mark - That we always want to display
-(void)displayNotificationThatLoveSongFailedWithError:(NSError *)error
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = NSLocalizedString(@"Houston, we got a problem!", nil);
    if (error.code == kLastFmErrorCodeInvalidSession || error.code == kLastFmErrorCodeInvalidParameters) {
        self.doISentANotificationThatUserWasLoggedOut = YES;
        notification.informativeText = NSLocalizedString(@"There are some issues with your Last.fm session. Open preferences and log in again.", nil);
        notification.soundName = NSUserNotificationDefaultSoundName;
        notification.hasActionButton = YES;
        notification.actionButtonTitle = NSLocalizedString(@"Open", nil);
        [notification setValue:@YES forKey:@"_showsButtons"];
        notification.userInfo = @{@"logout":@YES};
        [self forceLogOutUser];
    } else {
        notification.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%@", @"displayNotificationThatLoveSongFailedWithError"), error.localizedDescription];
    }
    
    [notification setDeliveryDate:[NSDate dateWithTimeInterval:1 sinceDate:[NSDate date]]];
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
}

-(void)displayNotificationThatTrackCanNotBeScrobbledWithError:(NSError *)error
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = NSLocalizedString(@"Houston, we got a problem!", nil);
    if ((error.code == kLastFmErrorCodeInvalidSession || error.code == kLastFmErrorCodeInvalidParameters) && !self.doISentANotificationThatUserWasLoggedOut) {
        self.doISentANotificationThatUserWasLoggedOut = YES;
        notification.informativeText = NSLocalizedString(@"There are some issues with your Last.fm session. Open preferences and log in again.", nil);
        notification.soundName = NSUserNotificationDefaultSoundName;
        notification.hasActionButton = YES;
        notification.actionButtonTitle = NSLocalizedString(@"Open", nil);
        [notification setValue:@YES forKey:@"_showsButtons"];
        notification.userInfo = @{@"logout":@YES};
        [self forceLogOutUser];
        
    } else if (error.code == kLastFmErrorCodeServiceOffline && !self.doISentANotificationThatLastFmIsDown) {
        if (!self.displayNotifications) {
            return;
        }
        self.doISentANotificationThatLastFmIsDown = YES;
        notification.informativeText = NSLocalizedString(@"It looks like Last.fm is offline. Don't worry, I'm going to scrobble all tracks later.", nil);
    } else {
        if (!self.displayNotifications || self.doISentANotificationThatUserWasLoggedOut || self.doISentANotificationThatLastFmIsDown) {
            return;
        }
        notification.informativeText = error.localizedDescription;
    }
    
    [notification setDeliveryDate:[NSDate dateWithTimeInterval:0 sinceDate:[NSDate date]]];
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
}

-(void)forceLogOutUser
{
    [(AppDelegate *)[NSApplication sharedApplication].delegate forceLogOut];
    [OfflineScrobbler sharedInstance].userWasLoggedOut = YES;
    [SettingsController sharedSettings].openPreferencesWhenThereIsNoUser = YES;
#if DEBUG
    NSLog(@"User %@ was logged out", [SettingsController sharedSettings].username);
#endif

}

#pragma mark - Getters
-(BOOL)displayNotifications
{
    return ![SettingsController sharedSettings].hideNotifications;
}

#pragma mark - User Notifications
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

-(void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    if ([[notification.userInfo objectForKey:@"logout"] boolValue]) {
        [((AppDelegate *)[NSApplication sharedApplication].delegate).menuController openPreferences:nil];
    }
}

-(void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
}

@end