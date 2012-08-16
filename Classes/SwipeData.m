//
//  SwipeData.m
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/14/12.
//
//

#import "SwipeData.h"

@implementation SwipeData
-(id) init {
  [self init];
  if(self) {
    badRead = false;
    raw = [[NSMutableData alloc] init];
    content = NULL;
  }
  return self;
}
- (void) setBadRead
{
  self->badRead = true;
}

- (BOOL) isBadRead 
{
  return self->badRead;
}

- (void) setContent: (NSString *) text {
  content = text;
}
@end
