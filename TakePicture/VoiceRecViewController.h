//
//  VoiceRecViewController.h
//  TakePicture
//
//  Created by Masakiyo on 2015/02/01.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VoiceRecViewControllerProtocol

- (void)completed;

@end

@interface VoiceRecViewController : UIViewController

@property (nonatomic, weak) id<VoiceRecViewControllerProtocol> delegate;

@end
