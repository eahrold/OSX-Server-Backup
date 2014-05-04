//
//  OSXSBInterfaces.h
//  OSX Server Backup
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
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
#import "OSXSBAuthorizer.h"
#import "OSXSBError.h"
#import "OSXSBUtility.h"

@class AHLaunchJobSchedule;
static NSString * const kOSXSBHelperName = @"com.eeaapps.osxsbak.helper";

#pragma mark - Helper Agent
@protocol OSXSBHelperAgent <NSObject>
-(void)installCliToolAtPath:(NSString*)path
                reply:(void (^)(NSError *))reply;

-(void)removeCliToolWithAuthorization:(NSData *)authData
                                reply:(void (^)(NSError *))reply;

-(void)removeScheduledJob:(NSString*)which
        withAuthorization:(NSData*)authdata
                    reply:(void (^)(NSError *))reply;

-(void)scheduleBackupWithTaskDict:(NSDictionary *)dict
                     schedule:(AHLaunchJobSchedule*)schedule
             authorization:(NSData *)authData
                     reply:(void (^)(NSError *))reply;

-(void)runBackupWithTaskDict:(NSDictionary *)dict
                    password:(NSString*)password
               authorization:(NSData *)authData
                       reply:(void (^)(NSError *))reply;

-(void)uninstallWithAuthorization:(NSData *)authData
                            reply:(void (^)(NSError *))reply;
    
-(void)setKeychainPassword:(NSString *)password
             authorization:(NSData *)authData
                     reply:(void (^)(NSError *))reply;

-(void)quitHelper;
@end

#pragma mark - Progress
@protocol OSXSBHelperProgress
- (void)startProgressPanel;
- (NSString*)promptForPassword;
- (void)didRecieveProgressMessage:(NSString*)message;
@end
