//  QMTV_Stream

#import "FrameSession.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

//Stream_State
typedef NS_ENUM(NSUInteger, QMTV_StreamState){
    //未知狀態
    QMTV_StreamStateStreamStateUnknow = 0,
    //連接中
    QMTV_StreamStateConnecting,
    /// 已連接
    QMTV_StreamStateConnected,
    /// 重新連接中
    QMTV_StreamStateRconnecting,
    /// 已斷開
    QMTV_StreamStateDisconnected,
    /// 連接出错
    QMTV_StreamStateError
};

typedef NS_ENUM(NSUInteger,QMTV_StreamSocketErrorCode) {
    QMTV_StreamSocketError_ConnectSocket    = 0,// 連接socket失败
    QMTV_StreamSocketError_Verification     = 1,// 驗證服務器失敗
    QMTV_StreamSocketError_ReConnectTimeOut = 2 // 重新連接服务器超时
};


@interface QMTV_Stream : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic,assign) int bitrate;
@property (nonatomic, assign) int fps;
@end
