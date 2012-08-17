//
//  bitset.c
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/16/12.
//
//
#include "bitset.h"

void setBitAtIndex(bitset_t bitset, int idx){
  int bucketPos = idx / (sizeof(int) * BYTE_SIZE);
  int offset = idx % (sizeof(int) * BYTE_SIZE);
  (*(bitset + bucketPos)) = (*(bitset + bucketPos)) | (1 << offset);
}

void unsetBitAtIndex(bitset_t bitset, int idx){
  int bucketPos = idx / (sizeof(int) * BYTE_SIZE);
  int offset = idx % (sizeof(int) * BYTE_SIZE);
  (*(bitset + bucketPos)) = (*(bitset + bucketPos)) & (~(1 << offset));
}

int getBitAtIndex(bitset_t bitset, int idx){
  int bucketPos = idx / (sizeof(int) * BYTE_SIZE);
  int offset = idx % (sizeof(int) * BYTE_SIZE);
  
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
  return BYTE_SIZE * sizeof(int) * i + j;
}

bitset_t initBitset(){
  bitset_t bits = malloc((BITSET_SIZE / BYTE_SIZE));
  memset(bits, '\0', (BITSET_SIZE / BYTE_SIZE));
  return bits;
}


