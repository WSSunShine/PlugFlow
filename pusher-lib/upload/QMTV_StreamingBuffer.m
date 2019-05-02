 //  QMTV_StreamingBuffer.m

#import "QMTV_StreamingBuffer.h"
#import "NSMutableArray+YYAdd.h"


static const NSUInteger defaultSortBufferMaxCount = 10;///< 排序10个内
static const NSUInteger defaultUpdateInterval = 1;///< 更新频率为1s
static const NSUInteger defaultCallBackInterval = 5;///< 5s计时一次
static const NSUInteger defaultSendBufferMaxCount = 100;///< 最大缓冲区为100

@interface QMTV_StreamingBuffer (){
    dispatch_semaphore_t _lock;
    QMTV_VideoFrame * drop_frame;
    BOOL is_dropframe;
    
}

@property (nonatomic, strong) NSMutableArray <QMTV_Frame*>*sortList;
@property (nonatomic, strong, readwrite) NSMutableArray <QMTV_Frame*>*list;
@property (nonatomic, strong) NSMutableArray *thresholdList;

/** 处理buffer缓冲区情况 */
@property (nonatomic, assign) NSInteger currentInterval;
@property (nonatomic, assign) NSInteger callBackInterval;
@property (nonatomic, assign) NSInteger updateInterval;
@property (nonatomic, assign) BOOL startTimer;

@end

@implementation QMTV_StreamingBuffer

- (instancetype)init{
    if(self = [super init]){
        _lock = dispatch_semaphore_create(1);
        self.updateInterval = defaultUpdateInterval;
        self.callBackInterval = defaultCallBackInterval;
        self.maxCount = defaultSendBufferMaxCount;
        
        self.lastDropFrames = 0;
        self.startTimer = NO;
        self.needDropFrame = YES;
        
        drop_frame=[QMTV_VideoFrame new];
        drop_frame.timestamp=0;
        is_dropframe=false;
    }
    return self;
}

- (void)dealloc{
}

#pragma mark -- Custom

/*
 *每1秒，计算1次 当前buffer
 *
 *新增缓存，先比对timestamp，做排序
 *
 */
- (void)appendObject:(QMTV_Frame*)frame{
    if(!frame) return;
    if(!_startTimer){
        _startTimer = YES;
        [self tick];
    }
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    
    if(self.sortList.count < defaultSortBufferMaxCount){
        [self.sortList addObject:frame];
    }else{
        //< 排序
        [self.sortList addObject:frame];
        
        NSArray *sortedSendQuery = [self.sortList sortedArrayUsingFunction:frameDataCompare context:NULL];
        
        [self.sortList removeAllObjects];
        
        [self.sortList addObjectsFromArray:sortedSendQuery];
        
        // 丢帧
        [self removeExpireFrame];
        
        // 添加至缓冲区
        QMTV_Frame *firstFrame = [self.sortList lf_PopFirstObject];
        
        if(firstFrame) [self.list addObject:firstFrame];
        
        /*****************************容易造成花屏*********************************/
        /**************************关键帧间隔超过2秒丟帧****************************/
        for(NSInteger index = 0;index < self.list.count;index++){
            QMTV_Frame *frame = [self.list objectAtIndex:index];
            if([frame isKindOfClass:[QMTV_VideoFrame class]]){
                QMTV_VideoFrame *videoFrame = (QMTV_VideoFrame*)frame;
                if(videoFrame.isKeyFrame){
                    if(videoFrame.timestamp-drop_frame.timestamp>0){
                        if((int)videoFrame.timestamp-(int)drop_frame.timestamp>2000){
                            is_dropframe=true;
                        }
                        drop_frame=videoFrame;
                    }
                    else{
                        is_dropframe=false;
                    }
                }
            }
        }
    }
    dispatch_semaphore_signal(_lock);
}

- (QMTV_Frame*)popFirstObject{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    QMTV_Frame *firstFrame = [self.list lf_PopFirstObject];
    dispatch_semaphore_signal(_lock);
    return firstFrame;
}

- (void)removeAllObject{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.list removeAllObjects];
    dispatch_semaphore_signal(_lock);
}
/*
 * TCP/CP是阻塞类型，当阻塞到一定的数量超过的缓存数量
 * list:代表可以传送的数量，队列形式，先来的先送出
 * maxcount:代表缓存数量，数量设定在100
 * 当list 超过 maxcount 就代表当前网路已经不好，将进行丟帧
 */
