//
//  MSBackupTasks.h
//  Mavericks Server Backup
//
//  Created by Eldon on 4/18/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSXSBackupTasks : NSObject

@property (copy,nonatomic) NSString* directory;
@property (copy,nonatomic) NSString* logFile;
@property (nonatomic)      BOOL      verboseOut;


-(instancetype)initWithDirectory:(NSString*)directory;

-(OSStatus)backupOpenDirectoryWithPassword:(NSString*)archivePassword;

-(OSStatus)backupPostgressDB:(NSString*)database
                   socketDir:(NSString *)socketDir
                        user:(NSString *)user
                     dumpAll:(BOOL)dumpAll;

-(OSStatus)backupCalendarPostgres;
-(OSStatus)backupDeviceManagerPostgres;
-(OSStatus)backupStandardPostgres;
-(OSStatus)backupWikiPostgres;
-(OSStatus)backupNamed;
-(OSStatus)backupKeychain;
-(OSStatus)backupCertificateAuthorities;

@end
