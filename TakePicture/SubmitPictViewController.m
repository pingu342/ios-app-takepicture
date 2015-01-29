//
//  SubmitPictViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "SubmitPictViewController.h"
#import "PreviewPictViewController.h"

@interface SubmitPictViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *imagePreview;
@property (nonatomic, weak) IBOutlet UITextView *comment;
@property (nonatomic, weak) IBOutlet UIView *content;

@end

@implementation SubmitPictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	self.imagePreview.image = self.image;
	self.imagePreview.contentMode = UIViewContentModeScaleAspectFit;
	
	// 影を付ける
#if 1
	self.imagePreview.layer.masksToBounds = NO;
	self.imagePreview.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);
	self.imagePreview.layer.shadowOpacity = 1.0f;
	self.imagePreview.layer.shadowColor = [UIColor blackColor].CGColor;
	self.imagePreview.layer.shadowRadius = 10.0f;
#endif
#if 1
	self.content.layer.masksToBounds = NO;
	self.content.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);
	self.content.layer.shadowOpacity = 1.0f;
	self.content.layer.shadowColor = [UIColor grayColor].CGColor;
	self.content.layer.shadowRadius = 1.0f;
#endif
	
	// 枠を付ける
	self.imagePreview.layer.borderWidth = 1.0f;
	self.imagePreview.layer.borderColor = [[UIColor whiteColor] CGColor];
	
	self.comment.layer.cornerRadius = 5.0f;
	self.comment.clipsToBounds = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate {
	return NO;	// 画面を回転させない
}

- (NSUInteger)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskLandscapeRight;	//画面向きをランドスケープ(ホームボタン右)で固定
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)tapBackButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
	self.image = nil;
}

- (IBAction)handleGesture:(id)sender {
	NSLog(@"hogeeee");
	PreviewPictViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewPictViewController"];
	viewController.image = self.image;
	[self presentViewController:viewController animated:YES completion:nil];
}


- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

@end
