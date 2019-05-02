//  QMTV_StreamSocket.h
#import <Foundation/Foundation.h>
#import "QMTV_Stream.h"
#import "QMTV_StreamingBuffer.h"

@protocol QMTV_StreamSocket ;
@protocol QMTV_StreamSocketDelegate <NSObject>

- (void)socketBufferStatus:(nullable id<QMTV_StreamSocket>)socket status:(QMTV_StreamingState)status;

- (void)socketStatus:(nullable id<QMTV_StreamSocket>)socket status:(QMTV_StreamState)status;


- (void)socketDidError:(nullable id<QMTV_StreamSocket>)socket errorCode:(QMTV_StreamSocketErrorCode)errorCode;

@end

@protocol QMTV_StreamSocket <NSObject>

- (nullable instancetype)initWithStream:(nullable QMTV_Stream*)stream;
- (void) start;
- (void) stop;
- (void) reconnect;
- (void) sendFrame:(nullable QMTV_Frame*)frame;
- (void) setDelegate:(nullable id<QMTV_StreamSocketDelegate>)delegate;

@end
