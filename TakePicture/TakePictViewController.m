//
//  TakePictViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "TakePictViewController.h"
#import "PreviewPictViewController.h"
#import "CameraManager.h"
#import "DeviceSystemVersion.h"

#import <ImageIO/ImageIO.h>

#define RAW_IMAGE

/// フォーカスモード
typedef NS_ENUM(NSInteger, FocusMode) {
	/// 自動モード
	FocusModeAutoFocus,
	/// 自動ロックモード
	FocusModeWhileEnteringAutoFocusModeLocked,
	/// 自動ロックモード
	FocusModeAutoFocusLocked,
	/// 手動モードへ変更中
	FocusModeWhileEnteringManualFocus,
	/// 手動モード
	FocusModeManualFocus,
	/// 自動モードへ変更中
	FocusModeWhileEnteringAutoFocus
};

/// 露出モード
typedef NS_ENUM(NSInteger, ExposureMode) {
	/// 自動モード
	ExposureModeAutoExpose,
	/// 自動ロックモードへ変更中
	ExposureModeWhileEnteringAutoExposeLocked,
	/// 自動ロックモード
	ExposureModeAutoExposeLocked,
	/// 手動モードへ変更中
	ExposureModeWhileEnteringManualExpose,
	/// 手動モード
	ExposureModeManulaExpose,
	/// 自動モードへ変更中
	ExposureModeWhileEnteringAutoExpose
};

@interface TakePictViewController () {
}

// UI
@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *flashModeButton;
@property (nonatomic, weak) IBOutlet UILabel *flashModeLabel;
@property (nonatomic, weak) IBOutlet UIButton *zoomModeButton;
@property (nonatomic, weak) IBOutlet UILabel *zoomValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *zoomValueEditButton;
@property (nonatomic, weak) IBOutlet UISlider *zoomValueSlider;
@property (nonatomic, weak) IBOutlet UIButton *zoomValueSliderCloseButton;
@property (nonatomic, weak) IBOutlet UIButton *focusModeButton;
@property (nonatomic, weak) IBOutlet UILabel *focusModeLabel;
@property (nonatomic, weak) IBOutlet UILabel *focusLensPositionLabel;
@property (nonatomic, weak) IBOutlet UIButton *focusLensPositionEditButton;
@property (nonatomic, weak) IBOutlet UISlider *focusLensPositionSlider;
@property (nonatomic, weak) IBOutlet UIButton *focusLensPositionSliderCloseButton;
@property (nonatomic, weak) IBOutlet UIButton *exposureModeButton;
@property (nonatomic, weak) IBOutlet UILabel *exposureModeLabel;
//@property (nonatomic, weak) IBOutlet UIButton *exposureDurationButton;
@property (nonatomic, weak) IBOutlet UILabel *exposureDurationLabel;
@property (nonatomic, weak) IBOutlet UIButton *exposureDurationEditButton;
@property (nonatomic, weak) IBOutlet UISlider *exposureDurationSlider;
@property (nonatomic, weak) IBOutlet UIButton *exposureDurationSliderCloseButton;
//@property (nonatomic, weak) IBOutlet UIButton *wbButton;
//@property (nonatomic, weak) IBOutlet UILabel *wbValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *evShiftButton;
//@property (nonatomic, weak) IBOutlet UILabel *evOffsetLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureTargetBiasLabel;
@property (nonatomic, weak) IBOutlet UIButton *exposureTargetBiasEditButton;
@property (nonatomic, weak) IBOutlet UISlider *exposureTargetBiasSlider;
@property (nonatomic, weak) IBOutlet UIButton *exposureTargetBiasSliderCloseButton;
@property (nonatomic, weak) IBOutlet UIButton *isoModeButton;
@property (nonatomic, weak) IBOutlet UILabel *isoModeLabel;
@property (nonatomic, weak) IBOutlet UILabel *isoValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *isoValueEditButton;
@property (nonatomic, weak) IBOutlet UISlider *isoValueSlider;
@property (nonatomic, weak) IBOutlet UIButton *isoValueSliderCloseButton;
@property (nonatomic, weak) IBOutlet UIImageView *focusPointOfInterestImageView;
@property (nonatomic, weak) IBOutlet UIImageView *exposurePointOfInterestImageView;
//@property (nonatomic, weak) IBOutlet UIButton *resetButton;

// dispatch_queueスレッドからアクセス
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDevice *captureDevice;
@property (nonatomic) AVCaptureDeviceInput *captureInput;
@property (nonatomic) AVCaptureStillImageOutput *captureOutput;
@property (nonatomic) AVCaptureConnection *captureConnection;
@property (nonatomic) AVCaptureVideoPreviewLayer *capturePreviewLayer;
@property (nonatomic) BOOL capturing;

// mainスレッドからアクセス
@property (nonatomic) BOOL previewing;
@property (nonatomic) CGFloat zoomValue;
@property (nonatomic) CGFloat maxZoomFactor;
@property (nonatomic) FocusMode focusMode;
@property (nonatomic) ExposureMode exposureMode;
@property (nonatomic) NSLayoutConstraint *focusPointOfInterestImageViewConstraintX;
@property (nonatomic) NSLayoutConstraint *focusPointOfInterestImageViewConstraintY;
@property (nonatomic) NSLayoutConstraint *exposurePointOfInterestImageViewConstraintX;
@property (nonatomic) NSLayoutConstraint *exposurePointOfInterestImageViewConstraintY;

@property (nonatomic, readonly) BOOL focusModeManualFocusSupported;
@property (nonatomic, readonly) BOOL exposureModeManualExposeSupported;

@property (nonatomic) dispatch_queue_t queue;

@end

@implementation TakePictViewController

- (void)viewDidLoad {
	NSLog(@"%s", __FUNCTION__);
	
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	if ([DeviceSystemVersion sharedInstance].major <= 7) {
		self.focusModeButton.hidden = YES;
		self.focusModeLabel.hidden = YES;
	}
	
	dispatch_queue_t queue = dispatch_queue_create("myQueue", DISPATCH_QUEUE_SERIAL);
	self.queue = queue;
	
	self.previewing = NO;
	
	// プログラムから動的に値を変更する制約を追加
	[self resetFocusPointOfInterestImageViewPosition];
	[self resetExposurePointOfInterestImageViewPosition];
}

- (void)didReceiveMemoryWarning {
	NSLog(@"%s", __FUNCTION__);
	
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewWillAppear:animated];
	
	// ビューを初期状態に設定
	self.flashModeButton.hidden = NO;
	self.flashModeButton.enabled = NO;
	self.flashModeLabel.text = @" ";
	
	self.zoomModeButton.hidden = NO;
	self.zoomModeButton.enabled = NO;
	self.zoomModeButton.userInteractionEnabled = NO;
	self.zoomValue = 1.0;
	self.zoomValueLabel.text = @" ";
	self.zoomValueSlider.hidden = YES;
	self.zoomValueEditButton.hidden = YES;
	self.zoomValueSliderCloseButton.hidden = YES;
	
	self.focusMode = FocusModeAutoFocus;
	self.focusModeButton.hidden = NO;
	self.focusModeButton.enabled = NO;
	self.focusModeLabel.text = @" ";
	self.focusLensPositionLabel.text = @" ";
	self.focusLensPositionSlider.hidden = YES;
	self.focusLensPositionEditButton.hidden = YES;
	self.focusLensPositionSliderCloseButton.hidden = YES;

	self.exposureMode = ExposureModeAutoExpose;
	self.exposureModeButton.hidden = NO;
	self.exposureModeButton.enabled = NO;
	self.exposureModeLabel.text = @" ";
	self.exposureDurationLabel.text = @" ";
	self.exposureDurationSlider.hidden = YES;
	self.exposureDurationEditButton.hidden = YES;
	self.exposureDurationSliderCloseButton.hidden = YES;
	
	//self.wbButton.enabled = NO;
	//self.wbValueLabel.text = @" ";
	//self.wbStatusLabel.text = @"White Balance Mode:";
	
	self.evShiftButton.hidden = NO;
	self.evShiftButton.enabled = NO;
	//self.evOffsetLabel.text = @" ";
	self.exposureTargetBiasLabel.text = @" ";
	self.exposureTargetBiasSlider.hidden = YES;
	self.exposureTargetBiasEditButton.hidden = YES;
	self.exposureTargetBiasSliderCloseButton.hidden = YES;
	
	self.isoModeButton.hidden = NO;
	self.isoModeButton.enabled = NO;
	self.isoModeLabel.text = @" ";
	self.isoValueLabel.text = @" ";
	self.isoValueSlider.hidden = YES;
	self.isoValueEditButton.hidden = YES;
	self.isoValueSliderCloseButton.hidden = YES;
	
	self.focusPointOfInterestImageView.hidden = YES;
	self.exposurePointOfInterestImageView.hidden = YES;
	//self.resetButton.hidden = YES;
	
	// カメラを開始して、全パラメーターをデフォルト値にリセット
	[self enqSel:@selector(setupCapture)];
	[self enqSel:@selector(resetCameraSettingsToDefault)];
}

