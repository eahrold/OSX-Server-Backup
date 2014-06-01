//
//  MSBackupTasks.h
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


#import <Foundation/Foundation.h>
#import "OSXSBError.h"

typedef NS_ENUM(NSInteger, OSXSBPermissionLevel){
    kOSXSBPermissionNone   = 755,
    kOSXSBPermissionWeak   = 750,
    kOSXSBPermissionStrong = 700,
};

static NSString *const OSXSBBackupDirectoryKey      = @"com.eeaapps.OSXSBBackupDirectoryKey";
static NSString *const OSXSBPermissionsKey          = @"com.eeaapps.OSXSBPermissionsKey";
static NSString *const OSXSBLogBackupKey            = @"com.eeaapps.OSXSBNoLoggingKey";
static NSString *const OSXSBPasswordKey             = @"com.eeaapps.OSXSBPasswordKey";
static NSString *const OSXSBMaxBackupsKey           = @"com.eeaapps.OSXSBMaxBackupsKey";

static NSString *const OSXSBPostgresStandardKey     = @"com.eeaapps.OSXSBPostgresStandardKey";
static NSString *const OSXSBPostgresDevicemgrKey    = @"com.eeaapps.OSXSBPostgresDevicemgrKey";
static NSString *const OSXSBPostgresCalendarKey     = @"com.eeaapps.OSXSBPostgresCalendarKey";
static NSString *const OSXSBPostgresCollabKey       = @"com.eeaapps.OSXSBPostgresCollabKey";

static NSString *const OSXSBServiceOpenDirectoryKey = @"com.eeaapps.OSXSBOpenDirectoryKey";
static NSString *const OSXSBServiceNamedKey         = @"com.eeaapps.OSXSBNamedKey";
static NSString *const OSXSBServiceRadiusKey        = @"com.eeaapps.OSXSBRadiusKey";
static NSString *const OSXSBServicePrintersKey      = @"com.eeaapps.OSXSBPrintersKey";
static NSString *const OSXSBServiceKeychainKey      = @"com.eeaapps.OSXSBKeychainKey";
static NSString *const OSXSBServiceMailKey          = @"com.eeaapps.OSXSBMailKey";
static NSString *const OSXSBServiceServeradminKey   = @"com.eeaapps.OSXSBServeradminKey";

@interface OSXSBackupTasks : NSObject

@property (copy,nonatomic) NSString* directory;
@property (copy,nonatomic) NSString* logFile;

@property (nonatomic)      OSXSBPermissionLevel permission;
@property (nonatomic)      BOOL      verboseOut;
@property (nonatomic)      NSInteger maxBackups;

-(instancetype)initWithDirectory:(NSString*)directory permission:(OSXSBPermissionLevel)permission;

-(BOOL)runFromDictionary:(NSDictionary*)dict
             withPasword:(NSString*)password
                starting:(void (^)(NSString *taskName))starting
                complete:(void (^)(NSString *taskName,NSError *error))complete;

-(BOOL)backupOpenDirectoryWithPassword:(NSString*)archivePassword error:(NSError **)error;
-(OSStatus)backupOpenDirectoryWithPassword:(NSString*)archivePassword;

-(BOOL)backupPostgressDB:(NSString*)database
                   socketDir:(NSString *)socketDir
                        user:(NSString *)user
                     dumpAll:(BOOL)dumpAll
                       error:(NSError **)error;

-(BOOL)backupCalendarPostgres:(NSError **)error;
-(OSStatus)backupCalendarPostgres;

-(BOOL)backupDeviceManagerPostgres:(NSError **)error;
-(OSStatus)backupDeviceManagerPostgres;

-(BOOL)backupStandardPostgres:(NSError **)error;
-(OSStatus)backupStandardPostgres;

-(BOOL)backupWikiPostgres:(NSError **)error;
-(OSStatus)backupWikiPostgres;

-(BOOL)backupPrinters:(NSError **)error;
-(OSStatus)backupPrinters;

-(BOOL)backupNamed:(NSError **)error;
-(OSStatus)backupNamed;

-(BOOL)backupRadius:(NSError **)error;
-(OSStatus)backupRadius;

-(BOOL)backupKeychainAndCertificatesWithPassword:(NSString*)password error:(NSError *__autoreleasing *)error;
-(OSStatus)backupKeychainAndCertificatesWithPassword:(NSString*)password;

-(BOOL)backupKeychain:(NSError **)error;
-(OSStatus)backupKeychain;

-(BOOL)backupCertificateAuthorities:(NSError **)error;
-(OSStatus)backupCertificateAuthorities;

-(BOOL)backupMail:(NSError **)error;
-(OSStatus)backupMail;

-(BOOL)backupAllSettings:(NSError **)error;
-(OSStatus)backupAllSettings;

-(BOOL)backupSqliteAtPath:(NSString*)path error:(NSError **)error;
-(OSStatus)backupSqliteAtPath:(NSString*)path;


@end
