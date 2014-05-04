//
//  NSTask+ExpectTask.h
//  OSX Server Backup
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



#import <Foundation/Foundation.h>

/**
 *  key used for the expect key in dictionary entry
 */
static NSString * const kNSTaskExpectKey = @"expect";

/**
 *  key used for send key in the expect dictionary entry
 */
static NSString * const kNSTaskSendKey   = @"send";

/**
 *  key used to determine wether the expect loop should end after a the matched dictionary
 *  @discussion this should only be set for the last expected prompt
 */
static NSString * const kNSExpectTaskBreakKey = @"break";

/**
 *  Catagory Extension for NSTask that utilize expect/spawn interactions
 */
@interface NSTask (ExpectTask)
/**
 *  Array containing Dictionary Entries in the form of @{kNSTaskExpectKey:@"What To Expect",kNSTaskSendKey:@"string to send"}
 */
@property (copy,nonatomic) NSArray   *expectArguments;

/**
 *  the full command you would like to spawn 
 *  @discussion for example task.spawnCommand = @"ssh user@myhost.com -p 40022"
 */
@property (copy)           NSString  *spawnCommand;
/**
 *  how long should the spawn wait at a prompt before timing out
 */
@property                  int        timeout;

/**
 *  Initialize NSTask object for use with Expect
 *
 *  @return initialized NSTask object with /usr/bin/expect set as launchPath
 */
-(instancetype)initForExpect;

/**
 *  Launch NSTask object that has been set to perform a expect/spawn task
 */
-(void)launchExpect;

@end
