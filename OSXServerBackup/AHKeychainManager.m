//
//  AHKeychainManager.m
//  AHKeychain
//
// This class is a derivative of SSKeychain https://github.com/soffes/sskeychain/
// And released under the same license.
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

#import "AHKeychainManager.h"
#import <Security/Security.h>

NSString * kAHKeychainManagerErrorDomain = @"com.eeaapps.keychain.manager";
typedef NS_ENUM(int, AHKeychainErrorCode) {
    kAHKeychainErrMissingKey = 100,
    kAHKeychainErrCouldNotCreateAccess,
} ;

NSString * kAHKeychainSystemKeychain = @"/Library/Keychains/System.keychain";
NSString * kAHKeychainLoginKeychain = @"login";

@implementation AHKeychainManager

#pragma mark - Public
-(id)init{
    self = [super init];
    if(self){
        _keychainDomain = kAHKeychainDomainNotSet;
    }
    return self;
}

-(BOOL)save:(NSError *__autoreleasing*)error{
    OSStatus status = kAHKeychainErrMissingKey;
    if (!self.service || !self.account || !self.passwordData) {
		return [[self class]errorWithCode:status error:error];
	}
    
    if(![self remove:nil]){
        NSLog(@"there was a problem removing the old keychain item");
    }
    
    NSMutableDictionary *query = [self query:error];
    if(!query)return NO;
    
    [query setObject:self.passwordData forKey:(__bridge id)kSecValueData];
    if (self.label) {
        [query setObject:self.label forKey:(__bridge id)kSecAttrLabel];
    }
    
    //	CFTypeRef accessibilityType = kSecAttrAccessibleAlwaysThisDeviceOnly;
    //    if (accessibilityType) {
    //        [query setObject:(__bridge id)accessibilityType forKey:(__bridge id)kSecAttrAccessible];
    //    }
    
    if(self.trustedApplications.count > 0){
        [self createAccessForQuery:query error:error];
    }
    
    status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return [[self class]errorWithCode:status error:error];
}

-(BOOL)get:(NSError *__autoreleasing*)error{
    OSStatus status = errSecSuccess;
    CFTypeRef results;
    
    NSMutableDictionary *query = [self query:error];
    if(!query)return NO;

    [query setObject:@YES forKey:(__bridge id)kSecReturnData];
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &results);
    
	if (status != errSecSuccess) {
		return [[self class]errorWithCode:status error:error];
	}
    
    self.passwordData = (__bridge_transfer NSData *)results;
    return YES;
}

-(BOOL)find:(NSError *__autoreleasing*)error{
    OSStatus status = errSecSuccess;
    CFTypeRef results;
    
    NSMutableDictionary *query = [self query:error];
    if(!query)return NO;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &results);
    return [[self class]errorWithCode:status error:error];
}

-(BOOL)remove:(NSError *__autoreleasing*)error{
    OSStatus status = 1;
    if (!self.service || !self.account) {
        return [[self class] errorWithCode:status error:error];
	}
    
    NSMutableDictionary *query = [self query:error];
    if(!query)return NO;
    
    CFTypeRef result = NULL;
    [query setObject:@YES forKey:(__bridge id)kSecReturnRef];
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        status = SecKeychainItemDelete((SecKeychainItemRef)result);
        CFRelease(result);
    }

    
    if (status != errSecSuccess && error != NULL) {
       [[self class]errorWithCode:status error:error];
    }
    
    return (status == errSecSuccess);

}

#pragma mark - Accessors
- (void)setPasswordObject:(id<NSCoding>)object {
    self.passwordData = [NSKeyedArchiver archivedDataWithRootObject:object];
}


- (id<NSCoding>)passwordObject {
    if ([self.passwordData length]) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:self.passwordData];
    }
    return nil;
}


- (void)setPassword:(NSString *)password {
    self.passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString *)password {
    if ([self.passwordData length]) {
        return [[NSString alloc] initWithData:self.passwordData encoding:NSUTF8StringEncoding];
    }
    return nil;
}

-(void)setKeychainDomain:(AHKeychainDomains)keychainDomain{
    if(!_keychain){
        switch (keychainDomain) {
            case kAHKeychainDomainSystem:
                _keychain = kAHKeychainSystemKeychain;
                break;
            default:
                _keychain = kAHKeychainLoginKeychain;
                break;
        }
    }
}

#pragma mark - Private
-(NSMutableDictionary*)query:(NSError**)error{
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:5];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    if (self.service) {
        [query setObject:self.service forKey:(__bridge id)kSecAttrService];
    }
    
    if (self.label) {
        [query setObject:self.label forKey:(__bridge id)kSecAttrLabel];
    }

    
    if (self.account) {
        [query setObject:self.account forKey:(__bridge id)kSecAttrAccount];
    }
    
    if(self.keychain || self.keychainDomain != kAHKeychainDomainNotSet){
        [self useKeychainForQuery:query error:error];
    }
    
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    return query;
}

