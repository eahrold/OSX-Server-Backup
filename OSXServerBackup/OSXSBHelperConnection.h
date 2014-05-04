//
//  OSXSBackupHelperConnection.h
//  OSX Server Backup
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSXSBHelperConnection : NSObject
@property (atomic, strong, readonly) NSXPCConnection * connection;
-(void)connect;
@end
