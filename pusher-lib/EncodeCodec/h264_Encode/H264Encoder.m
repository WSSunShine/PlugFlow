//  H264HWEncoder.m

#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

#import "H264Encoder.h"
#import <sys/utsname.h>

#import "QMTV_VideoFrame.h"
#import "QMTV_StreamRtmpSocket.h"

@interface H264Encoder ()

@property (nonatomic, strong) NSString *DeviceID;

@end


@implementation H264Encoder{
    
    //更换分辨率 必须重新初始化
    VTCompressionSessionRef session;
    
    NSInteger frameCount;
    
    //是否退到后台
    BOOL isBackGround;
    
}

#pragma mark--Initial
- (id) init :(int)width Height:(int)height FPS:(int)fps Bitrate:(int)bitrate{
    if (self = [super init]) {
        
        session = NULL;
        
        self.Width=width;
        
        self.Height=height;
        
        self.Bitrate=bitrate;
        
        self.FPS=fps;
        
        self.DeviceID=[self correspondVersion];
        
        //通知是否退到后台
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void) initSession
{
    if (session) {
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
        session = NULL;
    }
    
    CFMutableDictionaryRef encoderSpecifications = NULL;
    
    OSStatus ret = VTCompressionSessionCreate(kCFAllocatorDefault,
                                              self.Width,
                                              self.Height,
                                              kCMVideoCodecType_H264,
                                              encoderSpecifications,
                                              NULL,
                                              NULL,
                                              didCompressH264,
                                              (__bridge void *)(self),
                                              &session);
    
    if(ret!=noErr){
        
        NSLog(@"VTCompressionSessionCreate fail");
        return;
    }
    
    //gopsize
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_MaxKeyFrameInterval,
                         (__bridge CFTypeRef)@(self.FPS*2));
    
    //fps
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_ExpectedFrameRate,
                         (__bridge CFTypeRef)@(self.FPS));
    
    //关键幀间隔秒数
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                         (__bridge CFNumberRef)@(2));
    
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_AverageBitRate,
                         (__bridge CFTypeRef)@(self.Bitrate));
    
    NSArray *limit = @[@(self.Bitrate * 1.5/8), @(1)];
    
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_DataRateLimits,
                         (__bridge CFArrayRef)limit);
    
    if([self.DeviceID isEqualToString:@"6_Plus"]||[self.DeviceID isEqualToString:@"6s_Plus"]||[self.DeviceID isEqualToString:@"7_Plus"]){
        VTSessionSetProperty(session,
                             kVTCompressionPropertyKey_ProfileLevel,
                             kVTProfileLevel_H264_Main_AutoLevel);
        
        //kVTH264EntropyMode_CABAC 可壓縮更多的碼率 for mainlevel
        VTSessionSetProperty(session,
                             kVTCompressionPropertyKey_H264EntropyMode,
                             kVTH264EntropyMode_CABAC);
    }
    else{
        //直播只需要用到baseline即可 依照分辨率來自動調整
        VTSessionSetProperty(session,
                             kVTCompressionPropertyKey_ProfileLevel,
                             kVTProfileLevel_H264_Baseline_AutoLevel);
    }
    
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_RealTime,
                         kCFBooleanTrue);
    
    VTSessionSetProperty(session,
                         kVTCompressionPropertyKey_AllowFrameReordering,
                         kCFBooleanTrue);
    
    VTCompressionSessionPrepareToEncodeFrames(session);
    
}
#pragma mark --  Session Callback
void didCompressH264(void *outputCallbackRefCon,
                     void *sourceFrameRefCon,
                     OSStatus status,
                     VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    H264Encoder* encoder = (__bridge H264Encoder*)outputCallbackRefCon;
    
    if (status == noErr) {
        uint64_t timeStamp = [((__bridge_transfer NSNumber*)sourceFrameRefCon) longLongValue];
        return [encoder didReceiveSampleBuffer:sampleBuffer :timeStamp];
    }
    
    NSLog(@"Error %d : %@", (unsigned int)infoFlags, [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
}

- (void)didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer :(uint64_t )timeStamp{
    if (!sampleBuffer) {
        return;
    }
    
    NSData *sps, *pps;
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if(keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        
        const uint8_t *sparameterSet;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            uint32_t NALUnitLength = 0;
            
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            QMTV_VideoFrame *videoFrame = [QMTV_VideoFrame new];
            
            videoFrame.timestamp = timeStamp;
            
            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            videoFrame.isKeyFrame = keyframe;
            
            videoFrame.sps = sps;
            videoFrame.pps = pps;
            
            if(self.delegate && [self.delegate respondsToSelector:@selector(sendVideoframe:)]){
                [self.delegate sendVideoframe:videoFrame];
            }
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }

    }
}

#pragma mark Encode H264
- (void) encode:(CVImageBufferRef) cpixcel timeStamp:(uint64_t)timeStamp
{
    if(isBackGround) return;
    
    if(!session){
        [self initSession];
    }
    
    CMTime duration = CMTimeMake(1, (int32_t)self.FPS);
    frameCount ++;
    
    CMTime presentationTimeStamp = CMTimeMake(frameCount, 1000);
    
    VTEncodeInfoFlags flags;
    
    NSNumber *timeNumber = @(timeStamp);
    
    NSDictionary *properties = nil;
    if(frameCount % (int32_t)self.FPS == 0){
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    
    if( session != NULL && cpixcel!=NULL  ){
        OSStatus ret= VTCompressionSessionEncodeFrame(session,
                                                      cpixcel,
                                                      presentationTimeStamp,
                                                      duration,
                                                      (__bridge CFDictionaryRef)properties,
                                                      (__bridge_retained void *)timeNumber,
                                                      &flags);
        
        if(ret<0){
            NSLog(@"Encode fail");
        }
    }else{
        NSLog(@"Session or buffer is null");
    }
}
#pragma mark -- NSNotification
- (void)willEnterBackground:(NSNotification*)notification{
    [self invalidate];
    isBackGround = YES;
}

- (void)willEnterForeground:(NSNotification*)notification{
    [self initSession];
    isBackGround = NO;
}
#pragma  mark -- Destroy
- (void) invalidate
{
    if(session)
    {
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
        session = NULL;
    }
}
#pragma mark--取得设备id
- (NSString *)getDeviceVersionInfo
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithFormat:@"%s", systemInfo.machine];
    
    return platform;
}

