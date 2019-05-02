#import "GPUImageFilter.h"

@interface QMTV_GPUImageBeautyFilter : GPUImageFilter {
}
@property (nonatomic, assign) CGFloat intensity;
@property (nonatomic, assign) CGFloat beautyLevel;
@property (nonatomic, assign) CGFloat brightLevel;
@property (nonatomic, assign) CGFloat toneLevel;

//调整美颜效果
- (void)setBeautyWithToneLevel:(CGFloat)toneLevel beautyLevel:(CGFloat)beautyLevel brightLevel :(CGFloat)brightLevel;

@end
