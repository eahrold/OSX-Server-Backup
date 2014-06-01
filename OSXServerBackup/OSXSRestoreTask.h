//
//  OSXSRestoreTask.h
//  OSX Server Backup
//
//  Created by Eldon on 5/28/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSXSRestoreTask : NSObject
-(BOOL)restoreOpenDirectoryWithPassword:(NSString*)archivePassword error:(NSError **)error;
-(OSStatus)restoreOpenDirectoryWithPassword:(NSString*)archivePassword;

-(BOOL)restorePostgressDB:(NSString*)database
               socketDir:(NSString *)socketDir
                    user:(NSString *)user
                 dumpAll:(BOOL)dumpAll
                   error:(NSError **)error;

-(BOOL)restoreCalendarPostgres:(NSError **)error;
-(OSStatus)restoreCalendarPostgres;

-(BOOL)restoreDeviceManagerPostgres:(NSError **)error;
-(OSStatus)restoreDeviceManagerPostgres;

-(BOOL)restoreStandardPostgres:(NSError **)error;
-(OSStatus)restoreStandardPostgres;

-(BOOL)restoreWikiPostgres:(NSError **)error;
-(OSStatus)restoreWikiPostgres;

-(BOOL)restorePrinters:(NSError **)error;
-(OSStatus)restorePrinters;

-(BOOL)restoreNamed:(NSError **)error;
-(OSStatus)restoreNamed;

-(BOOL)restoreRadius:(NSError **)error;
-(OSStatus)restoreRadius;

-(BOOL)restoreKeychainAndCertificatesWithPassword:(NSString*)password error:(NSError *__autoreleasing *)error;
-(OSStatus)restoreKeychainAndCertificatesWithPassword:(NSString*)password;

-(BOOL)restoreKeychain:(NSError **)error;
-(OSStatus)restoreKeychain;

-(BOOL)restoreCertificateAuthorities:(NSError **)error;
-(OSStatus)restoreCertificateAuthorities;

-(BOOL)restoreMail:(NSError **)error;
-(OSStatus)restoreMail;

-(BOOL)restoreAllSettings:(NSError **)error;
-(OSStatus)restoreAllSettings;

-(BOOL)restoreSqliteAtPath:(NSString*)path error:(NSError **)error;
-(OSStatus)restoreSqliteAtPath:(NSString*)path;

@end