-(BOOL)createAccessForQuery:(NSMutableDictionary*)query error:(NSError*__autoreleasing*)error;
{
    OSStatus status;
    SecAccessRef access=nil;
    NSMutableArray *trustedApplications=[[NSMutableArray alloc]init];
    
    // Make an exception list of trusted applications; that is,
    // applications that are allowed to access the item without
    // requiring user confirmation:
    SecTrustedApplicationRef secTrustSelf;
    
    //Create trusted application references for this app//
    status = SecTrustedApplicationCreateFromPath(NULL, &secTrustSelf);
    
    // If we can't add ourself something's gon really wrong... abort.
    if (status != errSecSuccess) {
        return [[self class] errorWithCode:status error:error];
    }
    [trustedApplications addObject:(__bridge_transfer id)secTrustSelf];
    
    // calling SecTrustedApplicationCreateFromPath with NULL as the path
    // adds the caller, so we'll get that so we can skip it if it's
    // in the self.trustedApplications array.
    NSString *caller = [[NSProcessInfo processInfo] arguments][0];
    NSFileManager *fm = [NSFileManager new];

    //Create trusted application references any other specified apps//
    for(NSString *app in self.trustedApplications){
        if([fm fileExistsAtPath:app] && ![app isEqualToString:caller]){
            SecTrustedApplicationRef secTrustedApp = NULL;
            status = SecTrustedApplicationCreateFromPath(app.UTF8String,
                                                         &secTrustedApp);
            if (status == errSecSuccess) {
                [trustedApplications addObject:CFBridgingRelease(secTrustedApp)];
            }
        }
    }
    
    //Create an access object:
    status = SecAccessCreate((__bridge CFStringRef)self.service,
                             (__bridge CFArrayRef)trustedApplications,
                             &access);
    
    if(status == errSecSuccess){
        [query setObject:CFBridgingRelease(access) forKey:(__bridge id)kSecAttrAccess];
    }
    
    return [[self class] errorWithCode:status error:error];
}

-(BOOL)useKeychainForQuery:(NSMutableDictionary*)query error:(NSError *__autoreleasing *) error
{
    /**  the basis of this was inspired by keychain_utilities.c
     *  http://www.opensource.apple.com/source/SecurityTool/SecurityTool-55115/
     */
    OSStatus status = errSecInvalidKeychain;
    
    SecKeychainRef keychain = NULL;
    NSFileManager *fm = [NSFileManager new];
    
    if([fm fileExistsAtPath:self.keychain]){
        status = SecKeychainOpen(self.keychain.UTF8String, &keychain);
        if(status == errSecSuccess)
            [query setObject:CFBridgingRelease(keychain) forKey:(__bridge id)kSecUseKeychain];
    }
    else{
        CFArrayRef kcArray = NULL;
        status = SecKeychainCopyDomainSearchList(self.keychainDomain, &kcArray);
        if (status == errSecSuccess){
            // set the status here so if a match is not found in the for loop
            // the status code will be appropriate
            status = errSecInvalidKeychain;
            
            // convert it over to ARC for fast enumeration
            NSArray *keychainsList = CFBridgingRelease(kcArray);
            
            char pathName[MAXPATHLEN];
            UInt32 pathLength = sizeof(pathName);
            
            for ( id keychain in keychainsList){
                bzero(pathName, pathLength);
                OSStatus err = SecKeychainGetPath((__bridge SecKeychainRef)(keychain), &pathLength, pathName);
                if (err == errSecSuccess){
                    NSString* foundKeychainName = [[[NSString stringWithUTF8String:pathName]
                                                    lastPathComponent] stringByDeletingPathExtension];
                    if ([foundKeychainName isEqualToString:self.keychain]){
                        [query setObject:keychain forKey:(__bridge id)kSecUseKeychain];
                        break;
                    }
                }
            }
        }
    }
    return [[self class] errorWithCode:status error:error];
}

+(BOOL)setPassword:(NSString *)password service:(NSString *)service account:(NSString *)account keychain:(NSString *)keychain trustedApps:(NSArray *)trustedApps error:(NSError *__autoreleasing *)error
{
    AHKeychainManager *manager = [AHKeychainManager new];
    manager.account = account;
    manager.service = service;
    manager.keychain = keychain;
    manager.password = password;
    manager.trustedApplications = trustedApps;
    return [manager save:error];
}

+(BOOL)setPassword:(NSString *)password service:(NSString *)service account:(NSString *)account keychain:(NSString *)keycahin error:(NSError *__autoreleasing *)error{
    return [self setPassword:password service:service account:account keychain:keycahin trustedApps:nil error:error];
}


+(NSString*)getPasswordForService:(NSString *)service account:(NSString *)account keychain:(NSString *)keychain error:(NSError *__autoreleasing *)error{
    AHKeychainManager *manager = [AHKeychainManager new];
    manager.account = account;
    manager.service = service;
    manager.keychain = keychain;
    [manager get:error];
    return manager.password;
}

+(BOOL)removePasswordForService:(NSString *)service account:(NSString *)account keychain:(NSString *)keychain error:(NSError *__autoreleasing *)error{
    AHKeychainManager *manager = [AHKeychainManager new];
    manager.account = account;
    manager.service = service;
    manager.keychain = keychain;
    return [manager remove:error];
}


+ (BOOL)errorWithCode:(OSStatus)code error:(NSError*__autoreleasing*)error{
    NSString *message = nil;
    switch (code) {
        case errSecSuccess:
            return YES;
        case kAHKeychainErrMissingKey:
            message = @"Setting keychain password requires both account and service name";
            break;
        case kAHKeychainErrCouldNotCreateAccess:
            message = @"Could Not create proper access for the keychain item";
            break;
        default:
            message = (__bridge_transfer NSString *)SecCopyErrorMessageString(code, NULL);
            break;
    }
    
    NSDictionary *userInfo = nil;
    if (message != nil) {
        userInfo = message ? @{ NSLocalizedDescriptionKey : message }:@{ NSLocalizedDescriptionKey : @"unknown error" };
    }
    if(error)*error = [NSError errorWithDomain:kAHKeychainManagerErrorDomain
                                          code:code
                                      userInfo:userInfo];
    return NO;
}



@end
