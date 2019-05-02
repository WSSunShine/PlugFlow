
#import "AudioCapture.h"
#import "AACEncoder.h"
#import <AudioToolbox/AudioToolbox.h>

#define AUDIO_SAMPLERATE 44100

NSString *const AudioComponentFailedToCreateNotification = @"AudioComponentFailedToCreateNotification";
@interface AudioCapture ()

@property (nonatomic, assign) AudioComponentInstance    componetInstance;
@property (nonatomic, assign) AudioComponent            component;
@property (nonatomic, strong) dispatch_queue_t       taskQueue;
@property (nonatomic, strong) AACEncoder *aac;
@property (nonatomic, strong) FrameSession *session;
@property (nonatomic, assign) BOOL isRunning;

@end

@implementation AudioCapture

#pragma mark -- LiftCycle
- (nullable instancetype)initWithAudio{
    if(self = [super init]){
        self.isRunning = NO;
        self.muted=false;
        self.taskQueue = dispatch_queue_create("com.QM_Streaming.audioCapture.Queue", NULL);
        
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleRouteChange:)
                                                     name: AVAudioSessionRouteChangeNotification
                                                   object: session];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleInterruption:)
                                                     name: AVAudioSessionInterruptionNotification
                                                   object: session];
        
        NSError *error = nil;
        
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        
        [session setMode:AVAudioSessionModeVideoRecording error:&error];
        
        if (![session setActive:YES error:&error]) {
            [self handleAudioComponentCreationFailure];
        }
        
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        
        //kAudioUnitSubType_VoiceProcessingIO消除回音
        acd.componentSubType = kAudioUnitSubType_RemoteIO;//消除回音用
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        
        self.component = AudioComponentFindNext(NULL, &acd);
        
        OSStatus status = noErr;
        status = AudioComponentInstanceNew(self.component, &_componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        
        UInt32 flagOne = 1;
        
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
        
        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = AUDIO_SAMPLERATE;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        desc.mChannelsPerFrame = 1;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *)(self);
        cb.inputProc = handleInputBuffer;
        status = AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
        status = AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
        
        status = AudioUnitInitialize(self.componetInstance);
        
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }
        
        
        [session setPreferredSampleRate:AUDIO_SAMPLERATE error:nil];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:&error];
        
        
        [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];
        
        [session setActive:YES error:nil];
        
        
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    dispatch_sync(self.taskQueue, ^{
        if(self.componetInstance){
            AudioOutputUnitStop(self.componetInstance);
            AudioComponentInstanceDispose(self.componetInstance);
            self.componetInstance = nil;
            self.component = nil;
        }
    });
}

-(void)invalidate{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    dispatch_sync(self.taskQueue, ^{
        if(self.componetInstance){
            AudioOutputUnitStop(self.componetInstance);
            AudioComponentInstanceDispose(self.componetInstance);
            self.componetInstance = nil;
            self.component = nil;
        }
    });
}
#pragma mark -- Setter
- (void)setRunning:(BOOL)running{
    if(_running == running) return;
    _running = running;
    if(_running){
        dispatch_async(self.taskQueue, ^{
            self.isRunning = YES;
            AudioOutputUnitStart(self.componetInstance);
        });
    }else{
        self.isRunning = NO;
    }
}

#pragma mark -- CustomMethod
- (void)handleAudioComponentCreationFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AudioComponentFailedToCreateNotification object:nil];
    });
}

#pragma mark -- NSNotification
- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSession *session = [ AVAudioSession sharedInstance ];
    NSString* seccReason = @"";
    NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            seccReason = @"The route changed when the device woke up from sleep.";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            seccReason = @"The output route was overridden by the app.";
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            seccReason = @"The category of the session object changed.";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            seccReason = @"The previous audio output path is no longer available.";
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            seccReason = @"A preferred new audio output path is now available.";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            seccReason = @"The reason for the change is unknown.";
            break;
    }
    AVAudioSessionPortDescription *input = [[session.currentRoute.inputs count]?session.currentRoute.inputs:nil objectAtIndex:0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {
        
    }
}

- (void)handleInterruption:(NSNotification *)notification {
    NSInteger reason = 0;
    NSString* reasonStr = @"";
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        //Posted when an audio interruption occurs.
        reason = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            if (self.isRunning) {
                dispatch_sync(self.taskQueue, ^{
                    NSLog(@"MicrophoneSource: stopRunning");
                    AudioOutputUnitStop(self.componetInstance);
                });
            }
        }
        
        if (reason == AVAudioSessionInterruptionTypeEnded) {
            reasonStr = @"AVAudioSessionInterruptionTypeEnded";
            NSNumber* seccondReason = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] ;
            switch ([seccondReason integerValue]) {
                case AVAudioSessionInterruptionOptionShouldResume:
                    if (self.isRunning) {
                        dispatch_async(self.taskQueue, ^{
                            NSLog(@"MicrophoneSource: stopRunning");
                            AudioOutputUnitStart(self.componetInstance);
                        });
                    }
                    // Indicates that the audio session is active and immediately ready to be used. Your app can resume the audio operation that was interrupted.
                    break;
                default:
                    break;
            }
        }
        
    };
    NSLog(@"handleInterruption: %@ reason %@",[notification name], reasonStr);
}

#pragma mark -- CallBack
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    
    @autoreleasepool {
        AudioCapture *source = (__bridge AudioCapture *)inRefCon;
        if(!source) return -1;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
        
        OSStatus status = AudioUnitRender(source.componetInstance,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        
        if (!source.isRunning) {
            dispatch_sync(source.taskQueue, ^{
                NSLog(@"MicrophoneSource: stopRunning");
                AudioOutputUnitStop(source.componetInstance);
            });
            
            return status;
        }
        
        if (source.muted) {
            for (int i = 0; i < buffers.mNumberBuffers; i++) {
                AudioBuffer ab = buffers.mBuffers[i];
                memset(ab.mData, 0, ab.mDataByteSize);
            }
        }
        
        if(!status || !source.isRunning) {
            [source.delegate EncodeAudioFrame:buffers];
        }
        return status;
    }
}

@end