- (void)viewWillDisappear:(BOOL)animated {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewWillDisappear:animated];
	
	// カメラを停止
	[self enqSel:@selector(teardownCapture)];
}

- (void)viewDidLayoutSubviews {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewDidLayoutSubviews];
	//self.capturePreviewLayer.frame = self.previewView.bounds;
	//[self.view layoutIfNeeded];
}

- (BOOL)shouldAutorotate {
	return NO;	// 画面を回転させない
}

- (NSUInteger)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskLandscapeRight;	//画面向きをランドスケープ(ホームボタン右)で固定
}

- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)handleTapBackButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)handleTapTakePictButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self enqSel:@selector(takePicture)];
}

- (IBAction)handleTakePictButtonLongPressGesture:(UIGestureRecognizer *)sender {
	NSLog(@"%s", __FUNCTION__);
	
	if (sender.state == UIGestureRecognizerStateBegan) {
		NSLog(@"LongPress Began");
		[self lockAutoFocusAndAutoExposeWithInterestPoint:CGPointMake(-1.0, -1.0) //無効なinterestPoint
								 showPointOfInterestImage:NO
							 pointOfInterestImagePosition:CGPointMake(0.0, 0.0)];
	} else if (sender.state == UIGestureRecognizerStateChanged) {
		NSLog(@"LongPress Changed");
	} else if (sender.state == UIGestureRecognizerStateEnded) {
		NSLog(@"LongPress Ended");
	} else if (sender.state == UIGestureRecognizerStateCancelled) {
		NSLog(@"LongPress Canceled");
	} else if (sender.state == UIGestureRecognizerStateFailed) {
		NSLog(@"LongPress Failed");
	} else if (sender.state == UIGestureRecognizerStateRecognized) {
		NSLog(@"LongPress Recognized");
	}
}

- (IBAction)handleTapResetButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self enqSel:@selector(resetCameraSettingsToDefault)];
}

- (IBAction)handleTapZoomButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
}

- (IBAction)handleTapFocusButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	FocusMode newFocusMode;
	
	// フォーカスモード切替
	if (self.focusMode == FocusModeAutoFocus) {
		if (self.focusModeManualFocusSupported) {
			newFocusMode = FocusModeWhileEnteringManualFocus;
		} else {
			// TODO: エラーメッセージ？
			return;
		}
	} else if (self.focusMode == FocusModeAutoFocusLocked) {
		if (self.focusModeManualFocusSupported) {
			newFocusMode = FocusModeWhileEnteringManualFocus;
		} else {
			// TODO: エラーメッセージ？
			newFocusMode = FocusModeWhileEnteringAutoFocus;
		}
	} else if (self.focusMode == FocusModeManualFocus) {
		newFocusMode = FocusModeWhileEnteringAutoFocus;
	} else {
		return;
	}
	
	self.focusMode = newFocusMode;
	
	NSNumber *object = [NSNumber numberWithInteger:newFocusMode];
	[self enqSel:@selector(forwardFocusMode:) withObject:object];
}

- (IBAction)handleTapExposureButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	ExposureMode newExposureMode;
	
	// フォーカスモード切替
	if (self.exposureMode == ExposureModeAutoExpose) {
		if (self.exposureModeManualExposeSupported) {
			newExposureMode = ExposureModeWhileEnteringManualExpose;
		} else {
			// TODO: エラーメッセージを出す？
			return;
		}
	} else if (self.exposureMode == ExposureModeAutoExposeLocked) {
		if (self.exposureModeManualExposeSupported) {
			newExposureMode = ExposureModeWhileEnteringManualExpose;
		} else {
			// TODO: エラーメッセージを出す？
			newExposureMode = ExposureModeWhileEnteringAutoExpose;
		}
	} else if (self.exposureMode == ExposureModeManulaExpose) {
		newExposureMode = ExposureModeWhileEnteringAutoExpose;
	} else {
		return;
	}
	
	self.exposureMode = newExposureMode;
	
	NSNumber *object = [NSNumber numberWithInteger:newExposureMode];
	[self enqSel:@selector(forwardExposureMode:) withObject:object];
}

/*
 - (IBAction)handleTapWBButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
 return;
	}
 }
 */

- (IBAction)handleTapEVShiftButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
}

- (IBAction)handleTapISOButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self handleTapExposureButton:sender];
}

- (IBAction)hadleTapEditButton:(id)sender {
	
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	// スライダーを表示
	if (sender == self.zoomValueEditButton) {
		CGFloat maxZoom = 8.0;
		self.zoomValueSlider.minimumValue = 1.0;
		self.zoomValueSlider.maximumValue = self.maxZoomFactor;
		self.zoomValueSlider.maximumValue = self.zoomValueSlider.maximumValue > maxZoom ? maxZoom : self.zoomValueSlider.maximumValue;
		self.zoomValueSlider.value = self.captureDevice.videoZoomFactor;
		self.zoomValueSlider.continuous = YES;
		[self openSlider:self.zoomValueSlider
			  openButton:self.zoomValueEditButton
			 closeButton:self.zoomValueSliderCloseButton];
	}
	if (sender == self.focusLensPositionEditButton) {
		if (self.focusMode == FocusModeAutoFocusLocked) {
			self.focusMode = FocusModeWhileEnteringAutoFocus;
			NSNumber *object = [NSNumber numberWithInteger:self.focusMode];
			[self enqSel:@selector(forwardFocusMode:) withObject:object];
		} else {
			[self openSlider:self.focusLensPositionSlider
				  openButton:self.focusLensPositionEditButton
				 closeButton:self.focusLensPositionSliderCloseButton];
		}
	}
	if (sender == self.exposureDurationEditButton) {
		if (self.exposureMode == ExposureModeAutoExposeLocked) {
			self.exposureMode = ExposureModeWhileEnteringAutoExpose;
			NSNumber *object = [NSNumber numberWithInteger:self.exposureMode];
			[self enqSel:@selector(forwardExposureMode:) withObject:object];
		} else {
			[self openSlider:self.exposureDurationSlider
				  openButton:self.exposureDurationEditButton
				 closeButton:self.exposureDurationSliderCloseButton];
		}
	}
	if (sender == self.isoValueEditButton) {
		[self openSlider:self.isoValueSlider
			  openButton:self.isoValueEditButton
			 closeButton:self.isoValueSliderCloseButton];
	}
	if (sender == self.exposureTargetBiasEditButton) {
		if ([AVCaptureDevice instancesRespondToSelector:@selector(setExposureTargetBias:completionHandler:)]) {
			self.exposureTargetBiasSlider.minimumValue = self.captureDevice.minExposureTargetBias;
			self.exposureTargetBiasSlider.maximumValue = self.captureDevice.maxExposureTargetBias;
			self.exposureTargetBiasSlider.value = self.captureDevice.exposureTargetBias;
			self.exposureTargetBiasSlider.continuous = YES;
			[self openSlider:self.exposureTargetBiasSlider
				  openButton:self.exposureTargetBiasEditButton
				 closeButton:self.exposureTargetBiasSliderCloseButton];
		}
	}
}

- (IBAction)hadleTapSliderCloseButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// スライダーを消す
	if (sender == self.zoomValueSliderCloseButton) {
		[self closeSlider:self.zoomValueSlider
			   openButton:self.zoomValueEditButton
			  closeButton:self.zoomValueSliderCloseButton];
	}
	if (sender == self.focusLensPositionSliderCloseButton) {
		[self closeSlider:self.focusLensPositionSlider
			   openButton:self.focusLensPositionEditButton
			  closeButton:self.focusLensPositionSliderCloseButton];
	}
	if (sender == self.exposureDurationSliderCloseButton) {
		[self closeSlider:self.exposureDurationSlider
			   openButton:self.exposureDurationEditButton
			  closeButton:self.exposureDurationSliderCloseButton];
	}
	if (sender == self.isoValueSliderCloseButton) {
		[self closeSlider:self.isoValueSlider
			   openButton:self.isoValueEditButton
			  closeButton:self.isoValueSliderCloseButton];
	}
	if (sender == self.exposureTargetBiasSliderCloseButton) {
		[self closeSlider:self.exposureTargetBiasSlider
			   openButton:self.exposureTargetBiasEditButton
			  closeButton:self.exposureTargetBiasSliderCloseButton];
	}
}

