// QMTV_StreamRtmpSocket.m

#import "QMTV_StreamRtmpSocket.h"
#import "FrameSession.h"
#import "QMTV_LiveDrop.h"
#import "rtmp.h"
#import <sys/utsname.h>
#import "QMTV_Reachability.h"

//重新连接次数
static const NSInteger RetryTimesBreaken = 99999;
static const NSInteger RetryTimesMargin = 1;

#define RTMP_RECEIVE_TIMEOUT    1
#define DATA_ITEMS_MAX_COUNT 100
#define RTMP_DATA_RESERVE_SIZE 400

#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

#define SAVC(x)    static const AVal av_##x = AVC(#x)
static const AVal av_setDataFrame = AVC("@setDataFrame");
static const AVal av_SDKVersion = AVC("QMTV_ENCODE_v2.4.6");
static const AVal av_id = AVC("iphone");
static const AVal av_network=AVC("network");

SAVC(onMetaData);
SAVC(Duration);
SAVC(VideocoWidth);
SAVC(VideocoHeight);
SAVC(Videocodecid);
SAVC(Videodatarate);
SAVC(Framerate);
SAVC(Audiocodecid);
SAVC(Mono);
SAVC(Audiodatarate);
SAVC(Audiosamplerate);
SAVC(Audiosamplesize);
SAVC(Audiochannels);
SAVC(Stereo);
SAVC(Encoder);
SAVC(Device);
SAVC(ID);
SAVC(Network);
SAVC(FileSize);
SAVC(Avc1);
SAVC(Mp4a);




@interface QMTV_StreamRtmpSocket ()<QMTV_StreamingBufferDelegate>
{
    PILI_RTMP* _rtmp;
    BOOL is_videohead;
    BOOL is_audiohead;
}

@property (nonatomic, weak) id<QMTV_StreamSocketDelegate> delegate;
@property (nonatomic, strong) QMTV_Stream *stream;
@property (nonatomic, strong) QMTV_StreamingBuffer *buffer;
@property (nonatomic, strong) QMTV_LiveDrop *drop;

@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, assign) NSInteger retryTimes4netWorkBreaken;
@property (nonatomic, assign) NSInteger reconnectInterval;
@property (nonatomic, assign) NSInteger reconnectCount;

@property (nonatomic, assign) NSString *DeviceID;
@property (atomic, assign) BOOL isSending;

@property (nonatomic, assign) NSString *NetWorkStatus;
@property (nonatomic, assign) BOOL isConnected;//是否连结
@property (nonatomic, assign) BOOL isConnecting;//是否正在连结
@property (nonatomic, assign) BOOL isReconnecting;//是否正在重新连结中
@property (nonatomic, assign) BOOL sendVideoHead;//判断h264 头部字节有无发送
@property (nonatomic, assign) BOOL sendAudioHead;//判断aac 头部字节有无发送
@property (nonatomic, assign) RTMPError error;

@end

@implementation QMTV_StreamRtmpSocket

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

