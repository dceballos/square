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

static int minLevel = 50;
static bool silent = true;
static bool startedRecording = false;
static bool done = false;
static int silenceAtEndThreshold = 20;
static int silenceSamples = 0;

static int analyze( SAMPLE *inputBuffer,
						  unsigned long framesPerBuffer,
						  AudioSignalAnalyzer* analyzer)
{
	analyzerData *data = analyzer.pulseData;
	SAMPLE *pSample = inputBuffer;
	int lastFrame = data->lastFrame;
	
	unsigned idleInterval = data->plateauWidth + data->lastEdgeWidth + data->edgeWidth;
	
	for (long i=0; i < framesPerBuffer; i++, pSample++)
	{
		int thisFrame = *pSample;
		int diff = thisFrame - lastFrame;
		
		int sign = 0;
		if (diff > EDGE_SLOPE_THRESHOLD)
		{
      // NSLog(@"sinal rising");
			// Signal is rising
			sign = 1;
		}
		else if(-diff > EDGE_SLOPE_THRESHOLD)
		{
			// Signal is falling
      // NSLog(@"sinal falling");
			sign = -1;
		}
		
		// If the signal has changed direction or the edge detector has gone on for too long,
		//  then close out the current edge detection phase
		if(data->edgeSign != sign || (data->edgeSign && data->edgeWidth + 1 > EDGE_MAX_WIDTH))
		{
			if(abs(data->edgeDiff) > EDGE_DIFF_THRESHOLD && data->lastEdgeSign != data->edgeSign)
			{
				// The edge is significant
				[analyzer edge:data->edgeDiff
						 width:data->edgeWidth
					  interval:data->plateauWidth + data->edgeWidth];
				
				// Save the edge
				data->lastEdgeSign = data->edgeSign;
				data->lastEdgeWidth = data->edgeWidth;
				
				// Reset the plateau
				data->plateauWidth = 0;
				idleInterval = data->edgeWidth;
#ifdef DETAILED_ANALYSIS
				data->plateauSum = 0;
				data->plateauMin = data->plateauMax = thisFrame;
#endif
			}
			else
			{
				// The edge is rejected; add the edge data to the plateau
				data->plateauWidth += data->edgeWidth;
#ifdef DETAILED_ANALYSIS
				data->plateauSum += data->edgeSum;
				if(data->plateauMax < data->edgeMax)
					data->plateauMax = data->edgeMax;
				if(data->plateauMin > data->edgeMin)
					data->plateauMin = data->edgeMin;
#endif
			}
			
			data->edgeSign = sign;
			data->edgeWidth = 0;
			data->edgeDiff = 0;
#ifdef DETAILED_ANALYSIS
			data->edgeSum = 0;
			data->edgeMin = data->edgeMax = lastFrame;
#endif
		}
		
		if(data->edgeSign)
		{
			// Sample may be part of an edge
			data->edgeWidth++;
			data->edgeDiff += diff;
#ifdef DETAILED_ANALYSIS
			data->edgeSum += thisFrame;
			if(data->edgeMax < thisFrame)
				data->edgeMax = thisFrame;
			if(data->edgeMin > thisFrame)
				data->edgeMin = thisFrame;
#endif
		}
		else
		{
			// Sample is part of a plateau
			data->plateauWidth++;
#ifdef DETAILED_ANALYSIS
			data->plateauSum += thisFrame;
			if(data->plateauMax < thisFrame)
				data->plateauMax = thisFrame;
			if(data->plateauMin > thisFrame)
				data->plateauMin = thisFrame;
#endif
		}
		idleInterval++;
		
		data->lastFrame = lastFrame = thisFrame;
		
		if ( (idleInterval % IDLE_CHECK_PERIOD) == 0 )
			[analyzer idle:idleInterval];
		
	}
	
	return 0;
}


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
  
  @autoreleasepool {
  for (int i=0;i<sizeof(frames)-1;i++)
  {
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
    
    startedRecording = false;
    done = false;
    silent = true;
    silenceSamples = 0;
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
