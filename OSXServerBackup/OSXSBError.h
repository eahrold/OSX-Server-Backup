//
//  OSXSBError.h
//  OSX Server Backup
//
//  Created by Eldon on 2/24/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
static NSString *osxsbakPersistentDomain = @"com.eeaapps.osxsbak";
static NSString *osxsbakInstallDirectory = @"/usr/local/sbin/";

typedef NS_ENUM(NSInteger, OSXSBErrorCodes){
    kOSXSBErrorSuccess = 0,
    // helper tools errors
    kOSXSBErrorCouldNotAuthorized = 1000,
    kOSXSBErrorCouldNotInstallHelper,
    kOSXSBErrorCodeSignMisMatch,

    kOSXSBErrorUninstallRequest,
    kOSXSBErrorMissingArguments,

    
    // Backup Task Request Error
    kOSXSBErrorServiceNotRunning = 2001,
    kOSXSBErrorNoPasswordForArchive,
    kOSXSBErrorCouldNotCreateFile,
    kOSXSBErrorCannotCopyToSelf,
    kOSXSBErrorNoDatabaseSpecified,
    
    // general error
    kOSXSBErrorFeatureNotImplamented =3000,
};

@interface OSXSBError : NSObject

+(BOOL)errorFromTask:(NSTask*)task error:(NSError**)error;
+(BOOL)errorWithCode:(OSXSBErrorCodes)code error:(NSError**)error;
+(NSError*)errorWithCode:(OSXSBErrorCodes)code;

@end
