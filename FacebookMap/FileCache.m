//
//  FileCache.m
//  FlickrPictures
//
//  Created by Tom Kraina on 28.08.2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FileCache.h"
#define DEFAULT_MAX_SIZE 0

@implementation FileCache
@synthesize maxSize = _maxSize;
@synthesize domain = _domain;

#pragma mark - Cache

- (id)init
{
    self = [super init];
    if (self) {
        self.maxSize = DEFAULT_MAX_SIZE;
    }
    return self;
}

+ (NSURL *)cacheDirURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *cacheDirURL = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    return cacheDirURL;
}

- (NSURL *)domainCacheDirURL
{
    NSURL *cacheDirURL = [[self class] cacheDirURL];
    NSURL *domainCacheDirURL = [cacheDirURL URLByAppendingPathComponent:self.domain isDirectory:YES];
    NSFileManager *fileManager = [[NSFileManager alloc] init];   
    if (![fileManager fileExistsAtPath:domainCacheDirURL.path]) {
        [fileManager createDirectoryAtURL:domainCacheDirURL withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return domainCacheDirURL;
}

+ (NSUInteger)sizeOfDirectoryURL:(NSURL *)url
{
    NSUInteger filesize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directoryString = url.path;
    NSArray *filenames = [fileManager contentsOfDirectoryAtPath:directoryString error:nil];
    for (NSString *filename in filenames) {
        NSError *error;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[directoryString stringByAppendingPathComponent:filename] error:&error];
        filesize += [fileAttributes fileSize];
    }
    
    return filesize;
}

+ (void)cleanUpCacheToFitMaxSize:(NSUInteger)megabytes atURL:(NSURL *)url
{
    if (!megabytes || ([[self class] sizeOfDirectoryURL:url] < megabytes*1024*1024)) {
        return;
    }
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *directoryString = url.path;
    NSArray *filenames = [fileManager contentsOfDirectoryAtPath:directoryString error:nil];
    
    // remove the oldest files
    // sorted by created datetime desc (oldest first)
    NSArray *filenamesByCreation = [filenames sortedArrayUsingComparator: ^(id a, id b){
        NSDictionary *fileAttributes1 = [fileManager attributesOfItemAtPath:[directoryString stringByAppendingPathComponent:a] error:nil];
        NSDictionary *fileAttributes2 = [fileManager attributesOfItemAtPath:[directoryString stringByAppendingPathComponent:b] error:nil];
        return [[fileAttributes1 fileCreationDate] compare:[fileAttributes2 fileCreationDate]];
    }];
    
    for (NSString *filename in filenamesByCreation) {
        [fileManager removeItemAtPath:[directoryString stringByAppendingPathComponent:filename] error:nil];
        
        NSUInteger dirSize = [[self class] sizeOfDirectoryURL:url];
        if (dirSize < megabytes*1024*1024) break;
    }
}

- (void)cleanUpCache
{
    [[self class] cleanUpCacheToFitMaxSize:self.maxSize atURL:[self domainCacheDirURL]];
}

- (BOOL)saveData:(NSData *)data forKey:(NSString *)key
{
    [self cleanUpCache];
    NSURL *filename = [[self domainCacheDirURL] URLByAppendingPathComponent:key];
    return [data writeToURL:filename atomically:YES];
}

- (NSData *)dataForKey:(NSString *)key
{
    NSURL *filename = [[self domainCacheDirURL] URLByAppendingPathComponent:key];
    NSData *data = [NSData dataWithContentsOfURL:filename];
    return data;
}

@end
