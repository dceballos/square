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

@property(nonatomic,readonly) NSString* content;
@property(nonatomic) BOOL badRead;

- (void) setBadRead;
- (BOOL) isBadRead;
- (void) setContent: (NSString *)text;
@end