- (IBAction)handlePreviewViewTapGesture:(UIGestureRecognizer *)sender {
	NSLog(@"%s", __FUNCTION__);
	
	//CGPoint tapOnSuperView = [sender locationInView:self.view];
	CGPoint tapOnPreviewView = [sender locationInView:self.previewView];
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	// マニュアルコントロール用スライダー表示中はタップを無視
	if (!self.zoomValueSlider.hidden ||
		!self.focusLensPositionSlider ||
		!self.exposureDurationSlider.hidden ||
		!self.isoValueSlider.hidden ||
		!self.exposureTargetBiasSlider.hidden) {
		return;
	}
	
	// カメラプレビューのビューの領域
	CGRect previewViewRect = self.previewView.bounds;	// 画面はランドスケープ固定
	
	// カメラプレビューのビューの領域から、左右上下の黒帯を除いた領域を、imageRectに得る
	CGRect imageRect;
	imageRect.size.width = previewViewRect.size.height * 4.0 / 3.0;
	imageRect.size.height = previewViewRect.size.width * 3.0 / 4.0;
	if (imageRect.size.width <= previewViewRect.size.width) {
		imageRect.size.height = previewViewRect.size.height;
	} else {
		imageRect.size.width = previewViewRect.size.width;
	}
	imageRect.origin.x = (previewViewRect.size.width - imageRect.size.width) / 2.0;
	imageRect.origin.y = (previewViewRect.size.height - imageRect.size.height) / 2.0;
	
	// カメラプレビューがタップされた位置をinterestPointに取得
	CGPoint interestPoint = tapOnPreviewView;
	interestPoint.x -= imageRect.origin.x;
	interestPoint.y -= imageRect.origin.y;
	
	// カメラプレビューがタップされたのであれば処理を実行
	if (0.0 <= interestPoint.x && interestPoint.x <= imageRect.size.width &&
		0.0 <= interestPoint.y && interestPoint.y <= imageRect.size.height) {
		
		// interestPointにフォーカスと露出を自動で合わせる
		// そのためにinterestPointを、ランドスケープ(ホームボタン右)で左上を(0,0)、右下と(1,1)する座標系に変換する
		interestPoint.x /= imageRect.size.width;
		interestPoint.y /= imageRect.size.height;
		
		//NSLog(@"interestPoint=%@ zoom=%0.1f", NSStringFromCGPoint(interestPoint), self.zoomValue);
		
		// ズームを補正（ビューの中心を原点とする座標系に変換してからズームを補正後に左上原点の座標系に戻す）
		interestPoint = CGPointMake((interestPoint.x - 0.5) / self.zoomValue + 0.5,
									(interestPoint.y - 0.5) / self.zoomValue + 0.5);
		
		//NSLog(@"interestPoint=%@", NSStringFromCGPoint(interestPoint));
		
		[self lockAutoFocusAndAutoExposeWithInterestPoint:interestPoint
								 showPointOfInterestImage:YES
							 pointOfInterestImagePosition:tapOnPreviewView];
	}
}

- (void)openSlider:(UISlider *)slider openButton:(UIButton *)openButton closeButton:(UIButton *)closeButton {
	slider.hidden = NO;
	openButton.hidden = NO;
	openButton.enabled = NO;
	closeButton.hidden = NO;
	closeButton.enabled = YES;
}

- (void)closeSlider:(UISlider *)slider openButton:(UIButton *)openButton closeButton:(UIButton *)closeButton {
	slider.hidden = YES;
	openButton.hidden = NO;
	openButton.enabled = YES;
	closeButton.hidden = YES;
	closeButton.enabled = NO;
}

- (void)enqBlock:(dispatch_block_t)block {
	dispatch_async(self.queue, block);
}

- (void)enqSel:(SEL)selector {
	dispatch_async(self.queue, ^(void){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[self performSelector:selector];
#pragma clang diagnostic pop
	});
}

- (void)enqSel:(SEL)selector withObject:(id)object {
	dispatch_async(self.queue, ^(void){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[self performSelector:selector withObject:object];
#pragma clang diagnostic pop
	});
}

- (void) teardownCapture {
	NSLog(@"%s", __FUNCTION__);
	
	if (self.captureSession == nil) {
		return;
	}
	
	[self.captureSession stopRunning];
	[self.captureSession removeInput:self.captureInput];
	[self.captureSession removeOutput:self.captureOutput];
	
	// オブザーバーを削除
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AVCaptureDeviceSubjectAreaDidChangeNotification
												  object:nil];
	[self.captureDevice removeObserver:self forKeyPath:@"adjustingFocus"];
	[self.captureDevice removeObserver:self forKeyPath:@"focusMode"];
	if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
		[self.captureDevice removeObserver:self forKeyPath:@"lensPosition"];
	}
	[self.captureDevice removeObserver:self forKeyPath:@"exposureMode"];
	[self.captureDevice removeObserver:self forKeyPath:@"exposureDuration"];
	[self.captureDevice removeObserver:self forKeyPath:@"whiteBalanceMode"];
	if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetOffset)]) {
		[self.captureDevice removeObserver:self forKeyPath:@"exposureTargetOffset"];
	}
	if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetBias)]) {
		[self.captureDevice removeObserver:self forKeyPath:@"exposureTargetBias"];
	}
	if ([AVCaptureDevice instancesRespondToSelector:@selector(ISO)]) {
		[self.captureDevice removeObserver:self forKeyPath:@"ISO"];
	}
	
	self.captureSession = nil;
	self.captureDevice = nil;
	self.captureInput = nil;
	self.captureOutput = nil;
	self.captureConnection = nil;
	
	dispatch_sync(dispatch_get_main_queue(), ^(void){
		// プレビューレイヤーを削除
		[self.capturePreviewLayer removeFromSuperlayer];
		self.capturePreviewLayer = nil;
		self.previewing = NO;
		self.maxZoomFactor = 1.0;
	});
}

- (void)setupCapture {
	NSLog(@"%s", __FUNCTION__);
	
	NSError *error = nil;
	
	CameraManager *camManager = [CameraManager sharedManager];
	Camera *cam = camManager.backCamera;
	AVCaptureDevice *device = cam.captureDevice;
	if (device == nil || ![device hasMediaType:AVMediaTypeVideo]) {
		NSLog(@"capture device error");
		return;
	}
	
	AVCaptureSession *session = [AVCaptureSession new];
	
	NSString *sessionPreset = AVCaptureSessionPresetPhoto;//AVCaptureSessionPreset640x480;
	if ([session canSetSessionPreset:sessionPreset]) {
		[session setSessionPreset:sessionPreset];
	} else {
		NSLog(@"session preset error");
		return;
	}
	
	// フォーカスモードを確認
	switch (device.focusMode) {
		case AVCaptureFocusModeLocked:
			NSLog(@"focus=locked");
			break;
		case AVCaptureFocusModeAutoFocus:
			NSLog(@"focus=auto");
			break;
		case AVCaptureFocusModeContinuousAutoFocus:
			NSLog(@"focus=conituous_auto");
			break;
	}
	
	// フラッシュモードをautoに変更
	if ([device hasFlash] ) {
		if ([device lockForConfiguration:&error]) {
			[device setFlashMode:AVCaptureFlashModeAuto];
			[device unlockForConfiguration];
		}
	}
	
	// フラッシュモードを確認
	switch (device.flashMode) {
		case AVCaptureFlashModeOff:
			NSLog(@"flash=off");
			break;
		case AVCaptureFlashModeOn:
			NSLog(@"flash=on");
			break;
		case AVCaptureFlashModeAuto:
			NSLog(@"flash=auto");
			break;
	}
	
	error = nil;
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	if (error != nil) {
		NSLog(@"capture device input error");
		return;
	}
	
	if ([session canAddInput:input]) {
		[session addInput:input];
	} else {
		NSLog(@"capture session input error");
		return;
	}
	
	// On iOS the currently the only supported keys are AVVideoCodecKey and kCVPixelBufferPixelFormatTypeKey.
	// The keys are mutually exclusive, only one may be present.
	// The recommended values are kCMVideoCodecType_JPEG for AVVideoCodecKey and kCVPixelFormatType_420YpCbCr8BiPlanarFullRange and kCVPixelFormatType_32BGRA for kCVPixelBufferPixelFormatTypeKey.
	
	AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
#ifndef RAW_IMAGE
	NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG}; //カメラ出力にJPEGを指定
