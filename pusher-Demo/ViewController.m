//
//  ViewController.m
//  pusher-Demo
//
//  Created by Rick_Hsu on 2016/11/3.
//  Copyright © 2016年 Edtion. All rights reserved.
//

#import "ViewController.h"
#import "ParameterModel.h"
#import "FrameSession.h"

#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)

@interface ViewController ()
{
    UIView *containerView;
    UIView *encodeView;
    UITextField *url_tf;
    
    ParameterModel *parameterModel;
    
    CGFloat toneLevel;
    CGFloat beautyLevel;
    CGFloat brightLevel;
    
    BOOL is_mirror;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //默认值
    parameterModel = [[ParameterModel alloc]init];
    parameterModel.video_size = CGSizeMake(540, 960);
    parameterModel.video_FPS = @"24";
    parameterModel.video_bitrate = @"800000";
    //美颜参数默认值
    toneLevel = 0.3;
    beautyLevel = 0.1;
    brightLevel = 0.5;
    
    [self createSubviews];
    
    [self createFrameSession];
}

- (void)createSubviews{
    
    containerView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    [self.view addSubview:containerView];
    
    NSArray *title_arr = @[@"分辨率",@"FPS",@"码率"];
    
    NSArray *video_size_arr = @[@"360x640",@"540x960",@"720x1280"];
    NSArray *video_FPS_arr = @[@"30",@"24",@"20",@"15"];
    NSArray *video_Bitrate_arr = @[@"1500",@"800",@"500"];
    NSArray *seg_arr = @[video_size_arr,video_FPS_arr,video_Bitrate_arr];
    
    for (int i = 0; i < 3; i++) {
        
        UILabel *title_lbl = [[UILabel alloc]initWithFrame:CGRectMake(30, 50 +60*i, 150, 30)];
        title_lbl.text = title_arr[i];
        title_lbl.font = [UIFont systemFontOfSize:15];
        [containerView addSubview:title_lbl];
        
        UISegmentedControl *seg = [[UISegmentedControl alloc]initWithItems:seg_arr[i]];
        seg.selectedSegmentIndex = 1;
        seg.tag = 100 +i;
        seg.frame = CGRectMake(10, 80 +60*i, SCREEN_WIDTH -20, 30);
        [seg addTarget:self action:@selector(change:) forControlEvents:UIControlEventValueChanged];
        [containerView addSubview:seg];
    }
    
    UILabel *title_lbl = [[UILabel alloc]initWithFrame:CGRectMake(30, 240, 150, 30)];
    title_lbl.text = @"推流地址";
    title_lbl.font = [UIFont systemFontOfSize:15];
    [containerView addSubview:title_lbl];
    
    if (!url_tf) {
        url_tf = [[UITextField alloc]initWithFrame:CGRectMake(10, 270, SCREEN_WIDTH -20, 30)];
        url_tf.borderStyle = UITextBorderStyleRoundedRect;
        url_tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        //rtmp://45.124.125.45/live/3961948?key=70183107eb175d380b2198a77abb37ee&wsHost=up.quanmin.tv&screen=1&categoryId=29&title=Edtion%20is%20Busy
        url_tf.text = @"rtmp://10.9.1.106:1990/liveApp/room";
        [containerView addSubview:url_tf];
    }
    
    UIButton *startPreview_btn = [UIButton buttonWithType:UIButtonTypeCustom];
    startPreview_btn.frame = CGRectMake(50, 350, SCREEN_WIDTH -100, 35);
    startPreview_btn.layer.borderWidth = 1.0;
    startPreview_btn.layer.borderColor = [UIColor blueColor].CGColor;
    [startPreview_btn setTitle:@"开始预览" forState:UIControlStateNormal];
    [startPreview_btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [startPreview_btn setTitleColor:[UIColor purpleColor] forState:UIControlStateHighlighted];
    [startPreview_btn addTarget:self action:@selector(start_preview:) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:startPreview_btn];
    
    
    
    encodeView = [[UIView alloc]initWithFrame:self.view.frame];
    encodeView.hidden = YES;
    
    for (int i = 1; i < 4; i++) {
        //美颜相关控件
        UISlider *slider = [[UISlider alloc]initWithFrame:CGRectMake(1-0, SCREEN_HEIGHT -(50 *(4-i)), SCREEN_WIDTH -80, 30)];
        slider.tag = 200 +i;
        slider.minimumValue = -1.5;
        slider.maximumValue = 1.5;
        [slider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
        [encodeView addSubview:slider];
        
        UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(SCREEN_WIDTH -70, SCREEN_HEIGHT -(50 *(4-i)), 60, 30)];
        label.tag = 300 +i;
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:18];
        [encodeView addSubview:label];
    }
    
    for (int i = 1; i < 5; i++) {
        //播放相关
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 400 +i;
        button.frame = CGRectMake(SCREEN_WIDTH -(10 +35)*(5 -i) , 20, 35, 35);
        NSString *imageName;
        SEL method;
        if (i == 1) {
            imageName = @"camra_beauty_close";
            method = @selector(isMirror);
        }else if (i == 2){
            imageName = @"camra_beauty";
            method = @selector(isBeauty);
        }else if (i == 3){
            imageName = @"camra_preview";
            method = @selector(isCamera);
        }else if (i == 4){
            imageName = @"close_preview";
            method = @selector(closePreview);
        }
        [button addTarget:self action:method forControlEvents:UIControlEventTouchUpInside];
        [button setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        [encodeView addSubview:button];
    }
    
    
    UIButton *startEncode_btn = [UIButton buttonWithType:UIButtonTypeCustom];
    startEncode_btn.tag = 999;
    startEncode_btn.frame = CGRectMake(50, 350, SCREEN_WIDTH -100, 35);
    startEncode_btn.layer.borderWidth = 1.0;
    startEncode_btn.layer.borderColor = [UIColor blueColor].CGColor;
    [startEncode_btn setTitle:@"开始直播" forState:UIControlStateNormal];
    [startEncode_btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [startEncode_btn setTitleColor:[UIColor purpleColor] forState:UIControlStateHighlighted];
    [startEncode_btn addTarget:self action:@selector(start_encode:) forControlEvents:UIControlEventTouchUpInside];
    [encodeView addSubview:startEncode_btn];
}

- (void)createFrameSession{
    [[FrameSession getInstance] setSessionFrameWidth:parameterModel.video_size.width height:parameterModel.video_size.height FPS:[parameterModel.video_FPS intValue]  bitrate:[parameterModel.video_bitrate intValue] horizontal:NO];
    [[FrameSession getInstance] Preview:self.view];
    [[FrameSession getInstance] startPreview];
}

#pragma mark - session参数设置
- (void)change:(UISegmentedControl *)seg{
    switch (seg.tag) {
        case 100:
        {
            if (seg.selectedSegmentIndex == 0) {
                parameterModel.video_size = CGSizeMake(360, 640);
            }else if (seg.selectedSegmentIndex == 1){
                parameterModel.video_size = CGSizeMake(540, 960);
            }else if (seg.selectedSegmentIndex == 2){
                parameterModel.video_size = CGSizeMake(720, 1280);
            }
        }
            break;
        case 101:
        {
            if (seg.selectedSegmentIndex == 0) {
                parameterModel.video_FPS = @"30";
            }else if (seg.selectedSegmentIndex == 1){
                parameterModel.video_FPS = @"25";
            }else if (seg.selectedSegmentIndex == 2){
                parameterModel.video_FPS = @"20";
            }else if (seg.selectedSegmentIndex == 3){
                parameterModel.video_FPS = @"15";
            }
        }
            break;
        case 102:
        {
            if (seg.selectedSegmentIndex == 0) {
                parameterModel.video_bitrate = @"1500000";
            }else if (seg.selectedSegmentIndex == 1){
                parameterModel.video_bitrate = @"800000";
            }else if (seg.selectedSegmentIndex == 2){
                parameterModel.video_bitrate = @"500000";
            }
        }
            break;
    }
}

#pragma mark - 开始预览
- (void)start_preview:(id)sender{
    containerView.hidden = YES;
    encodeView.hidden = NO;
    [self.view addSubview:encodeView];
    [[FrameSession getInstance] setSessionFrameWidth:parameterModel.video_size.width height:parameterModel.video_size.height FPS:[parameterModel.video_FPS intValue]  bitrate:[parameterModel.video_bitrate intValue] horizontal:NO];
    [[FrameSession getInstance] stopEncoding];
    [[FrameSession getInstance] startPreview];
    [[FrameSession getInstance] Rtmp_url:url_tf.text];
    [FrameSession getInstance].mirror = YES;
}

#pragma mark - 开始直播
- (void)start_encode:(id)sender{
    [[FrameSession getInstance] startEncoding];
    [(UIButton *)sender setHidden:YES];
}

#pragma mark - 调整美颜效果
- (void)sliderValueChange:(UISlider *)slider{
    switch (slider.tag) {
        case 201:
        {
            UILabel *label = [self.view viewWithTag:301];
            label.text =[NSString stringWithFormat:@"%.2f",slider.value];
            toneLevel = slider.value;
            [[FrameSession getInstance] setBeautyWithToneLevel:toneLevel beautyLevel:beautyLevel brightLevel:brightLevel];
            
        }
            break;
        case 202:
        {
            UILabel *label = [self.view viewWithTag:302];
            label.text =[NSString stringWithFormat:@"%.2f",slider.value];
            beautyLevel = slider.value;
            [[FrameSession getInstance] setBeautyWithToneLevel:toneLevel beautyLevel:beautyLevel brightLevel:brightLevel];
        }
            break;
        case 203:
        {
            UILabel *label = [self.view viewWithTag:303];
            label.text =[NSString stringWithFormat:@"%.2f",slider.value];
            brightLevel = slider.value;
            [[FrameSession getInstance] setBeautyWithToneLevel:toneLevel beautyLevel:beautyLevel brightLevel:brightLevel];
        }
            break;
    }
}
#pragma mark - 右上角按钮触发
//美颜开关
- (void)isBeauty{
    [FrameSession getInstance].beautyFace = ![FrameSession getInstance].beautyFace;
}
//前后镜头
- (void)isCamera{
    if ([FrameSession getInstance].capturePositionBack == 1) {
        [FrameSession getInstance].capturePositionBack = 2;
    } else{
        [FrameSession getInstance].capturePositionBack = 1;
    }
}
//退出预览到session设置
- (void)closePreview{
    [[FrameSession getInstance] stopEncoding];
    
    UIButton *button = [self.view viewWithTag:999];
    [button setHidden:NO];
    [encodeView removeFromSuperview];
    encodeView.hidden = YES;
    
    containerView.hidden = NO;
}
//镜像
- (void)isMirror{
    is_mirror = !is_mirror;
    [FrameSession getInstance].mirror = is_mirror;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
