//
//  ControlViewController.m
//  NepTunes
//
//  Created by rurza on 15/02/16.
//  Copyright © 2016 micropixels. All rights reserved.
//

#import "ControlViewController.h"
#import "MusicController.h"
#import "SettingsController.h"
#import "MusicScrobbler.h"
#import "Track.h"
#import "CoverSettingsController.h"
#import "MenuController.h"
#import "MusicPlayer.h"

@import LastFm;

static NSUInteger const kFPS = 30;
static NSUInteger const kNumberOfFrames = 10;

@interface ControlViewController () <NSPopoverDelegate>
@property (nonatomic) NSImage *playImage;
@property (nonatomic) NSImage *pauseImage;
@property (nonatomic) NSImage *emptyHeartImage;
@property (nonatomic) NSUInteger animationCurrentStep;
@property (nonatomic) MusicPlayer *musicPlayer;
@property (nonatomic) NSCache *volumeIconCache;;
@end

@implementation ControlViewController

-(void)awakeFromNib
{
    self.loveButton.image.template = YES;
    self.playButton.image.template = YES;
    self.forwardButton.image.template = YES;
    self.backwardButton.image.template = YES;
    self.volumeButton.image.template = YES;
    self.shareButton.image.template = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateControlsState:) name:kTrackInfoUpdated object:nil];
    [self.forwardButton addGestureRecognizer:[[NSPressGestureRecognizer alloc] initWithTarget:self action:@selector(forwardButtonWasPressed:)]];
    [self.backwardButton addGestureRecognizer:[[NSPressGestureRecognizer alloc] initWithTarget:self action:@selector(backwardButtonWasPressed:)]];
    self.volumePopover.delegate = self;
    [self updateControlsState:nil];
    self.shareButton.action = @selector(openShareMenu:);
    self.shareButton.target = self;
    [self.musicPlayer addObserver:self forKeyPath:@"soundVolume" options:NSKeyValueObservingOptionNew context:NULL];
}

-(void)updateControlsState:(NSNotification *)note
{
    if (self.musicPlayer.playerState == MusicPlayerStatePlaying) {
        self.playButton.image = self.pauseImage;
        if ([SettingsController sharedSettings].integrationWithMusicPlayer && self.musicPlayer.currentTrack.loved) {
            self.loveButton.image = [NSImage imageNamed:@"fullheart"];
            self.loveButton.image.template = YES;
        } else {
            self.loveButton.image = self.emptyHeartImage;
        }

    } else {
        self.playButton.image = self.playImage;
    }
    if ([[note.userInfo objectForKey:@"Back Button State"] isEqualToString:@"Info"]) {
        self.backwardButton.enabled = NO;
        self.backwardButton.alphaValue = 0.5;
    } else {
        self.backwardButton.enabled = YES;
        self.backwardButton.alphaValue = 1;
    }
}

- (IBAction)playOrPauseTrack:(NSButton *)sender
{
    [self.musicPlayer playPause];
}

-(void)backwardButtonWasPressed:(NSGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == NSGestureRecognizerStateBegan) {
        [self.backwardButton highlight:YES];
        [self.musicPlayer rewind];
    }
    if (gestureRecognizer.state == NSGestureRecognizerStateEnded || gestureRecognizer.state == NSGestureRecognizerStateCancelled || gestureRecognizer.state == NSGestureRecognizerStateFailed) {
        [self.backwardButton highlight:NO];
        [self.musicPlayer resume];
    }
    
}

-(void)forwardButtonWasPressed:(NSGestureRecognizer *)gestureRecognizer
{
    
    if (gestureRecognizer.state == NSGestureRecognizerStateBegan) {
        [self.forwardButton highlight:YES];
        [self.musicPlayer fastForward];
    }
    if (gestureRecognizer.state == NSGestureRecognizerStateEnded || gestureRecognizer.state == NSGestureRecognizerStateCancelled || gestureRecognizer.state == NSGestureRecognizerStateFailed) {
        [self.forwardButton highlight:NO];
        [self.musicPlayer resume];
        
    }
}

-(void)updateVolumeIcon
{
    NSInteger soundVolume = self.musicPlayer.soundVolume;
    self.volumeButton.image = [self volumeIconForVolume:soundVolume];
    self.volumeButton.image.template = YES;
}

-(NSImage *)volumeIconForVolume:(NSUInteger)volume
{
    NSImage *volumeIcon;
    if (volume > 66) {
        if ([self.volumeIconCache objectForKey:@66]) {
            volumeIcon = [self.volumeIconCache objectForKey:@66];
        } else {
            volumeIcon = [NSImage imageNamed:@"volume-max"];
            [self.volumeIconCache setObject:volumeIcon forKey:@(66)];
        }
    } else if (volume > 33) {
        if ([self.volumeIconCache objectForKey:@33]) {
            volumeIcon = [self.volumeIconCache objectForKey:@33];
        } else {
            volumeIcon = [NSImage imageNamed:@"volume-mid"];
            [self.volumeIconCache setObject:volumeIcon forKey:@(33)];
        }
    } else if (volume > 0) {
        if ([self.volumeIconCache objectForKey:@1]) {
            volumeIcon = [self.volumeIconCache objectForKey:@1];
        } else {
            volumeIcon = [NSImage imageNamed:@"volume-min"];
            [self.volumeIconCache setObject:volumeIcon forKey:@(1)];
        }
    } else {
        if ([self.volumeIconCache objectForKey:@0]) {
            volumeIcon = [self.volumeIconCache objectForKey:@0];
        } else {
            volumeIcon = [NSImage imageNamed:@"volume-mute"];
            [self.volumeIconCache setObject:volumeIcon forKey:@(0)];
        }
    }
    return volumeIcon;
}

