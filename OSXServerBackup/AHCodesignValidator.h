//
//  AHCodesignCerts.h
//  codesing-example
//
//  Createdkloop9op[' by Eldon on 4/27/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AHCodesignValidator : NSObject
+(NSString*)certNameOfItemAtPath:(NSString*)path error:(NSError**)error;
+(BOOL)certOfItemAtPath:(NSString *)item1 isSameAsItemAtPath:(NSString *)item2 error:(NSError **)error;
@end
