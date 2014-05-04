//
//  AHKeychainManager.h
//  AHKeychain
//
//  Created by Eldon on 4/30/14.
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

typedef NS_ENUM(int, AHKeychainDomains) {
    kAHKeychainDomainNotSet = -1,
	/** Indicates the user preference domain preferences. */
	kAHKeychainDomainUser = kSecPreferencesDomainUser,
    
    /** Indicates the system preference domain preferences. */
    kAHKeychainDomainSystem = kSecPreferencesDomainSystem,
    
    /** Indicates the shared preference domain preferences. */
    kAHKeychainDomainShared = kSecPreferencesDomainCommon,
    
    /** Indicates Indicates a dynamic search list.  */
	kAHKeychainDomainDynamic = kSecPreferencesDomainDynamic,
} ;

extern NSString * kAHKeychainSystemKeychain;
extern NSString * kAHKeychainLoginKeychain;

@interface AHKeychainManager : NSObject
/**
 *  service name of keychain item
 */
@property (copy,nonatomic) NSString *service;

/**
 *  lable of keychain item
 */
@property (copy,nonatomic) NSString *label;
/**
 *  account name of keychain item
 */
@property (copy,nonatomic) NSString *account;

/**
 *   Root storage for password information
 */
@property (nonatomic, copy) NSData *passwordData;

/**
 This property automatically transitions between an object and the value of
 `passwordData` using NSKeyedArchiver and NSKeyedUnarchiver.
 */
@property (nonatomic, copy) id<NSCoding> passwordObject;
/**
 *  password for keychain item
 */
@property (copy,nonatomic) NSString *password;
/**
 *  Name of, or path to Keychain (path includes .keychain)
 */
@property (copy,nonatomic) NSString *keychain;
/**
 *  Array of paths to applications that should have permission to the keychain
 */
@property (copy,nonatomic) NSArray  *trustedApplications;
/**
 *  keychain domain to searh for approperiate keychains
 */
@property (nonatomic)      AHKeychainDomains      keychainDomain;

/**
 *  save the proposed keychain item
 *
 *  @param error populated should error occur
 *
 *  @return YES on success NO on failure
 */
-(BOOL) save:(NSError**)error;

/**
 *  Get the keychain item and retreive it's passwordData.
 *
 *  @param error populated should error occur
 *
 *  @return YES on success, NO on failure
 */
-(BOOL) get:(NSError**)error;

/**
 *  Find a keychain item
 *
 *  @discussion this will only tell you wether a keychain item exists, it dose not provide any password data.
 *  @param error populated should error occur
 *
 *  @return YES if item exists, NO if not
 */
-(BOOL) find:(NSError**)error;

-(BOOL) remove:(NSError**)error;

+(BOOL)setPassword:(NSString*)password service:(NSString*)service account:(NSString*)account keychain:(NSString*)keycahin trustedApps:(NSArray*)trustedApps error:(NSError**)error;

+(BOOL)setPassword:(NSString*)password service:(NSString*)service account:(NSString*)account keychain:(NSString*)keycahin error:(NSError**)error;

+(NSString*)getPasswordForService:(NSString*)service account:(NSString*)account keychain:(NSString*)keycahin error:(NSError**)error;

+(BOOL)removePasswordForService:(NSString*)service account:(NSString*)account keychain:(NSString*)keycahin error:(NSError**)error;

@end