#else /*RAW_IMAGE*/
	NSDictionary *outputSettings = @{ (__bridge_transfer NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)}; //無圧縮を指定
#endif /*RAW_IMAGE*/
	
	[output setOutputSettings:outputSettings];
	
	if ([session canAddOutput:output]) {
		[session addOutput:output];
	} else {
		NSLog(@"capture session output error");
		[session removeInput:input];
		return;
	}
	
	AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
	if (connection == nil) {
		NSLog(@"caputure connection error.");
		[session removeInput:input];
		[session removeOutput:output];
		return;
	}
	
	if (connection.supportsVideoOrientation) {
		// videoOrientationを指定することで出力のJPEGのExifが変わる
		// TODO: なんかうまくいかない
		//connection.videoOrientation = [cam videoOrientationWithRotation:[CameraManager displayRotationWithViewController:self]];
		connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
	} else {
		NSLog(@"Capture connection does not support video orientation");
		[session removeInput:input];
		[session removeOutput:output];
		return;
	}
	
	if (connection.videoOrientation == AVCaptureVideoOrientationPortrait) {
		NSLog(@"Set Video Orientation : Portrait");
	} else if (connection.videoOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
		NSLog(@"Set Video Orientation : PortraitUpsideDown");
	} else if (connection.videoOrientation == AVCaptureVideoOrientationLandscapeLeft) {
		NSLog(@"Set Video Orientation : LandscapeLeft");
	} else if (connection.videoOrientation == AVCaptureVideoOrientationLandscapeRight) {
		NSLog(@"Set Video Orientation : LandscapeRight");
	}
	
	// subjectAreaChangeMonitoringEnabledのデフォルトはNO
	if ([device lockForConfiguration:&error]) {
		NSLog(@"enable subjectAreaChangeMonitoring");
		device.subjectAreaChangeMonitoringEnabled = YES;
		[device unlockForConfiguration];
		
		// 通知センターにAVCaptureDeviceSubjectAreaDidChangeNotificationを登録
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(subjectAreaDidChanged)
													 name:AVCaptureDeviceSubjectAreaDidChangeNotification
												   object:nil];
	}

	// AVCaptureDeviceのプロパティの変化通知をobserveValueForKeyPathメソッドで受け取る
	[device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
	[device addObserver:self forKeyPath:@"focusMode" options:NSKeyValueObservingOptionNew context:nil];
	if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
		[device addObserver:self forKeyPath:@"lensPosition" options:NSKeyValueObservingOptionNew context:nil];
	}
	[device addObserver:self forKeyPath:@"exposureMode" options:NSKeyValueObservingOptionNew context:nil];
	[device addObserver:self forKeyPath:@"exposureDuration" options:NSKeyValueObservingOptionNew context:nil];
	[device addObserver:self forKeyPath:@"whiteBalanceMode" options:NSKeyValueObservingOptionNew context:nil];
	if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetOffset)]) {
		[device addObserver:self forKeyPath:@"exposureTargetOffset" options:NSKeyValueObservingOptionNew context:nil];
	}
	if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetBias)]) {
		[device addObserver:self forKeyPath:@"exposureTargetBias" options:NSKeyValueObservingOptionNew context:nil];
	}
	if ([AVCaptureDevice instancesRespondToSelector:@selector(ISO)]) {
		[device addObserver:self forKeyPath:@"ISO" options:NSKeyValueObservingOptionNew context:nil];
	}
	
	[session startRunning];
	
	self.captureSession = session;
	self.captureDevice = device;
	self.captureInput = input;
	self.captureOutput = output;
	self.captureConnection = connection;
	
	_focusModeManualFocusSupported = NO;
	_exposureModeManualExposeSupported = NO;
	
	if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
		_focusModeManualFocusSupported = YES;
	}
	if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeCustom]) {
		_exposureModeManualExposeSupported = YES;
	}
	
	dispatch_sync(dispatch_get_main_queue(), ^(void){
		// キャプチャ中を示すフラグをON
		self.previewing = YES;
		
		// 最大ズーム
		self.maxZoomFactor = self.captureDevice.activeFormat.videoMaxZoomFactor;
		
		// プレビューレイヤーを作成
		self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
		self.capturePreviewLayer.backgroundColor = [[UIColor blackColor] CGColor];
		self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
		//self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
		
		// 回転させる
		int displayRotation = [CameraManager displayRotationWithViewController:self];
		if (self.capturePreviewLayer.connection.supportsVideoOrientation) {
			self.capturePreviewLayer.connection.videoOrientation = [CameraManager appropriateVideoOrientationWithDisplayRotation:displayRotation];
		}
		
		// プレビューレイヤーをビューに追加
		self.capturePreviewLayer.frame = self.previewView.bounds;
		[self.previewView.layer addSublayer:self.capturePreviewLayer];
		[self.previewView.layer setMasksToBounds:YES];
		
		// 枠を付ける
		//[self.previewView.layer setBorderWidth:1.0f];
		//[self.previewView.layer setBorderColor:[[UIColor blueColor] CGColor]];
	});
}

- (void)resetCameraSettingsToDefault {
	NSLog(@"%s", __FUNCTION__);
	
	if (![self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] ||
		![self.captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] ||
		![self.captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
		// TODO: エラー処理
	}
	
	void (^additional)(void) = ^(void){
		[self.captureDevice setVideoZoomFactor:1.0];
		[self.captureDevice setExposureTargetBias:0.0 completionHandler:^(CMTime syncTime){
		}];
	};
	
	if ([self setFocusMode:AVCaptureFocusModeContinuousAutoFocus
	  focusPointOfInterest:CGPointMake(0.5, 0.5)
			  exposureMode:AVCaptureExposureModeContinuousAutoExposure
   exposurePointOfInterest:CGPointMake(0.5, 0.5)
		  whiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance
				additional:additional]) {
		
		// ビューに表示するカメラのパラメーターを取得
		Float64 exposureDuration = CMTimeGetSeconds(self.captureDevice.exposureDuration);
		float lensPosition = 0.0;
		float evOffset = 0.0;
		float exposureTargetBias = 0.0;
		float ISO = 0.0;
		if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
			lensPosition = self.captureDevice.lensPosition;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetOffset)]) {
			evOffset = self.captureDevice.exposureTargetOffset;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetBias)]) {
			exposureTargetBias = self.captureDevice.exposureTargetBias;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(ISO)]) {
			ISO = self.captureDevice.ISO;
		}

		// ビューの表示はメインスレッドで実行
		dispatch_sync(dispatch_get_main_queue(), ^(void){
			
			// ビューをカメラ開始時のデフォルト状態に変更
			self.focusPointOfInterestImageView.hidden = NO;
			[self resetFocusPointOfInterestImageViewPosition];
			self.focusPointOfInterestImageView.alpha = 1.0;
			[UIView animateWithDuration:1.0f
								  delay:0.0f
								options:UIViewAnimationOptionCurveEaseIn
							 animations:^{
								 self.focusPointOfInterestImageView.alpha = 0.0;
							 } completion:^(BOOL finished) {
							 }];
			
			self.exposurePointOfInterestImageView.hidden = NO;
			[self resetExposurePointOfInterestImageViewPosition];
			self.exposurePointOfInterestImageView.alpha = 1.0;
			[UIView animateWithDuration:1.0f
								  delay:0.0f
								options:UIViewAnimationOptionCurveEaseIn
							 animations:^{
								 self.exposurePointOfInterestImageView.alpha = 0.0;
							 } completion:^(BOOL finished) {
							 }];
			
			self.flashModeButton.enabled = YES;
			self.flashModeLabel.text = @"自動";
			
			self.zoomValueLabel.text = @"x1.0";
			self.zoomValue = 1.0;
			self.zoomValueSlider.hidden = YES;
			self.zoomValueEditButton.hidden = NO;
			[self.zoomValueEditButton setTitle:@"変更" forState:UIControlStateNormal];
			self.zoomValueSliderCloseButton.hidden = YES;
			self.zoomModeButton.enabled = YES;
			self.zoomModeButton.userInteractionEnabled = NO;
			
			self.focusMode	= FocusModeAutoFocus;
			self.focusModeLabel.text = [self focusModeLabelText];
			self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
			self.focusLensPositionSlider.hidden = YES;
			self.focusLensPositionEditButton.hidden = YES;
			self.focusLensPositionSliderCloseButton.hidden = YES;
			self.focusModeButton.enabled = YES;
			[self updateFocusGroupTextColor];
			
			self.exposureMode = ExposureModeAutoExpose;
			self.exposureModeLabel.text = [self exposureModeLabelText];
			self.exposureDurationLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
			self.exposureDurationSlider.hidden = YES;
			self.exposureDurationEditButton.hidden = YES;
			self.exposureDurationSliderCloseButton.hidden = YES;
			self.exposureModeButton.enabled = YES;
			[self updateExposureGroupTextColor];
			
			if (evOffset < 0) {
				//self.evOffsetLabel.text = [NSString stringWithFormat:@"Offset: %0.3fEV", evOffset];
			} else {
				//self.evOffsetLabel.text = [NSString stringWithFormat:@"Offset: +%0.3fEV", evOffset];
			}
			if (exposureTargetBias < 0) {
				self.exposureTargetBiasLabel.text = [NSString stringWithFormat:@"%0.3fEV", exposureTargetBias];
			} else {
				self.exposureTargetBiasLabel.text = [NSString stringWithFormat:@"+%0.3fEV", exposureTargetBias];
			}
			self.exposureTargetBiasSlider.hidden = YES;
			self.exposureTargetBiasEditButton.hidden = NO;
			[self.exposureTargetBiasEditButton setTitle:@"変更" forState:UIControlStateNormal];
			self.exposureTargetBiasSliderCloseButton.hidden = YES;
			self.evShiftButton.enabled = YES;
			self.evShiftButton.userInteractionEnabled = NO;
			[self updateEVShiftGroupTextColor];
			
			self.isoModeButton.enabled = YES;
			self.isoModeLabel.text = @"自動";
			self.isoValueLabel.text = [NSString stringWithFormat:@"%0.3fEV", ISO];
			self.isoValueSlider.hidden = YES;
			self.isoValueEditButton.hidden = YES;
			self.isoValueSliderCloseButton.hidden = YES;
			
			//self.resetButton.hidden = YES;
			
		});
	} else {
		// lockForConfigurationが失敗
		// TODO: エラー処理
	}
}

