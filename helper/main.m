//
//  main.m
//  helper
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSXSBHelper.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        OSXSBHelper *helper = [OSXSBHelper new];
        [helper run];
    }
    return 0;
}

