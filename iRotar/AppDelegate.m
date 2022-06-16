//
//  AppDelegate.m
//  iRotar
//
//  Created by Verdantflute on 13-1-20.
//


#import "AppDelegate.h"
#import "smslib.h"

@interface AppDelegate()

@end

@implementation AppDelegate

# pragma mark Consts

#define SMSTimerInterval 0.5
#define MAX_DISPLAYS 16
enum {
    kIOFBSetTransform = 0x00000400,
};

NSString *const Setting_AutomaticallyRotate     = @"Automatically rotate";
NSString *const Setting_EnableGlobalHotkey      = @"Enable Global Hotkey";
NSString *const Setting_EnableLaunchAtLogin     = @"Launch by System Start";
NSString *const Setting_EnableSwapSensorAxes    = @"Sensor Axes Swapped";
NSString *const Setting_RotateExternalDevice    = @"Rotate external Mouse and Trackpad";

NSString *const Orientation_Landscape           = @"Landscape";
NSString *const Orientation_LeftPortrait        = @"Left Portrait";
NSString *const Orientation_RightPortrait       = @"Right Portrait";
NSString *const Orientation_UpsideDown          = @"Upside Down";

enum {
    kMouseOther = 0,
    kMouseMove = 1,
    kMouseScroll = 2
};

# pragma mark instance variables

// flag for sensor swap
BOOL _sensorAxesSwapped = NO;

// sms timer object
NSTimer *_smsTimer = nil;

// monitor object
id   _hotkeyMonitor = nil;

// current rotation degree
long _angle = 0l;
CFMachPortRef _eventTap = NULL;
CFRunLoopSourceRef _runLoopSource = NULL;


# pragma mark Application Delegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    //init variables
    _userDefaults = [NSUserDefaults standardUserDefaults];
    _loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    //setup statusbar
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem setMenu:_statusMenu];
    [_statusItem setHighlightMode:YES];
    
    [_statusItem setImage: [NSImage imageNamed: @"iRotarStatusBar"]];
    [_statusItem setToolTip: NSLocalizedStringFromTable(@"iRotar", @"InfoPlist", nil)];
    
    //setup Auto Launch
    NSMenuItem *menuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableLaunchAtLogin, @"InfoPlist", nil)];
    [menuItem setState: [self isLaunchAtLogin] ? NSOnState : NSOffState];
       
    //setup Global Hotkey
    menuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableGlobalHotkey, @"InfoPlist", nil)];
    if([_userDefaults boolForKey:Setting_EnableGlobalHotkey] == YES){
        [menuItem setState: NSOnState];
        //register hotkey
        if([self registerHotkey] == YES){
            [menuItem setState:  NSOnState];
        }else{
            [menuItem setState: NSOffState];
            [self disableHotkey];
        }
    }else{
        [menuItem setState: NSOffState];
    }
    
    //setup Auto Rotate
    menuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_AutomaticallyRotate, @"InfoPlist", nil)];
    if([_userDefaults boolForKey:Setting_AutomaticallyRotate] == YES){
        
        if([self startSMSLib] == YES){
            [menuItem setState:  NSOnState];
        }else{
            [menuItem setState: NSOffState];
            [self disableSMSLib];
        }
    }else{
        [menuItem setState:  NSOffState];
    }
   
    //swapped sensor
    menuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableSwapSensorAxes, @"InfoPlist", nil)];
    if([_userDefaults boolForKey:Setting_EnableSwapSensorAxes] == YES){
        _sensorAxesSwapped = YES;
        [menuItem setState:  NSOnState];
    }else{
        [menuItem setState:  NSOffState];
    }    
    
    //dirsplay rotation, if screen has been rotated before app start
    _angle = (int) CGDisplayRotation(0);
    
    //event tap
    [self registerEventTap];
    if(_angle!=0){
        [self enableEventTap];
    }
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    //stop SMS
    if(_smsTimer){
        [self stopSMSLib];
    }
    
    //unregister global hotkey
    if(_hotkeyMonitor){
        [self unregisterHotkey];
    }
    
    //ungister event tap
    if(_eventTap || _runLoopSource){
        [self ungisterEventTap];
    }
    
    //release resources
    CFRelease(_loginItems);
}

