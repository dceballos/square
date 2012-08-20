//
//  bitset.c
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/16/12.
//
//
#include "bitset.h"

void setBitAtIndex(bitset_t bitset, int idx){
  
  /*
   * Represent bitset with array of ints. 
   * An element consists of 4 bytes. Since we treat the bitset
   * as a continuous entity, we need to figure out which bucket
   * a particular index falls into.
   *       2          1           0
   * |95 ... 64 | 63 ... 32 | 31 ... 0 |
   *
   * offset is the offset of the index within a bucket
   *
   * eg. idx = 8
   * 
   * ...|15 ... 8|7 ... 0|
   *
   * ...|0  ... 0|1 ... 0|
   * ...|0  ... 1|0 ... 0| => (1 << offset)
   * ---------------------- (|)
   * ...|0  ... 1|1 ... 0|
   */
  int bucketPos = idx / (int)(sizeof(int) * BYTE_SIZE);
  int offset = idx % (int)(sizeof(int) * BYTE_SIZE);
  (*(bitset + bucketPos)) |= (1 << offset);
}

void unsetBitAtIndex(bitset_t bitset, int idx){
  /*
   *
   * eg. idx = 8
   *
   * ...|15 ... 8|7 ... 0|
   *
   * ...|0  ... 1|1 ... 0|
   * ...|1  ... 0|1 ... 1| => ~(1 << offset)
   * ---------------------- (&)
   * ...|0  ... 0|1 ... 0|
   */

  int bucketPos = idx / ((int)sizeof(int) * BYTE_SIZE);
  int offset = idx % ((int)sizeof(int) * BYTE_SIZE);
  (*(bitset + bucketPos)) &= (~(1 << offset));
}

int getBitAtIndex(bitset_t bitset, int idx){
  int bucketPos = idx / ((int)sizeof(int) * BYTE_SIZE);
  int offset = idx % ((int)sizeof(int) * BYTE_SIZE);
  
  if(bucketPos > (BITSET_SIZE / BYTE_SIZE))
    return -1;
  
  return ((*(bitset + bucketPos)) >> offset) & 1;
}

int firstSetBit(bitset_t bitset){
  int i = 0;
  int j = 0;
  int bitSlice = -1;
  for(; i < (BITSET_SIZE / BYTE_SIZE / sizeof(int)); i++){
    if(abs(bitset[i]) > 0){
      bitSlice = bitset[i];
      break;
    }
  }
  if(bitSlice == -1){
    return -1;
  }
  for(; j < (BYTE_SIZE * sizeof(int)); j++){
    if((bitSlice >> j) & 0x1){
      break;
    }
  }
  return BYTE_SIZE * (int)sizeof(int) * i + j;
}

bitset_t initBitset(){
  bitset_t bits = malloc((BITSET_SIZE / BYTE_SIZE));
  memset(bits, '\0', (BITSET_SIZE / BYTE_SIZE));
  return bits;
}


