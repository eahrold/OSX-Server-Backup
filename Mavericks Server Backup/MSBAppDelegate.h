//
//  MSBAppDelegate.h
//  Mavericks Server Backup
//
//  Created by Eldon on 4/18/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MSBAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSTextField *backupDirectoryTF;
@property (weak) IBOutlet NSButton    *chooseBackupDirBT;

#pragma mark - service
@property (weak) IBOutlet NSButton *openDirectoryCheckbox;
@property (weak) IBOutlet NSButton *namedCheckbox;
@property (weak) IBOutlet NSButton *keychainCheckbox;

#pragma mark - postgres
@property (weak) IBOutlet NSButton *pgOSXCheckbox;
@property (weak) IBOutlet NSButton *pgCalendarCheckbox;
@property (weak) IBOutlet NSButton *pgDevicemgrCheckbox;
@property (weak) IBOutlet NSButton *pgWikiCheckbox;

- (IBAction)run:(NSButton *)sender;
- (IBAction)schedule:(NSButton*)sender;

@end
