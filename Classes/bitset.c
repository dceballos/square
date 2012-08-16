//
//  bitset.c
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/16/12.
//
//
#include "bitset.h"

void setBitAtIndex(bitset_t bitset, int pos){
  int bucketPos = pos / (BYTE_SIZE - 1);
  int relPos = pos % BYTE_SIZE;
  (*(bitset + bucketPos)) = (*(bitset + bucketPos)) | (1 << relPos);
}

void unsetBitAtIndex(bitset_t bitset, int pos){
  int bucketPos = pos / (BYTE_SIZE - 1);
  int relPos = pos % BYTE_SIZE;
  (*(bitset + bucketPos)) = (*(bitset + bucketPos)) | (~(1 << relPos));
}

int getBitAtIndex(bitset_t bitset, int pos){
  int bucketPos = pos / (BYTE_SIZE - 1);
  int relPos = pos % BYTE_SIZE;
  
  if(bucketPos > (BITSET_SIZE / BYTE_SIZE))
    return -1;
  
  return (*(bitset + bucketPos)) >> relPos;
}

int firstSetBit(bitset_t bitset){
  int i = 0;
  int j = 0;
  int bitSlice = -1;
  for(; i < (BITSET_SIZE / BYTE_SIZE); i++){
    if(bitset[i] > 0){
      bitSlice = bitset[i];
      break;
    }
  }
  if(bitSlice == -1){
    return -1;
  }
  for(; j < BYTE_SIZE; j++){
    if((bitSlice >> j) & 0x1){
      break;
    }
  }
  return BYTE_SIZE * i + j;
}

bitset_t initBitset(){
  return malloc((BITSET_SIZE / BYTE_SIZE));
}

