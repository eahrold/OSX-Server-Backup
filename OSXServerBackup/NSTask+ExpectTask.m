//
//  NSTask+ExpectTask.m
//
//  Created by Eldon on 4/22/14.
//  Copyright (c) 2014 Eldon Ahrold.
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



#import "NSTask+ExpectTask.h"
#import <objc/runtime.h>
#import <syslog.h>

static char * kNSExpectTaskSpawnCommandKey = "kNSExpectTaskSpawnCommandKey";
static char * kNSExpectTaskExpectArgsKey   = "kNSExpectTaskExpectArgumentsKey";
static char * kNSExpectTaskTimeOutKey      = "kNSExpectTaskTimeoutKey";

@implementation NSTask (ExpectTask)

-(id)initForExpect{
    self = [self init];
    if(self){
        self.launchPath = @"/usr/bin/expect";
        // set arguments here as a place holder so
        // expect doesn't hang if it gets launched improperly
        self.arguments = @[@"x"];
    }
    return self;
}

-(void)launchExpect{
    return [self launchExpect1];
}

-(void)launchExpect1{
    if(!self.spawnCommand||!self.expectArguments){
        self.launchPath = @"/bin/bash";
        self.arguments = @[@"-c",@"echo \"The spawn command was not properly setup...\"; exit 1"];
        [self launch];
        return;
    }
    
    if(self.timeout == 0){
        self.timeout = -1;
    }
    
    NSMutableArray *expectArray = [NSMutableArray new];
    [expectArray addObject:self.spawnCommand];
    
    [expectArray addObject:[NSString stringWithFormat:@"set timeout %d",self.timeout]];
    [expectArray addObject:@"while 1 { expect {"];
    for (NSDictionary * expectDictionary in self.expectArguments){
        /*
         This will convert the dict values into strings formatted like this -- "String To Expect" {send "string to send"}
         */
        [expectArray addObject:[NSString stringWithFormat:@"\"%@\" {send \"%@\r\" %@}",expectDictionary[kNSTaskExpectKey],expectDictionary[kNSTaskSendKey],expectDictionary[kNSExpectTaskBreakKey]?@";break":@""]];
    }
    [expectArray addObject:@"timeout {puts \"Operation Timed Out..\";exit 1}"];
    [expectArray addObject:@"}\n}"];
    [expectArray addObject:@"expect eof"];
        
    self.arguments = @[@"-c", [expectArray componentsJoinedByString:@"\n"]];
    
    [self launch];
}


-(void)launchExpect2{
    if(!self.spawnCommand||!self.expectArguments){
        self.launchPath = @"/bin/bash";
        self.arguments = @[@"-c",@"echo \"The spawn command was not properly setup...\"; exit 1"];
        [self launch];
        return;
    }
    
    if(self.timeout == 0){
        self.timeout = -1;
    }
    
    NSMutableArray *expectArray = [[NSMutableArray alloc] initWithCapacity:self.expectArguments.count+1];
    [expectArray addObject:[NSString stringWithFormat:@"set timeout %d",self.timeout]];
    [expectArray addObject:self.spawnCommand];
    for (NSDictionary * expectDictionary in self.expectArguments){
        /*
         This will convert the dict values into strings formatted like this -- "String To Expect" {send "string to send"}
         */
        [expectArray addObject:[NSString stringWithFormat:@"expect \"%@\" {send \"%@\r\"}",expectDictionary[kNSTaskExpectKey],expectDictionary[kNSTaskSendKey]]];
    }
    [expectArray addObject:@"expect timeout {exit 1}"];

    self.arguments = @[@"-c", [expectArray componentsJoinedByString:@"\n"]];

    [self launch];
}




#pragma mark - get/set...
// expectArguments
-(NSArray *)expectArguments{
    return objc_getAssociatedObject(self, kNSExpectTaskExpectArgsKey);
}

-(void)setExpectArguments:(NSArray *)expectArguments{
    objc_setAssociatedObject(self, kNSExpectTaskExpectArgsKey, expectArguments, OBJC_ASSOCIATION_COPY);
}

//spawnCommand
-(NSString *)spawnCommand{
    return objc_getAssociatedObject(self, kNSExpectTaskSpawnCommandKey);
}

-(void)setSpawnCommand:(NSString *)spawnCommand{
    objc_setAssociatedObject(self, kNSExpectTaskSpawnCommandKey, spawnCommand, OBJC_ASSOCIATION_COPY);
}

//timeout
-(int)timeout{
    NSNumber *num = objc_getAssociatedObject(self, kNSExpectTaskTimeOutKey);
    return [num intValue];
}

-(void)setTimeout:(int)timeout{
    objc_setAssociatedObject(self, kNSExpectTaskTimeOutKey, [NSNumber numberWithInt:timeout], OBJC_ASSOCIATION_COPY);
}

@end