- (void)forwardFocusMode:(id)object {
	NSError *error;
	BOOL result = NO;
	FocusMode focusMode = [(NSNumber *)object integerValue];
	
	if (focusMode == FocusModeWhileEnteringAutoFocus) {
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
				self.captureDevice.focusPointOfInterest = CGPointMake(0.5, 0.5);
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.focusMode = FocusModeAutoFocus;
					self.focusModeLabel.text = [self focusModeLabelText];
					[self updateFocusGroupTextColor];
					
					// スコープを一瞬だけ中央に表示
					self.focusPointOfInterestImageView.hidden = NO;
					[self resetFocusPointOfInterestImageViewPosition];
					self.focusPointOfInterestImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.focusPointOfInterestImageView.alpha = 0.0;
									 } completion:^(BOOL finished) {
									 }];
					
					// スライダーを消す
					self.focusLensPositionSlider.hidden = YES;
					self.focusLensPositionEditButton.hidden = YES;
					self.focusLensPositionSliderCloseButton.hidden = YES;
					
					// TODO: ボタンの制御
				});
				
				result = YES;
			}
		}
		
	} else if (focusMode == FocusModeWhileEnteringManualFocus) {
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked] &&
			[self.class isManualFocusSupported]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeLocked;
				self.captureDevice.focusPointOfInterest = CGPointMake(0.5, 0.5);
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.focusMode = FocusModeManualFocus;
					self.focusModeLabel.text = [self focusModeLabelText];
					[self updateFocusGroupTextColor];
					
					self.focusPointOfInterestImageView.hidden = YES;
					
					// スライダーを表示する
					self.focusLensPositionSlider.hidden = NO;
					self.focusLensPositionEditButton.hidden = NO;
					self.focusLensPositionEditButton.enabled = NO;
					[self.focusLensPositionEditButton setTitle:@"変更" forState:UIControlStateNormal];
					self.focusLensPositionSliderCloseButton.hidden = NO;
					self.focusLensPositionSliderCloseButton.enabled = YES;
					self.focusLensPositionSlider.minimumValue = 0.0; // 最も近い
					self.focusLensPositionSlider.maximumValue = 1.0; // 最も遠い
					if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
						self.focusLensPositionSlider.value = self.captureDevice.lensPosition; // 現在値
					} else {
						self.focusLensPositionSlider.value = 0.0;
					}
					self.focusLensPositionSlider.continuous = YES;
					
					// TODO: ボタンの制御
				});
				
				result = YES;
			}
		}
	}
	
	if (!result) {
		[self resetCameraSettingsToDefault];
	}
}

- (void)forwardExposureMode:(id)object {
	NSError *error;
	ExposureMode exposureMode = [(NSNumber *)object integerValue];
	
	if (exposureMode == ExposureModeWhileEnteringAutoExpose) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
				self.captureDevice.exposurePointOfInterest = CGPointMake(0.5, 0.5);
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureMode = ExposureModeAutoExpose;
					self.exposureModeLabel.text = [self exposureModeLabelText];
					[self updateExposureGroupTextColor];
					
					// スコープを一瞬だけ中央に表示
					self.exposurePointOfInterestImageView.hidden = NO;
					[self resetExposurePointOfInterestImageViewPosition];
					self.exposurePointOfInterestImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.exposurePointOfInterestImageView.alpha = 0.0;
									 } completion:^(BOOL finished) {
									 }];
					
					// スライダーを消す
					self.exposureDurationSlider.hidden = YES;
					self.exposureDurationEditButton.hidden = YES;
					self.exposureDurationSliderCloseButton.hidden = YES;
					
					// ISO感度も自動モード
					self.isoModeLabel.text = [self exposureModeLabelText];
					self.isoValueSlider.hidden = YES;
					self.isoValueEditButton.hidden = YES;
					self.isoValueSliderCloseButton.hidden = YES;
					
					/// 露出補正が効く
					self.exposureTargetBiasEditButton.hidden = NO;
					[self updateEVShiftGroupTextColor];
				});
			}
		}
	} else if (exposureMode == ExposureModeWhileEnteringManualExpose) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeCustom]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeCustom;
				self.captureDevice.exposurePointOfInterest = CGPointMake(0.5, 0.5);
				[self.captureDevice unlockForConfiguration];
				
				CMTime minExposureDuration = self.captureDevice.activeFormat.minExposureDuration;
				CMTime maxExposureDuration = self.captureDevice.activeFormat.maxExposureDuration;
				CMTime exposureDuration = self.captureDevice.exposureDuration;
				
				NSLog(@"exposureDuration: min=%f max=%f current=%f", CMTimeGetSeconds(minExposureDuration), CMTimeGetSeconds(maxExposureDuration), CMTimeGetSeconds(exposureDuration));
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureMode = ExposureModeManulaExpose;
					self.exposureModeLabel.text = [self exposureModeLabelText];
					[self updateExposureGroupTextColor];
					
					self.exposurePointOfInterestImageView.hidden = YES;
					
					// スライダーを表示する
					self.exposureDurationSlider.hidden = NO;
					self.exposureDurationEditButton.hidden = NO;
					self.exposureDurationEditButton.enabled = NO;
					[self.exposureDurationEditButton setTitle:@"変更" forState:UIControlStateNormal];
					self.exposureDurationSliderCloseButton.hidden = NO;
					self.exposureDurationSliderCloseButton.enabled = YES;
					self.exposureDurationSlider.minimumValue = CMTimeGetSeconds(minExposureDuration);
					self.exposureDurationSlider.maximumValue = CMTimeGetSeconds(maxExposureDuration);
					self.exposureDurationSlider.value = CMTimeGetSeconds(exposureDuration);
					self.exposureDurationSlider.continuous = YES;
					
					// ISO感度も手動モード
					self.isoModeLabel.text = [self exposureModeLabelText];
					self.isoValueSlider.hidden = NO;
					self.isoValueEditButton.hidden = NO;
					self.isoValueEditButton.enabled = NO;
					[self.isoValueEditButton setTitle:@"変更" forState:UIControlStateNormal];
					self.isoValueSliderCloseButton.hidden = NO;
					self.isoValueSliderCloseButton.enabled = YES;
					self.isoValueSlider.minimumValue = self.captureDevice.activeFormat.minISO;
					self.isoValueSlider.maximumValue = self.captureDevice.activeFormat.maxISO;
					self.isoValueSlider.value = self.captureDevice.ISO;
					self.isoValueSlider.continuous = YES;
					
					/// 露出補正は効かない
					self.exposureTargetBiasSlider.hidden = YES;
					self.exposureTargetBiasEditButton.hidden = YES;
					self.exposureTargetBiasSliderCloseButton.hidden = YES;
					[self updateEVShiftGroupTextColor];
				});
			}
		}
	}
}

