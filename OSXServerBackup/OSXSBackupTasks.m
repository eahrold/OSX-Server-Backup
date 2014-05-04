//
//  MSBackupTasks.m
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

#import "OSXSBackupTasks.h"
#import "NSTask+ExpectTask.h"
#import "NSFileHandle+writeToFile.h"
#import "Objective-CUPS.h"
#import "OSXSBUtility.h"
#import <syslog.h>

static NSString * kOSXServeradmin = @"/Applications/Server.app/Contents/ServerRoot/usr/sbin/serveradmin";

@interface OSXSBackupTasks ()
@property (copy,nonatomic) NSString* timeStampDirectory;
@end

@implementation OSXSBackupTasks{
    NSPipe *_logPipe;
    NSFileHandle *_logFileHandle;
}
-(id)init{
    self = [super init];
    if(self){
        _permission = kOSXSBPermissionStrong;
        _maxBackups = -1;
    }
    return self;
}

-(instancetype)initWithDirectory:(NSString*)directory permission:(OSXSBPermissionLevel)permission{
    self = [self init];
    if(self){
        _permission = permission;
        self.directory = directory;
    }
    return self;
}

-(void)dealloc{
    removeExcessBackups(_directory, _maxBackups);
    if(_logFileHandle){
        [_logFileHandle writeFormatString:@"Finished OSX Server Backup: %@\n",[NSDate dateWithTimeIntervalSinceNow:0]];
        [_logFileHandle writeString:osxsbakLineBreak];
        [_logFileHandle closeFile];
    }
    if(_logPipe.fileHandleForWriting){
        [_logPipe.fileHandleForWriting closeFile];
    }
}

#pragma mark - Accessors
-(void)setDirectory:(NSString *)directory{
    _directory = directory;
    _timeStampDirectory = timeStampedFolder(directory);
    makeBackupDir(_timeStampDirectory,_permission);
}


-(void)setLogFile:(NSString *)logFile{
    _logFile = logFile;
    rotateLog(_logFile,NSCalendarUnitDay);

    if(![[NSFileManager defaultManager]fileExistsAtPath:logFile isDirectory:nil]){
        [[NSData data] writeToFile:logFile options:0 error:nil];
    }
    
    _logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFile];
    
    [_logFileHandle writeString:osxsbakLineBreak];
    [_logFileHandle writeFormatString:@"Starting OSX Server Backup: %@\n",[NSDate dateWithTimeIntervalSinceNow:0]];
}

