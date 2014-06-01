//
//  MSBAppDelegate.m
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



#import "OSXSBAppDelegate.h"
#import "OSXSBackupTasks.h"
#import "OSXSBInterfaces.h"
#import "OSXSBHelperConnection.h"

#import "AHLaunchCtl.h"
#import "AHCodesignValidator.h"

@implementation OSXSBAppDelegate
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return YES;
}

-(void)applicationWillTerminate:(NSNotification *)notification{
    OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
    [helper connect];
    [[helper.connection remoteObjectProxy] quitHelper];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSError *error;
    if(checkForKeychainItem(nil)){
        NSLog(@"found");
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"backup_dir":@"/var/root/Library/ServerBackup",
                                 @"pg_osx":[NSNumber numberWithBool:YES],
                                 @"pg_calendar":[NSNumber numberWithBool:YES],
                                 @"pg_devicemgr":[NSNumber numberWithBool:YES],
                                 @"pg_wiki":[NSNumber numberWithBool:YES],
                                 @"service_dirserv":[NSNumber numberWithBool:YES],
                                 @"service_named":[NSNumber numberWithBool:YES],
                                 @"service_keychain":[NSNumber numberWithBool:YES],
                                 @"service_serveradmin":[NSNumber numberWithBool:YES],
                                 @"service_radius":[NSNumber numberWithBool:YES],
                                 @"service_mail":[NSNumber numberWithBool:YES],
                                 }
     ];
    
    BOOL rc = [AHLaunchCtl installHelper:kOSXSBHelperName
                                  prompt:@"To create backups, "
                                   error:&error];
    if(!rc){
        [NSApp presentError:error
             modalForWindow:_window
                   delegate:self
         didPresentSelector:@selector(setupDidEndWithTerminalError:)
                contextInfo:NULL];
        return;
    }
    
    self.osxsbakInstalledVersion = embeddedVersionOfItemAtPath(@"/usr/local/sbin/osxsbak");
}

- (IBAction)run:(NSButton *)sender {
    if(_openDirectoryCheckbox.state || _keychainCheckbox.state){
        [self promptForPassword:1];
    }else{
        [self runBackup:nil];
    }
    
}

-(void)runBackup:(NSString*)password{
    NSData *authorization = [OSXSBAuthorizer authorizeHelper];
    assert(authorization != nil);
    
    NSDictionary *dict = [self taskDictionaryWithAppendedPath:@"manual"];

    if(!dict){
        [self alertWithTitle:@"Error running backup" message:@"Please check that a backup path is set" error:nil];
    }
    
    OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
    [helper connect];
    assert(helper.connection != nil);
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [self handleRemoteObjectProxyError:error];
    }] runBackupWithTaskDict:dict password:password authorization:authorization reply:^(NSError *error) {
        [self handleHelperResponseError:error success:@"finished running backup"];
    }];    
}

- (IBAction)schedule:(NSButton *)sender {
    // check on version
    NSString *iv = embeddedVersionOfItemAtPath(@"/usr/local/sbin/osxsbak");
    NSString *av = embeddedVersionOfItemAtPath([[NSBundle mainBundle]pathForAuxiliaryExecutable:@"osxsbak"]);
    if([AHLaunchCtl version:av isGreaterThanVersion:iv]){
        return [self installCliTool];
    }
    
    if(_openDirectoryCheckbox.state && !checkForKeychainItem(nil)){
        return [self promptForPassword:2];
    }
    
    NSData *authorization = [OSXSBAuthorizer authorizeHelper];
    assert(authorization != nil);

    NSDictionary *dict;
    AHLaunchJobSchedule *schedule;
    if([[[_scheduleMatrix selectedCell] title] isEqualToString:@"Daily"]){
        schedule = [AHLaunchJobSchedule dailyRunAtHour:2 minute:00];
        dict = [self taskDictionaryWithAppendedPath:@"daily"];
        NSLog(@"Scheduling daily backup");
    }else{
        schedule = [AHLaunchJobSchedule weeklyRunOnWeekday:0 hour:2];
        dict = [self taskDictionaryWithAppendedPath:@"weekly"];
        NSLog(@"Scheduling weekly backup");
    }
    
    if(!dict){
        [self alertWithTitle:@"Error scheduling run" message:@"Please check that a backup path is set" error:nil];
    }
    
    if([dict[OSXSBServiceOpenDirectoryKey]  isEqual: @YES]){
        NSLog(@"Checking for keychain password");
        //make sure there's a password in the keychain...
    }
    
    OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
    [helper connect];
    assert(helper.connection != nil);
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [self handleRemoteObjectProxyError:error];
    }] scheduleBackupWithTaskDict:dict schedule:schedule authorization:authorization reply:^(NSError *error){
        NSString *message;
        NSString *title;
        if(error){
            title = @"Error installing scheduled LaunchDaemon";
            message = error.localizedDescription;
        }else{
            title = @"Backup scheduled";
            message = @"You Successfully scheduled a backup.  You can reschedule it at any time and the old job will be overwritten";
        }
        [self alertWithTitle:title message:message error:error];
    }];
}

