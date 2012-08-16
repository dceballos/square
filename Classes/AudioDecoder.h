//
//  AudioDecoder.h
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/15/12.
//
//
#import "SwipeData.h"
#include "bitset.h"

@interface AudioDecoder : NSObject {
  int silenceLevel;
  int minLevel;
  double minLevelCoeff;
}
  
- (int) getMinLevel: (NSMutableData *)data coeff:(double)coeff;
- (BOOL) isOne: (int)actualInterval oneInterval:(int)oneInterval;
- (bitset_t) decodeToBitSet: (NSMutableData *)data;
- (SwipeData *) decodeToASCII: (bitset_t)bits;
- (SwipeData *) decodeToASCII: (bitset_t)bits beginIndex:(int)beginIndex bitsPerChar:(int)bitsPerChar baseChar:(int)baseChar;
- (char) decode: (int)input baseChar:(int)baseChar;
@end