- (void)takePicture {
	NSLog(@"%s", __FUNCTION__);
	
	if (self.captureOutput == nil) {
		return;
	}
	
	if (self.capturing) {
		NSLog(@"ignore");
		return;
	}
	
	self.capturing = YES;
	
	[self.captureOutput captureStillImageAsynchronouslyFromConnection:self.captureConnection
												  completionHandler:
	 ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
		 CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
		 if (exifAttachments) {
			 // Do something with the attachments.
			 
			 // Exifをリードするサンプル
			 NSDictionary *exifDict = (__bridge NSDictionary*)exifAttachments;
			 NSLog(@"exifDict: %@", exifDict);
			 NSLog(@"size: %dx%d", [[exifDict objectForKey:@"PixelXDimension"] intValue], [[exifDict objectForKey:@"PixelYDimension"] intValue]);
		 }
		 
		 // オリジナル画像を作成
#ifndef RAW_IMAGE
		 // カメラ出力JPEGからUIImageを生成
		 NSData *pictData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
		 NSLog(@"pictData: %d bytes", pictData.length);
		 UIImage *original = [[UIImage alloc] initWithData:pictData];
#else /*RAW_IMAGE*/
		 // カメラ出力RAW(Bitmap)からUIImageを生成
		 UIImage *original = [self imageFromSampleBuffer:imageSampleBuffer];
#endif /*RAW_IMAGE*/
		 
		 // サムネイル画像を作成
		 UIImage *thumbnail;
		 CGFloat height = 240, width = 320;
		 
		 UIGraphicsBeginImageContext(CGSizeMake(width, height));
		 [original drawInRect:CGRectMake(0, 0, width, height)];
		 thumbnail = UIGraphicsGetImageFromCurrentImageContext();
		 UIGraphicsEndImageContext();
		 
		 // オリジナル画像のサイズ
		 NSLog(@"image: %@", NSStringFromCGSize(original.size));
		 
		 PreviewPictViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewPictViewController"];
		 viewController.image = original;
		 [self presentViewController:viewController animated:YES completion:nil];
		 
		 // カメラを終了
		 [self enqBlock:^(void){
			 self.capturing = NO;
			 [self teardownCapture];
		 }];
	 }];

}

#ifdef RAW_IMAGE
/// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	CVPixelBufferLockBaseAddress(imageBuffer,0);        // Lock the image buffer
	
	uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);   // Get information of the image
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
	size_t width = CVPixelBufferGetWidth(imageBuffer);
	size_t height = CVPixelBufferGetHeight(imageBuffer);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
	CGImageRef newImage = CGBitmapContextCreateImage(newContext);
	CGContextRelease(newContext);
	
	CGColorSpaceRelease(colorSpace);
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	/* CVBufferRelease(imageBuffer); */  // do not call this!
	
	UIImage *image = [UIImage imageWithCGImage:newImage
										 scale:1.0f
								   orientation:UIImageOrientationUp];
	
	CGImageRelease(newImage);
	
	return image;
}
#endif /*RAW_IMAGE*/

- (void)enableLeftSideButtons {
	self.zoomModeButton.enabled = YES;
	self.focusModeButton.enabled = NO;
	self.exposureModeButton.enabled = NO;
	if (self.exposureMode == ExposureModeManulaExpose) {
		self.isoModeButton.enabled = YES;
	} else {
		self.isoModeButton.enabled = NO;
	}
	self.evShiftButton.enabled = NO;
}

- (void)disableLeftSideButtons {
	self.zoomModeButton.enabled = NO;
	self.focusModeButton.enabled = NO;
	self.exposureModeButton.enabled = NO;
	self.isoModeButton.enabled = NO;
	self.evShiftButton.enabled = NO;
}

- (void)lockAutoFocusAndAutoExposeWithInterestPoint:(CGPoint)interestPoint showPointOfInterestImage:(BOOL)showPointOfInterestImage pointOfInterestImagePosition:(CGPoint)pointOfInterestImagePosition {
	
	if (self.focusMode == FocusModeAutoFocus ||
		self.focusMode == FocusModeAutoFocusLocked) {
		;
	} else {
		// 無視
		return;
	}
	
	if (self.exposureMode == ExposureModeAutoExpose ||
		self.exposureMode == ExposureModeAutoExposeLocked) {
		;
	} else {
		// 無視
		return;
	}
	
	BOOL validInterestPoint = NO;
	if (0.0 <= interestPoint.x && interestPoint.x <= 1.0) {
		if (0.0 <= interestPoint.y && interestPoint.y <= 1.0) {
			validInterestPoint = YES;
		}
	}
	
	FocusMode oldFocusMode = self.focusMode;
	ExposureMode oldExposureMode = self.exposureMode;
	
	self.focusMode = FocusModeWhileEnteringAutoFocusModeLocked;
	self.exposureMode = ExposureModeWhileEnteringAutoExposeLocked;
	
	self.focusModeLabel.text = [self focusModeLabelText];
	self.exposureModeLabel.text = [self exposureModeLabelText];
	
	[self enqBlock:^(void){
		
		NSError *error;
		BOOL afl = NO;
		BOOL ael = NO;
		
		if ([self.captureDevice lockForConfiguration:&error]) {
			if (self.focusMode == FocusModeWhileEnteringAutoFocusModeLocked) {
				if ([self.captureDevice isFocusPointOfInterestSupported] &&
					[self.captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
					if (![self.captureDevice isAdjustingFocus]) {
						// タップされた位置にフォーカスを合わせてロックする
						NSLog(@"setFocusPointOfInterest interestPoint=%@", NSStringFromCGPoint(interestPoint));
						if (validInterestPoint) {
							self.captureDevice.focusPointOfInterest = interestPoint;
						}
						self.captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
						afl = YES;
					}
				}
			}
			
			if (self.exposureMode == ExposureModeWhileEnteringAutoExposeLocked) {
				if ([self.captureDevice isExposurePointOfInterestSupported] &&
					[self.captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
					if (![self.captureDevice isAdjustingExposure]) {
						// タップされた位置に露出を合わせてロックする
						NSLog(@"setExposurePointOfInterest interestPoint=%@", NSStringFromCGPoint(interestPoint));
						if (validInterestPoint) {
							self.captureDevice.exposurePointOfInterest = interestPoint;
						}
						self.captureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
						ael = YES;
					}
				}
			}
			
			[self.captureDevice unlockForConfiguration];
		}
		
		dispatch_sync(dispatch_get_main_queue(), ^(void){
			
			if (!afl) {
				self.focusMode = oldFocusMode;
				self.focusModeLabel.text = [self focusModeLabelText];
			}
			
			if (!ael) {
				self.exposureMode = oldExposureMode;
				self.exposureModeLabel.text = [self exposureModeLabelText];
			}
			
			if (afl) {
				if (showPointOfInterestImage) {
					// 昔のアニメーションを中止
					[self.focusPointOfInterestImageView.layer removeAllAnimations];
					
					// focusPointOfInterestImageViewを表示し、1秒かけて徐々に薄くする
					self.focusPointOfInterestImageView.hidden = NO;
					[self moveFocusPointOfInterestImageViewToPosition:pointOfInterestImagePosition];
					self.focusPointOfInterestImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.focusPointOfInterestImageView.alpha = 0.5;
									 } completion:^(BOOL finished) {
									 }];
				}
				
				self.focusLensPositionEditButton.hidden = YES;
			}
			
			if (ael) {
				if (showPointOfInterestImage) {
					// 昔のアニメーションを中止
					[self.exposurePointOfInterestImageView.layer removeAllAnimations];
					
					// exposurePointOfInterestImageViewを表示し、1秒かけて徐々に薄くする
					self.exposurePointOfInterestImageView.hidden = NO;
					[self moveExposurePointOfInterestImageViewToPosition:pointOfInterestImagePosition];
					self.exposurePointOfInterestImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.exposurePointOfInterestImageView.alpha = 0.5;
									 } completion:^(BOOL finished) {
									 }];
				}
				
				self.exposureDurationEditButton.hidden = YES;
			}
		});
	}];
}