#pragma mark-- 初始化stream;
- (instancetype)initWithStream:(QMTV_Stream*)stream{
    if(!stream) @throw [NSException exceptionWithName:@"QMTV_StreamRtmpSocket init error" reason:@"stream is nil" userInfo:nil];
    if(self = [super init]){
        _stream = stream;
        _reconnectInterval = RetryTimesMargin;
        _reconnectCount = RetryTimesBreaken;
        
        //网路监听
        QMTV_Reachability *reach = [QMTV_Reachability reachabilityWithHostName:@"www.hcios.com"];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:QMTV_ReachabilityChangedNotification object:nil];
        [reach startNotifier];
        
        [self addObserver:self forKeyPath:@"isSending" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

//收到通知调用的方法
- (void)reachabilityChanged:(NSNotification *)notification {
    QMTV_Reachability *reach = [notification object];
    //判断网络状态
    if (![reach isReachable]) {
        NSLog(@"网络连接不可用");
    } else {
        if ([reach currentReachabilityStatus] == ReachableViaWiFi) {
            self.NetWorkStatus=@"WiFi";
//            NSLog(@"WiFi");
        } else if ([reach currentReachabilityStatus] == ReachableViaWWAN) {
            self.NetWorkStatus=@"4g";
//            NSLog(@"4g");
        }
    }
}
/*
 *Rtmp 开始连结
 *1:代表成功连结
 *2:代表正常连结中
 *-1:代表连结失败
 *-2:rtmp url为空值，url为空值将导致崩溃
*/
- (void) start{
    dispatch_async(self.socketQueue, ^{
        if(!_stream) return;
        if(_isConnecting) return;
        [self clean];
        
       self.DeviceID=[self correspondVersion];
       
       NSInteger res= [self RTMP264_Connect:(char*)[_stream.url cStringUsingEncoding:NSASCIIStringEncoding]];
        
        switch (res) {
            case 1:
                NSLog(@"========rtmp connect is successful========");
                break;
            case 2:
                NSLog(@"========rtmp is connecting========");
                break;
            case -1:
                [self clean];
                NSLog(@"========rtmp connect is fail========");
                break;
            case -2:
                [self clean];
                NSLog(@"========rtmp url is null========");
                break;
            default:
                break;
        }
    });
}
/*
 *Rtmp 断开连结
 */
- (void) stop{
    dispatch_async(self.socketQueue, ^{
        if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [self.delegate socketStatus:self status:QMTV_StreamStateDisconnected];
        }
        if(_rtmp != NULL){
            PILI_RTMP_Close(_rtmp, &_error);
            PILI_RTMP_Free(_rtmp);
            _rtmp = NULL;
        }
        [self clean];
    });
}

- (void)sendFrame:(QMTV_Frame*)frame{
 
    if(!frame) return;
    [self.buffer appendObject:frame];
    if(!self.isSending){
        [self sendFrame];
    }

}
/*
 *Rtmp upload
 *VideoHead:每一帧frame都带有头部字节，但是只发一次 多發將給影像帶來不正常
 *AudioHead:每一帧frame都带有头部字节，但是只发一次 多發將給声音带来不正常
 */

#pragma mark -- CustomMethod
- (void)sendFrame{
    dispatch_async(self.socketQueue, ^{
        if(self.buffer.list.count > 0 &&!self.isSending){
            self.isSending = YES;
            if(!_isConnected ||  _isReconnecting || _isConnecting || !_rtmp) {
                self.isSending = NO;
                return;
            }
            
            QMTV_Frame *frame = [self.buffer popFirstObject];
            
            if([frame isKindOfClass:[QMTV_VideoFrame class]]){
                if(!self.sendVideoHead){
                    if(!((QMTV_VideoFrame*)frame).sps || !((QMTV_VideoFrame*)frame).pps){
                        self.isSending = NO;
                        return;
                    }
                    [self sendVideoHeader:(QMTV_VideoFrame*)frame];
                }else{
                    [self sendVideo:(QMTV_VideoFrame*)frame];
                }
            }else{
                if(!self.sendAudioHead){
                
                    if(!((QMTV_AudioFrame*)frame).audioInfo){
                        self.isSending = NO;
                        return;
                    }
                    [self sendAudioHeader:(QMTV_AudioFrame*)frame];
                }else{
                    [self sendAudio:frame];
                }
                
            }
            
            self.drop.totalFrame++;
            self.drop.dropFrame += self.buffer.lastDropFrames;
            self.buffer.lastDropFrames = 0;
            
            self.drop.dataFlow += frame.data.length;
            self.drop.elapsedMilli = CACurrentMediaTime() * 1000 - self.drop.timeStamp;
            
            /*
             *a时间:rtmp send 时间传完在来计算drop时间
             *b时间:rtmp send 没传送成功再来计算drop时间
             *当前时间扣除a时间假超过0.1秒 代表已经传送成功 因为传送需要时间 需要等待rtmp call back的时间
             *当前时间扣除b时间假没超过0.1秒 代表没传送成功 因为没传出去 已经阻塞  当前网路并不好
             *unSendCount超過10基本上網路狀況就已經不好了
             */
            if (self.drop.elapsedMilli < 100) {
                self.drop.bandwidth += frame.data.length;
                if ([frame isKindOfClass:[QMTV_AudioFrame class]]) {
                    self.drop.capturedAudioCount++;
                } else {
                    self.drop.capturedVideoCount++;
                }
                
                self.drop.unSendCount = self.buffer.list.count;
                
                if(self.drop.unSendCount>10){
                    //網路狀況差
                    if(self.delegate && [self.delegate respondsToSelector:@selector(socketBufferStatus:status:)]){
                        [self.delegate socketBufferStatus:self status:QMTV_StreamingDecline];
                    }
                }
                
            }else{
                if(self.delegate && [self.delegate respondsToSelector:@selector(socketBufferStatus:status:)]){
                    [self.delegate socketBufferStatus:self status:QMTV_StreamingIncrease];
                }
                self.drop.currentBandwidth = self.drop.bandwidth;
                self.drop.currentCapturedAudioCount = self.drop.capturedAudioCount;
                self.drop.currentCapturedVideoCount = self.drop.capturedVideoCount;
                self.drop.bandwidth = 0;
                self.drop.capturedAudioCount = 0;
                self.drop.capturedVideoCount = 0;
                self.drop.timeStamp = CACurrentMediaTime() * 1000;
                
            }
            
            //修改发送状态
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //< 这里只为了不循环调用sendFrame方法 调用栈是保证先出栈再进栈
                self.isSending = NO;
            });
        }
    });
}

