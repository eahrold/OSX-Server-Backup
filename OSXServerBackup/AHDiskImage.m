//
//  AHDMGTask.m
//  AHDMGTask-Example
//
//  Created by Eldon on 5/12/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//
//


#import "AHDiskImage.h"

typedef NS_ENUM(NSInteger, AHDiskImageErrorCode){
    kAHDiskImageErrSuccess,
    kAHDiskImageErrInvalidArgs,
    kAHDiskImageErrSourceRequired,
    kAHDiskImageErrNoValidSources,
    kAHDiskImageErrNotRWImageFormat,
    kAHDiskImageErrSizeNotSpecified,

};
@interface AHDiskImage()
@property (copy,nonatomic,readonly) NSString *formatString;
@property (copy,nonatomic,readonly) NSString *fileSystemString;
@end

@implementation AHDiskImage
#pragma mark - Public Methods
-(BOOL)create:(NSError*__autoreleasing*)error overwrite:(BOOL)overwrite{
    NSFileManager *fm = [NSFileManager new];

    // Check for required args
    if(!_destination || !_name){
        return [self errorFromCode:kAHDiskImageErrInvalidArgs error:error];
    }
    
    if( !_sourceItems && !self.readWriteFormat){
        return [self errorFromCode:kAHDiskImageErrSourceRequired error:error];
    }
    
    if(self.readWriteFormat){
        
    }
    
    NSTask *task = [NSTask new];
    NSMutableArray *args = [NSMutableArray new];
    
    task.launchPath = @"/usr/bin/hdiutil";
    task.standardInput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    
    if(self.logFileHandle)
        task.standardOutput = self.logFileHandle;

    [args addObjectsFromArray:@[@"create"]];
    if(overwrite){
        [args addObject:@"-ov"];
    }
    
    if(_password){
        task.standardInput = [NSPipe pipe];
        [args addObjectsFromArray:@[@"-encryption",@"AES-256",@"-stdinpass"]];
        [[task.standardInput fileHandleForWriting] writeData:[self.password dataUsingEncoding:NSUTF8StringEncoding]];
        [[task.standardInput fileHandleForWriting] closeFile];
    }
    
    [args addObjectsFromArray:@[@"-volname",self.volumeName]];
    [args addObjectsFromArray:@[@"-fs",self.fileSystemString]];
    
    int i = 0;
    if(_sourceItems){
        [args addObjectsFromArray:@[@"-format",self.formatString]];
        for(NSString *source in _sourceItems){
            if([fm fileExistsAtPath:source]){
                [args addObjectsFromArray:@[@"-srcfolder",source,]];
                i++;
            }
        }
        if(i == 0 && !self.readWriteFormat){
            return [self errorFromCode:kAHDiskImageErrNoValidSources error:error];
        }
    }
    
    if(self.readWriteFormat){
        if(!_size)
            return [self errorFromCode:kAHDiskImageErrSizeNotSpecified error:error];
        
        [args addObjectsFromArray:@[@"-type",self.typeString]];
        [args addObjectsFromArray:@[@"-size",_size]];
    }

    
    [args addObject:[_destination stringByAppendingPathComponent:self.name]];
    task.arguments = args;
    [task launch];
    [task waitUntilExit];
    return [self errorFromTask:task error:error];
}

-(BOOL)create:(NSError*__autoreleasing*)error{
    return [self create:error overwrite:NO];
}

#pragma mark - Accessors
-(NSString *)formatString{
    NSString *formatString;
    switch (_format) {
        case kAHDiskImageFormatZipCompressed:
            formatString = @"UDZO";
            break;
        case kAHDiskImageFormatReadWrite:
            formatString = @"UDRW";
            break;
        case kAHDiskImageFormatReadOnly:
            formatString = @"UDRO";
            break;
        case kAHDiskImageFormatADCCompressed:
            formatString = @"UDCO";
            break;
        case kAHDiskImageFormatBZip2Compressed:
            formatString = @"UDBZ";
            break;
        case kAHDiskImageFormatSparse:
            formatString = @"UDSP";
            break;
        case kAHDiskImageFormatSparseBundle:
            formatString = @"UDSB";
            break;
        default:
            formatString = @"UDZO";
            break;
    }
    return formatString;
}

-(NSString*)typeString{
    NSString *typeString;
    switch (_format) {
        case kAHDiskImageFormatReadWrite:
            typeString = @"UDIF";
            break;
        case kAHDiskImageFormatSparse:
            typeString = @"SPARSE";
            break;
        case kAHDiskImageFormatSparseBundle:
            typeString = @"SPARSEBUNDLE";
            break;
        default:
            break;
    }
    return typeString;
}

-(NSString *)fileSystemString{
    NSString *fileSystemString;
    switch (_fileSystem) {
        case kAHDiskImageFileSystemHFS:
            fileSystemString = @"HFS+";
            break;
        case kAHDiskImageFileSystemJHFS:
            fileSystemString = @"HFS+J";
            break;
        case kAHDiskImageFileSystemHFSX:
            fileSystemString = @"HFSX";
            break;
        case kAHDiskImageFileSystemMSDOS:
            fileSystemString = @"MS-DOS";
            break;
        case kAHDiskImageFileSystemUDF:
            fileSystemString = @"UDF";
            break;
        default:
            fileSystemString = @"HFS+";
            break;
    }
    return fileSystemString;
}

-(NSString *)volumeName{
    if(!_volumeName)
        _volumeName = _name;
    return _volumeName;
}

-(NSString *)password{
    if(_password)
        return [_password stringByAppendingString:@"\0\n"];
    return nil;
}

#pragma mark - Private
-(BOOL)readWriteFormat{
    switch (_format) {
        case kAHDiskImageFormatSparse:
        case kAHDiskImageFormatSparseBundle:
        case kAHDiskImageFormatReadWrite:
            return YES;
        default:
            break;
    }
    return NO;
}
-(BOOL)errorFromTask:(NSTask *)task error:(NSError *__autoreleasing *)error{
    if(error && task.terminationStatus != 0){
        NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
        NSString *errorMsg = errData ? [[NSString alloc]initWithData:errData encoding:NSASCIIStringEncoding]:
                                        [NSString stringWithFormat:@"There was a problem executing %@",task.launchPath];
        
        *error = [NSError errorWithDomain:[[NSBundle mainBundle]bundleIdentifier]
                                     code:task.terminationStatus
                                 userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    }
    return (task.terminationStatus == 0);
}

-(BOOL)errorFromCode:(AHDiskImageErrorCode)code error:(NSError *__autoreleasing *)error{
    if(error && code != kAHDiskImageErrSuccess){
        NSString *errorMsg;
        switch (code) {
            case kAHDiskImageErrInvalidArgs:
                errorMsg = @"Missing required setting to create the disk image file.";
                break;
            case kAHDiskImageErrNoValidSources:
                errorMsg = @"No valid sources were specified";
                break;
            case kAHDiskImageErrSourceRequired:
                errorMsg = @"Source files required when creating read-only disk images";
                break;
            case kAHDiskImageErrNotRWImageFormat:
                errorMsg = @"not a read write disk image format";
                break;
            case kAHDiskImageErrSizeNotSpecified:
                errorMsg = @"you must specify a size for the Disk image";
                break;
            default:
                errorMsg = @"An unknown error occured";
                break;
        }
        *error = [NSError errorWithDomain:[[NSBundle mainBundle]bundleIdentifier]
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey:errorMsg}];
    }
    return (code == 0);
}

@end
