//  AACEncoder.m


#import "AACEncoder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#include "speex_echo.h"
#include "speex_preprocess.h"


#define DSP_SAMPLING_RATE       44100
#define DSP_FRAME_SIZE          1024         //PCM Frame Size
#define DSP_FRAME_TAIL          1024


#define AAC_MSAMPERATE 44100
//码率
#define AAC_SAMPLERATE 64000
#define AAC_SIZE 1024
#define AAC_CAHNNELS 1


@interface AACEncoder(){
    AudioConverterRef audioConverter;
    
    AudioConverterRef m_converter;
    char *pcmBuf;
    char *aacBuf;
    NSInteger pcmLength;
    
    SpeexEchoState          *ses;
    SpeexPreprocessState    *sps;
    
    UInt32                  sampleRate;
}
@end

@implementation AACEncoder

- (void) dealloc {

    AudioConverterDispose(audioConverter);
    if (aacBuf) free(aacBuf);
    if (pcmBuf) free(pcmBuf);
}

- (id) init {
    if (self = [super init]) {
        if (!pcmBuf) {
            pcmBuf = malloc([self bufferLength]);
        }
        
        if (!aacBuf) {
            aacBuf = malloc([self bufferLength]);
        }
        
//        [self Denoise];
    }
    return self;
}
- (NSUInteger)bufferLength{
    return AAC_SIZE*2*AAC_CAHNNELS;
}
#pragma mark -- CustomMethod
- (BOOL)createAudioConvert { //根据输入样本初始化一个编码转换器
    if (m_converter != nil) {
        return TRUE;
    }
    
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = AAC_MSAMPERATE;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    //单声道
    inputFormat.mChannelsPerFrame =AAC_CAHNNELS;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;
    
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    //数组或者结构体清0的最快操作
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = inputFormat.mSampleRate;       // 采样率保持一致
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;            // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = AAC_CAHNNELS;
    outputFormat.mFramesPerPacket = AAC_SIZE;                     // AAC一帧是1024个字节
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    //软硬件编码器
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    // 创建编码器Converter
    OSStatus result = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, requestedCodecs, &m_converter);
    //创建的编码率
    UInt32 outputBitrate = AAC_SAMPLERATE;
    UInt32 propSize = sizeof(outputBitrate);
    
    if(result == noErr) {
        result = AudioConverterSetProperty(m_converter, kAudioConverterEncodeBitRate, propSize, &outputBitrate);
    }
    return YES;
}


#pragma mark -- AudioCallBack
OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * *outDataPacketDescription, void *inUserData) { //<span style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
    AudioBufferList bufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}
