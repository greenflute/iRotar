//
//  AppDelegate.h
//  iRotar
//
//  Created by Verdantflute on 13-1-20.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic) IBOutlet NSMenu *statusMenu;

@property (nonatomic) NSStatusItem *statusItem;
@property (nonatomic) NSUserDefaults *userDefaults;
@property (nonatomic) LSSharedFileListRef loginItems;

- (IBAction)configure:(NSMenuItem *)sender;
- (IBAction)rotate:(NSMenuItem *)sender;
- (void) handleSMSTimer;
@end
