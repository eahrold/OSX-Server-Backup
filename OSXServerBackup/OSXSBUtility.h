//
//  OSXSBUtility.h
//  OSX Server Backup
//
//  Created by Eldon on 4/23/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSXSBackupTasks.h"

#define RESET       "\033[0m"
#define BOLDRED     "\033[1m\033[31m"      /* Bold Red */
#define BOLDBLACK   "\033[1m\033[30m"      /* Bold Black */
#define BOLDBLUE    "\033[1m\033[34m"      /* Bold Blue */


BOOL selfInstall(const char *path, NSError *__autoreleasing*);
BOOL selfLink(const char *path,NSError *__autoreleasing*);

BOOL makeBackupDir(NSString* directory,OSXSBPermissionLevel permissions);
BOOL removeExcessBackups(NSString* directory,NSInteger maxBackups);
BOOL restrictPermissions(NSString * directory,OSXSBPermissionLevel permissions);

NSString *timeStampedFolder(NSString* directory);
NSDictionary * OSXSBackupPermission(OSXSBPermissionLevel permissions);

void rotateLog(NSString *logFile,NSCalendarUnit unit);
BOOL bZip2File(NSString* filePath,BOOL overwrite, NSError *__autoreleasing* error);

NSString* getPassword(NSString* backupDir, NSError **error);
BOOL setKeychainPassword(NSString *password,NSError **error);
BOOL removeKeychainPassword(NSError **error);
BOOL checkForKeychainItem(NSError **error);

NSString *embeddedVersionOfItemAtPath(NSString* path);

// convience formatter string....
static NSString *osxsbakLineBreak =
@"=============================================================================\n";