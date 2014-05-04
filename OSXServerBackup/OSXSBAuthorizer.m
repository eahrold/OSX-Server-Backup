//
//  OSXSBAuthorizer.m
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



#import "OSXSBAuthorizer.h"
#import "OSXSBInterfaces.h"
#import "AHLaunchCtl.h"

@implementation OSXSBAuthorizer

static NSString * kCommandKeyAuthRightName    = @"authRightName";
static NSString * kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString * kCommandKeyAuthRightDesc    = @"authRightDescription";

+ (NSDictionary *)commandInfo
{
    static dispatch_once_t dOnceToken;
    static NSDictionary   *dCommandInfo;
    
    dispatch_once(&dOnceToken, ^{
        dCommandInfo = @{
                         NSStringFromSelector(@selector(installCliToolAtPath:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.installcli",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"OSX Server Backup needs to instal a cli tool /usr/local/sbin/osxsbak.",
                                                                                 @"prompt shown when user is required to authorize to uninstall"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(removeCliToolWithAuthorization:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.removecli",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"OSX Server Backup needs to removing the cli tool /usr/local/sbin/osxsbak.",
                                                                                 @"prompt shown when user is required to authorize to remove client"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(runBackupWithTaskDict:password:authorization:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.run",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"OSX Server Backup wants to run a backup.",
                                                                                 @"prompt shown when user is required to authorize to run backup"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(scheduleBackupWithTaskDict:schedule:authorization:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.scheduled",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"OSX Server Backup wants to schedule osxsbak runs.",
                                                                                 @"prompt shown when user is required to authorize to schedule jobs"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(removeScheduledJob:withAuthorization:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.purge-scheduled",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"OSX Server Backup wants to remove the osxsbak daily or weekly LaunchDaemons.",
                                                                                 @"prompt shown when user is required to authorize to remove jobs"
                                                                                )
                                 },
                         NSStringFromSelector(@selector(setKeychainPassword:authorization:reply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.eeaapps.osxsbak.setpassword",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"Please enter an admin password to update they current keychain password for osxsbak.",
                                                                                 @"prompt shown when user is required to authorize to update system keychain."
                                                                                 )
                                 },
                         };
    });
    return dCommandInfo;
}

+ (NSString *)authorizationRightForCommand:(SEL)command
{
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
#pragma unused(key)
#pragma unused(stop)
        NSDictionary *commandDict;
        NSString     *authRightName;
        id           authRightDefault;
        NSString     *authRightDesc;
        
        
        commandDict = (NSDictionary *) obj;
        assert([commandDict isKindOfClass:[NSDictionary class]]);
        
        authRightName = [commandDict objectForKey:kCommandKeyAuthRightName];
        assert([authRightName isKindOfClass:[NSString class]]);
        
        authRightDefault = [commandDict objectForKey:kCommandKeyAuthRightDefault];
        assert(authRightDefault != nil);
        
        authRightDesc = [commandDict objectForKey:kCommandKeyAuthRightDesc];
        assert([authRightDesc isKindOfClass:[NSString class]]);
        
        block(authRightName, authRightDefault, authRightDesc);
    }];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
{
    assert(authRef != NULL);
    [[self class] enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        OSStatus    blockErr;
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            blockErr = AuthorizationRightSet(
                                             authRef,                                    // authRef
                                             [authRightName UTF8String],                 // rightName
                                             (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                                             (__bridge CFStringRef) authRightDesc,       // descriptionKey
                                             NULL,                                       // bundle (NULL implies main bundle)
                                             CFSTR("Common")                             // localeTableName
                                             );
            assert(blockErr == errAuthorizationSuccess);
        } else {
        }
    }];
}

#pragma mark - Authorization
+ (BOOL)checkAuthorization:(NSData *)authData command:(SEL)command error:(NSError *__autoreleasing *)error
{
#pragma unused(authData)
    NSError *                   localError;
    OSStatus                    err;
    OSStatus                    junk;
    AuthorizationRef            authRef;
    
    assert(command != nil);
    
    authRef = NULL;
    
    localError = nil;
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        localError = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if (localError == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        if (err == errAuthorizationSuccess) {
            AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights   = { 1, &oneRight };
            
            oneRight.name = [[[self class] authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &rights,
                                          NULL,
                                          kAuthorizationFlagExtendRights |
                                          kAuthorizationFlagInteractionAllowed,
                                          NULL
                                          );
        }
        if (err != errAuthorizationSuccess) {
            localError = [NSError errorWithDomain:kOSXSBHelperName code:1 userInfo:@{NSLocalizedDescriptionKey:@"Could Not Create Authorization"}] ;
        }
    }
    
    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }
    
    if(localError){
        if(error)*error = localError;
        return NO;
    }
    
    return YES;
}

+(NSData*)authorizeHelper{
    OSStatus                    err;
    AuthorizationExternalForm   extForm;
    AuthorizationRef            authRef;
    NSData                     *authorization;
    
    err = AuthorizationCreate(NULL, NULL, 0, &authRef);
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(authRef, &extForm);
    }
    if (err == errAuthorizationSuccess) {
        authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }
    assert(err == errAuthorizationSuccess);
    
    if (authRef) {
        [[self class] setupAuthorizationRights:authRef];
    }
    
    return authorization;
}


@end
