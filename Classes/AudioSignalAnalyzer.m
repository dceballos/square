//
//  AudioSignalAnalyzer.m
//  iNfrared
//
//  Created by George Dean on 11/28/08.
//  Copyright 2008 Perceptive Development. All rights reserved.
//

#import "AudioSignalAnalyzer.h"

#define SAMPLE_RATE  44100
#define SAMPLE  SInt16
#define NUM_CHANNELS  1
#define BYTES_PER_FRAME  (NUM_CHANNELS * sizeof(SAMPLE))

#define SAMPLES_TO_NS(__samples__) (((UInt64)(__samples__) * 1000000000) / SAMPLE_RATE)
#define NS_TO_SAMPLES(__nanosec__)  (unsigned)(((UInt64)(__nanosec__)  * SAMPLE_RATE) / 1000000000)
#define US_TO_SAMPLES(__microsec__) (unsigned)(((UInt64)(__microsec__) * SAMPLE_RATE) / 1000000)
#define MS_TO_SAMPLES(__millisec__) (unsigned)(((UInt64)(__millisec__) * SAMPLE_RATE) / 1000)

#define EDGE_DIFF_THRESHOLD		16384
#define EDGE_SLOPE_THRESHOLD	256
#define EDGE_MAX_WIDTH			8
#define IDLE_CHECK_PERIOD		MS_TO_SAMPLES(10)

static int minLevel = 500;
static bool silent = true;
static bool startedRecording = false;
static bool done = false;
static int silenceAtEndThreshold = SAMPLE_RATE;
static int silenceSamples = 0;

static void recordingCallback (
							   void								*inUserData,
							   AudioQueueRef						inAudioQueue,
							   AudioQueueBufferRef					inBuffer,
							   const AudioTimeStamp				*inStartTime,
							   UInt32								inNumPackets,
							   const AudioStreamPacketDescription	*inPacketDesc
) {
	// This is not a Cocoa thread, it needs a manually allocated pool
//    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
 	// This callback, being outside the implementation block, needs a reference to the AudioRecorder object
	AudioSignalAnalyzer *analyzer = (AudioSignalAnalyzer *) inUserData;
  SInt16* frames = (SInt16*)inBuffer->mAudioData;
  
  //NSLog(@"sizeof %ld", inNumPackets);
  
  @autoreleasepool {
  for (int i=0;i<inNumPackets;i++)
  {
    //NSLog(@"SAMPLE %d", frames[i]);
    
    silent = abs(frames[i]) < minLevel;
    if (!silent)
    {
      silent = false;
      startedRecording = true;
      //NSLog(@"appending byte %d", frames[i]);
      
      if (!analyzer.data)
      {
        analyzer.data = [NSMutableData dataWithBytes:&frames[i] length:sizeof(SInt16)];
      }
      else
      {
        [analyzer.data appendBytes:&frames[i] length:sizeof(SInt16)];
      }
    }
    else if(silent && startedRecording)
    {
      //NSLog(@"++ silence %d", silenceSamples);
      silenceSamples++;
      if (silenceSamples > silenceAtEndThreshold)
      {
        done = true;
      }
    }
  }
  }
  
  if (done)
  {
    NSLog(@"finished recording size %d", [analyzer.data length]);    
    [analyzer decode];
    
    /*SInt16* ints = (SInt16*)[analyzer.data bytes];
    
    for (int i=0;i<[analyzer.data length]/sizeof(SInt16);i++)
    {
      NSLog(@"%d", ints[i]);
    }*/
    
    startedRecording = false;
    done = false;
    silent = true;
    silenceSamples = 0;
    analyzer.data = nil;
  }
  
	// if there is audio data, analyze it
	/*if (inNumPackets > 0) {
    NSData *buffData = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    NSString *dataStr = [[NSString alloc] initWithData:buffData encoding:NSASCIIStringEncoding];
    if (![dataStr isEqualToString:@"ýÿöÿ"])
    {
      //analyze((SAMPLE*)inBuffer->mAudioData, inBuffer->mAudioDataByteSize / BYTES_PER_FRAME, analyzer);
      [analyzer.data appendData:buffData];
      NSLog(@"appending data %@", [[NSString alloc] initWithData:analyzer.data encoding:NSASCIIStringEncoding]);
    }
	}*/
	
	// if not stopping, re-enqueue the buffer so that it can be filled again
	if ([analyzer isRunning]) {		
		AudioQueueEnqueueBuffer (
								 inAudioQueue,
								 inBuffer,
								 0,
								 NULL
								 );
	}
	
//	[pool release];
}



