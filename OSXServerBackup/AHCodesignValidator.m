//
//  AHCodesignCerts.m
//  codesing-example
//
//  Created by Eldon on 4/27/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "AHCodesignValidator.h"
#import <Security/Security.h>

@implementation AHCodesignValidator

+(SecCertificateRef)codesignCertOfItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error{
    SecCertificateRef cert = NULL;
    NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
    if (url) {
        SecStaticCodeRef staticCodeRef = NULL;
        if (SecStaticCodeCreateWithPath((__bridge CFURLRef)(url),0,&staticCodeRef) == errSecSuccess){
            OSStatus status = SecStaticCodeCheckValidityWithErrors(staticCodeRef, 0, NULL, NULL);
            if ( status != errSecSuccess){
                [self errorFromSecError:status item:[path lastPathComponent] error:error];
            }
            else{
                CFDictionaryRef codeSigningInfo;
                if (SecCodeCopySigningInformation(staticCodeRef,kSecCSSigningInformation,&codeSigningInfo) == errSecSuccess){
                    NSArray *certs = CFDictionaryGetValue(codeSigningInfo,kSecCodeInfoCertificates);
                    if (certs){
                        cert = (__bridge_retained SecCertificateRef)(certs[0]);
                    }
                }
                CFRelease(codeSigningInfo);
            }
            CFRelease(staticCodeRef);
        }
    }
    return cert;
}

+(NSString *)certNameOfItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error{
    CFStringRef certString = NULL;
    NSString    *certName  = nil;
    
    SecCertificateRef cert = [self codesignCertOfItemAtPath:path error:error];
    if(cert != NULL){
        if(SecCertificateCopyCommonName(cert, &certString) == errSecSuccess){
            certName = CFBridgingRelease(certString);
        }
        CFRelease(cert);
    }
    return certName;
}


+(NSData *)codesignCertDataOfItemAtPath:(NSString *)path error:(NSError *__autoreleasing *)error{
    NSData *data = nil;
    SecCertificateRef cert = [self codesignCertOfItemAtPath:path error:error];
    
    if(cert != NULL){
        data = CFBridgingRelease(SecCertificateCopyData(cert));
        CFRelease(cert);
    }
    return data;
}

+(BOOL)certOfItemAtPath:(NSString *)item1 isSameAsItemAtPath:(NSString *)item2 error:(NSError *__autoreleasing *)error{
    NSData *certData1 = [self codesignCertDataOfItemAtPath:item1 error:error];
    if(certData1 == nil){
        return NO;
    }
    NSData *certData2 = [self codesignCertDataOfItemAtPath:item2 error:error];
    if(certData2 == nil){
        return NO;
    }
    
    if([certData1 isEqualToData:certData2]){
        return YES;
    }
    return [self errorFromSecError:errSecAppleSignatureMismatch item:item1 error:error];
}

+(BOOL)errorFromSecError:(OSStatus)status item:(NSString*)item error:(NSError *__autoreleasing*)error{
    NSError* err;
    if(status != errSecSuccess){
        NSString *emsg =  CFBridgingRelease(SecCopyErrorMessageString (status,NULL));
        err = [NSError errorWithDomain:@"com.eeaapps.csvalidator" code:status userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Codesign failed on %@ because %@",item,emsg]}];
        if(error)*error=err;
        return NO;
    }else{
        return YES;
    }
}
@end
