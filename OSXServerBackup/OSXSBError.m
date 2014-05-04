//
//  OSXSBError.m
//  OSX Server Backup

//
//  Created by Eldon on 2/24/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "OSXSBError.h"

static NSString *osxsbErrorMessageFromCode(OSXSBErrorCodes code)
{
    NSString * msg;
    switch (code) {
        case kOSXSBErrorCouldNotAuthorized:     msg = @"Your are not authorized to perform this action.";
            break;
        case kOSXSBErrorCouldNotInstallHelper:  msg = @"The necessary helper tool could not be installed.  We will now quit.";
            break;
        case kOSXSBErrorCodeSignMisMatch:       msg = @"The cli tool was not signed using the same certificate or verification failed.";
            break;
        case kOSXSBErrorUninstallRequest:       msg = @"Helper Tool and associated files have been removed.  You can safely remove MunkiMenu from the Applications folder.  We will now quit";
            break;
        case kOSXSBErrorCouldNotCreateFile:     msg = @"Could not create the file";
            break;
        case kOSXSBErrorNoPasswordForArchive:   msg = @"backing up opendirectory requiers a password";
            break;
        case kOSXSBErrorCannotCopyToSelf:       msg = @"no need to install self over self";
            break;
        case kOSXSBErrorNoDatabaseSpecified:    msg = @"No database specified";
            break;
        case kOSXSBErrorFeatureNotImplamented:  msg = @"that feature is not yet implemented";
            break;
        case kOSXSBErrorMissingArguments:       msg = @"improper usage please see the help";
            break;
        default:msg = @"unknown problem occurred";
            break;
    }
    return msg;
}


@implementation OSXSBError

+(BOOL)errorFromTask:(NSTask *)task error:(NSError *__autoreleasing *)error{
    if(error && task.terminationStatus != 0){
        NSString *errorMsg = [NSString stringWithFormat:@"There was a problem executing %@",task.launchPath];
        *error = [NSError errorWithDomain:osxsbakPersistentDomain code:task.terminationStatus userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
        return NO;
    }
    return YES;
}

+(BOOL)errorWithCode:(OSXSBErrorCodes)code error:(NSError *__autoreleasing *)error{
    BOOL rc = code > kOSXSBErrorSuccess ? NO:YES;
    NSError *err = [self errorWithCode:code];
    if(error)
        *error = err;
    else
        NSLog(@"Error: %@",err.localizedDescription);
    
    return rc;
}

+(NSError*)errorWithCode:(OSXSBErrorCodes)code{
    NSString * msg = osxsbErrorMessageFromCode(code);
    NSError  * error = [NSError errorWithDomain:@"com.googlecode.MunkiMenu"
                                       code:code
                                   userInfo:@{NSLocalizedDescriptionKey:msg}];
    return error;
}

@end