- (void)resetExposurePointOfInterestImageViewPosition {
	
	if ([self.view.constraints containsObject:self.exposurePointOfInterestImageViewConstraintX]) {
		[self.view removeConstraint:self.exposurePointOfInterestImageViewConstraintX];
		self.exposurePointOfInterestImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.exposurePointOfInterestImageViewConstraintY]) {
		[self.view removeConstraint:self.exposurePointOfInterestImageViewConstraintY];
		self.exposurePointOfInterestImageViewConstraintY = nil;
	}
	
	self.exposurePointOfInterestImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.exposurePointOfInterestImageView
																  attribute:NSLayoutAttributeCenterX
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterX
																 multiplier:1.0 constant:0.0];
	self.exposurePointOfInterestImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.exposurePointOfInterestImageView
																  attribute:NSLayoutAttributeCenterY
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterY
																 multiplier:1.0 constant:0.0];
	[self.view addConstraint:self.exposurePointOfInterestImageViewConstraintX];
	[self.view addConstraint:self.exposurePointOfInterestImageViewConstraintY];
}

- (void)moveExposurePointOfInterestImageViewToPosition:(CGPoint)position {
	
	if ([self.view.constraints containsObject:self.exposurePointOfInterestImageViewConstraintX]) {
		NSLog(@"remove old constraintX");
		[self.view removeConstraint:self.exposurePointOfInterestImageViewConstraintX];
		self.exposurePointOfInterestImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.exposurePointOfInterestImageViewConstraintY]) {
		NSLog(@"remove old constraintY");
		[self.view removeConstraint:self.exposurePointOfInterestImageViewConstraintY];
		self.exposurePointOfInterestImageViewConstraintY = nil;
	}
	
	NSLog(@"position=%@", NSStringFromCGPoint(position));
	
	self.exposurePointOfInterestImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.exposurePointOfInterestImageView
																  attribute:NSLayoutAttributeLeading
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeLeading
																 multiplier:1.0 constant:position.x - 50.0]; // ImageView高さ50の半分を差し引く
	self.exposurePointOfInterestImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.exposurePointOfInterestImageView
																  attribute:NSLayoutAttributeTop
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeTop
																 multiplier:1.0 constant:position.y - 50.0]; // ImageView幅50の半分を差し引く
	[self.view addConstraint:self.exposurePointOfInterestImageViewConstraintX];
	[self.view addConstraint:self.exposurePointOfInterestImageViewConstraintY];
}

- (void)resetFocusPointOfInterestImageViewPosition {
	
	if ([self.view.constraints containsObject:self.focusPointOfInterestImageViewConstraintX]) {
		[self.view removeConstraint:self.focusPointOfInterestImageViewConstraintX];
		self.focusPointOfInterestImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.focusPointOfInterestImageViewConstraintY]) {
		[self.view removeConstraint:self.focusPointOfInterestImageViewConstraintY];
		self.focusPointOfInterestImageViewConstraintY = nil;
	}
	
	self.focusPointOfInterestImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.focusPointOfInterestImageView
																  attribute:NSLayoutAttributeCenterX
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterX
																 multiplier:1.0 constant:0.0];
	self.focusPointOfInterestImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.focusPointOfInterestImageView
																  attribute:NSLayoutAttributeCenterY
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterY
																 multiplier:1.0 constant:0.0];
	[self.view addConstraint:self.focusPointOfInterestImageViewConstraintX];
	[self.view addConstraint:self.focusPointOfInterestImageViewConstraintY];
}

- (void)moveFocusPointOfInterestImageViewToPosition:(CGPoint)position {
	
	if ([self.view.constraints containsObject:self.focusPointOfInterestImageViewConstraintX]) {
		NSLog(@"remove old constraintX");
		[self.view removeConstraint:self.focusPointOfInterestImageViewConstraintX];
		self.focusPointOfInterestImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.focusPointOfInterestImageViewConstraintY]) {
		NSLog(@"remove old constraintY");
		[self.view removeConstraint:self.focusPointOfInterestImageViewConstraintY];
		self.focusPointOfInterestImageViewConstraintY = nil;
	}
	
	NSLog(@"position=%@", NSStringFromCGPoint(position));
	
	self.focusPointOfInterestImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.focusPointOfInterestImageView
																  attribute:NSLayoutAttributeLeading
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeLeading
																 multiplier:1.0 constant:position.x - 15.0]; // ImageView高さの半分を差し引く
	self.focusPointOfInterestImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.focusPointOfInterestImageView
																  attribute:NSLayoutAttributeTop
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeTop
																 multiplier:1.0 constant:position.y - 15.0]; // ImageView幅の半分を差し引く
	[self.view addConstraint:self.focusPointOfInterestImageViewConstraintX];
	[self.view addConstraint:self.focusPointOfInterestImageViewConstraintY];
}

- (IBAction)zoomValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"zoomValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float zoomValue = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.class isVideoZoomSupported]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				[self.captureDevice setVideoZoomFactor:zoomValue];
				[self.captureDevice unlockForConfiguration];
				
				dispatch_async(dispatch_get_main_queue(), ^(void){
					self.zoomValue = zoomValue;
					self.zoomValueLabel.text = [NSString stringWithFormat:@"x%0.1f", zoomValue];
				});
			}
		}
	}];
}

- (IBAction)focusValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"focusValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float focusValue = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.class isManualFocusSupported]) {
			if (![self.captureDevice isAdjustingFocus]) {
				if ([self.captureDevice lockForConfiguration:&error]) {
					[self.captureDevice setFocusModeLockedWithLensPosition:focusValue
														 completionHandler:^(CMTime syncTime) {
						//unlockForConfigurationは勝手にやってくれている？
					}];
				}
			}
		}
	}];
}

- (IBAction)exposureValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"exposureValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float exposureValue = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.class isManualExposureSupported]) {
			if (![self.captureDevice isAdjustingExposure]) {
				if ([self.captureDevice lockForConfiguration:&error]) {
					CMTime exposureDuration = CMTimeMakeWithSeconds(exposureValue, 1000000000);
					if (CMTimeCompare(exposureDuration, self.captureDevice.activeFormat.minExposureDuration) < 0) {
						exposureDuration = self.captureDevice.activeFormat.minExposureDuration;
					}
					if (CMTimeCompare(exposureDuration, self.captureDevice.activeFormat.maxExposureDuration) > 0) {
						exposureDuration = self.captureDevice.activeFormat.maxExposureDuration;
					}
					[self.captureDevice setExposureModeCustomWithDuration:exposureDuration
																	  ISO:AVCaptureISOCurrent
														completionHandler:^(CMTime syncTime) {
															//unlockForConfigurationは勝手にやってくれている？
														}];
				}
			}
		}
	}];
}

- (IBAction)isoValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"isoValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float isoValue = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.class isManualExposureSupported]) {
			if (![self.captureDevice isAdjustingExposure]) {
				if ([self.captureDevice lockForConfiguration:&error]) {
					[self.captureDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent
																	  ISO:isoValue
														completionHandler:^(CMTime syncTime) {
															//unlockForConfigurationは勝手にやってくれている？
														}];
				}
			}
		}
	}];
}

- (IBAction)evShiftValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"exposureTargetBias=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float exposureTargetBias = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.captureDevice lockForConfiguration:&error]) {
			[self.captureDevice setExposureTargetBias:exposureTargetBias
									completionHandler:^(CMTime syncTime){
									}];
			[self.captureDevice unlockForConfiguration];
		}
	}];
}

- (void)subjectAreaDidChanged{
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"interest=%@", NSStringFromCGPoint(self.captureDevice.focusPointOfInterest));
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	if (self.focusMode == FocusModeAutoFocus) {
		//if (self.AFLocked || self.AELocked) {
			//[self enqSel:@selector(resetCameraSettingsToDefault)];
			//self.autoFocusLockedTemporarily = NO;
		//}
	}
}