- (void)clean{
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _isConnected = NO;
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    self.drop = nil;
    [self.buffer removeAllObject];
    self.retryTimes4netWorkBreaken = 0;
}


-(NSInteger) RTMP264_Connect:(char *)push_url{
    
    if(_isConnecting) return 2;
    
    _isConnecting = YES;
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
        [self.delegate socketStatus:self status:QMTV_StreamStateConnecting];
    }
    
    if(_rtmp != NULL){
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);

        _rtmp = NULL;
    }
    
    _rtmp = PILI_RTMP_Alloc();
    PILI_RTMP_Init(_rtmp);
    
    if(push_url==NULL){
        return -2;
    }
    //设置URL
    if (PILI_RTMP_SetupURL(_rtmp, push_url,&_error) < 0){

        goto Failed;
    }
    
    _rtmp->m_errorCallback =  RTMPErrorCallback;
    _rtmp->m_connCallback = ConnectionTimeCallback;
    _rtmp->m_userData = (__bridge void*)self;
    _rtmp->m_msgCounter = 1;
    _rtmp->Link.timeout = RTMP_RECEIVE_TIMEOUT;
    
 
    PILI_RTMP_EnableWrite(_rtmp);
    _rtmp->Link.timeout = RTMP_RECEIVE_TIMEOUT;

    if (PILI_RTMP_Connect(_rtmp, NULL,&_error) < 0){
        goto Failed;
    }
    
    if (PILI_RTMP_ConnectStream(_rtmp, 0,&_error) < 0) {
        goto Failed;
    }
    if(PILI_RTMP_IsConnected(_rtmp) && self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
        [self.delegate socketStatus:self status:QMTV_StreamStateConnected];
    }
    
    [self sendMetaData];
    
    _isConnected = YES;
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _retryTimes4netWorkBreaken = 0;
    return 1;
    
Failed:
    PILI_RTMP_Close(_rtmp, &_error);
    PILI_RTMP_Free(_rtmp);

    [self clean];
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
        [self.delegate socketDidError:self errorCode:QMTV_StreamSocketError_ConnectSocket];
    }
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
        [self.delegate socketStatus:self status:QMTV_StreamStateError];
    }
    return -1;
}
#pragma mark -- Reconnect
-(void)reconnect {
    dispatch_async(self.socketQueue, ^{
        _isReconnecting = NO;
        if(_isConnected) return;
        [self stop];
        [self start];
    });
}

