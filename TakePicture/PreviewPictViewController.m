//
//  PreviewPictViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "PreviewPictViewController.h"

@interface PreviewPictViewController ()

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation PreviewPictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	self.imageView.image = self.image;
	self.imageView.contentMode = UIViewContentModeScaleAspectFit;
	
	self.scrollView.minimumZoomScale = 1.0;
	self.scrollView.maximumZoomScale = 3.0;
	self.scrollView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
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

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return self.imageView;
}

- (IBAction)tapBackButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

@end