/// FocusMode, ExposureMode, interestPointを設定
/// - 指定されたモードやinterestPointがサポートされていない場合
///   - 本メソッドは指定されたモードやinterestPointを設定せず、エラーを返さない。
///   - 呼び出し側が事前にモードやinterestPointがサポートされているかどうか確認すること。
/// - lockForConfigurationに失敗した場合
///   - エラーを返す。
- (BOOL)setFocusMode:(AVCaptureFocusMode)focusMode focusPointOfInterest:(CGPoint)focusPointOfInterest exposureMode:(AVCaptureExposureMode)exposureMode exposurePointOfInterest:(CGPoint)exposurePointOfInterest whiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode additional:(void (^)(void))additional {
	NSLog(@"%s", __FUNCTION__);
	NSError *error;
	
	if ([self.captureDevice lockForConfiguration:&error]) {
		if ([self.captureDevice isFocusPointOfInterestSupported]) {
			self.captureDevice.focusPointOfInterest = focusPointOfInterest;
		}
		if ([self.captureDevice isFocusModeSupported:focusMode]) {
			self.captureDevice.focusMode = focusMode;
		}
		if ([self.captureDevice isExposurePointOfInterestSupported]) {
			self.captureDevice.exposurePointOfInterest = exposurePointOfInterest;
		}
		if ([self.captureDevice isExposureModeSupported:exposureMode]) {
			self.captureDevice.exposureMode = exposureMode;
		}
		if ([self.captureDevice isWhiteBalanceModeSupported:whiteBalanceMode]) {
			self.captureDevice.whiteBalanceMode = whiteBalanceMode;
		}
		if (additional != nil) {
			additional();
		}
		[self.captureDevice unlockForConfiguration];
		return YES;
	}
	
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"keyPath=%@", keyPath);
	if ([keyPath isEqualToString:@"adjustingFocus"]) {
		BOOL adjustingFocus = [ [change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1] ];
		NSLog(@"Is adjusting focus? %@", adjustingFocus ? @"YES" : @"NO" );
		//NSLog(@"Change dictionary: %@", change);
	} else if ([keyPath isEqualToString:@"focusMode"]) {
		AVCaptureFocusMode focusMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (focusMode == AVCaptureFocusModeLocked) {
			//self.focusStatusLabel.text = @"Focus Mode: Locked";
			if (self.focusMode == FocusModeWhileEnteringAutoFocusModeLocked) {
				self.focusMode = FocusModeAutoFocusLocked;
				self.focusModeLabel.text = [self focusModeLabelText];
				[self updateFocusGroupTextColor];
				[self.focusLensPositionEditButton setTitle:@"解除" forState:UIControlStateNormal];
				self.focusLensPositionEditButton.hidden = NO;
				self.focusLensPositionEditButton.enabled = YES;
			}
		} else if (focusMode == AVCaptureFocusModeAutoFocus) {
			//self.focusStatusLabel.text = @"Focus Mode: Auto";
		} else if (focusMode == AVCaptureFocusModeContinuousAutoFocus) {
			//self.focusStatusLabel.text = @"Focus Mode: Continuous Auto";
		}
	} else if ([keyPath isEqualToString:@"exposureMode"]) {
		AVCaptureExposureMode exposureMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (exposureMode == AVCaptureExposureModeLocked) {
			//self.exposureStatusLabel.text = @"Exposure Mode: Locked";
			if (self.exposureMode == ExposureModeWhileEnteringAutoExposeLocked) {
				self.exposureMode = ExposureModeAutoExposeLocked;
				self.exposureModeLabel.text = [self exposureModeLabelText];
				[self updateExposureGroupTextColor];
				[self.exposureDurationEditButton setTitle:@"解除" forState:UIControlStateNormal];
				self.exposureDurationEditButton.hidden = NO;
				self.exposureDurationEditButton.enabled = YES;
			}
		} else if (exposureMode == AVCaptureExposureModeAutoExpose) {
			//self.exposureStatusLabel.text = @"Exposure Mode: Auto";
		} else if (exposureMode == AVCaptureExposureModeContinuousAutoExposure) {
			//self.exposureStatusLabel.text = @"Exposure Mode: Continuous Auto";
		} else if (exposureMode == AVCaptureExposureModeCustom) {
			//self.exposureStatusLabel.text = @"Exposure Mode: Custom";
		}
	} else if ([keyPath isEqualToString:@"exposureDuration"]) {
		CMTime time;
		[[change objectForKey:NSKeyValueChangeNewKey] getValue:&time];
		Float64 exposureDuration = CMTimeGetSeconds(time);
		self.exposureDurationLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
	} else if ([keyPath isEqualToString:@"lensPosition"]) {
		float lensPosition = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
	} else if ([keyPath isEqualToString:@"whiteBalanceMode"]) {
		AVCaptureWhiteBalanceMode whiteBalanceMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (whiteBalanceMode == AVCaptureWhiteBalanceModeLocked) {
			//self.wbStatusLabel.text = @"White Balance Mode: Locked";
		} else if (whiteBalanceMode == AVCaptureWhiteBalanceModeAutoWhiteBalance) {
			//self.wbStatusLabel.text = @"White Balance Mode: Auto";
		} else if (whiteBalanceMode == AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance) {
			//self.wbStatusLabel.text = @"White Balance Mode: Continuous Auto";
		}
	} else if ([keyPath isEqualToString:@"exposureTargetOffset"]) {
		float exposureTargetOffset = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		if (exposureTargetOffset < 0) {
			//self.evOffsetLabel.text = [NSString stringWithFormat:@"Offset: %0.3fEV", exposureTargetOffset];
		} else {
			//self.evOffsetLabel.text = [NSString stringWithFormat:@"Offset: +%0.3fEV", exposureTargetOffset];
		}
	} else if ([keyPath isEqualToString:@"exposureTargetBias"]) {
		float exposureTargetBias = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		if (exposureTargetBias < 0) {
			self.exposureTargetBiasLabel.text = [NSString stringWithFormat:@"%0.3fEV", exposureTargetBias];
		} else {
			self.exposureTargetBiasLabel.text = [NSString stringWithFormat:@"+%0.3fEV", exposureTargetBias];
		}
	} else if ([keyPath isEqualToString:@"ISO"]) {
		float ISO = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.isoValueLabel.text = [NSString stringWithFormat:@"%0.3fEV", ISO];
	}
}

+ (BOOL)isVideoZoomSupported {
	if (![AVCaptureDevice instancesRespondToSelector:@selector(setVideoZoomFactor:)]) {
		return NO;
	}
	return YES;
}

+ (BOOL)isManualFocusSupported {
	if (![AVCaptureDevice instancesRespondToSelector:@selector(setFocusModeLockedWithLensPosition:completionHandler:)]) {
		return NO;
	}
	if (![AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
		return NO;
	}
	return YES;
}

+ (BOOL)isManualExposureSupported {
	if (![AVCaptureDevice instancesRespondToSelector:@selector(setExposureModeCustomWithDuration:ISO:completionHandler:)]) {
		return NO;
	}
	return YES;
}

- (void)updateFocusGroupTextColor {
	UIColor *color;
	if (self.focusMode == FocusModeAutoFocusLocked) {
		color = [self.class cantaloupeColor];
	} else {
		color = [UIColor whiteColor];
	}
	
	[self.focusModeButton setTitleColor:color forState:UIControlStateNormal];
	[self.focusLensPositionEditButton setTitleColor:color forState:UIControlStateNormal];
	self.focusModeLabel.textColor = color;
	self.focusLensPositionLabel.textColor = color;
}

- (void)updateEVShiftGroupTextColor {
	UIColor *color = [UIColor darkGrayColor];
	if (self.exposureMode == ExposureModeManulaExpose) {
		color = [UIColor darkGrayColor];
	} else {
		color = [UIColor whiteColor];
	}
	
	[self.evShiftButton setTitleColor:color forState:UIControlStateNormal];
	self.exposureTargetBiasLabel.textColor = color;
}

- (void)updateExposureGroupTextColor {
	UIColor *color;
	if (self.exposureMode == ExposureModeAutoExposeLocked) {
		color = [self.class cantaloupeColor];
	} else {
		color = [UIColor whiteColor];
	}
	
	[self.exposureModeButton setTitleColor:color forState:UIControlStateNormal];
	[self.exposureDurationEditButton setTitleColor:color forState:UIControlStateNormal];
	self.exposureModeLabel.textColor = color;
	self.exposureDurationLabel.textColor = color;
}

- (NSString *)focusModeLabelText {
	if (self.focusMode == FocusModeAutoFocus) {
		return @"自動";
	} else if (self.focusMode == FocusModeWhileEnteringAutoFocusModeLocked) {
		return @"調整中";
	} else if (self.focusMode == FocusModeAutoFocusLocked) {
		return @"ロック";
	} else if (self.focusMode == FocusModeManualFocus) {
		return @"手動";
	}
	return @" ";
}

- (NSString *)exposureModeLabelText {
	if (self.exposureMode == ExposureModeAutoExpose) {
		return @"自動";
	} else if (self.exposureMode == ExposureModeWhileEnteringAutoExposeLocked) {
		return @"調整中";
	} else if (self.exposureMode == ExposureModeAutoExposeLocked) {
		return @"ロック";
	} else if (self.exposureMode == ExposureModeManulaExpose) {
		return @"手動";
	}
	return @" ";
}

+ (UIColor *)cantaloupeColor {
	return [UIColor colorWithRed:1.000 green:0.800 blue:0.400 alpha:1.000];
}

@end
