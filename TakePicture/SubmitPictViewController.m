//
//  SubmitPictViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "SubmitPictViewController.h"
#import "PreviewPictViewController.h"
#import "SubmitPictWithCommentViewController.h"

@interface SubmitPictViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *imagePreview;

@end

@implementation SubmitPictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	self.imagePreview.image = self.image;
	self.imagePreview.contentMode = UIViewContentModeScaleAspectFit;
	
	// self.imagePreviewに影を付ける
	self.imagePreview.layer.masksToBounds = NO;
	self.imagePreview.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
	self.imagePreview.layer.shadowOpacity = 1.0f;
	self.imagePreview.layer.shadowColor = [UIColor blackColor].CGColor;
	self.imagePreview.layer.shadowRadius = 8.0f;
	
	// self.imagePreviewに枠を付ける
	self.imagePreview.layer.borderWidth = 1.0f;
	self.imagePreview.layer.borderColor = [[UIColor whiteColor] CGColor];
	
	//self.comment.layer.cornerRadius = 5.0f;
	//self.comment.clipsToBounds = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)handleGesture:(id)sender {
	PreviewPictViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewPictViewController"];
	viewController.image = self.image;
	[self presentViewController:viewController animated:YES completion:nil];
}

@end