- (void)removeExpireFrame{
    
    if (!is_dropframe&&self.list.count < self.maxCount) return;
    
    if(self.needDropFrame){
        NSArray *pFrames = [self expirePFrames];///< 第一个P到第一个I之间的p帧
        self.lastDropFrames += [pFrames count];
        if (pFrames && pFrames.count > 0) {
            [self.list removeObjectsInArray:pFrames];
            return;
        }
        
        NSArray *iFrames = [self expireIFrames];///<  删除一个I帧（但一个I帧可能对应多个nal）
        self.lastDropFrames += [iFrames count];
        if (iFrames) {
            [self.list removeObjectsInArray:iFrames];
            return;
        }
        NSLog(@"最後丟幀數=%ld",(long)self.lastDropFrames);
        [self.list removeAllObjects];
    }else{
        [self.list lf_PopFirstObject];
    }
}

/*刪除P帧 I幀之前的 P帧 要全部删除 否则一定花屏
 *
 */
- (NSArray*)expirePFrames{
    NSMutableArray *pframes = [[NSMutableArray alloc] init];
    for(NSInteger index = 0;index < self.list.count;index++){
        QMTV_Frame *frame = [self.list objectAtIndex:index];
        if([frame isKindOfClass:[QMTV_VideoFrame class]]){
            QMTV_VideoFrame *videoFrame = (QMTV_VideoFrame*)frame;
            if(videoFrame.isKeyFrame && pframes.count > 0){
                break;
            }else if(!videoFrame.isKeyFrame){
                [pframes addObject:frame];
            }
        }
    }
    return pframes;
}

/*
 * 删除I幀 除非后面已经没有P帧 否则不可随意删除I幀 P帧需要參考I帧
 */
- (NSArray*)expireIFrames{
    NSMutableArray *iframes = [[NSMutableArray alloc] init];
    uint64_t timeStamp = 0;
    for(NSInteger index = 0;index < self.list.count;index++){
        QMTV_Frame *frame = [self.list objectAtIndex:index];
        if([frame isKindOfClass:[QMTV_VideoFrame class]] && ((QMTV_VideoFrame*)frame).isKeyFrame){
            if(timeStamp != 0 && timeStamp != frame.timestamp) break;
            [iframes addObject:frame];
            timeStamp = frame.timestamp;
        }
    }
    return iframes;
}
/*
 *比较时间戳，做递增排列
 */
NSInteger frameDataCompare(id obj1, id obj2, void *context){
    QMTV_Frame* frame1 = (QMTV_Frame*) obj1;
    QMTV_Frame *frame2 = (QMTV_Frame*) obj2;
    
    if (frame1.timestamp == frame2.timestamp)
        return NSOrderedSame;
    else if(frame1.timestamp > frame2.timestamp)
        return NSOrderedDescending;
    return NSOrderedAscending;
}

- (QMTV_StreamingState)currentBufferState{
    NSInteger currentCount = 0;
    NSInteger increaseCount = 0;
    NSInteger decreaseCount = 0;
    
    for(NSNumber *number in self.thresholdList){
        if(number.integerValue >= currentCount){
            increaseCount ++;
        }else{
            decreaseCount ++;
        }
        currentCount = [number integerValue];
    }
    
    if(increaseCount >= self.callBackInterval){
        return QMTV_StreamingIncrease;
    }
    
    if(decreaseCount >= self.callBackInterval){
        return QMTV_StreamingDecline;
    }
    
    return QMTV_StreamingUnknown;
}

#pragma mark -- Setter Getter
- (NSMutableArray*)list{
    if(!_list){
        _list = [[NSMutableArray alloc] init];
    }
    return _list;
}

- (NSMutableArray*)sortList{
    if(!_sortList){
        _sortList = [[NSMutableArray alloc] init];
    }
    return _sortList;
}

- (NSMutableArray*)thresholdList{
    if(!_thresholdList){
        _thresholdList = [[NSMutableArray alloc] init];
    }
    return _thresholdList;
}



/*
 *用当前时间与callback的时间差 来计算当前buffer状况 尚未写好
 */
#pragma mark -- 采样
//每一秒来计算
- (void)tick{
    _currentInterval += self.updateInterval;
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.thresholdList addObject:@(self.list.count)];
    dispatch_semaphore_signal(_lock);
    
    if(self.currentInterval >= self.callBackInterval){
        QMTV_StreamingState state = [self currentBufferState];
        
//        if(state == QMTV_StreamingIncrease){
//            if(self.delegate && [self.delegate respondsToSelector:@selector(streamingBuffer:bufferState:)]){
//                [self.delegate streamingBuffer:self bufferState:QMTV_StreamingIncrease];
//            }
//        }else if(state == QMTV_StreamingDecline){
//            if(self.delegate && [self.delegate respondsToSelector:@selector(streamingBuffer:bufferState:)]){
//                [self.delegate streamingBuffer:self bufferState:QMTV_StreamingDecline];
//            }
//        }
        self.currentInterval = 0;
        [self.thresholdList removeAllObjects];
    }
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.updateInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __weak typeof(_self) self = _self;
        [self tick];
    });
}

@end
