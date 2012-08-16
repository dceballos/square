//
//  AudioDecoder.m
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/15/12.
//
//

#import "AudioDecoder.h"
@implementation AudioDecoder
- (id) init {
  self = [super init];
  if(self) {
    silenceLevel = 500;
    minLevel = 0;
    minLevelCoeff = 0.5;
  }
  return self;
}

- (int) getMinLevel: (NSMutableData *)data coeff:(double)coeff {
  short lastval = 0;
  short val = 0;
  int peakCount = 0;
  int peakSum = 0;
  int peakTemp = 0; // value to store highest peak value between zero crossings
  BOOL hitmin = false;
  
  NSInputStream* nis = [[NSInputStream alloc] initWithData:data];
  [nis open];
  
  while ([nis hasBytesAvailable]) {
    uint8_t buff[2];
    NSInteger bytesRead = [nis read:buff maxLength:2];
    memcpy(&val, buff, sizeof(short));
    if(val > 0 && lastval <=0){
      // Coming from negative to positive, reset peakTemp
      peakTemp = 0;
      hitmin = false;
    } else if (val < 0 && lastval >= 0 && hitmin) {
      // Going from positive to negative, add peakTemp to peakSum
      peakSum += peakTemp;
      peakCount++;
    }
    if((val > 0) && (lastval > val) && (lastval > silenceLevel) && (val > peakTemp)){
      // new peak, higher than last peak since zero
      hitmin = true;
      peakTemp = val;
    }
    lastval = val;
  }
  
  //The .3 in the following line is an arbitrary scaling factor.
  //I have come up with it experimentally, but it can be changed to make the decode more or less noise sensitive
  if(peakCount > 0){
    int level = floor(((double)peakSum / (double)peakCount) * coeff);
    return level;
  } else {
    return silenceLevel;
  }
}

- (BOOL) isOne: (int)actualInterval oneInterval:(int)oneInterval {
  int diffToOI = abs(actualInterval - oneInterval);
  int diffToZI = abs(actualInterval - (2 * oneInterval));
  if(diffToOI < diffToZI){
    return true;
  } else {
    return false;
  }
}

- (CFMutableBitVectorRef) decodeToBitSet:(NSMutableData *)data {
  CFMutableBitVectorRef result = CFBitVectorCreateMutable(NULL, 0);
  NSInputStream *nis = [[NSInputStream alloc] initWithData:data];
  int i = 0;
  int resultBitCount = 0;
  int lastSign = -1;
  int lasti = 0;
  short dp;
  int first = 0;
  
  //Interval between transitions for a 1 bit. There are two transition per 1 bit, 1 per 1 bit, 1 per 0.
  //So if interval is around 15, then if the space between transitions is 17, 15, that's a 1. But if that was 32, that'd be 0.
  //The pattern starts with a self-clocking set of 0s. We'll discard the first few, just because.
  int oneInterval = -1;
  int introDiscard = 1;
  int discardCount = 0;
  //If the last interval was the first half of a 1, the next better be the second half
  BOOL needHalfOne = false;
  //invert every 1 bit. Parity bit should make number of 1s in group odd.
  int expectedParityBit = 1;
  
  while([nis hasBytesAvailable]){
    uint8_t buff[2];
    //Might want to do something if the result is negative
    NSInteger bytesRead = [nis read:buff maxLength:2];
    if((dp * lastSign < 0) && (abs(dp) > minLevel)){
      if(first == 0) {
        first = i;
      } else if (discardCount < introDiscard){
        discardCount++;
      } else {
        int sinceLast = i - lasti;
        
        if(oneInterval == -1) {
          oneInterval = sinceLast/2;
        } else {
          
          BOOL oz = [self isOne:sinceLast oneInterval:oneInterval];
          if(oz){
            oneInterval = sinceLast;
            if(needHalfOne){
              expectedParityBit = 1 - expectedParityBit;
              CFBitVectorSetBitAtIndex(result, resultBitCount, true);
              resultBitCount++;
              // don't need next to be
              needHalfOne = false;
            } else {
              needHalfOne = true;
            }
          } else {
            oneInterval = sinceLast / 2;
            if (needHalfOne) {
              break;
              // throw new error did not get second half of 1 value
            } else {
              CFBitVectorSetBitAtIndex(result, resultBitCount, false);
              resultBitCount++;
            }
          }
        }
      }
      lasti = i;
      lastSign *= -1;
    }
    i++;
  }
  [nis close];
  return result;
}

- (SwipeData *) decodeToASCII:(CFMutableBitVectorRef)bits {
  SwipeData *toReturn = [[SwipeData alloc] init];
  CFRange range = CFRangeMake(0, CFBitVectorGetCount(bits));
  int first1 = CFBitVectorGetFirstIndexOfBit(bits, range, true);
  
  if(first1 < 0) {
    [toReturn setBadRead];
    return toReturn;
  }
  int sentinel = 0;
  int exp = 0;
  int i = first1;
  //check for 5 bit sentinel
  for(; i < first1 + 4; i++){
    if(CFBitVectorGetBitAtIndex(bits, i)){
      //lsb first. so with each following bit, shift it lef 1 place
      sentinel += 1 << exp;
    }
    exp++;
  }
  //11 is magic sentinel number for track 2. Corresponds to ascii ';' with offset 48 (ascii '0')
  if (sentinel == 11) {
    return [self decodeToASCII:bits beginIndex:first1 bitsPerChar:4 baseChar:48];
  } else {
    for(; i < first1 + 6; i++){
      if(CFBitVectorGetBitAtIndex(bits, i)){
        sentinel += 1 << exp;
      }
      exp++;
    }
    //5 is magic sentinel number for track 1. Corresponds to ascii '%' with offset 48 (ascii space)
    if(sentinel == 5){
      return [self decodeToASCII:bits beginIndex:first1 bitsPerChar:6 baseChar:32];
    }
  }
  [toReturn setBadRead];
  return toReturn;
}

- (SwipeData *) decodeToASCII:(CFMutableBitVectorRef)bits beginIndex:(int)beginIndex bitsPerChar:(int)bitsPerChar baseChar:(int)baseChar {
  NSMutableString *nms = [[NSMutableString alloc] init];
  SwipeData *toReturn = [[SwipeData alloc] init];
  int i = beginIndex;
  char endSentinel = '?';
  int charCount = 0;
  BOOL sentinelFound = false;
  int size = CFBitVectorGetCount(bits);
  int letterVal = 0;
  char letter;
  BOOL expectedParity;
  BOOL bit;
  int exp;
  while((i < size) && !sentinelFound){
    letterVal = 0;
    expectedParity = TRUE;
    exp = 0;
    int nextCharIndex = i + bitsPerChar;
    for(; i < nextCharIndex; i++){
      bit = CFBitVectorGetBitAtIndex(bits, i);
      if(bit){
        letterVal += 1 << exp;
        expectedParity = !expectedParity;
      }
      exp++;
    }
    letter = [self decode:letterVal baseChar:baseChar];
    [nms appendFormat:@"%c", letter];
    bit = CFBitVectorGetBitAtIndex(bits, i);
    if(bit != expectedParity){
  
    }
    i++;
    charCount++;
    if(letter == endSentinel){
      sentinelFound = true;
    }
  }
  [toReturn setContent:nms];
  return toReturn;
}

- (char) decode:(int)input baseChar:(int)baseChar {
  char decoded = (char)(input + baseChar);
  return decoded;
}
@end
