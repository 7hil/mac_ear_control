//
//  AppDelegate.m
//  mac_ear_control
//
//  Created by Huang Peihao on 10/9/2016.
//  Copyright © 2016 Huang Peihao. All rights reserved.
//

#import "AppDelegate.h"
#import "DDHidAppleMikey.h"
#import "MediaKey.h"
#import "IOKit/hid/IOHIDManager.h"
#include <IOKit/usb/IOUSBLib.h>


@interface AppDelegate ()
@property (weak) IBOutlet NSMenu * statusItemMenu;
@end

@implementation AppDelegate {
    NSStatusItem * statusItem;
    DDHidAppleMikey * mCurrentMikey;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupMenuItem];
    // unload rcd service to prevent iTunes show up
    // when push the earphone button
    [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:@[@"unload",@"/System/Library/LaunchAgents/com.apple.rcd.plist"]];

    // from http://stackoverflow.com/questions/10843559/cocoa-detecting-usb-devices-by-vendor-id/24832676#24832676
    // from http://stackoverflow.com/questions/27963870/mac-os-x-usb-hid-how-the-receive-device-added-device-removed-callbacks
    IOHIDManagerRef HIDManager = IOHIDManagerCreate(kCFAllocatorDefault,
                                                    kIOHIDOptionsTypeNone);
    IOHIDManagerSetDeviceMatching(HIDManager, nil);  // match all device
    // Here we use the same callback for insertion & removal.
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, Handle_UsbDetectionCallback, (__bridge void*)self);
    IOHIDManagerRegisterDeviceRemovalCallback(HIDManager, Handle_UsbDetectionCallback2, (__bridge void*)self);
    IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOReturn IOReturn = IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone);
    if(IOReturn) puts("IOHIDManagerOpen failed.");
    [self toggleDockIcon:true];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:@[@"load",@"/System/Library/LaunchAgents/com.apple.rcd.plist"]];
}

// New device has been added (callback function)
static void Handle_UsbDetectionCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef) {
    NSLog(@"device added: %p",
          (void *)inIOHIDDeviceRef);
    [(__bridge AppDelegate *)(inContext) updateMikey];
    [(__bridge AppDelegate *)(inContext) updateMikey]; // run twice in case of excption when earphone removed
}

// A device has been removed (callback function)
static void Handle_UsbDetectionCallback2(void *inContext, IOReturn inResult, void *inSender, IOHIDDeviceRef inIOHIDDeviceRef) {
    NSLog(@"device removed: %p",
          (void *)inIOHIDDeviceRef);
    [(__bridge AppDelegate *)(inContext) updateMikey];
}

- (void) setupMenuItem {
    if(statusItem == nil) {
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        NSImage *image = [NSImage imageNamed:@"MenuItemTemplate"];
        [image setTemplate:YES];
        statusItem.image = image;
        statusItem.menu = _statusItemMenu;
    }
}

- (bool) updateMikey {
    @try {
        NSArray * mikeys = [DDHidAppleMikey allMikeys] ;
        
        [mikeys makeObjectsPerformSelector: @selector(setDelegate:)
                                withObject: self];
        NSLog(@"%p", [mikeys firstObject]);
        [self setMikey: [mikeys firstObject]];
    }
    @catch (NSException *e) {
        NSLog(@"%@", e.description);
        return false;
    }
    return true;
}

- (void) setMikey: (DDHidAppleMikey *) newMikey
{
    if (newMikey != nil) {
        if (mCurrentMikey != nil) {
            [mCurrentMikey stopListening];
        } else {
            NSLog(@"New earphone connected.");
        }
        mCurrentMikey = newMikey;
        [mCurrentMikey startListening];
        NSImage *image = [NSImage imageNamed:@"MenuItemOn"];
        [image setTemplate:YES];
        statusItem.image = image;
    } else {
        NSLog(@"No earphone connected.");
        NSImage *image = [NSImage imageNamed:@"MenuItemTemplate"];
        [image setTemplate:YES];
        statusItem.image = image;
        [mCurrentMikey stopListening];
        mCurrentMikey = nil;
    }
}

- (void) toggleConnectedIcon : (bool) connected {
    // from http://stackoverflow.com/a/9220857/1813988
    if (connected) {
        [NSApp setActivationPolicy: NSApplicationActivationPolicyProhibited];
    } else {
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    }
}

- (void) toggleDockIcon : (bool) disable {
    // from http://stackoverflow.com/a/9220857/1813988
    if (disable) {
        [NSApp setActivationPolicy: NSApplicationActivationPolicyProhibited];
    } else {
        [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];
    }
}

- (IBAction) showDockIcon:(id)sender {
    NSLog(@"showDockIcon");
    [self toggleDockIcon:false];
}

- (IBAction) hideDockIcon:(id)sender {
    NSLog(@"hideDockIcon");
    [self toggleDockIcon:true];
}

@end

@implementation AppDelegate (DDHidAppleMikeyDelegate)

- (void) ddhidAppleMikey:(DDHidAppleMikey *)mikey press:(unsigned)usageId upOrDown:(BOOL)upOrDown
{
    if (upOrDown == TRUE) {
#if DEBUG
        NSLog(@"Apple Mikey keypress detected: %d", usageId);
#endif
        switch (usageId) {
            case kHIDUsage_GD_SystemMenu:
                NSLog(@"Play/Pause");
                [MediaKey send:NX_KEYTYPE_PLAY];
                break;
            case kHIDUsage_GD_SystemMenuRight:
                NSLog(@"Next");
                // NX_KEYTYPE_NEXT seems invalid here
                [MediaKey send:NX_KEYTYPE_FAST];
                break;
            case kHIDUsage_GD_SystemMenuLeft:
                NSLog(@"Previous");
                // NX_KEYTYPE_PREVIOUS seems invalid here
                [MediaKey send:NX_KEYTYPE_REWIND];
                break;
            case kHIDUsage_GD_SystemMenuUp:
                NSLog(@"sound up");
                [MediaKey send:NX_KEYTYPE_SOUND_UP];
                break;
            case kHIDUsage_GD_SystemMenuDown:
                NSLog(@"sound down");
                [MediaKey send:NX_KEYTYPE_SOUND_DOWN];
                break;
            default:
                NSLog(@"Unknown key press seen %d", usageId);
        }
    }
}

@end