- (IBAction)backTrack:(NSButton *)sender
{
    [self.musicPlayer backTrack];
}

- (IBAction)nextTrack:(NSButton *)sender
{
    [self.musicPlayer nextTrack];
}

- (IBAction)loveTrack:(NSButton *)sender
{
    [[MusicController sharedController] loveTrackWithCompletionHandler:nil];
    [self animationLoveButton];
}

- (IBAction)changeVolume:(NSButton *)sender
{
    [self.volumePopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMinYEdge];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateVolumeIcon];
    });
}


- (void)popoverWillShow:(NSNotification *)notification
{
    self.delegate.popoverIsShown = YES;
}

-(void)popoverDidClose:(NSNotification *)notification
{
    self.delegate.popoverIsShown = NO;
    NSPoint mouseLoc = [NSEvent mouseLocation]; //get current mouse position
    if (!NSPointInRect(mouseLoc, [self.delegate window].frame)) {
        [self.delegate hideControls];
    }
}

-(void)animationLoveButton
{
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1.0 / kFPS * NSEC_PER_SEC);
    
    dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        self.animationCurrentStep++;
        
        if (self.animationCurrentStep <= kNumberOfFrames) {
            [self animationLoveButton];
        } else {
            self.animationCurrentStep = 0;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loveButton.image = [self imageForStep:self.animationCurrentStep];
        });
    });
}

#pragma mark - Sharing

-(void)openShareMenu:(NSButton *)button
{
    NSEvent *event = [NSEvent mouseEventWithType:NSLeftMouseDown location:NSPointFromCGPoint(CGPointMake(button.frame.origin.x + button.frame.size.width, button.frame.origin.y + button.frame.size.height)) modifierFlags:NSDeviceIndependentModifierFlagsMask timestamp:0 windowNumber:button.window.windowNumber context:button.window.graphicsContext eventNumber:0 clickCount:1 pressure:1];
    [NSMenu popUpContextMenu:[MenuController sharedController].shareMenu withEvent:event forView:button];
}

//- (IBAction)rateTrack:(NSButton *)sender
//{
//    if (self.musicPlayer.currentPlayer == MusicPlayeriTunes) {
//        
//        __weak typeof(self) weakSelf = self;
//        dispatch_async(dispatch_get_main_queue(), ^{
//            Track *currentTrack = weakSelf.musicPlayer.currentTrack;
//            switch (sender.tag) {
//                case 1:
//                    if (currentTrack.rating > 0 && currentTrack.rating < 21) {
//                        currentTrack.rating = 0;
//                    } else {
//                        currentTrack.rating = 20;
//                    }
//                    break;
//                case 2:
//                    currentTrack.rating = 40;
//                    break;
//                case 3:
//                    currentTrack.rating = 60;
//                    break;
//                case 4:
//                    currentTrack.rating = 80;
//                    break;
//                case 5:
//                    currentTrack.rating = 100;
//                    break;
//                default:
//                    break;
//            }
//            [weakSelf.delegate updateUIbasedOnCurrentTrackRating];
//        });
//    }
//}



#pragma mark - Getters

-(NSImage *)imageForStep:(NSUInteger)step
{
    NSImage *image;
    if (step != 0) {
        image = [NSImage imageNamed:[NSString stringWithFormat:@"heart%lu", (unsigned long)step]];
    } else image = [NSImage imageNamed:@"fullheart"];
    
    [image setTemplate:YES];
    return image;
}


-(NSImage *)playImage
{
    if (!_playImage) {
        _playImage = [NSImage imageNamed:@"play"];
        _playImage.template = YES;
    }
    return _playImage;
}

-(NSImage *)pauseImage
{
    if (!_pauseImage) {
        _pauseImage = [NSImage imageNamed:@"pause"];
        _pauseImage.template = YES;
    }
    return _pauseImage;
}

-(NSImage *)emptyHeartImage
{
    if (!_emptyHeartImage) {
        _emptyHeartImage = [NSImage imageNamed:@"heart"];
        _emptyHeartImage.template = YES;
    }
    return _emptyHeartImage;
}

-(MusicPlayer *)musicPlayer
{
    if (!_musicPlayer) {
        _musicPlayer = [MusicPlayer sharedPlayer];
    }
    return _musicPlayer;
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if ([keyPath isEqual:@"soundVolume"]) {
        [self updateVolumeIcon];
    }
}

-(NSCache *)volumeIconCache
{
    if (!_volumeIconCache) {
        _volumeIconCache = [[NSCache alloc] init];
    }
    return _volumeIconCache;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kTrackInfoUpdated object:nil];
    [self.musicPlayer removeObserver:self forKeyPath:@"soundVolume"];
}

@end