# pragma mark LSSharedFileList: Manage Login Item

-(NSURL*) appURL{
    return [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
}

-(LSSharedFileListItemRef) findLoginItem{
    if(_loginItems){
        
        UInt32 seedValue;
        CFArrayRef snapshotRef =  LSSharedFileListCopySnapshot(_loginItems, &seedValue);
		for(id loginItem in (__bridge NSArray *) snapshotRef){
            
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef) loginItem;
            CFURLRef cfURL = NULL;
            
            if (LSSharedFileListItemResolve(itemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &cfURL, NULL) == noErr) {
				if (cfURL && CFEqual(cfURL, (__bridge CFTypeRef)[self appURL])){
                    CFRelease(cfURL);
                    CFRelease(snapshotRef);
                    return itemRef;
				}
            }
        }
        if(snapshotRef){
            CFRelease(snapshotRef);
        }
    }
    return NULL;
}

-(BOOL) isLaunchAtLogin{
    LSSharedFileListItemRef itemRef = [self findLoginItem];
    /*
    CFURLRef cfURL = NULL;
    if (itemRef && LSSharedFileListItemResolve(itemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &cfURL, NULL) == noErr) {
        if (cfURL && CFEqual(cfURL, (__bridge CFTypeRef)[self appURL])){
            CFRelease(cfURL);
            return YES;
        }
    }*/
    return (itemRef!=NULL) ? YES : NO;
}

-(void) setLaunchAtLogin: (BOOL) enable{
	CFURLRef url = (__bridge CFURLRef)[self appURL];
    
	if (_loginItems) {
        if(enable == YES){
            LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(_loginItems,kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (itemRef){
                CFRelease(itemRef);                
            }
            [_userDefaults setBool:YES forKey:Setting_EnableLaunchAtLogin];
            return;
        }else{
            UInt32 seedValue;
            CFArrayRef snapshotRef =  LSSharedFileListCopySnapshot(_loginItems, &seedValue);
            for(id loginItem in (__bridge NSArray *) snapshotRef){
                
                LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef) loginItem;
                CFURLRef cfURL = NULL;
                
                if (LSSharedFileListItemResolve(itemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &cfURL, NULL) == noErr) {
                    if (cfURL && CFEqual(cfURL, (__bridge CFTypeRef)[self appURL])){
                        CFRelease(cfURL);
                        CFRelease(snapshotRef);
                        LSSharedFileListItemRemove(_loginItems,itemRef);
                        [_userDefaults setBool:YES forKey:Setting_EnableLaunchAtLogin];
                        return;
                    }
                }
            }
            if(snapshotRef){
                CFRelease(snapshotRef);
            }                       
        }
	}
	
}


# pragma mark Hotkey

-(BOOL) registerHotkey{
    _hotkeyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask
                                           handler:^(NSEvent *event){                                               
                                               NSInteger flags = [event modifierFlags];
                                               int keyCode = [event keyCode];
                                               
                                               if(flags&NSFunctionKeyMask && flags&NSControlKeyMask){
                                                   //NSLog(@"%s, %s, %d", (flags&NSFunctionKeyMask?"Fn":""), (flags&NSControlKeyMask?"Ctrl":""), keyCode);
                                                   long angle = (keyCode==115) ? 90 : (keyCode==121) ? 180: (keyCode==119)? 270 : 0; //keycode=116
                                                   [self rotateCurrentDisplayWithAngle:angle];
                                               }                                            
                                               
                                           }];
    return (_hotkeyMonitor!=nil) ? YES : NO;
}

-(BOOL) enableHotkey{
    if([self registerHotkey]){
        [_userDefaults setBool:YES  forKey:Setting_EnableGlobalHotkey];
        return YES;
    }
    return NO;
}

