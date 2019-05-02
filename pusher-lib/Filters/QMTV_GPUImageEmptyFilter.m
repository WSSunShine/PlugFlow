//
//  GPUImageEmptyFilter.m
//  BeautifyFace
//
//  Created by jianqiangzhang on 16/5/27.
//  Copyright © 2016年 ClaudeLi. All rights reserved.
//

#import "QMTV_GPUImageEmptyFilter.h"
NSString *const QMTVGPUImageEmptyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     gl_FragColor = vec4((textureColor.rgb), textureColor.w);
 }
 );
@implementation QMTV_GPUImageEmptyFilter
- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:QMTVGPUImageEmptyFragmentShaderString]))
    {
        return nil;
    }
    
    return self;
}
@end
