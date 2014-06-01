//
//  OSXSRestoreTask.m
//  OSX Server Backup
//
//  Created by Eldon on 5/28/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSRestoreTask.h"

@implementation OSXSRestoreTask
-(BOOL)restoreOpenDirectoryWithPassword:(NSString*)archivePassword error:(NSError **)error{return 0;}
-(OSStatus)restoreOpenDirectoryWithPassword:(NSString*)archivePassword{return 0;}

-(BOOL)restorePostgressDB:(NSString*)database
                socketDir:(NSString *)socketDir
                     user:(NSString *)user
                  dumpAll:(BOOL)dumpAll
                    error:(NSError **)error{return 0;}

-(BOOL)restoreCalendarPostgres:(NSError **)error{return 0;}
-(OSStatus)restoreCalendarPostgres{return 0;}

-(BOOL)restoreDeviceManagerPostgres:(NSError **)error{return 0;}
-(OSStatus)restoreDeviceManagerPostgres{return 0;}

-(BOOL)restoreStandardPostgres:(NSError **)error{return 0;}
-(OSStatus)restoreStandardPostgres{return 0;}

-(BOOL)restoreWikiPostgres:(NSError **)error{return 0;}
-(OSStatus)restoreWikiPostgres{return 0;}

-(BOOL)restorePrinters:(NSError **)error{return 0;}
-(OSStatus)restorePrinters{return 0;}

-(BOOL)restoreNamed:(NSError **)error{return 0;}
-(OSStatus)restoreNamed{return 0;}

-(BOOL)restoreRadius:(NSError **)error{return 0;}
-(OSStatus)restoreRadius{return 0;}

-(BOOL)restoreKeychainAndCertificatesWithPassword:(NSString*)password error:(NSError *__autoreleasing *)error{return 0;}
-(OSStatus)restoreKeychainAndCertificatesWithPassword:(NSString*)password{return 0;}

-(BOOL)restoreKeychain:(NSError **)error{return 0;}
-(OSStatus)restoreKeychain{return 0;}

-(BOOL)restoreCertificateAuthorities:(NSError **)error{return 0;}
-(OSStatus)restoreCertificateAuthorities{return 0;}

-(BOOL)restoreMail:(NSError **)error{return 0;}
-(OSStatus)restoreMail{return 0;}

-(BOOL)restoreAllSettings:(NSError **)error{return 0;}
-(OSStatus)restoreAllSettings{return 0;}

-(BOOL)restoreSqliteAtPath:(NSString*)path error:(NSError **)error{return 0;}
-(OSStatus)restoreSqliteAtPath:(NSString*)path{return 0;}
@end
