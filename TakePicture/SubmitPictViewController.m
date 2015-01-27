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

@end

@implementation SubmitPictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	self.imagePreview.image = self.image;
	self.imagePreview.contentMode = UIViewContentModeScaleAspectFit;
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

- (IBAction)tapBackButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)handleGesture:(id)sender {
	NSLog(@"hogeeee");
	PreviewPictViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewPictViewController"];
	viewController.image = self.image;
	[self presentViewController:viewController animated:YES completion:nil];
}

@end
