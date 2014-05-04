//
//  OSXSBHelper.m
//  OSX Server Backup
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSBHelper.h"
#import "OSXSBInterfaces.h"
#import "OSXSBackupTasks.h"
#import "OSXSBUtility.h"

#import "AHCodesignValidator.h"
#import "AHLaunchCtl.h"
#import <syslog.h>

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

static NSString * kOSXSBCliTool = @"/usr/local/sbin/osxsbak";

@interface OSXSBHelper ()<OSXSBHelperAgent,NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener   *listener;
@property (weak)                      NSXPCConnection *connection;
@property (nonatomic, assign)         BOOL             helperToolShouldQuit;
@end

@implementation OSXSBHelper

-(id)init{
    self = [super init];
    if(self){
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kOSXSBHelperName];
        self->_listener.delegate = self;
    }
    return self;
}

-(void)run{
    [self.listener resume];
    while (!self.helperToolShouldQuit)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
}

-(void)setKeychainPassword:(NSString *)password
             authorization:(NSData *)authData
                     reply:(void (^)(NSError *))reply{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        setKeychainPassword(password, &error);
    }
    reply(error);
}

-(void)installCliToolAtPath:(NSString*)path
                      reply:(void (^)(NSError *))reply{
    NSError *error;
    NSString *helperToolPath = [[NSProcessInfo processInfo]arguments][0];
   
    if([AHCodesignValidator certOfItemAtPath:path
                          isSameAsItemAtPath:helperToolPath error:&error]){
        NSFileManager *fm = [NSFileManager new];
        if([fm fileExistsAtPath:kOSXSBCliTool isDirectory:nil]){
            if([fm removeItemAtPath:kOSXSBCliTool error:&error]){
                reply(error);return;
            }
        }
        [fm copyItemAtPath:path toPath:kOSXSBCliTool error:&error];
    }
    reply(error);
}

-(void)removeCliToolWithAuthorization:(NSData *)authData
                                reply:(void (^)(NSError *))reply
{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        // do stuff;
    }
    reply(error);

    
}

-(void)uninstallWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        // do stuff;
    }
    reply(error);
}

-(void)scheduleBackupWithTaskDict:(NSDictionary *)dict
                         schedule:(AHLaunchJobSchedule*)schedule
                    authorization:(NSData *)authData
                            reply:(void (^)(NSError *))reply{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        NSString *suffix;
        if(schedule.weekday != AHUndefinedSchedulComponent){
            suffix = @"run.weekly";
        }else{
            suffix = @"run.daily";
        }
        
        AHLaunchJob *job = [[AHLaunchJob alloc]init];
        job.Label = [osxsbakPersistentDomain stringByAppendingPathExtension:suffix];
        job.ProgramArguments = [@[kOSXSBCliTool] arrayByAddingObjectsFromArray:[self argsFromDict:dict]];
        job.StartCalendarInterval = schedule;
        job.LowPriorityIO = YES;
        
        [[AHLaunchCtl sharedControler]add:job toDomain:kAHGlobalLaunchDaemon error:&error];
    }
    reply(error);
}

-(void)removeScheduledJob:(NSString *)which
        withAuthorization:(NSData *)authData
                    reply:(void (^)(NSError *))reply{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        NSString *job = [osxsbakPersistentDomain stringByAppendingFormat:@".run.%@",which];
        [[AHLaunchCtl sharedControler] remove:job fromDomain:kAHGlobalLaunchDaemon error:&error];
    
    }
    reply(error);
}

