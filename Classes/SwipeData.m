//
//  SwipeData.m
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/14/12.
//
//

#import "SwipeData.h"

@implementation SwipeData

@synthesize content;
@synthesize badRead;

-(id) init {
  self = [super init];
  if(self) {
    badRead = false;
    raw = [[NSMutableData alloc] init];
    content = NULL;
  }
  return self;
}
- (void) setBadRead
{
  self.badRead = YES;
}

- (BOOL) isBadRead 
{
  return self->badRead;
}

- (void) setContent: (NSString *) text {
  NSLog(@"setting content %@", text);
  content = text;
}
@end
