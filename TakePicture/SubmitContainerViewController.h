//
//  SubmitContainerViewController.h
//  TakePicture
//
//  Created by Masakiyo on 2015/02/01.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VoiceRecViewController.h"

@interface SubmitContainerViewController : UIViewController <VoiceRecViewControllerProtocol>

@property (nonatomic) UIImage *image;

@end
