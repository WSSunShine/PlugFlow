//
//  ParameterModel.h
//  pusher-Demo
//
//  Created by Rick_Hsu on 2016/11/3.
//  Copyright © 2016年 Edtion. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface ParameterModel : NSObject

@property (nonatomic, assign)CGSize video_size;
@property (nonatomic, strong)NSString *video_FPS;
@property (nonatomic, strong)NSString *video_bitrate;
@property (nonatomic, strong)NSString *video_url;

@end
