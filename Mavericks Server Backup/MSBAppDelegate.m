//
//  MSBAppDelegate.m
//  Mavericks Server Backup
//
//  Created by Eldon on 4/18/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "MSBAppDelegate.h"
#import "OSXSBackupTasks.h"

@implementation MSBAppDelegate
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{@"backup_dir":@"/var/root/Library/ServerBackup",
                                 @"pg_osx":[NSNumber numberWithBool:YES],
                                 @"pg_calendar":[NSNumber numberWithBool:YES],
                                 @"pg_devicemgr":[NSNumber numberWithBool:YES],
                                 @"pg_wiki":[NSNumber numberWithBool:YES],
                                 @"service_od":[NSNumber numberWithBool:YES],
                                 @"service_named":[NSNumber numberWithBool:YES],
                                 @"service_keychain":[NSNumber numberWithBool:YES],}
     ];
}

- (IBAction)run:(NSButton *)sender {
    NSString *archivePassword = @"mypass";
    
    // Setup date String to denote backup names
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0];
    NSString *dateStr = [dateFormatter stringFromDate:date];
    
    
    NSString *finalDest = [NSString stringWithFormat:@"%@/%@",_backupDirectoryTF.stringValue,dateStr];
    OSXSBackupTasks *backupTask = [[OSXSBackupTasks alloc]initWithDirectory:finalDest];
    
    OSStatus status;
    if(_pgOSXCheckbox.state){
        status = [backupTask backupStandardPostgres];
        NSLog(@"backup OSX Postgres: %d",status);
    }
    
    if(_pgCalendarCheckbox.state){
        status = [backupTask backupCalendarPostgres];
        NSLog(@"backup calendar: %d",status);
    }
    
    if(_pgDevicemgrCheckbox.state){
        NSLog(@"backup named: %d",status);
        status = [backupTask backupDeviceManagerPostgres];
    }
    
    if(_namedCheckbox.state){
        status = [backupTask backupNamed];
        NSLog(@"backup named: %d",status);
    }
    
    if(_openDirectoryCheckbox.state){
        status = [backupTask backupOpenDirectoryWithPassword:archivePassword];
        NSLog(@"backup Open Directory: %d",status);
    }
    
    if(_keychainCheckbox.state){
        status = [backupTask backupKeychain];
        status = [backupTask backupCertificateAuthorities];
    }
    
}

- (IBAction)schedule:(NSButton *)sender {
}

@end