- (NSString *)correspondVersion
{
    NSString *correspondVersion = [self getDeviceVersionInfo];
    
    if ([correspondVersion isEqualToString:@"i386"])        return@"Simulator";
    if ([correspondVersion isEqualToString:@"x86_64"])       return @"Simulator";
    
    if ([correspondVersion isEqualToString:@"iPhone1,1"])   return@"1";
    if ([correspondVersion isEqualToString:@"iPhone1,2"])   return@"3";
    if ([correspondVersion isEqualToString:@"iPhone2,1"])   return@"3S";
    if ([correspondVersion isEqualToString:@"iPhone3,1"] || [correspondVersion isEqualToString:@"iPhone3,2"])   return@"4";
    if ([correspondVersion isEqualToString:@"iPhone4,1"])   return@"4S";
    if ([correspondVersion isEqualToString:@"iPhone5,1"] || [correspondVersion isEqualToString:@"iPhone5,2"])   return @"5";
    if ([correspondVersion isEqualToString:@"iPhone5,3"] || [correspondVersion isEqualToString:@"iPhone5,4"])   return @"5C";
    if ([correspondVersion isEqualToString:@"iPhone6,1"] || [correspondVersion isEqualToString:@"iPhone6,2"])   return @"5S";
    if ([correspondVersion isEqualToString:@"iPhone7,1"])   return @"6_Plus";
    if ([correspondVersion isEqualToString:@"iPhone7,2"])   return @"6";
    if ([correspondVersion isEqualToString:@"iPhone8,1"])   return @"6s";
    if ([correspondVersion isEqualToString:@"iPhone8,2"])   return @"6s_Plus";
    if ([correspondVersion isEqualToString:@"iPhone9,1"])   return @"7";
    if ([correspondVersion isEqualToString:@"iPhone9,2"])   return @"7_Plus";
    
    if ([correspondVersion isEqualToString:@"iPod1,1"])     return@"iPod Touch 1";
    if ([correspondVersion isEqualToString:@"iPod2,1"])     return@"iPod Touch 2";
    if ([correspondVersion isEqualToString:@"iPod3,1"])     return@"iPod Touch 3";
    if ([correspondVersion isEqualToString:@"iPod4,1"])     return@"iPod Touch 4";
    if ([correspondVersion isEqualToString:@"iPod5,1"])     return@"iPod Touch 5";
    
    if ([correspondVersion isEqualToString:@"iPad1,1"])     return@"iPad 1";
    if ([correspondVersion isEqualToString:@"iPad2,1"] || [correspondVersion isEqualToString:@"iPad2,2"] || [correspondVersion isEqualToString:@"iPad2,3"] || [correspondVersion isEqualToString:@"iPad2,4"])     return@"iPad 2";
    if ([correspondVersion isEqualToString:@"iPad2,5"] || [correspondVersion isEqualToString:@"iPad2,6"] || [correspondVersion isEqualToString:@"iPad2,7"] )      return @"iPad Mini";
    if ([correspondVersion isEqualToString:@"iPad3,1"] || [correspondVersion isEqualToString:@"iPad3,2"] || [correspondVersion isEqualToString:@"iPad3,3"] || [correspondVersion isEqualToString:@"iPad3,4"] || [correspondVersion isEqualToString:@"iPad3,5"] || [correspondVersion isEqualToString:@"iPad3,6"])      return @"iPad 3";
    if ([correspondVersion isEqualToString:@"iPad4,4"] || [correspondVersion isEqualToString:@"iPad4,5"] || [correspondVersion isEqualToString:@"iPad4,6"] || [correspondVersion isEqualToString:@"iPad4,7"] || [correspondVersion isEqualToString:@"iPad4,8"] || [correspondVersion isEqualToString:@"iPad4,9"] || [correspondVersion isEqualToString:@"iPad2,5"] || [correspondVersion isEqualToString:@"iPad2,6"] || [correspondVersion isEqualToString:@"iPad2,7"])     return @"iPad Mini";//检测ipad mini 和4s一样需要调整
    return correspondVersion;
}
#pragma mark -- delloc
- (void) dealloc {
    [self invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