-(void) unregisterHotkey{
    if(_hotkeyMonitor){
        [NSEvent removeMonitor:_hotkeyMonitor];
    }
}

-(void) disableHotkey{
    [self unregisterHotkey];
    [_userDefaults setBool:NO  forKey:Setting_EnableGlobalHotkey];
}

# pragma mark Trackpad Rotation

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    long tt = kMouseOther;
    CGEventField fx, fy;
    
    switch (type) {
        case kCGEventMouseMoved:
        case kCGEventLeftMouseDragged:
        case kCGEventRightMouseDragged:
        case kCGEventOtherMouseDragged:
            fx = kCGMouseEventDeltaX;
            fy = kCGMouseEventDeltaY;
            tt = kMouseMove;
            break;
        case kCGEventScrollWheel:
            fx = kCGScrollWheelEventDeltaAxis2;
            fy = kCGScrollWheelEventDeltaAxis1;
            tt = kMouseScroll;
            break;
        default:
            break;
    }
    
    if(tt != kMouseOther){
        
        CGPoint location = CGEventGetLocation(event);
#if DEBUG
        double ox=location.x, oy=location.y;
#endif
        int64_t dx = CGEventGetIntegerValueField(event, fx);
        int64_t dy = CGEventGetIntegerValueField(event, fy);
        
        int64_t ndx = (_angle == 90 ? -dy : _angle == 180 ? -dx : _angle == 270 ? dy : dx);
        int64_t ndy = (_angle == 90 ? dx : _angle == 180 ? -dy : _angle == 270 ? -dx : dy);
        
        if(tt == kMouseScroll){
            
            CGEventSetIntegerValueField(event, fx, ndx);
            CGEventSetIntegerValueField(event, fy, ndy);
            
        }else if(tt == kMouseMove){
            
            //1. universal adjustment
            //ndx = ndx * 0.6;
            //ndy = ndy * 0.6;
            //2. ratio based adjustment
            ndx = (double)ndx * (_angle == 90 ? 0.6 : _angle == 270 ? 0.4 : 0.6);
            ndy = (double)ndy * (_angle == 90 ? 0.4 : _angle == 270 ? 0.6 : 0.6);
            //3. statistic based adjustment
            //ndx = (_angle == 90) ? (double)(ndx + ndy * 0.5) : (_angle == 270) ? (double)(ndx - ndy * 0.5) : (double)(ndx * 0.6);
            //ndy = (_angle == 90) ? (double)(ndy - ndx * 0.33) : (_angle == 270) ? (double)(ndy + ndx * 0.33) : (double)(ndy * 0.6);
            
            CGEventSetIntegerValueField(event, fx, ndx);
            CGEventSetIntegerValueField(event, fy, ndy);
            
            location.x += ndx;
            location.y += ndy;
            CGEventSetLocation(event, location);
            CGWarpMouseCursorPosition(location);
            //CGWarpMouseCursorPosition(CGPointMake(location.x+ndx, location.y+dy));
        }

#if DEBUG
        NSLog(@"%ld %s: (%ld, %ld) + (%lld, %lld) --> (%lld, %lld) ==> (%ld, %ld)\n", _angle, (tt==1?"move":"scroll"), (long)ox, (long)oy, dx, dy, ndx, ndy, (long)location.x, (long)location.y );
#endif
    }
    return event;
}


-(void) registerEventTap{
    //create a disabled event tap
    _eventTap = CGEventTapCreate(kCGHIDEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                //NSMouseMovedMask | NSScrollWheelMask,
                                CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged),
                                myCGEventCallback,
                                nil);
    CGEventTapEnable(_eventTap, false);
    
    // Create a run loop source.
    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    
    // Add to the current run loop.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
}

-(void) enableEventTap{
    if(!CGEventTapIsEnabled(_eventTap)) {
        CGEventTapEnable(_eventTap, true);
        CGAssociateMouseAndMouseCursorPosition(false);
    }
}