#pragma mark - Open Directory
-(OSStatus)backupOpenDirectoryWithPassword:(NSString *)archivePassword{
    NSError *error;
    if(![self backupOpenDirectoryWithPassword:archivePassword error:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;

}
-(BOOL)backupOpenDirectoryWithPassword:(NSString *)archivePassword error:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    
    // TODO: NSTask is hanging on stdin only outside of xcode...
    return [self backupOpenDirectoryWithPassword2:archivePassword error:error];
}

-(BOOL)backupOpenDirectoryWithPassword1:(NSString *)archivePassword error:(NSError *__autoreleasing *)error{
    /* For some reason this only works when executed from within xcode.
     When it's called normally, the slapconfig never gets sent the pass and hangs.
     For now I'm just doing and ugly spawn/expect implamentation...
     */
    if(!archivePassword || [archivePassword isEqualToString:@""]){
        return [OSXSBError errorWithCode:kOSXSBErrorNoPasswordForArchive error:error];
    }
    
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/sbin/slapconfig";
    NSString* arcDest = [NSString stringWithFormat:@"%@/ODArchive.dmg",_timeStampDirectory];
    task.arguments = @[@"-backupdb",arcDest];
    
    
    // handle output either log or send to nowhere...
    if(_logFileHandle){
        task.standardOutput= _logFileHandle;
    }else{
        task.standardOutput = nil;
    }
    task.standardError  = task.standardOutput;
    
    // set up  the stdin pipe
    task.standardInput = [NSPipe pipe];
    NSFileHandle *sendCommand = [task.standardInput fileHandleForWriting];
    
    NSData *data = [[NSString stringWithFormat:@"%@\r",archivePassword]dataUsingEncoding:NSASCIIStringEncoding];
    
    [task launch];
    [sendCommand writeData:data];
    [sendCommand closeFile];
    [task waitUntilExit];
    
    return [OSXSBError errorFromTask:task error:error];
}


-(BOOL)backupOpenDirectoryWithPassword2:(NSString *)archivePassword error:(NSError *__autoreleasing *)error{
    if(!archivePassword || [archivePassword isEqualToString:@""]){
        return [OSXSBError errorWithCode:kOSXSBErrorNoPasswordForArchive error:error];
    }
    
    // This uses the NSTask+ExpectTask Catagory extension...
    NSTask *task = [[NSTask alloc]initForExpect];
    task.currentDirectoryPath = _timeStampDirectory;
    
    // handle output either log or send to nowhere...
    if(_logFileHandle){
        task.standardOutput= _logFileHandle;
    }else{
        task.standardOutput = nil;
    }
    
    //task.standardError  = task.standardOutput;
    
    task.spawnCommand = @"spawn /usr/sbin/slapconfig -backupdb ./ODArchive.dmg";
    task.timeout = -1;

    syslog(1, "setting password to %s",archivePassword.UTF8String);
    
    NSDictionary *expectDictionary = @{kNSTaskExpectKey:@"Enter archive password:",
                                       kNSTaskSendKey:archivePassword,
                                       kNSExpectTaskBreakKey:@YES};
    
    task.expectArguments = @[expectDictionary];
    
    [task launchExpect];
    [task waitUntilExit];
        
    return [OSXSBError errorFromTask:task error:error];
}

#pragma mark - Postgres
-(BOOL)backupPostgressDB:(NSString*)database socketDir:(NSString *)socketDir user:(NSString *)user dumpAll:(BOOL)dumpAll error:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    
    NSString *file = [NSString stringWithFormat:@"%@/pg_backup_%@.sql",_timeStampDirectory,dumpAll ? @"osx_all":database];
    NSTask *task = [NSTask new];
    
    if(_logFileHandle){
        [_logFileHandle writeFormatString:@"Backing up %@ PostgresDB...\n",database ? database:user];
        task.standardOutput= _logFileHandle;
    }else{
        task.standardOutput = [NSPipe pipe];
    }
    task.standardError  = task.standardOutput;

    
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"-h",socketDir,
                                                            @"-f",file,
                                                            @"-U",user]];
    
    if(dumpAll){
        task.launchPath = @"/Applications/Server.app/Contents/ServerRoot/usr/bin/pg_dumpall";
    }else{
        task.launchPath = @"/Applications/Server.app/Contents/ServerRoot/usr/bin/pg_dump";
        if(database){
            [args addObject:database];
        }else{
            return [OSXSBError errorWithCode:kOSXSBErrorNoDatabaseSpecified error:error];
        }
    }
    
    task.arguments = args;
    
    [task launch];
    [task waitUntilExit];
    return [OSXSBError errorFromTask:task error:error];
}