@implementation AudioSignalAnalyzer

@synthesize stopping;
@synthesize data;

- (analyzerData*) pulseData
{
	return &pulseData;
}

- (id) init
{
	self = [super init];

	if (self != nil) 
	{
		recognizers = [[NSMutableArray alloc] init];
		// these statements define the audio stream basic description
		// for the file to record into.
		audioFormat.mSampleRate			  = SAMPLE_RATE;
		audioFormat.mFormatID			    = kAudioFormatLinearPCM;
		audioFormat.mFormatFlags		  = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
		audioFormat.mFramesPerPacket	= 1;
		audioFormat.mChannelsPerFrame	= 1;
		audioFormat.mBitsPerChannel		= 16;
		audioFormat.mBytesPerPacket		= 2;
		audioFormat.mBytesPerFrame		= 2;
		
		
		AudioQueueNewInput (
							&audioFormat,
							recordingCallback,
							self,									// userData
							NULL,									// run loop
							NULL,									// run loop mode
							0,										// flags
							&queueObject
							);
		
	}
	return self;
}

- (void)addRecognizer:(id<PatternRecognizer>)recognizer
{
	[recognizers addObject:recognizer];
}

- (void) record
{
	[self setupRecording];
	
	[self reset];
	
	AudioQueueStart (
					 queueObject,
					 NULL			// start time. NULL means ASAP.
					 );	
}


- (void) stop
{
  NSLog(@"stopping");
	AudioQueueStop (
					queueObject,
					TRUE
					);
	
	[self reset];
}


- (void) setupRecording
{
	// allocate and enqueue buffers
	int bufferByteSize = 4096;		// this is the maximum buffer size used by the player class
	int bufferIndex;
	
	for (bufferIndex = 0; bufferIndex < 20; ++bufferIndex) {
		
		AudioQueueBufferRef bufferRef;
		
		AudioQueueAllocateBuffer (
								  queueObject,
								  bufferByteSize, &bufferRef
								  );
		
		AudioQueueEnqueueBuffer (
								 queueObject,
								 bufferRef,
								 0,
								 NULL
								 );
	}
}

- (void) idle: (unsigned)samples
{
	// Convert to microseconds
	UInt64 nsInterval = SAMPLES_TO_NS(samples);
	for (id<PatternRecognizer> rec in recognizers)
		[rec idle:nsInterval];
}

- (void) edge: (int)height width:(unsigned)width interval:(unsigned)interval
{
	// Convert to microseconds
	UInt64 nsInterval = SAMPLES_TO_NS(interval);
	UInt64 nsWidth = SAMPLES_TO_NS(width);
	for (id<PatternRecognizer> rec in recognizers)
		[rec edge:height width:nsWidth interval:nsInterval];
}

- (void)decode
{
  AudioDecoder *decoder = [[AudioDecoder alloc] init];
    
  NSLog(@"MIN VALUE: %d", [decoder getMinLevel:data coeff:0.5]);
  CFMutableBitVectorRef bits = [decoder decodeToBitSet:data];
  
  SwipeData *sd = [decoder decodeToASCII:bits];
  NSLog(@"bad read? %@", [sd isBadRead] ? @"YES" : @"NO");
  NSLog(@"%@", sd.content);
}

- (void) reset
{
	[recognizers makeObjectsPerformSelector:@selector(reset)];
	
	memset(&pulseData, 0, sizeof(pulseData));
}

- (void) dealloc
{
	AudioQueueDispose (queueObject,
					   TRUE);
	
	[recognizers release];
	
	[super dealloc];
}

@end