-(void) disableEventTap{
    if(CGEventTapIsEnabled(_eventTap)){
        CGEventTapEnable(_eventTap, false);
        CGAssociateMouseAndMouseCursorPosition(true);
    }
}

-(void) ungisterEventTap{
    //if(CFRunLoopContainsSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes)){
    //    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
        CGAssociateMouseAndMouseCursorPosition(true);
        if(CFRunLoopSourceIsValid(_runLoopSource)) CFRunLoopSourceInvalidate(_runLoopSource);
    //}
}

# pragma mark SMSLib


-(BOOL) startSMSLib{
    if (smsStartup(nil, nil)==SMS_SUCCESS){
        smsLoadCalibration();
        
        //setup timer and handler
        _smsTimer = [NSTimer scheduledTimerWithTimeInterval: SMSTimerInterval
                                                    target: self
                                                  selector: @selector(handleSMSTimer)
                                                  userInfo: nil
                                                   repeats: YES];
        return YES;
    }
    return NO;
}

-(BOOL) enableSMSLib{
    if([self startSMSLib]){
        [_userDefaults setBool:YES  forKey:Setting_AutomaticallyRotate];
        return YES;
    }
    return NO;
}

-(void)stopSMSLib{
    [_smsTimer invalidate];
    _smsTimer = nil;
    smsShutdown();
}

-(void) disableSMSLib{
    [self stopSMSLib];
    [_userDefaults setBool:NO  forKey:Setting_AutomaticallyRotate];    
}

-(void) handleSMSTimer{
    //static sms_acceleration pre_accel = {0.0f, 0.0f, 1.0f};
    sms_acceleration accel;
    smsGetData(&accel);
    
    //NSLog(@"SMSTimer: %f, %f, %f", accel.x, accel.y, accel.z);
    long angle = 0;
    if(_sensorAxesSwapped == YES){
        angle = (accel.x < -0.9f) ? 270 : (accel.z < -0.9f) ? 180 : (accel.x > 0.9) ? 90 : 0;
    }else{
        angle = (accel.x < -0.9f) ? 90 : (accel.z < -0.9f) ? 180 : (accel.x > 0.9) ? 270 : 0;
    }
    [self rotateDisplay:0 withAngle:angle];
    
}

-(void) setSensorAxesSwapped:(BOOL) swapped{
    _sensorAxesSwapped = swapped;
    [_userDefaults setBool:swapped  forKey:Setting_EnableSwapSensorAxes];
}

# pragma mark UI Action

- (IBAction)configure:(NSMenuItem *)sender {
    NSMenuItem* autoRotateMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_AutomaticallyRotate, @"InfoPlist", nil)];
    NSMenuItem* hotkeyMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableGlobalHotkey, @"InfoPlist", nil)];
    NSMenuItem* loginMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableLaunchAtLogin, @"InfoPlist", nil)];
    NSMenuItem* swapMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Setting_EnableSwapSensorAxes, @"InfoPlist", nil)];
    if(sender == autoRotateMenuItem){
        if([sender state]==NSOnState){            
            [self disableSMSLib];
            [sender setState:NSOffState];
        }else{
            if([self enableSMSLib]){
                [sender setState:NSOnState];
            }
            
        }
    }else if(sender == hotkeyMenuItem){
        if([sender state]==NSOnState){
            [self disableHotkey];
            [sender setState:NSOffState];
        }else{
            if([self enableHotkey]){
                [sender setState:NSOnState];
            }
        }
    }else if(sender == loginMenuItem){
        
        if([sender state]==NSOnState){
            [self setLaunchAtLogin:NO];
            [sender setState:NSOffState];
        }else{
            [self setLaunchAtLogin:YES];
            [sender setState:NSOnState];
        }
    }else if(sender == swapMenuItem){
        
        if([sender state]==NSOnState){
            [self setSensorAxesSwapped:NO];
            [sender setState:NSOffState];
        }else{
            [self setSensorAxesSwapped:YES];
            [sender setState:NSOnState];
        }        
    }
}

