//
//  main.m
//  mavservbak
//
//  Created by Eldon on 4/19/14.
//  Copyright (c) 2014 Eldon Ahrold.
//

#import <Foundation/Foundation.h>
#import "OSXSBackupTasks.h"
#import "OSXSBUtility.h"
#import <getopt.h>

int usage(int rc);
const char *version();
void printfSuccessStatus(OSStatus status);
void printfBackupMessage(const char* message);
void printfErrorString(NSString* string);
OSStatus printfError(NSError *error);

#pragma mark - main
int main(int argc, char * argv[])
{

    @autoreleasepool {

        int c;
        int bk_settings     = 0,
            bk_printers     = 0,
            bk_dirserv      = 0,
            bk_named        = 0,
            bk_keychain     = 0,
            bk_radius       = 0,
            bk_pg_osx       = 0,
            bk_pg_caldav    = 0,
            bk_pg_devicemgr = 0,
            bk_pg_wiki      = 0;
        
        NSError         *error = nil;
        NSString        *backup_folder_location = nil;
        NSString        *archive_password = nil;
        NSMutableArray  *sqliteArray = nil;
        BOOL             logbackup = YES;
        BOOL             install = NO;
        BOOL             write_settigs = NO;
        BOOL             reset_settigs = NO;
        OSXSBPermissionLevel permissions   = kOSXSBPermissionStrong;
        NSInteger            max_backups = 0;
        
        // Parse options...
        struct option longopts[] = {
            { "backupdir"     , required_argument, NULL,       'B'},
            { "password"      , required_argument, NULL,       'P'},
            
            { "dirserv"       , no_argument, & bk_dirserv,      1 },
            { "printers"      , no_argument, & bk_printers,     1 },
            { "named"         , no_argument, & bk_named,        1 },
            { "keychain"      , no_argument, & bk_keychain,     1 },
            { "radius"        , no_argument, & bk_radius,       1 },
            { "settings"      , no_argument, & bk_settings,     1 },
            
            { "pg-osx"        , no_argument, & bk_pg_osx,       1 },
            { "pg-caldav"     , no_argument, & bk_pg_caldav,    1 },
            { "pg-devicemgr"  , no_argument, & bk_pg_devicemgr, 1 },
            { "pg-wiki"       , no_argument, & bk_pg_wiki,      1 },
            { "sqlite"        , required_argument, NULL,       'm'},

            { "nolog"         , no_argument, NULL,             'N'},
            { "install"       , no_argument, NULL,             'I'},
            { "set"           , no_argument, NULL,             'S'},
            { "reset"         , no_argument, NULL,             'R'},
            { "permissions"   , required_argument, NULL,       'L'},
            { "max-backups"   , required_argument, NULL,       'M'},

            { "version"       , no_argument, NULL,             'v'},
            { "usage"         , no_argument, NULL,             'h'},
            { "help"          , no_argument, NULL,             'h'},
            {  NULL, 0 , 0 , 0} // NULL row to catch anything unknown.
        };
        
        while ((c = getopt_long(argc, argv, "hvB:L:P:", longopts, NULL)) != -1){
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
                case 'L':
                    if (!strcmp(optarg, "weak"))
                        permissions = kOSXSBPermissionWeak;
                    else if (!strcmp(optarg, "none"))
                        permissions = kOSXSBPermissionNone;
                    else
                        permissions = kOSXSBPermissionStrong;
                    break;
                case 'M':
                    max_backups = [[NSString stringWithUTF8String:optarg] integerValue];
                    break;
                case 'S':
                    write_settigs = YES;
                    break;
                case 'I':
                    install = YES;
                    break;
                case 'R':
                    reset_settigs = YES;
                    break;
                case 'h':
                    return usage(1);
                case 'v':
                    printf("%s\n",version());
                    return 0;
                case 'm':
                    if(!sqliteArray){
                        sqliteArray = [NSMutableArray new];
                    }
                    [sqliteArray addObject:[NSString stringWithFormat:@"%s",optarg]];
                    break;
            }
        };
        
        
        // Sanity Checks...
        if (getuid() != 0){
            printfErrorString(@"osxsbak must run as root");
            return -1;
        }
        
        if(install){
            char* resolved = NULL;
            char* fullpath = realpath(argv[0], resolved);
            if(!selfInstall(fullpath,&error)){
                exit(printfError(error));
            }
            exit(0);
        }
        
        NSUserDefaults *defaults = [NSUserDefaults new];
        if(reset_settigs){
            
            printf("%sResetting stored settings.%s\n   This has no effect on Launched Daemons\n",BOLDBLUE,RESET);

            [defaults removePersistentDomainForName:osxsbakPersistentDomain];
            if(!removeKeychainPassword(&error)){
                printfErrorString(error.localizedDescription);
            }
            return 0;
        }
        
        if(write_settigs){
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults persistentDomainForName:osxsbakPersistentDomain]];
            
            if (backup_folder_location)
                [dict setObject:backup_folder_location forKey:@"BackupDirectory"];
            
            printf("%sSetting defaults. From now on these will be used when nothing is specified\n%s",BOLDBLUE,RESET);
            for (id key in [dict allKeys]){
                printf("   %s\n",[[NSString stringWithFormat:@"%@ = %@",key,dict[key]] UTF8String]);
            }
            
            if(archive_password && ![archive_password isEqualToString:@""]){
                printf("   ArchivePassword = %s****\n",[[archive_password substringToIndex:2] UTF8String]);
                setKeychainPassword(archive_password,&error);
                if(error)printfErrorString(error.localizedDescription);
            }
            
            [defaults setPersistentDomain:dict forName:osxsbakPersistentDomain];
            return 0;
        }
        
        if(!backup_folder_location && !(backup_folder_location = [defaults persistentDomainForName:osxsbakPersistentDomain][@"BackupDirectory"])){
            printfErrorString(@"No Backup Directory Specified. specify one with \"--backupdir=/path/to/backup/\" see -h for usage.");
            return 1;
        }
        
        
        if(bk_dirserv && !archive_password){
            archive_password = getPassword(backup_folder_location,nil);
            if(!archive_password){
                printfErrorString(@"Backing up Open Directory requires a password\n\
                                  Please set on in your keychain using ../osxsbak --set --password=yourpass\n\
                                  or put a file called .archivePass in the root of your backup directory");
                return kOSXSBErrorNoPasswordForArchive;
            }
        }
        
        printf("%sStarting Backups...%s\n",BOLDBLACK,RESET);

        OSStatus err        = 0;
        OSStatus status     = 0;
        OSXSBackupTasks *backupTask = [[OSXSBackupTasks alloc]initWithDirectory:backup_folder_location permission:permissions];
        backupTask.maxBackups = max_backups;
        
        if(logbackup)
            backupTask.logFile = @"/var/log/osxsbak.log";
        
        if(bk_settings == 1){
            printfBackupMessage("Server Settings");
            status = [backupTask backupAllSettings];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
        if(bk_printers == 1){
            printfBackupMessage("Printers");
            status = [backupTask backupPrinters];
            printfSuccessStatus(status);
            if(status != 0){
                err = 1;
            }
        }
        
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
        if(bk_radius == 1){
            printfBackupMessage("RADIUS");
            status = [backupTask backupRadius];
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
        
        if(sqliteArray){
            for(NSString* db in sqliteArray){
                NSString *msg = [NSString stringWithFormat:@"%@ sqlite3 database",[db lastPathComponent]];
                printfBackupMessage(msg.UTF8String);
                [backupTask backupSqliteAtPath:db];
                printfSuccessStatus(status);
                if(status != 0){
                    err = 1;
                }
            }
        }
        
        if(err > 0)
            printf("There were errors during tha backup, check the logs for more details\n");
        
        // nil this to trigger dealloc...
        backupTask = nil;
        return err;
    }
    
    return 0;
}

