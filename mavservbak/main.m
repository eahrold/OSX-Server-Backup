//
//  main.m
//  mavservbak
//
//  Created by Eldon on 4/19/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSXSBackupTasks.h"
#import <getopt.h>

#define RESET       "\033[0m"
#define BOLDRED     "\033[1m\033[31m"      /* Bold Red */
#define BOLDBLACK   "\033[1m\033[30m"      /* Bold Black */
#define BOLDBLUE    "\033[1m\033[34m"      /* Bold Blue */

const char     *version = "0.1";
NSString *controllerID = @"com.eeaapps.Mavericks-Server-Backup";

#pragma mark - messages
int usage(int rc)
{
    printf("\n%sBackup OSX Server Data and Settings%s\n",BOLDBLUE,RESET);
    printf("Usage: ../../mavservbak [settings] [options]\n");
    printf("Settings:\n");
    printf("  -B|--backupdir=/path/to/backup    Full Path to Backup Directory\n");
    printf("  -P|--password=yourpass            Archiving OpenDirectory requires a password.\n");
    printf("                                    if you dont't specify one it will look for a file \n");
    printf("                                    named .archivePass in the root of the Backup Directory\n\n");
    printf("  -V|--verbose                      Full Path to Backup Directory\n");
    printf("  -N|--nolog                        do not send output to /var/log/mavservback.log\n");

    printf("Options:\n");
    printf("  --dirserv                Backup OpenDirectory\n");
    printf("  --named                  Backup Named\n");
    printf("  --keychain               Backup Keychains and Certificate Authorities\n");
    printf("  --pg-osx                 Backup OSX Postgres\n");
    printf("  --pg-caldav              Backup Calendar and Contacts Postgres\n");
    printf("  --pg-devicemgr           Backup Profile Manger Postgres\n");
    printf("  --pg-wiki                Backup Wiki/Collabd Postgres\n");
    printf("\n");
    printf("Example: to backup Open Dirctory,DNS and OSX's Postgres run\n");
    printf("/usr/sbin/mavservbak --backupdir=/Volumes/Backup/folder --opendir --password=mypass --named --pg-osx\n\n");

    return rc;
}

void printfSuccessStatus(OSStatus status){
    if(status != 0){
        printf("%sFailed%s\n",BOLDRED,RESET);
    }else{
        printf("%sSuccess%s\n",BOLDBLUE,RESET);
    }
}

void printfBackupMessage(const char* message){
    printf("Backing up: %s ... ",message);
    fflush(stdout);
}

#pragma mark - util
NSString* getPassword(NSString* backupDir){
    NSString* password;
    password = [[NSString alloc]initWithContentsOfFile:[NSString stringWithFormat:@"%@/.archivePass",backupDir]
                                                   encoding:NSASCIIStringEncoding
                                                      error:nil];
    
    return password;
}

NSString *timeStampedFolder(NSString* directory){
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
    NSDate *date = [NSDate date];
    NSString *dateStr = [dateFormatter stringFromDate:date];
    return [NSString stringWithFormat:@"%@/%@",directory,dateStr];
}

#pragma mark - main
int main(int argc, char * argv[])
{

    @autoreleasepool {

        int c;
        int bk_dirserv      = 0,
            bk_named        = 0,
            bk_keychain     = 0,
            bk_pg_osx       = 0,
            bk_pg_caldav    = 0,
            bk_pg_devicemgr = 0,
            bk_pg_wiki      = 0;
        
        NSString *backup_folder_location = nil;
        NSString *archive_password = nil;
        BOOL logbackup = YES;
        
        // Parse options...
        struct option longopts[] = {
            { "backupdir"     , required_argument, NULL,       'B'},
            { "password"      , required_argument, NULL,       'P'},
            { "dirserv"       , no_argument, & bk_dirserv,      1 },
            { "named"         , no_argument, & bk_named,        1 },
            { "keychian"      , no_argument, & bk_keychain,     1 },
            { "pg-osx"        , no_argument, & bk_pg_osx,       1 },
            { "pg-caldav"     , no_argument, & bk_pg_caldav,    1 },
            { "pg-devicemgr"  , no_argument, & bk_pg_devicemgr, 1 },
            { "pg-wiki"       , no_argument, & bk_pg_wiki,      1 },
            { "nolog"         , no_argument, NULL,             'N'},
            { "version"       , no_argument, NULL,             'v'},
            { "usage"         , no_argument, NULL,             'h'},
            { "help"          , no_argument, NULL,             'h'},
        };
        
        while ((c = getopt_long(argc, argv, "hvB:P:", longopts, NULL)) != -1){
            switch (c) {
                case 'B':
                    backup_folder_location = [NSString stringWithFormat:@"%s",optarg];
                    break;
                case 'P':
                    archive_password = [NSString stringWithFormat:@"%s",optarg];
                    break;
                case 'N':
                    logbackup = NO;
                    break;
                case 'h':
                    return usage(1);
                case 'v':
                    printf("%s\n",version);
                    return 0;
            }
        };
        
        
        // Sanity Checks...
        if (getuid() != 0){
            printf("mavservback must run as root\n");
            return -1;
        }
        
        if(!backup_folder_location){
            printf("No Backup Directory Specified, exiting\n");
            return usage(1);
        }
        
        if(bk_dirserv && !archive_password){
            archive_password = getPassword(backup_folder_location);
            if(!archive_password){
                printf("Backing up open directory requires a password\n");
                return -1001;
            }
        }
        
        printf("%sStarting Backups...%s\n",BOLDBLACK,RESET);

        OSStatus err        = 0;
        OSStatus status     = 0;
        OSXSBackupTasks *backupTask = [[OSXSBackupTasks alloc]initWithDirectory:timeStampedFolder(backup_folder_location)];
        
        if(logbackup)
            backupTask.logFile = @"/var/log/mavserverback.log";
        
        if(bk_dirserv == 1){
            printfBackupMessage("OpenDirectory");
            status = [backupTask backupOpenDirectoryWithPassword:archive_password];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_named == 1){
            printfBackupMessage("Named (DNS)");
            status = [backupTask backupNamed];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_keychain == 1){
            printfBackupMessage("Keychain");
            status = [backupTask backupKeychain];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_pg_osx == 1){
            printfBackupMessage("OSX Postgres");
            status = [backupTask backupStandardPostgres];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_pg_wiki){
            printfBackupMessage("Wiki Postgres");
            status = [backupTask backupWikiPostgres];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        if(bk_pg_devicemgr == 1){
            printfBackupMessage("Profile Manager Postgres");
            status = [backupTask backupDeviceManagerPostgres];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_pg_caldav){
            printfBackupMessage("Calendar and Contacts Postgres");
            status = [backupTask backupCalendarPostgres];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(err > 0)
            printf("There were errors during tha backup, check the logs for more details");
        
        // nil this to trigger dealloc...
        backupTask = nil;
        return err;
    }
    
    return 0;
}