-(void)runBackupWithTaskDict:(NSDictionary *)dict
                    password:(NSString*)password
                   authorization:(NSData *)authData
                           reply:(void (^)(NSError *))reply
{
    NSError *error;
    if([OSXSBAuthorizer checkAuthorization:authData command:_cmd error:&error]){
        [[self.connection remoteObjectProxy]startProgressPanel];
        NSOperationQueue *bkQueue = [NSOperationQueue new];
        [bkQueue addOperationWithBlock:^{
            NSError *runError;
            NSString *backupDest = dict[OSXSBBackupDirectoryKey];
            assert(backupDest != nil);
            
            OSXSBackupTasks *backupTask = [[OSXSBackupTasks alloc]init];
            __weak OSXSBHelper *responseSelf = self;
            
            BOOL rc = [backupTask runFromDictionary:dict
                                        withPasword:password
                                           starting:^(NSString *task){
                                               [responseSelf sendProgressMessageBack:[NSString stringWithFormat:@"Starting backup of %@...",task]];
                                           }
                                           complete:^(NSString *task, NSError *error) {
                                               NSString *msg = [NSString stringWithFormat:@"Backed up %@ : %@",task, error ? @"Failed":@"Success\n"];
                                               [responseSelf sendProgressMessageBack:msg];
                                               if(error){
                                                   [responseSelf sendProgressMessageBack:[error.localizedDescription stringByAppendingString:@"\n"]];
                                               }
                                           }];
            
            [responseSelf sendProgressMessageBack:@"Backup complete."];
            if(!rc)[OSXSBError errorWithCode:1 error:&runError];
            reply(runError);
        }];
    }
    reply(error);    
}

-(NSArray*)argsFromDict:(NSDictionary*)dict{
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:dict.count];
    NSString *backupDest = dict[OSXSBBackupDirectoryKey];
    assert(backupDest != nil);

    // Settings
    [args addObject:[NSString stringWithFormat:@"--backupdir=%@",backupDest]];

    if([dict[OSXSBPermissionsKey] integerValue] == kOSXSBPermissionWeak){
        [args addObject:@"--permissions=weak"];
    }else{
        [args addObject:@"--permissions=strong"];
    }
    if([dict[OSXSBLogBackupKey] boolValue] == YES){
        [args addObject:@"--nolog"];
    }
    if(dict[OSXSBMaxBackupsKey]){
        [args addObject:[NSString stringWithFormat:@"--max-backups=%@",dict[OSXSBMaxBackupsKey]]];
    }
    
    // Services
    if(dict[OSXSBServiceOpenDirectoryKey]){
        [args addObject:@"--dirserv"];
    }
    if(dict[OSXSBServicePrintersKey]){
        [args addObject:@"--printers"];
    }
    if(dict[OSXSBServiceNamedKey]){
        [args addObject:@"--named"];
    }
    if(dict[OSXSBServiceKeychainKey]){
        [args addObject:@"--keychain"];
    }
    if(dict[OSXSBServiceRadiusKey]){
        [args addObject:@"--radius"];
    }
    if(dict[OSXSBServiceServeradminKey]){
        [args addObject:@"--settings"];
    }

    // Postgres
    if(dict[OSXSBPostgresStandardKey]){
        [args addObject:@"--pg-osx"];
    }
    if(dict[OSXSBPostgresCalendarKey]){
        [args addObject:@"--pg-caldav"];
    }
    if(dict[OSXSBPostgresDevicemgrKey]){
        [args addObject:@"--pg-devicemgr"];
    }
    if(dict[OSXSBPostgresCollabKey]){
        [args addObject:@"--pg-collab"];
    }
    
    return args;
}


-(BOOL)checkForPassword:(NSString*)bakpath error:(NSError*__autoreleasing*)error{
    NSError *localError;
    NSString *pass = getPassword(bakpath,&localError);
    [self sendProgressMessageBack:localError.localizedDescription];
    if(pass == nil)
        return [OSXSBError errorWithCode:kOSXSBErrorNoPasswordForArchive error:error];
    else
        return YES;
}

#pragma mark - NSXPC Delegate / Good Citizen
-(void)sendProgressMessageBack:(NSString*)message{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[self.connection remoteObjectProxy]didRecieveProgressMessage:message];
    }];
}


-(void)quitHelper{
    self.helperToolShouldQuit = YES;
}

//----------------------------------------
// Set up the one method of NSXPClistener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    assert(listener == self.listener);
    
    newConnection.exportedInterface = [NSXPCInterface
                                       interfaceWithProtocol:@protocol(OSXSBHelperAgent)];
    
    newConnection.exportedObject = self;
    
    newConnection.remoteObjectInterface = [NSXPCInterface
                                           interfaceWithProtocol:@protocol(OSXSBHelperProgress)];
    
    [newConnection resume];
    
    self.connection = newConnection;
    return YES;
}

@end
