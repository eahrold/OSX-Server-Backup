//
//  MSBackupTasks.m
//  Mavericks Server Backup
//
//  Created by Eldon on 4/18/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSBackupTasks.h"


@implementation OSXSBackupTasks{
    NSPipe *_logPipe;
    NSFileHandle *_logFileHandle;
}

-(instancetype)initWithDirectory:(NSString*)directory{
    self = [super init];
    if(self){
        self.directory = directory;
    }
    return self;
}

-(void)dealloc{
    if(_logFileHandle){
        [_logFileHandle writeData:[[NSString stringWithFormat:@"Finished OSX Server Backup: %@\n",[NSDate dateWithTimeIntervalSinceNow:0]] dataUsingEncoding:NSASCIIStringEncoding]];
        [_logFileHandle writeData:[self lineBreak]];
        [_logFileHandle closeFile];
    }
}

-(void)setDirectory:(NSString *)directory{
    _directory = directory;
    [self makeBackupDir];
}

-(void)setLogFile:(NSString *)logFile{
    _logFile = logFile;
    [self rotateLog];

    if(![[NSFileManager defaultManager]fileExistsAtPath:logFile isDirectory:nil]){
        [[NSData data] writeToFile:logFile options:0 error:nil];
    }
    
    _logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFile];
    [_logFileHandle seekToEndOfFile];
    [_logFileHandle writeData:[self lineBreak]];
    [_logFileHandle writeData:[[NSString stringWithFormat:@"Starting OSX Server Backup: %@\n",[NSDate dateWithTimeIntervalSinceNow:0]] dataUsingEncoding:NSASCIIStringEncoding]];
}

-(BOOL)makeBackupDir{
        return [[NSFileManager defaultManager]createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
}

-(OSStatus)backupOpenDirectoryWithPassword:(NSString *)archivePassword{
    // TODO: fix NSTask's stdin
    /* For some reason this only works when executed from within xcode.  
       When it's called normally, the slapconfig never gets sent the pass and hangs.
       For now I'm just doing and ugly spawn/expect implamentation...
     */
    return [self backupOpenDirectoryWithPassword2:archivePassword];
    
    if(!archivePassword){
        return -1001;
    }
    
    NSTask *task = [NSTask new];
    NSPipe *pipe = [NSPipe pipe];

    if(_logFileHandle){
        task.standardOutput = _logFileHandle;
    }else{
        task.standardOutput = nil;
    }
    
    task.launchPath = @"/usr/sbin/slapconfig";
    NSString* arcDest = [NSString stringWithFormat:@"%@/ODArchive.dmg",self.directory];
    task.arguments = @[@"-backupdb",arcDest];
    
    
    task.standardInput = pipe;
    NSFileHandle *sendCommand = [pipe fileHandleForWriting];
    NSData *data = [[NSString stringWithFormat:@"%@\r\n",archivePassword]
                    dataUsingEncoding:NSASCIIStringEncoding];
    
 
    [task launch];
    
    [sendCommand writeData:data];
    [sendCommand closeFile];
    
    [task waitUntilExit];
    
    return task.terminationStatus;
}

-(OSStatus)backupOpenDirectoryWithPassword2:(NSString *)archivePassword{
    if(!archivePassword){
        return -1001;
    }
    
    NSTask *task = [NSTask new];
    task.launchPath = @"/bin/bash";
    task.currentDirectoryPath = self.directory;
    
    if(_logFileHandle){
        task.standardOutput = _logFileHandle;
    }else{
        task.standardOutput = nil;
    }
    
    NSString *spawn = [NSString stringWithFormat: @"expect <<- DONE\nset timeout -1\n\
                                                    spawn /usr/sbin/slapconfig -backupdb ./ODArchive.dmg\n\
                                                    expect \"*?assword:*\"\n\
                                                    send \"%@\r\"\n\
                                                    send  \"\r\"\n\
                                                    expect eof\nDONE",archivePassword];
    
    task.arguments = @[@"-c",spawn];
    [task launch];
    [task waitUntilExit];
    
    return task.terminationStatus;
}

-(OSStatus)backupPostgressDB:(NSString*)database socketDir:(NSString *)socketDir user:(NSString *)user dumpAll:(BOOL)dumpAll{
    
    NSString *file = [NSString stringWithFormat:@"%@/pg_backup_%@",self.directory,dumpAll ? @"osx_all":database];
    
    NSTask *task = [NSTask new];
    if(_logFileHandle){
        [_logFileHandle writeData:[[NSString stringWithFormat:@"Backing up %@ PostgresDB...\n",database ? database:user] dataUsingEncoding:NSUTF8StringEncoding]];
        task.standardError = _logFileHandle;
        task.standardOutput= _logFileHandle;
    }else{
        task.standardOutput = [NSPipe pipe];
        task.standardError  = [NSPipe pipe];
    }

    
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"-h",socketDir,@"-f",file,@"-U",user]];
    
    if(dumpAll){
        task.launchPath = @"/Applications/Server.app/Contents/ServerRoot/usr/bin/pg_dumpall";
    }else{
        task.launchPath = @"/Applications/Server.app/Contents/ServerRoot/usr/bin/pg_dump";
        [args addObject:database];
    }
    
    task.arguments = args;
    
    [task launch];
    [task waitUntilExit];
    
    return task.terminationStatus;
}

