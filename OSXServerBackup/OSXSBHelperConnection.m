//
//  OSXSBackupHelperConnection.m
//  OSX Server Backup
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSBHelperConnection.h"
#import "OSXSBInterfaces.h"

@interface OSXSBHelperConnection ()
@property (atomic, strong, readwrite) NSXPCConnection * connection;
@end

@implementation OSXSBHelperConnection
#pragma mark - Initializers
-(void)connect{
    assert([NSThread isMainThread]);
    if (self.connection == nil) {
        self.connection = [[NSXPCConnection alloc] initWithMachServiceName:kOSXSBHelperName
                                                                   options:NSXPCConnectionPrivileged];
        
        self.connection.remoteObjectInterface = [NSXPCInterface
                                                 interfaceWithProtocol:@protocol(OSXSBHelperAgent)];
        self.connection.exportedInterface = [NSXPCInterface
                                             interfaceWithProtocol:@protocol(OSXSBHelperProgress)];
        
        
        self.connection.invalidationHandler = ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            self.connection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.connection = nil;
            }];
#pragma clang diagnostic pop
        };
        self.connection.exportedObject = [NSApp delegate];
        
        [self.connection resume];
    }
}

@end