#pragma mark -- Encode AAC
- (void)encodeAudioData:(CMSampleBufferRef)samplebuffer timeStamp:(uint64_t)timeStamp {
    
    if (![self createAudioConvert]) {
        return;
    }

    AudioBufferList audioBufferList;
    NSMutableData *audioData= [NSMutableData data];
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(samplebuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
    
    for( int y=0; y< audioBufferList.mNumberBuffers; y++ ){
        
        AudioBuffer audioBuffer = audioBufferList.mBuffers[y];
        Float32 *frame = (Float32*)audioBuffer.mData;
        
        [audioData appendBytes:frame length:audioBuffer.mDataByteSize];
        
    }
    
    CFRelease(blockBuffer);
    
    if(pcmLength + audioData.length >= [self bufferLength]){
        NSInteger totalSize = pcmLength + audioData.length;
        NSInteger encodeCount = totalSize/[self bufferLength];
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;
        
        memset(totalBuf, (int)totalSize, 0);
        memcpy(totalBuf, pcmBuf, pcmLength);
        memcpy(totalBuf + pcmLength, audioData.bytes, audioData.length);
        
        for(NSInteger index = 0;index < encodeCount;index++){
            [self encodeBuffer:p  timeStamp:timeStamp];
            p += [self bufferLength];
        }
        free(totalBuf);
        
        pcmLength = totalSize%[self bufferLength];
        
        memset(pcmBuf, 0, [self bufferLength]);
        memcpy(pcmBuf, totalBuf + (totalSize -pcmLength), pcmLength);
        
    }else{
        //累积缓存 aac长度基本是1024 6s的长度不够 需要做缓存
        memcpy(pcmBuf+pcmLength, audioData.bytes, audioData.length);
        pcmLength = pcmLength + audioData.length;
    }

}


- (void)encodeBuffer:(char*)buf timeStamp:(uint64_t)timeStamp{
    
    AudioBuffer inBuffer;
    inBuffer.mNumberChannels = 1;
    inBuffer.mData = buf;
    inBuffer.mDataByteSize = [self bufferLength];
    
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = inBuffer;
    
    
    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers = 1;
    outBufferList.mBuffers[0].mNumberChannels = inBuffer.mNumberChannels;
    outBufferList.mBuffers[0].mDataByteSize = inBuffer.mDataByteSize;   // 设置缓冲区大小
    outBufferList.mBuffers[0].mData = aacBuf;           // 设置AAC缓冲区
    UInt32 outputDataPacketSize = 1;
    if (AudioConverterFillComplexBuffer(m_converter, inputDataProc, &buffers, &outputDataPacketSize, &outBufferList, NULL) != noErr) {
        return;
    }
    
    QMTV_AudioFrame *audioFrame = [QMTV_AudioFrame new];
    audioFrame.timestamp = timeStamp;
    audioFrame.data = [NSData dataWithBytes:aacBuf length:outBufferList.mBuffers[0].mDataByteSize];
    
    audioFrame.audioInfo=[self aachead:[self sampleRateIndex:AAC_MSAMPERATE] Channel:AAC_CAHNNELS];
    
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(sendAudioframe:)]){
        [self.delegate sendAudioframe:audioFrame];
    }

}


#pragma mark -- AAC HEAD
- (NSData*)aachead:(NSUInteger)sampleRateIndex Channel:(NSUInteger)num{
    char asc[2];
    NSData *data = nil;
    asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    asc[1] = ((sampleRateIndex & 0x1)<<7) | ((num & 0xF) << 3);
    data=[NSData dataWithBytes:asc length:2];
    return data;
}

#pragma mark -- Custom Method
- (NSInteger)sampleRateIndex:(NSInteger)frequencyInHz {
    NSInteger sampleRateIndex = 0;
    switch (frequencyInHz) {
        case 96000:
            sampleRateIndex = 0;
            break;
        case 88200:
            sampleRateIndex = 1;
            break;
        case 64000:
            sampleRateIndex = 2;
            break;
        case 48000:
            sampleRateIndex = 3;
            break;
        case 44100:
            sampleRateIndex = 4;
            break;
        case 32000:
            sampleRateIndex = 5;
            break;
        case 24000:
            sampleRateIndex = 6;
            break;
        case 22050:
            sampleRateIndex = 7;
            break;
        case 16000:
            sampleRateIndex = 8;
            break;
        case 12000:
            sampleRateIndex = 9;
            break;
        case 11025:
            sampleRateIndex = 10;
            break;
        case 8000:
            sampleRateIndex = 11;
            break;
        case 7350:
            sampleRateIndex = 12;
            break;
        default:
            sampleRateIndex = 15;
    }
    return sampleRateIndex;
}
#pragma mark -- Denoise
-(void)Denoise{
    //消除噪音
    sampleRate = DSP_SAMPLING_RATE;
    ses = speex_echo_state_init(DSP_FRAME_SIZE, DSP_FRAME_TAIL);
    sps = speex_preprocess_state_init(DSP_FRAME_SIZE, sampleRate);
    int denoise = 1;
    int noiseSuppress = -3;
    speex_preprocess_ctl(sps, SPEEX_PREPROCESS_SET_DENOISE, &denoise);// 降噪
    speex_preprocess_ctl(sps, SPEEX_PREPROCESS_SET_NOISE_SUPPRESS, &noiseSuppress);// 噪音分贝数
    speex_preprocess_ctl(sps, SPEEX_PREPROCESS_SET_ECHO_STATE, ses);

}
@end