-(OSStatus)backupStandardPostgres{
    NSString *socketDir = @"/var/pgsql_socket";
    NSString *user = @"_postgres";
    return [self backupPostgressDB:nil socketDir:socketDir user:user dumpAll:YES];
}

-(OSStatus)backupCalendarPostgres{
    NSString *socketDir = @"/var/run/caldavd/PostgresSocket/";
    NSString *user = @"caldav";
    NSString *db =@"caldav";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO];
}

-(OSStatus)backupDeviceManagerPostgres{
    NSString *socketDir = @"/Library/Server/ProfileManager/Config/var/PostgreSQL/";
    NSString *user = @"_devicemgr";
    NSString *db =@"devicemgr_v2m0";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO];
}

-(OSStatus)backupWikiPostgres{
    // user collab to dump coolab, and user _teamserver to dump all
    NSString *socketDir = @"/Library/Server//Wiki/PostgresSocket/";
    NSString *user = @"collab";
    NSString *db = @"collab";
    return [self backupPostgressDB:db socketDir:socketDir user:user dumpAll:NO];
}

-(OSStatus)backupKeychain{
    return 0;

}

-(OSStatus)backupNamed{
    NSString *namedDir = @"/Library/Server/named";
    return [self zip:namedDir to:self.directory];
}


-(OSStatus)backupCertificateAuthorities{
    return 0;
}

#pragma mark - Utility...
-(OSStatus)zip:(NSString*)inPath to:(NSString*)outPath{
    NSString *zipName = [inPath lastPathComponent];
    NSString *finalDest = [NSString stringWithFormat:@"%@/%@.zip",self.directory,zipName];
    
    NSTask *task = [NSTask new];
    
    if(_logFileHandle){
        [_logFileHandle writeData:[[NSString stringWithFormat:@"Backing up Directory %@\n",inPath] dataUsingEncoding:NSUTF8StringEncoding]];
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
    
    return task.terminationStatus;
}

-(void)rotateLog{
    NSDateComponents *components = [NSDateComponents new];
    [components setMonth:-1];
    NSDate *lastMonth = [[NSCalendar currentCalendar] dateByAddingComponents:components
                                                                      toDate:[NSDate date]
                                                                     options:0];
    
    NSLog(@"%@",lastMonth);
    
    NSDictionary *fileAttrs = nil;
    NSFileManager *fm = [NSFileManager new];
    if([fm fileExistsAtPath:_logFile isDirectory:nil]){
        NSDate *creationDate = nil;
        fileAttrs = [fm attributesOfItemAtPath:_logFile error:nil];
        creationDate = fileAttrs[@"NSFileCreationDate"];
        
        if([lastMonth compare:creationDate] == NSOrderedDescending){
            NSLog(@"Rotating Log file...");
            //TODO: rotate log file...
        }
    }
    
}

-(NSData*)lineBreak{
    return [@"=============================================================================\n" dataUsingEncoding:NSASCIIStringEncoding];
}

@end
