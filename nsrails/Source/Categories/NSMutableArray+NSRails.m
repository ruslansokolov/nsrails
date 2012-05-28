/*
 
 _|_|_|    _|_|  _|_|  _|_|  _|  _|      _|_|           
 _|  _|  _|_|    _|    _|_|  _|  _|_|  _|_| 
 
 NSMutableArray+NSRails.m
 
 Copyright (c) 2012 Dan Hassin.
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "NSMutableArray+NSRails.h"
#import "NSRails.h"

@implementation NSMutableArray (NSRFetch)

//helper method to set array to returned values - has to keep the objects, just update them individually to their new dict
//returns whether or not there was a local change
- (BOOL) setSelfToRemoteArray:(NSArray *)array forClass:(Class)class
{
	BOOL changes = NO;
	
	NSMutableArray *itemsToDelete = [self mutableCopy];
	
	for (NSDictionary *dict in array)
	{
		NSNumber *railsID = [dict objectForKey:@"id"];
		id existing = nil;
		
		if (railsID)
			existing = [[self filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"remoteID == %@",railsID]] lastObject];
		
		if (!existing)
		{
			id new = [class findOrInsertObjectUsingRemoteDictionary:dict];
			[self addObject:new];
			changes = YES;
		}
		else
		{
			BOOL neededChange = [existing setPropertiesUsingRemoteDictionary:dict];
			if (neededChange)
				changes = YES;

			[itemsToDelete removeObject:existing];
		}
	}
	
	if (itemsToDelete.count > 0)
	{
		changes = YES;
		[self removeObjectsInArray:itemsToDelete];
	}
	
	return changes;
}

- (void) assertValidSubclass:(Class)class
{
	if (![class isSubclassOfClass:[NSRRemoteObject class]])
	{
		[NSException raise:NSInvalidArgumentException format:@"Class passed into remoteFetchAll:error:changes: (%@) is not a subclass of NSRRemoteObject.",class];
	}
}

- (BOOL) remoteFetchAll:(Class)class error:(NSError **)errorPtr changes:(BOOL *)changesPtr
{
	[self assertValidSubclass:class];
	
	NSArray *array = [class remoteGET:nil error:errorPtr];
	
	if (!array)
	{
		if (changesPtr)
			*changesPtr = NO;
		return NO;
	}
	
	BOOL changes = [self setSelfToRemoteArray:array forClass:class];
	
	if (changesPtr)
		*changesPtr = changes;
	
	return YES;
}

- (void) remoteFetchAll:(Class)class async:(NSRFetchCompletionBlock)block
{
	[self assertValidSubclass:class];
	
	[class remoteGET:nil async:^(id jsonRep, NSError *error) 
	{
		if (!jsonRep)
		{
			block(NO, error);
		}
		else
		{
			BOOL changes = [self setSelfToRemoteArray:jsonRep forClass:class];
			block(changes, nil);
		}
	}];
}

@end
