//
//  AHDMGTask.h
//  AHDMGTask-Example
//
//  Created by Eldon on 5/12/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//
//


#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, AHDiskImageFormat){
    kAHDiskImageFormatZipCompressed,    // UDZO - UDIF   zlib-compressed image <- default
    kAHDiskImageFormatReadWrite,        // UDRW - UDRW - UDIF read/write image
    kAHDiskImageFormatReadOnly,         // UDRO - UDRO - UDIF read-only image
    kAHDiskImageFormatADCCompressed,    // UDCO - UDCO - UDIF ADC-compressed image
    kAHDiskImageFormatBZip2Compressed,  // UDBZ - UDIF bzip2-compressed image (OS X 10.4+ only)
    kAHDiskImageFormatSparse,           // UDSP - SPARSE (grows with content)
    kAHDiskImageFormatSparseBundle,     // UDSB -  (grows with content; bundle-backed)
};

typedef NS_ENUM(NSInteger, AHDiskImageFileSystem){
    kAHDiskImageFileSystemHFS,  // HFS+
    kAHDiskImageFileSystemJHFS, // Journaled HFS+
    kAHDiskImageFileSystemHFSX, // Case Sensitive (no-wrapper) HFS+
    kAHDiskImageFileSystemMSDOS,// MS-DOS
    kAHDiskImageFileSystemUDF,  // Universal Disk Format
};


@interface AHDiskImage : NSObject
/** name of the .dmg file */
@property (copy,nonatomic) NSString * name;

/** full paths to included items, can be files or directories */
@property (copy,nonatomic) NSArray * sourceItems;

/** directory where the DMG file is saved to */
@property (copy,nonatomic) NSString * destination;

/** password used to encrypt the DMG (optional) */
@property (copy,nonatomic) NSString * password;

/** Name of the dmg's mounted file system.  Defaults to name property */
@property (copy,nonatomic) NSString * volumeName;

/** size of dmg if the disk format is Read/Write (eg 32m or 1g) */
@property (nonatomic) NSString  * size;

/** format of the dmg.  Defaults to kAHDiskImageFormatZipCompressed */
@property (nonatomic) AHDiskImageFormat format;

/** file system of the dmg kAHDiskImageFileSystemHFS */
@property (nonatomic) AHDiskImageFileSystem fileSystem;

/** file to log standard out */
@property (nonatomic) NSFileHandle *logFileHandle;

/**
 *  Create a disk image
 *
 *  @param error populated should error occur
 *
 *  @return YES on Success NO on failure
 */
-(BOOL)create:(NSError**)error;

/**
 *  Create a disk image
 *
 *  @param error populated should error occur
 *  @param overwrite YES to overwrite NO to fail if a dmg file exists at the path.
 *
 *  @return YES on Success NO on failure
 */
-(BOOL)create:(NSError**)error overwrite:(BOOL)overwrite;
@end