#pragma mark -- CallBack
void RTMPErrorCallback(RTMPError *error, void *userData){

    QMTV_StreamRtmpSocket *socket = (__bridge QMTV_StreamRtmpSocket*)userData;
    if(error->code < 0){
        
        if(socket.delegate && [socket.delegate respondsToSelector:@selector(socketStatus:status:)]){
            [socket.delegate socketStatus:socket status:QMTV_StreamStateError];
        }
        if(socket.retryTimes4netWorkBreaken++ < socket.reconnectCount && !socket.isReconnecting){
            socket.isConnected = NO;
            socket.isConnecting = NO;
            socket.isReconnecting = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(socket.reconnectInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [socket reconnect];
            });
        }else if(socket.retryTimes4netWorkBreaken >= socket.reconnectCount){
            if(socket.delegate && [socket.delegate respondsToSelector:@selector(socketStatus:status:)]){
                [socket.delegate socketStatus:socket status:QMTV_StreamStateError];
            }
            if(socket.delegate && [socket.delegate respondsToSelector:@selector(socketDidError:errorCode:)]){
                [socket.delegate socketDidError:socket errorCode:QMTV_StreamSocketError_ReConnectTimeOut];
            }
        }
    }
}

#pragma mark--Send Metadata
- (void)sendMetaData {
    PILI_RTMPPacket packet;
    
    char pbuf[2048], *pend = pbuf+sizeof(pbuf);
    
    packet.m_nChannel = 0x03;     // control channel (invoke)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = _rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;
    
    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMetaData);
    
    
    *enc++ = AMF_OBJECT;
    
    enc = AMF_EncodeNamedNumber(enc,
                                pend,
                                &av_Duration,
                                0.0);
    enc = AMF_EncodeNamedNumber(enc,
                                pend,
                                &av_FileSize,
                                0.0);
    
    
    // videosize
    
    enc = AMF_EncodeNamedNumber(enc, pend,
                                &av_VideocoWidth,
                                _stream.width);
    
    enc = AMF_EncodeNamedNumber(enc, pend,
                                &av_VideocoHeight,
                                _stream.height);
    
    // video
    enc = AMF_EncodeNamedString(enc, pend,
                                &av_Videocodecid,
                                &av_Avc1);
    
    enc = AMF_EncodeNamedNumber(enc, pend,
                                &av_Videodatarate,
                                _stream.bitrate/ 1000.f);
    
    enc = AMF_EncodeNamedNumber(enc,
                                pend,
                                &av_Framerate,
                                _stream.fps);
    
    // audio
    enc = AMF_EncodeNamedString(enc, pend,
                                &av_Audiocodecid,
                                &av_Mp4a);
    
    enc = AMF_EncodeNamedNumber(enc, pend,
                                &av_Audiodatarate,
                                44100);
    
    enc = AMF_EncodeNamedNumber(enc, pend,
                                &av_Audiosamplerate,
                                64000);
    
    enc = AMF_EncodeNamedNumber(enc,
                                pend,
                                &av_Audiosamplesize,
                                16.0);
    
    enc = AMF_EncodeNamedBoolean(enc,
                                 pend,
                                 &av_Mono,
                                 1);
    
    //network status
    AVal av_network= AVC((char*)[self.NetWorkStatus UTF8String]);
    if(self.NetWorkStatus!=nil){
        enc = AMF_EncodeNamedString(enc,pend,
                                    &av_Network,
                                    &av_network);
    }
    
    
    //device
    if(self.DeviceID!=nil){
        AVal av_device= AVC((char*)[self.DeviceID UTF8String]);
        
        enc = AMF_EncodeNamedString(enc,pend,
                                    &av_ID,
                                    &av_id);
        
        
        enc = AMF_EncodeNamedString(enc,pend,
                                    &av_Device,
                                    &av_device);
    }
    
    // sdk version
    enc = AMF_EncodeNamedString(enc, pend,
                                &av_Encoder,
                                &av_SDKVersion);
    
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;
    
    
    
    packet.m_nBodySize =(uint32_t) (enc - packet.m_body);
    if(!PILI_RTMP_SendPacket(_rtmp, &packet, FALSE, &_error)) {
        return;
    }
}

void ConnectionTimeCallback(PILI_CONNECTION_TIME* conn_time, void *userData){
    
}

