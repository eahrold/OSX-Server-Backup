//
//  OSXSBUtility.m
//  OSX Server Backup
//
//  Created by Eldon on 4/23/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSBUtility.h"
#import "OSXSBError.h"
#import "AHKeychainManager.h"

#pragma mark - Install
BOOL selfInstallCheck(NSString * exeSelf, NSString * exeDest, NSError *__autoreleasing* error){
    NSFileManager *manager = [NSFileManager new];
    
    if([exeSelf isEqualToString:exeDest]){
        return [OSXSBError errorWithCode:kOSXSBErrorCannotCopyToSelf error:error];
    }
    
    if([manager fileExistsAtPath:exeDest]){
        if(![manager removeItemAtPath:exeDest error:error]){
            return NO;
        }
    }
    
    if(![manager fileExistsAtPath:osxsbakInstallDirectory]){
        if(![manager createDirectoryAtPath:osxsbakInstallDirectory withIntermediateDirectories:YES attributes:OSXSBackupPermission(kOSXSBPermissionNone) error:error]){
            return NO;
        }
    }
    
    return YES;
}

BOOL selfInstall(const char *path, NSError *__autoreleasing* error)
{
    NSString *exeSelf = [NSString stringWithUTF8String:path];
    NSString *exeDest = [osxsbakInstallDirectory stringByAppendingPathComponent:@"osxsbak"];
    
    NSFileManager *manager = [NSFileManager new];
    if(selfInstallCheck(exeSelf, exeDest, error)){
        if([manager copyItemAtPath:exeSelf toPath:exeDest error:error]){
            printf("%sosxsbak was installed into /usr/local/sbin/%s\n",BOLDBLUE,RESET);
            return YES;
        }
    }
    
    return NO;
}

