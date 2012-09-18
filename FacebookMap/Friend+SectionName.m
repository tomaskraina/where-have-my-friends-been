//
//  Friend+SectionName.m
//  FacebookMap
//
//  Created by Tom K on 9/18/12.
//  Copyright (c) 2012 tomkraina.com. All rights reserved.
//

#import "Friend+SectionName.h"

@implementation Friend (SectionName)

- (NSString *)sectionName
{
    NSInteger sectionIndex = [[UILocalizedIndexedCollation currentCollation] sectionForObject:self collationStringSelector:@selector(name)];
    NSString *sectionName = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:sectionIndex];
    
    return sectionName;
}

@end