#pragma mark -- Standard
-(BOOL)backupStandardPostgres:(NSError *__autoreleasing *)error{
    NSString *socketDir = @"/var/pgsql_socket";
    NSString *user = @"_postgres";
    return [self backupPostgressDB:nil socketDir:socketDir user:user dumpAll:YES error:error];
}
-(OSStatus)backupStandardPostgres{
    NSError *error;
    if(![self backupStandardPostgres:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Calendar
-(BOOL)backupCalendarPostgres:(NSError *__autoreleasing *)error{
    NSString *socketDir = @"/var/run/caldavd/PostgresSocket/";
    NSString *user = @"caldav";
    NSString *db = @"caldav";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO error:error];
}
-(OSStatus)backupCalendarPostgres{
    NSError *error;
    if(![self backupCalendarPostgres:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Device Manager
-(BOOL)backupDeviceManagerPostgres:(NSError *__autoreleasing *)error{
    NSString *socketDir = @"/Library/Server/ProfileManager/Config/var/PostgreSQL/";
    NSString *user = @"_devicemgr";
    NSString *db =@"devicemgr_v2m0";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO error:error];
}
-(OSStatus)backupDeviceManagerPostgres{
    NSError *error;
    if(![self backupDeviceManagerPostgres:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Wiki
-(BOOL)backupWikiPostgres:(NSError *__autoreleasing *)error{
    // user collab to dump colab, and user _teamserver to dump all
    NSString *socketDir = @"/Library/Server/Wiki/PostgresSocket/";
    NSString *user = @"collab";
    NSString *db = @"collab";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO error:error];
}

-(OSStatus)backupWikiPostgres{
    NSError *error;
    if(![self backupWikiPostgres:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark - Other Backup Tasks
#pragma mark -- Printers
-(BOOL)backupPrinters:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    
    NSSet *printers = [CUPSManager installedPrinters];
    if(!printers){
        [_logFileHandle writeFormatString:@"No printers installed"];
        return 0;
    }
    NSString *backupFile = [NSString stringWithFormat:@"%@/Reinstall Printers.command",_timeStampDirectory];
    
    if(![[NSFileManager defaultManager] createFileAtPath:backupFile contents:[NSData data] attributes:@{NSFilePosixPermissions:[NSNumber numberWithInteger:511]}]){
        return 1;
    }
    
    NSFileHandle *installFileHandle = [NSFileHandle fileHandleForWritingAtPath:backupFile];
    [installFileHandle writeFormatString:@"#!/bin/bash\n\n"];
    for(Printer *p in printers){
        if (![p.protocol isEqualToString:@"usb"]&&
            ![p.protocol isEqualToString:@"file"])
        {
            NSMutableString *str = [NSMutableString new];
            [str appendFormat:@"lpadmin -p %@ -v %@ -E ",p.name,p.url];
            
            if(p.location && ![p.location isEqualToString:@""])
                [str appendFormat:@"-L \"%@\" ",p.location];
            
            if(p.description && ![p.description isEqualToString:@""])
                [str appendFormat:@"-D \"%@\" ",p.description];
            
            NSString* ppd = [[CUPSManager ppdsForModel:p.model]lastObject];
            if(ppd){
                [str appendFormat:@"-P \"%@\"\n",ppd];
            }else if ([ p.model isEqualToString:@"Local Raw Printer"]){
                [str appendString:@"-m raw\n"];
            }else{
                [str appendString:@"\n"];
            }
            
            [installFileHandle writeString:str];
        }
    }
    return 0;
}

-(OSStatus)backupPrinters{
    NSError *error;
    if(![self backupPrinters:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Named
-(BOOL)backupNamed:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    NSString *namedDir = @"/Library/Server/named";
    return [self zip:namedDir to:_timeStampDirectory error:error];
}

-(OSStatus)backupNamed{
    NSError *error;
    if(![self backupNamed:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Radius
-(BOOL)backupRadius:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    NSString *radiusDir = @"/Library/Server/radius";
    return [self zip:radiusDir to:_timeStampDirectory error:error];
}
-(OSStatus)backupRadius{
    NSError *error;
    if(![self backupRadius:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark -- Keychain / Certificates
-(BOOL)backupKeychain:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    return [OSXSBError errorWithCode:kOSXSBErrorFeatureNotImplamented error:error];
}

-(OSStatus)backupKeychain{
    NSError *error;
    if(![self backupKeychain:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

-(BOOL)backupCertificateAuthorities:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    return [OSXSBError errorWithCode:kOSXSBErrorFeatureNotImplamented error:error];
}

-(OSStatus)backupCertificateAuthorities{
    NSError *error;
    if(![self backupCertificateAuthorities:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;

}

#pragma mark -- Mail
-(BOOL)backupMail:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    return [OSXSBError errorWithCode:kOSXSBErrorFeatureNotImplamented error:error];
}

-(OSStatus)backupMail{
    NSError *error;
    if(![self backupMail:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;

}

#pragma mark - serveradmin
-(BOOL)backupServeradminSettings:(NSString*)settings error:(NSError *__autoreleasing*)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    
    NSTask *task = [NSTask new];
    NSString *settingsDir = [NSString stringWithFormat:@"%@/Settings/",_timeStampDirectory];
    NSString *settingsFilePath = [NSString stringWithFormat:@"%@/%@.txt",settingsDir,settings];
    
    if(![[NSFileManager defaultManager]fileExistsAtPath:settingsFilePath isDirectory:nil]){
        if(makeBackupDir(settingsDir,_permission))
            [[NSData data] writeToFile:settingsFilePath options:0 error:nil];
        else
            return [OSXSBError errorWithCode:kOSXSBErrorCouldNotCreateFile error:error];
    }
    
    NSFileHandle *settingsFileHandle = [NSFileHandle fileHandleForWritingAtPath:settingsFilePath];
    task.launchPath = kOSXServeradmin;
    task.arguments = @[@"settings",settings];
    task.standardOutput = settingsFileHandle;
    
    if(_logFileHandle){
        task.standardError = _logFileHandle;
    }else{
        task.standardError = nil;
    }
    
    [task launch];
    [task waitUntilExit];
    [settingsFileHandle closeFile];
    
    return [OSXSBError errorFromTask:task error:error];
}

-(NSArray*)avaliableSettings{
    NSTask *task = [NSTask new];
    task.launchPath = kOSXServeradmin;
    task.arguments = @[@"list"];
    task.standardOutput = [NSPipe pipe];
    [task launch];
    [task waitUntilExit];
    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *results = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
    return [results componentsSeparatedByString:@"\n"];
}

-(BOOL)backupAllSettings:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    NSArray *avaliableSettings = [self avaliableSettings];
    for(NSString* setting in avaliableSettings){
        [self backupServeradminSettings:setting error:error];
    }
    return [self backupServeradminSettings:@"all" error:error];
}

-(OSStatus)backupAllSettings{
    NSError *error;
    if(![self backupAllSettings:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}


#pragma mark - SQLite/MySQL
-(BOOL)backupSqliteAtPath:(NSString *)path error:(NSError *__autoreleasing *)error{
    if(![self preflightCheck:error]){
        return NO;
    }
    NSTask *task = [NSTask new];
    
    NSString *dbName = [path lastPathComponent];
    NSString *backupFile = [NSString stringWithFormat:@"%@/%@.sqlite",_timeStampDirectory,dbName];
    
    if(![[NSFileManager defaultManager] createFileAtPath:backupFile contents:[NSData data] attributes:nil]){
        [_logFileHandle writeFormatString:@"Could not dump %@ to backup folder",dbName];
        return [OSXSBError errorWithCode:kOSXSBErrorCouldNotCreateFile error:error];
    }
    
    NSFileHandle *dumpFileHandle = [NSFileHandle fileHandleForWritingAtPath:backupFile];
    
    if(_logFileHandle){
        task.standardError = _logFileHandle;
    }else{
        task.standardError = nil;
    }
    
    task.launchPath = @"/usr/bin/sqlite3";
    task.arguments = @[path,@".dump"];
    task.standardOutput = dumpFileHandle;
    
    [task launch];
    [task waitUntilExit];
    
    return [OSXSBError errorFromTask:task error:error];
}


-(OSStatus)backupSqliteAtPath:(NSString *)path{
    NSError *error;
    if(![self backupSqliteAtPath:path error:&error]){
        return (OSStatus)error.code;
    }
    return kOSXSBErrorSuccess;
}

#pragma mark - convenience
-(BOOL)runFromDictionary:(NSDictionary *)dict
             withPasword:(NSString*)password
                starting:(void (^)(NSString *taskName))starting
                complete:(void (^)(NSString *taskName,NSError * error))complete;
{
    BOOL errorOccured = NO;
    
    if(dict[OSXSBPermissionsKey]){
        self.permission = [dict[OSXSBPermissionsKey] integerValue];
    }
    
    self.directory = dict[OSXSBBackupDirectoryKey];
    assert(_directory != nil);
    
    
    if([dict[OSXSBLogBackupKey] boolValue]){
        self.logFile = @"/var/log/osxsbak.log";
    }
    
    if(dict[OSXSBMaxBackupsKey] != nil){
        self.maxBackups = [dict[OSXSBMaxBackupsKey] integerValue];
    }
    
    if(dict[OSXSBServiceOpenDirectoryKey]){
        NSString *taskName = @"Open Directory (dirserv)";
        starting(taskName);
        NSError* taskError;
        if(!password)
            password = getPassword(self.directory,nil);

        if(![self backupOpenDirectoryWithPassword:password error:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    if(dict[OSXSBServiceNamedKey]){
        NSError* taskError;
        NSString *taskName = @"Named (DNS)";
        starting(taskName);
        if(![self backupNamed:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBServiceKeychainKey]){
        NSError* taskError;
        NSString *taskName = @"Keychain";
        starting(taskName);
        if(![self backupKeychain:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBServicePrintersKey]){
        NSError* taskError;
        NSString *taskName = @"Printers";
        starting(taskName);
        if(![self backupPrinters:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBServiceRadiusKey]){
        NSError* taskError;
        NSString *taskName = @"RADIUS";
        starting(taskName);
        if(![self backupRadius:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBServiceMailKey]){
        NSError* taskError;
        NSString *taskName = @"Mail";
        starting(taskName);
        if(![self backupMail:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBServiceServeradminKey]){
        NSError* taskError;
        NSString *taskName = @"OSX Server.app Settings (serveradmin)";
        starting(taskName);
        if(![self backupAllSettings:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBPostgresStandardKey]){
        NSError* taskError;
        NSString *taskName = @"OSX Postgres";
        starting(taskName);
        if(![self backupStandardPostgres:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBPostgresCalendarKey]){
        NSError* taskError;
        NSString *taskName = @"Calendar Postgres (caldav)";
        starting(taskName);
        if(![self backupCalendarPostgres:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBPostgresDevicemgrKey]){
        NSError* taskError;
        NSString *taskName = @"Profile Manger (devicemgr) Postgres";
        starting(taskName);
        if(![self backupDeviceManagerPostgres:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    if(dict[OSXSBPostgresCollabKey]){
        NSError* taskError;
        NSString *taskName = @"Wiki (collab) Postgres";
        starting(taskName);
        if(![self backupWikiPostgres:&taskError]){
            errorOccured = YES;
        }
        complete(taskName,taskError);
    }
    
    return errorOccured;
}

#pragma mark - Utility...
-(BOOL)zip:(NSString*)inPath to:(NSString*)outPath error:(NSError*__autoreleasing*)error{    
    NSString *zipName = [inPath lastPathComponent];
    NSString *finalDest = [NSString stringWithFormat:@"%@/%@.zip",_timeStampDirectory,zipName];
    
    NSTask *task = [NSTask new];
    
    if(_logFileHandle){
        [_logFileHandle writeFormatString:@"Backing up Directory %@\n",inPath];
        
        task.standardError = _logFileHandle;
        task.standardOutput= _logFileHandle;
    }else{
        task.standardOutput = [NSPipe pipe];
        task.standardError  = [NSPipe pipe];
    }
    
    task.launchPath = @"/usr/bin/zip";
    task.currentDirectoryPath = inPath;
    task.arguments = @[@"-r",finalDest,@"./"];
    
    [task launch];
    [task waitUntilExit];
    
    return [OSXSBError errorFromTask:task error:error];
}

-(BOOL)preflightCheck:(NSError*__autoreleasing*)error{
    if(!self.timeStampDirectory || !self.directory){
       return [OSXSBError errorWithCode:kOSXSBErrorMissingArguments error:error];
    }
    return YES;
}

@end


