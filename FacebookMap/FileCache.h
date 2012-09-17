//
//  FileCache.h
//  FlickrPictures
//
//  Created by Tom Kraina on 28.08.2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileCache : NSObject
@property (nonatomic) NSUInteger maxSize;
@property (copy, nonatomic) NSString *domain;

+ (NSURL *)cacheDirURL;
- (NSURL *)domainCacheDirURL;
- (BOOL)saveData:(NSData *)data forKey:(NSString *)key;
- (NSData *)dataForKey:(NSString *)key;
@end