- (IBAction)rotate:(NSMenuItem *)sender {
    //NSMenuItem* upMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Orientation_Landscape, @"InfoPlist", nil)];
    NSMenuItem* leftMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Orientation_LeftPortrait, @"InfoPlist", nil)];
    NSMenuItem* rightMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Orientation_RightPortrait, @"InfoPlist", nil)];
    NSMenuItem* downMenuItem = [_statusMenu itemWithTitle: NSLocalizedStringFromTable(Orientation_UpsideDown, @"InfoPlist", nil)];
    
    //determine degree
    long angle = (sender==leftMenuItem) ? 90 : (sender==downMenuItem) ? 180 : (sender==rightMenuItem) ? 270 : 0;
    //rotate
    [self rotateCurrentDisplayWithAngle:angle];
}


# pragma mark CGDisplay

/*
CGDirectDisplayID getDisplayID(){
    CGDirectDisplayID targetDisplay = CGMainDisplayID();
    CGDisplayErr      dErr;
    CGDisplayCount    displayCount,i;
    CGDirectDisplayID onlineDisplays[MAX_DISPLAYS];
    
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint ourLoc = CGEventGetLocation(ourEvent);
    CFRelease(ourEvent);
    
    dErr = CGGetOnlineDisplayList(MAX_DISPLAYS, onlineDisplays, &displayCount);
    if (dErr != kCGErrorSuccess) {
        //NSLog(@"CGGetOnlineDisplayList: error %d.\n", dErr);
    }
    
    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];
        if( CGRectContainsPoint(CGDisplayBounds(dID), ourLoc)){
            targetDisplay = dID;
            //NSLog(@"Mouse Cursor located on Screen: %d", dID);
        }
    }
    return targetDisplay;
}
*/

CGDirectDisplayID getDisplayIDAtPoint(CGPoint location){
    CGDirectDisplayID targetDisplay = CGMainDisplayID();
    CGDisplayErr      dErr;
    CGDisplayCount    displayCount;
    CGDirectDisplayID onlineDisplays[MAX_DISPLAYS];
    
    dErr = CGGetDisplaysWithPoint(location, MAX_DISPLAYS, onlineDisplays, &displayCount);
    if (dErr == kCGErrorSuccess && displayCount > 0) {
        
        //NSLog(@"CGGetOnlineDisplayList: error %d.\n", dErr);
        targetDisplay = onlineDisplays[0];
    }
    return targetDisplay;
}

CGDirectDisplayID getDisplayID(void){
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint location = CGEventGetLocation(ourEvent);
    CFRelease(ourEvent);
    
    return getDisplayIDAtPoint(location);
}


IOOptionBits angle2options(long angle){
    
    static IOOptionBits anglebits[] = {
        (kIOFBSetTransform | (kIOScaleRotate0)   << 16),
        (kIOFBSetTransform | (kIOScaleRotate90)  << 16),
        (kIOFBSetTransform | (kIOScaleRotate180) << 16),
        (kIOFBSetTransform | (kIOScaleRotate270) << 16)
    };
    
    if ((angle % 90) != 0) // Map arbitrary angles to a rotation reset
        return anglebits[0];
    
    return anglebits[(angle / 90) % 4];
}

- (void) rotateCurrentDisplayWithAngle:(long)angle{
    [self rotateDisplay:getDisplayID() withAngle:angle];
}

- (void) rotateDisplay:(CGDirectDisplayID)targetDisplay withAngle:(long)angle{
    //only rotate when angle changed
    if(_angle!=angle){
        
        io_service_t      service;
        CGDisplayErr      dErr;
        IOOptionBits      options;
        
        options = angle2options(angle);
        service = CGDisplayIOServicePort(targetDisplay);
        
        dErr = IOServiceRequestProbe(service, options);
        if (dErr == kCGErrorSuccess) {
            //update angle
            _angle = angle;
        }
    }
    
    //put it here to fix odd problem of event tap.
    //no need to process event in normal direction.
    /*if(_angle==0){
        [self disableEventTap];
    }else{
        [self enableEventTap];
    }*/

}

@end
