//
//  SwipeData.h
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/14/12.
//
//


@interface SwipeData : NSObject {
  BOOL badRead;
  NSMutableData *raw;
  NSString *content;
}

- (void) setBadRead;
- (BOOL) isBadRead;
- (void) setContent: (NSString *)text;
@end