BOOL selfLink(const char *path,NSError *__autoreleasing* error)
{
    NSString *exeSelf = [NSString stringWithUTF8String:path];
    NSString *exeDest = [osxsbakInstallDirectory stringByAppendingPathComponent:@"osxsbak"];
    
    NSFileManager *manager = [NSFileManager new];
    if(selfInstallCheck(exeSelf, exeDest, error)){
        if([manager linkItemAtPath:exeSelf toPath:exeDest error:error]){
            printf("%sa symlink was created for osxsbak at /usr/local/sbin/%s\n",BOLDBLUE,RESET);
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Backup Directory Functions
BOOL makeBackupDir(NSString* directory,OSXSBPermissionLevel permissions)
{
    NSFileManager *fm = [NSFileManager new];
    BOOL rc = YES;
    if(![fm fileExistsAtPath:directory]){
        rc = [fm createDirectoryAtPath:directory
           withIntermediateDirectories:YES
                            attributes:OSXSBackupPermission(permissions)
                                 error:nil];
    }else{
        rc = restrictPermissions(directory,permissions);
    }
    // we put a market here to make sure that on backup removal
    // we're actually removing a osxsbak backup
    [fm createFileAtPath:[directory stringByAppendingPathComponent:@".osxsbak"] contents:[NSData data] attributes:nil];
    
    return rc;
}

BOOL removeExcessBackups(NSString* directory,NSInteger maxBackups){
    if(maxBackups <= 0 )return YES;
    NSFileManager *fm = [NSFileManager new];
    NSArray *folerList = [fm contentsOfDirectoryAtPath:directory error:nil];
    
    NSMutableArray *backups = [[NSMutableArray alloc]initWithCapacity:folerList.count];
    for (NSString *folder in folerList){
        NSString *bkCheck = [NSString stringWithFormat:@"%@/%@/.osxsbak",directory,folder];
        if([fm fileExistsAtPath:bkCheck])
            [backups addObject:folder];
    }
    
    NSInteger removeCount = backups.count - maxBackups;
    for(int i = 0;i < removeCount;i++){
        [fm removeItemAtPath:[directory stringByAppendingPathComponent:backups[i]] error:nil];
    }
    return YES;
}

BOOL restrictPermissions(NSString * directory,OSXSBPermissionLevel permissions)
{
    return [[NSFileManager defaultManager]setAttributes:OSXSBackupPermission(permissions) ofItemAtPath:directory error:nil];
}

#pragma mark -
NSDictionary * OSXSBackupPermission(OSXSBPermissionLevel perms){
    NSNumber *permOctInt;
    switch (perms) {
        case kOSXSBPermissionNone:
            permOctInt = [NSNumber numberWithShort:0755];
            break;
        case kOSXSBPermissionWeak:
            permOctInt = [NSNumber numberWithShort:0750];
            break;
        case kOSXSBPermissionStrong:
            permOctInt = [NSNumber numberWithShort:0700];
            break;
        default:
            permOctInt = [NSNumber numberWithShort:0700];
            break;
    }
    
    return @{NSFileOwnerAccountName:@"root",
             NSFileGroupOwnerAccountName:@"admin",
             NSFilePosixPermissions:permOctInt};
}

NSString *timeStampedFolder(NSString* directory)
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
    return [NSString stringWithFormat:@"%@/%@",directory,[dateFormatter stringFromDate:[NSDate date]]];
}


#pragma mark - Archiving
void rotateLog(NSString *logFile,NSCalendarUnit unit)
{
    NSDateComponents *components = [NSDateComponents new];
    switch (unit) {
        case NSCalendarUnitDay:
            [components setDay:-1];
            break;
        case NSCalendarUnitMonth:
            [components setMonth:-1];
            break;
        case NSCalendarUnitYear:
            [components setYear:-1];
        default:
            [components setMonth:-1];
            break;
    }
    
    NSDate *rotateDate = [[NSCalendar currentCalendar] dateByAddingComponents:components
                                                                      toDate:[NSDate date]
                                                                     options:0];
    NSDictionary *fileAttrs = nil;
    NSFileManager *fm = [NSFileManager new];
    if([fm fileExistsAtPath:logFile isDirectory:nil]){
        fileAttrs = [fm attributesOfItemAtPath:logFile error:nil];
        NSDate * creationDate = fileAttrs[NSFileCreationDate];
        if([rotateDate compare:creationDate] == NSOrderedDescending){
            NSLog(@"Rotating Log file...");
            bZip2File(logFile,YES,nil);
        }
    }
}

BOOL bZip2File(NSString* filePath,BOOL overwrite, NSError *__autoreleasing* error){
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/bzip2";
    if (overwrite) {
        task.arguments = @[@"-f",filePath];
    }else{
        task.arguments = @[filePath];
    }
    [task launch];
    [task waitUntilExit];
    return [OSXSBError errorFromTask:task error:error];
}

#pragma mark - Password
AHKeychainManager * setupKeychainManager(){
    AHKeychainManager *item = [[AHKeychainManager alloc] init];
    item.service = osxsbakPersistentDomain;
    item.account = @"root";
    item.keychainDomain = kAHKeychainDomainSystem;
    return item;
}


NSString * getPassword(NSString* backupDir,NSError *__autoreleasing*error){
    NSString* password;
    password = [[NSString alloc]initWithContentsOfFile:[NSString stringWithFormat:@"%@/.archivePass",backupDir]
                                              encoding:NSASCIIStringEncoding
                                                 error:nil];
    if(password == nil){
        AHKeychainManager *item = setupKeychainManager();
        [item get:error];
        password = item.password;
    }
    return password;
}

BOOL setKeychainPassword(NSString *password,NSError *__autoreleasing*error){
//    return [SSKeychain setPassword:password forService:osxsbakPersistentDomain account:@"root" error:error];
    AHKeychainManager *item = setupKeychainManager();
    item.password = password;
    item.trustedApplications = @[@"/usr/local/sbin/osxsbak",
                                 @"/Library/PrivilegedHelperTools/com.eeaapps.osxsbak.helper",
                                 @"/usr/bin/security"];
    
    return [item save:error];
}

BOOL removeKeychainPassword(NSError *__autoreleasing*error){
    AHKeychainManager *item = setupKeychainManager();
    return [item remove:error];
}

BOOL checkForKeychainItem(NSError **error){
    AHKeychainManager *item = setupKeychainManager();
    return [item find:error];
}


#pragma mark - Versioning
NSString *embeddedVersionOfItemAtPath(NSString* path){
    NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSDictionary* infoPlist = (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((__bridge CFURLRef)(url)));
    return infoPlist[@"CFBundleVersion"];
}