const char *version(){
    NSString *path = [[NSProcessInfo processInfo]arguments][0];
    return embeddedVersionOfItemAtPath(path).UTF8String;
}

#pragma mark - messages
int usage(int rc)
{
    printf("%sosxsbak version %s.  Backup OSX Server Data and Settings%s\n",version(),BOLDBLUE,RESET);
    printf("Usage: ../../osxsbak [action] [settings] [options]\n");
    printf("Actions:\n");
    printf("  -I|--install                      Install at /usr/local/sbin/osxsbak\n");
    printf("  -S|--set                          If you specify set it will set any settings passed in. (Will not run backup)\n");
    printf("  -R|--reset                        Clear any previously set defaults and keychain itmes.\n");
    printf("\n");
    printf("Settings:\n");
    printf("  -B|--backupdir=/path/to/backup    Full Path to Backup Directory\n");
    printf("  -P|--password=yourpass            Archiving Open Directory requires a password.\n");
    printf("                                    if you dont't specify one it will look for a file \n");
    printf("                                    named .archivePass in the root of the Backup Directory\n");
    printf("                                    then will check the system keychain for an item\n");
    printf("                                    named com.eeaapps.osxsbak\n");
    printf("  -N|--nolog                        do not send output to /var/log/osxsbak.log\n");
    printf("  -L|--permission=strong/weak/none  Limit posix permissions on backup dirctory\n");
    printf("                                    \"strong\" for 700, \"weak\" for 750 \"none\" for 755.  Defaults to strong\n");
    printf("                                    The Owner is always root and the group always admin\n");
    printf("\n");
    printf("Options:\n");
    printf("  --settings                        Backup Server.app (serveradmin) settings \n");
    printf("  --dirserv                         Backup OpenDirectory\n");
    printf("  --named                           Backup Named\n");
    printf("  --radius                          Backup Radius\n");
    printf("  --keychain                        Backup Keychains and Certificate Authorities\n");
    printf("  --printers                        Backup Printers\n");
    printf("  --pg-osx                          Backup OSX Postgres\n");
    printf("  --pg-caldav                       Backup Calendar and Contacts Postgres\n");
    printf("  --pg-devicemgr                    Backup Profile Manger Postgres\n");
    printf("  --pg-wiki                         Backup Wiki/Collabd Postgres\n");
    printf("  --sqlite=/path/to/sqlite.db       Backup sqlite3 DB at specified path\n");
    printf("                                           this can be specified multiple times\n");
    printf("\n");
    printf("Example: to backup Open Dirctory,DNS and OSX's Postgres run\n");
    printf("/usr/sbin/osxsbak --backupdir=/Volumes/Backup/folder --password=mypass --dirserv --named --pg-osx\n\n");
    
    return rc;
}

void printfSuccessStatus(OSStatus status){
    const char * msg;
    const char * color;
    switch (status) {
        case kOSXSBErrorSuccess:
            msg = "Success";
            color = BOLDBLUE;
            break;
        case kOSXSBErrorServiceNotRunning:
            msg = "Not Running";
            color = BOLDBLUE;
            break;
        case kOSXSBErrorFeatureNotImplamented:
            msg = "Feature Not yet implamented";
            color = BOLDBLACK;
            break;
        default:
            msg = "Failed";
            color = BOLDRED;
            break;
    }
    printf("%-10s%s%s\n",color,msg,RESET);
    fflush(stdout);
}

void printfBackupMessage(const char* message){
    printf("Backing up: %-15s %-40s",message,"........................................   ");
    fflush(stdout);
}

void printfErrorString(NSString* string){
    printf("%s%s%s\n",BOLDRED,string.UTF8String,RESET);
    fflush(stdout);
}
OSStatus printfError(NSError *error){
    printfErrorString(error.localizedDescription);
    return (OSStatus)error.code;
}


