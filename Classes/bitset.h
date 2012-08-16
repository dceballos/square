//
//  bitset.h
//  SoftModemTerminal
//
//  Created by Adam Rachman on 8/16/12.
//
//

#ifndef SoftModemTerminal_bitset_h
#define SoftModemTerminal_bitset_h
#include<stdlib.h>
#include<string.h>

#define BITSET_SIZE 2048
#define BYTE_SIZE 8

typedef int* bitset_t;

/*
 * setBitAtIndex sets the bit of a given bitset at position pos
 *
 * @params bitset bitset
 * @params pos bitset index to be set
 * @return void
 */
void setBitAtIndex(bitset_t, int);

/*
 * getBitAtIndex returns the bit of a given bitset at position pos
 *
 * @params bitset bitset
 * @params pos bitset index to be read
 * @return int of the bit at position pos (1 or 0) or -1 if an error
 * occured
 */
int getBitAtIndex(bitset_t, int);
void unsetBitAtIndex(bitset_t, int);
int firstSetBit(bitset_t);
bitset_t initBitset();

#endif