- (IBAction)removeSchedule:(NSButton*)sender{
    NSData *authorization = [OSXSBAuthorizer authorizeHelper];
    assert(authorization != nil);
    NSString *whichSchedule;
    
    if([[[_scheduleMatrix selectedCell] title] isEqualToString:@"Daily"]){
        whichSchedule = @"daily";
    }else{
        whichSchedule = @"weekly";
    }
    
    OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
    [helper connect];
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [self handleRemoteObjectProxyError:error];
    }] removeScheduledJob:whichSchedule withAuthorization:authorization reply:^(NSError *error) {
        NSString *message = [NSString stringWithFormat:@"The %@ osxsbak launchd.plists was unloaded and removed.",whichSchedule];
        [self alertWithTitle:@"Backup Schedule" message:message error:error];
    }];
}

- (void)installCliTool{
    NSString *cliTool = [NSString stringWithFormat:@"%@",[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"osxsbak"]];

    NSAlert *installAlert = [NSAlert alertWithMessageText:@"Install osxsbak cli tool"
                                            defaultButton:@"Install"
                                          alternateButton:@"Don't Install"
                                              otherButton:nil
                                informativeTextWithFormat:@"A newer version of osxsbak is avaliable, you need to install it to schedule runs."];
    
    __weak OSXSBAppDelegate *weakSelf = self;
    [installAlert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSOKButton){
            if(cliTool != nil){
                OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
                [helper connect];
                [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
                    [weakSelf handleRemoteObjectProxyError:error];
                }] installCliToolAtPath:cliTool reply:^(NSError *error) {
                    [weakSelf handleHelperResponseError:error success:nil];
                    weakSelf.osxsbakInstalledVersion = embeddedVersionOfItemAtPath(@"/usr/local/sbin/osxsbak");
                }];
            }
        }
    }];
}

- (IBAction)removeCliTool:(NSButton *)sender{

}

- (IBAction)updateArchivePassword:(id)sender {
    [self promptForPassword:2];
}

-(void)addPasswordToKeychain:(NSString*)password{
    NSData *authorization = [OSXSBAuthorizer authorizeHelper];
    assert(authorization != nil);
    
    OSXSBHelperConnection *helper = [OSXSBHelperConnection new];
    [helper connect];
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [self handleRemoteObjectProxyError:error];
    }]setKeychainPassword:password authorization:authorization reply:^(NSError *error) {
        [self alertWithTitle:@"Updated keychain" message:@"set they keychain" error:error];
    }];
}

- (IBAction)uninstallAll:(NSButton *)sender{
    
}

- (NSDictionary *)taskDictionaryWithAppendedPath:(NSString*)appendation{
    NSMutableDictionary *tasks = [NSMutableDictionary new];
    if([_backupDirectoryTF.stringValue isEqualToString:@""]){
        return nil;
    }
    
    NSString *backupDest = [_backupDirectoryTF.stringValue stringByAppendingPathComponent:appendation];
    
    [tasks setObject:backupDest forKey:OSXSBBackupDirectoryKey];
    
    [tasks setObject:_logActionCheckbox.state ? @YES:@NO
              forKey:OSXSBLogBackupKey];
    
    OSXSBPermissionLevel permission = _permissionCheckbox.state ? kOSXSBPermissionStrong:kOSXSBPermissionWeak;
    [tasks setObject:[NSNumber numberWithInteger:permission] forKey:OSXSBPermissionsKey];
    
    NSInteger maxBackups = [_maxBackupsButton.titleOfSelectedItem integerValue];
    if(maxBackups > 0){
        [tasks setObject:[NSNumber numberWithInteger:maxBackups] forKey:OSXSBMaxBackupsKey];
    }
    if(!_permissionCheckbox.state){
        [tasks setObject:[NSNumber numberWithInteger:kOSXSBPermissionWeak]
              forKey:OSXSBPermissionsKey];
    }
    if(_pgOSXCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBPostgresStandardKey];
    }
    if(_pgCalendarCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBPostgresCalendarKey];
    }
    if(_pgDevicemgrCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBPostgresDevicemgrKey];
    }
    if(_pgWikiCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBPostgresCollabKey];
    }
    if(_namedCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServiceNamedKey];
    }
    if(_openDirectoryCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServiceOpenDirectoryKey];
    }
    if(_keychainCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServiceKeychainKey];
    }
    if(_printerCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServicePrintersKey];
    }
    if(_radiusCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServiceRadiusKey];
    }
    if(_serversettingsCheckbox.state){
        [tasks setObject:@YES forKey:OSXSBServiceServeradminKey];
    }
    
    return tasks;
}

