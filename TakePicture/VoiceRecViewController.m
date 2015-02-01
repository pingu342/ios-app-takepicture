//
//  VoiceRecViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/02/01.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "VoiceRecViewController.h"

@interface VoiceRecViewController ()

@property (nonatomic, weak) IBOutlet UIProgressView *progress;
@property (nonatomic) float time;

@end

@implementation VoiceRecViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.time = 0.0;
	[self.progress setProgress:0.0 animated:NO];
	[self performSelector:@selector(myMethod) withObject:nil afterDelay:0.01];
	self.time = 0;
}

- (void)myMethod {
	self.time += 0.01;
	[self.progress setProgress:(self.time / 3.0) animated:YES];
	
	if (self.time < 3.0) {
		[self performSelector:@selector(myMethod) withObject:nil afterDelay:0.01];
		return;
	}
	
	[self.delegate completed];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
