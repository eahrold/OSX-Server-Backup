//
//  MSBAppDelegate.h
//  Mavericks Server Backup
//
//  Created by Eldon on 4/18/14.
//  Copyright (c) 2014 Eldon Ahrold.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.



#import <Cocoa/Cocoa.h>

@interface OSXSBAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow    *window;
@property (assign) IBOutlet NSPanel     *progressPanel;
@property (assign) IBOutlet NSTextView  *progressTextView;

@property (weak)            NSString *progressMessage;         // <-- this is bound
@property (assign)          NSString *osxsbakInstalledVersion; // <-- this is bound
@property (copy)            NSString *osxsbakAvaliableVersion;


@property (weak) IBOutlet NSTextField *backupDirectoryTF;
@property (weak) IBOutlet NSButton    *chooseBackupDirBT;

#pragma mark - service
@property (weak) IBOutlet NSButton *openDirectoryCheckbox;
@property (weak) IBOutlet NSButton *namedCheckbox;
@property (weak) IBOutlet NSButton *keychainCheckbox;
@property (weak) IBOutlet NSButton *printerCheckbox;
@property (weak) IBOutlet NSButton *radiusCheckbox;
@property (weak) IBOutlet NSButton *serversettingsCheckbox;

#pragma mark - settings
@property (weak) IBOutlet NSButton      *permissionCheckbox;
@property (weak) IBOutlet NSButton      *logActionCheckbox;
@property (weak) IBOutlet NSMatrix      *scheduleMatrix;
@property (weak) IBOutlet NSPopUpButton *maxBackupsButton;


#pragma mark - postgres
@property (weak) IBOutlet NSButton *pgOSXCheckbox;
@property (weak) IBOutlet NSButton *pgCalendarCheckbox;
@property (weak) IBOutlet NSButton *pgDevicemgrCheckbox;
@property (weak) IBOutlet NSButton *pgWikiCheckbox;


- (IBAction)run:(NSButton *)sender;

- (IBAction)schedule:(NSButton*)sender;
- (IBAction)removeSchedule:(NSButton*)sender;

- (IBAction)uninstallAll:(NSButton*)sender;

- (IBAction)chooseBackupDir:(NSButton *)sender;
- (IBAction)closePanel:(NSButton *)sender;


- (void)startProgressPanel;
- (void)stopProgressPanel;

@end