#pragma mark - Event Handlera
-(void)handleRemoteObjectProxyError:(NSError *)error{
    if(error){
        NSLog(@"Error: %@",error.localizedDescription);
    }
}

-(void)handleHelperResponseError:(NSError*)error success:(NSString*)message{
    self.progressMessage = @"Done...";
    if(error){
        NSLog(@"Error: %@",error.localizedDescription);
        [self didRecieveProgressMessage:error.localizedDescription];
    }
}

#pragma mark - Panels / Dialogs
- (IBAction)chooseBackupDir:(NSButton *)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setPrompt:@"Choose a backup directory"];
    
    [panel beginSheetModalForWindow:[[NSApplication sharedApplication]mainWindow] completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            _backupDirectoryTF.stringValue = [[panel URL] path];
        }
    }];
}


-(void)promptForPassword:(int)proceed{
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        NSString *info;
        switch (proceed) {
            case 1:
                info = @"A password is required to backup Open Directory, this will only be used this one time and not stored in your keychain";
                break;
            case 2:
                info = @"A backing up both Open Directory and Keychains/Certificates requires a password, we need to add this to the system keychain so the osxsbak cli tool can access it.  It will create an item call com.eeaapps.osxsbak";
                break;
            default:
                info = @"enter password";
                break;
        }
        
        NSAlert *alert = [NSAlert alertWithMessageText: @"Please set an archive password"
                                         defaultButton:@"OK"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"%@",info];
        NSSecureTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
        [input setStringValue:@""];
        [alert setAccessoryView:input];
        [alert beginSheetModalForWindow:_window
                      completionHandler:^(NSModalResponse returnCode) {
                          if (returnCode == NSAlertDefaultReturn) {
                              [input validateEditing];
                              NSString *password = [input stringValue];
                              if(proceed == 1){
                                  [self runBackup:password];
                              }else if(proceed == 2){
                                  [self addPasswordToKeychain:password];
                              }
                          }
                      }];
    }];
}

#pragma mark - Progresss Panel
-(void)alertWithTitle:(NSString*)title message:(NSString*)message error:(NSError*)error{
    if(error)message = error.localizedDescription;
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",message];
        [alert setIcon:nil];
        [alert beginSheetModalForWindow:_window
                          modalDelegate:self
                         didEndSelector:NULL
                            contextInfo:NULL];
    }];
}
- (IBAction)OpenBackupFolder:(NSButton *)sender {
    [self stopProgressPanel];
     [[NSWorkspace sharedWorkspace]openFile:self.backupDirectoryTF.stringValue withApplication:@"Finder"];
}

-(IBAction)closePanel:(NSButton *)sender{
    [self stopProgressPanel];
}

- (void)startProgressPanel{
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
    /* Display a progress panel as a sheet */
        self.progressMessage = @"Running...";
        [NSApp beginSheet:_progressPanel
           modalForWindow:_window
            modalDelegate:self
           didEndSelector:nil
              contextInfo:NULL];
    }];
}

- (void)stopProgressPanel{
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        if(_progressPanel.isVisible){
            [self.progressTextView.textStorage setAttributedString:[NSAttributedString new]];
            [_progressPanel orderOut:self];
            [NSApp endSheet:_progressPanel returnCode:0];
        }
    }];
}

- (void)didRecieveProgressMessage:(NSString*)message{
    NSLog(@"%@",message);
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        [self.progressTextView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:[message stringByAppendingString:@"\n"]]];
    }];
}


#pragma mark - did end selectors...
- (void)setupDidEndWithTerminalError:(NSAlert *)alert
{
    [NSApp terminate:self];
}



@end
