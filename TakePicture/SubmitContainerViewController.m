//
//  SubmitContainerViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/02/01.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "SubmitContainerViewController.h"
#import "SubmitPictViewController.h"
#import "SubmitPictWithCommentViewController.h"
#import "VoiceRecViewController.h"

@interface SubmitContainerViewController ()

@property (nonatomic, weak) IBOutlet UIView *contentView;
@property (nonatomic) SubmitPictViewController *pictViewController;
@property (nonatomic) SubmitPictWithCommentViewController *pictWithCommentViewController;
@property (nonatomic) VoiceRecViewController *voiceRecViewController;
@property (nonatomic) UIViewController *presentingChildViewController;
@property (nonatomic, weak) IBOutlet UIButton *firstButton;
@property (nonatomic, weak) IBOutlet UIButton *secondButton;

@end

@implementation SubmitContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
#if 0
	// self.contentViewに影を付ける
	self.contentView.layer.masksToBounds = NO;
	self.contentView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
	self.contentView.layer.shadowOpacity = 1.0f;
	self.contentView.layer.shadowColor = [UIColor grayColor].CGColor;
	self.contentView.layer.shadowRadius = 1.0f;
#endif
	
	// self.contentViewに表示するビューコントローラのインスタンスを作成
	self.pictViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SubmitPictViewController"];
	self.pictViewController.image = self.image;
	self.pictWithCommentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SubmitPictWithCommentViewController"];
	self.pictWithCommentViewController.image = self.image;
	self.voiceRecViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"VoiceRecViewController"];
	self.voiceRecViewController.delegate = self;
	
	// self.contentViewにビューコントローラを表示
	UIViewController *child = self.pictViewController;
	child.view.frame = self.contentView.bounds;
	[self addChildViewController:child];
	[self.contentView addSubview:child.view];
	[child didMoveToParentViewController:self];
	self.presentingChildViewController = child;
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

- (void)presetChildViewController:(UIViewController *)child {
	
	if (self.presentingChildViewController == child || child == nil) {
		return;
	}
	
	UIViewController *oldC = self.presentingChildViewController;
	UIViewController *newC = child;
	
	[oldC willMoveToParentViewController:nil];
	[self addChildViewController:newC];
	
	newC.view.frame = self.contentView.bounds;
	
	[self transitionFromViewController: oldC toViewController: newC
							  duration: 0.5 options:UIViewAnimationOptionTransitionCrossDissolve
							animations:^{
							}
							completion:^(BOOL finished) {
								[oldC removeFromParentViewController];
								[newC didMoveToParentViewController:self];
							}];
	
	self.presentingChildViewController = newC;
}

- (IBAction)tapBackButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
	self.image = nil;
}

- (IBAction)tapFirstButton:(id)sender {
	
	UIViewController *parent = nil;
	UIViewController *child = nil;
	
	// プログレスバーを表示
	if (self.presentingChildViewController == self.pictViewController ||
		self.presentingChildViewController == self.pictWithCommentViewController) {
		parent = self.presentingChildViewController;
		child = self.voiceRecViewController;
	} else {
		return;
	}
	child.view.frame = parent.view.bounds;
	[parent addChildViewController:child];
	[parent.view addSubview:child.view];
	[child didMoveToParentViewController:parent];
	
	// コメント追加ボタンをキーボードボタンに変更
	[self.firstButton setImage:[UIImage imageNamed:@"Keyboard"] forState:UIControlStateNormal];
}

- (IBAction)tapSecondButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
	self.image = nil;
}

- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotate {
	return NO;	// 画面を回転させない
}

- (NSUInteger)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskLandscapeRight;	//画面向きをランドスケープ(ホームボタン右)で固定
}

- (void)completed {
	// プログレスバーを消す
	[self.voiceRecViewController willMoveToParentViewController:nil];
	[self.voiceRecViewController.view removeFromSuperview];
	[self.voiceRecViewController removeFromParentViewController];
	
	// コメント付きで表示
	[self presetChildViewController:self.pictWithCommentViewController];
	
	// コメント追加ボタンをコメントやりなおしボタンに変更
	[self.firstButton setImage:[UIImage imageNamed:@"Undo"] forState:UIControlStateNormal];
}

@end