#pragma mark -- Rtmp Send Video Head
- (void)sendVideoHeader:(QMTV_VideoFrame*)videoFrame{
    is_videohead=YES;

    unsigned char * body=NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = videoFrame.sps.bytes;
    const char *pps = videoFrame.pps.bytes;
    NSInteger sps_len = videoFrame.sps.length;
    NSInteger pps_len = videoFrame.pps.length;
    
    body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    body[iIndex++] = 0x17;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;
    
    /*sps*/
    body[iIndex++]   = 0xe1;
    body[iIndex++] = (sps_len >> 8) & 0xff;
    body[iIndex++] = sps_len & 0xff;
    memcpy(&body[iIndex],sps,sps_len);
    iIndex +=  sps_len;
    
    /*pps*/
    body[iIndex++]   = 0x01;
    body[iIndex++] = (pps_len >> 8) & 0xff;
    body[iIndex++] = (pps_len) & 0xff;
    memcpy(&body[iIndex], pps, pps_len);
    iIndex +=  pps_len;
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    free(body);
}

#pragma mark -- Rtmp Send Video Frame
- (void)sendVideo:(QMTV_VideoFrame*)frame{
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length+9;
    unsigned char *body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    if(frame.isKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    } else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length ) & 0xff;
    memcpy(&body[i],frame.data.bytes,frame.data.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

#pragma mark -- Rtmp Send Audio Head
- (void)sendAudioHeader:(QMTV_AudioFrame*)audioFrame{
    is_audiohead=true;
    NSInteger rtmpLength = audioFrame.audioInfo.length + 2;
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    body[0] = 0xAF;
    body[1] = 0x00;
    memcpy(&body[2],audioFrame.audioInfo.bytes,audioFrame.audioInfo.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
    free(body);
}

#pragma mark -- Rtmp Send Audio Frame
- (void)sendAudio:(QMTV_Frame*)frame{
    if(!frame) return;
    
    NSInteger rtmpLength = frame.data.length + 2;
    unsigned char * body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    body[0] = 0xAF;
    body[1] = 0x01;
    
    memcpy(&body[2],frame.data.bytes,frame.data.length);
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:frame.timestamp];
    free(body);
}

#pragma mark -- Rtmp Send Packet
-(NSInteger) sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp{
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(_rtmp) rtmp_pack.m_nInfoField2 = _rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];
    
    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(PILI_RTMPPacket*)packet{
    if (PILI_RTMP_IsConnected(_rtmp)){
        int success = PILI_RTMP_SendPacket(_rtmp,packet,0,&_error);
        if(success){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
                if(is_videohead){
                    NSLog(@"video head is send");//確定h264 head 已經送出
                    self.sendVideoHead = YES;
                    is_videohead=false;
                }
                
                if(is_audiohead){
                    NSLog(@"audio head is send");//確定aac head 已經送出
                    self.sendAudioHead = YES;
                    is_audiohead=false;
                }
                
                if(_isSending){
                    [self sendFrame];
                }
            });
            
        }
        return success;
    }
    else{
        _isConnected=false;
        [self reconnect];
    
    }
    return -1;
}

#pragma mark -- Observer
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqualToString:@"isSending"]){
        if(!self.isSending){
            [self sendFrame];
        }
    }
}

#pragma mark -- 懶加載
- (dispatch_queue_t)socketQueue{
    if(!_socketQueue){
        _socketQueue = dispatch_queue_create("com.QMTV_Streaming.live.socketQueue", NULL);
    }
    return _socketQueue;
}

- (QMTV_LiveDrop *)drop {
    if (!_drop) {
        _drop = [[QMTV_LiveDrop alloc] init];
    }
    return _drop;
}

- (QMTV_StreamingBuffer*)buffer{
    if(!_buffer){
        _buffer = [[QMTV_StreamingBuffer alloc] init];
        _buffer.needDropFrame = YES;
        _buffer.delegate = self;
    }
    return _buffer;
}

- (void)streamingBuffer:(nullable QMTV_StreamingBuffer * )buffer bufferState:(QMTV_StreamingState)state{
   
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]){
        [self.delegate socketBufferStatus:self status:state];
    }
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"isSending"];
}


@end
