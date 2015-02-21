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

/// マニュアルコントロール用スライダー使用状態
typedef NS_ENUM(NSInteger, SliderUseState) {
	/// 未使用
	SliderUseStateNoUse,
	/// ズームの調整に使用中
	SliderUseStateUseInZoom,
	/// フォーカスの調整に使用中
	SliderUseStateUseInFocus,
	/// 露出期間の調整に使用中
	SliderUseStateUseInExposureDuration,
	/// ISO感度の調整に使用中
	SliderUseStateUseInExposureISO,
	/// 露出補正に使用中
	SliderUseStateUseInExposureBias
};

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
@property (nonatomic, weak) IBOutlet UISlider *slider;
@property (nonatomic, weak) IBOutlet UIButton *sliderCancelButton;
@property (nonatomic, weak) IBOutlet UIButton *flashModeButton;
@property (nonatomic, weak) IBOutlet UILabel *flashModeLabel;
@property (nonatomic, weak) IBOutlet UIButton *zoomModeButton;
@property (nonatomic, weak) IBOutlet UILabel *zoomValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *focusModeButton;
@property (nonatomic, weak) IBOutlet UILabel *focusModeLabel;
@property (nonatomic, weak) IBOutlet UILabel *focusLensPositionLabel;
@property (nonatomic, weak) IBOutlet UIButton *exposureModeButton;
@property (nonatomic, weak) IBOutlet UILabel *exposureModelLabel;
//@property (nonatomic, weak) IBOutlet UIButton *exposureDurationButton;
@property (nonatomic, weak) IBOutlet UILabel *exposureDurationValueLabel;
@property (nonatomic, weak) IBOutlet UIImageView *scopeImageView;
@property (nonatomic, weak) IBOutlet UIButton *resetButton;
//@property (nonatomic, weak) IBOutlet UIButton *wbButton;
//@property (nonatomic, weak) IBOutlet UILabel *wbValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *evShiftButton;
@property (nonatomic, weak) IBOutlet UILabel *evOffsetLabel;
@property (nonatomic, weak) IBOutlet UILabel *evBiasLabel;
@property (nonatomic, weak) IBOutlet UIButton *isoButton;
@property (nonatomic, weak) IBOutlet UILabel *isoValueLabel;
@property (nonatomic, weak) IBOutlet UILabel *focusStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *wbStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *autoFocusStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *autoExposureStatusLabel;

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
@property (nonatomic) BOOL zoomMode;
@property (nonatomic) CGFloat zoomValue;
@property (nonatomic) CGFloat maxZoomFactor;
@property (nonatomic) FocusMode focusMode;
@property (nonatomic) ExposureMode exposureMode;
@property (nonatomic) BOOL evShiftMode;
@property (nonatomic) NSLayoutConstraint *scopeImageViewConstraintX;
@property (nonatomic) NSLayoutConstraint *scopeImageViewConstraintY;
@property (nonatomic) SliderUseState sliderUseState;

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
	[self resetScopeImageViewPositionToCenter];
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
	self.slider.hidden = YES;
	self.sliderUseState = SliderUseStateNoUse;
	self.sliderCancelButton.hidden = YES;
	self.flashModeButton.enabled = NO;
	self.flashModeLabel.text = @" ";
	self.zoomValueLabel.text = @" ";
	self.zoomValue = 1.0;
	self.zoomModeButton.enabled = NO;
	self.zoomMode = NO;
	self.focusModeLabel.text = @" ";
	if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
		self.focusLensPositionLabel.text = @" ";
	} else {
		self.focusLensPositionLabel.text = @" ";
	}
	self.focusMode = FocusModeAutoFocus;
	self.focusModeButton.enabled = NO;
	self.focusStatusLabel.text = @"Focus Mode:";
	self.exposureModelLabel.text = @" ";
	self.exposureDurationValueLabel.text = @" ";
	self.exposureMode = ExposureModeAutoExpose;
	self.exposureModeButton.enabled = NO;
	self.exposureStatusLabel.text = @"Exposure Mode:";
	//self.wbButton.enabled = NO;
	//self.wbValueLabel.text = @" ";
	self.wbStatusLabel.text = @"White Balance Mode:";
	self.evShiftButton.enabled = NO;
	self.evOffsetLabel.text = @" ";
	self.evBiasLabel.text = @" ";
	self.evShiftMode = NO;
	self.isoButton.enabled = NO;
	self.isoValueLabel.text = @" ";
	self.scopeImageView.hidden = YES;
	self.resetButton.hidden = YES;
	self.autoFocusStatusLabel.hidden = YES;
	self.autoExposureStatusLabel.hidden = YES;
	
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
		[self lockFocusAndExposureDurationWithInterestPoint:CGPointMake(-1.0, -1.0) //無効なinterestPoint
												  showScope:NO
											  scopePosition:CGPointMake(0.0, 0.0)];
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
		float evBias = 0.0;
		float ISO = 0.0;
		if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
			lensPosition = self.captureDevice.lensPosition;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetOffset)]) {
			evOffset = self.captureDevice.exposureTargetOffset;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(exposureTargetBias)]) {
			evBias = self.captureDevice.exposureTargetBias;
		}
		if ([AVCaptureDevice instancesRespondToSelector:@selector(ISO)]) {
			ISO = self.captureDevice.ISO;
		}

		// ビューの表示はメインスレッドで実行
		dispatch_sync(dispatch_get_main_queue(), ^(void){
			
			// ビューをカメラ開始時のデフォルト状態に変更
			self.scopeImageView.hidden = NO;
			[self resetScopeImageViewPositionToCenter];
			self.scopeImageView.alpha = 1.0;
			[UIView animateWithDuration:1.0f
								  delay:0.0f
								options:UIViewAnimationOptionCurveEaseIn
							 animations:^{
								 self.scopeImageView.alpha = 0.0;
							 } completion:^(BOOL finished) {
							 }];
			
			self.sliderUseState = SliderUseStateNoUse;
			self.slider.hidden = YES;
			self.sliderCancelButton.hidden = YES;
			
			self.flashModeButton.enabled = YES;
			self.flashModeLabel.text = @"自動";
			
			self.zoomValueLabel.text = @"x1.0";
			self.zoomValue = 1.0;
			self.zoomModeButton.enabled = YES;
			self.zoomMode = NO;
			
			self.focusMode	= FocusModeAutoFocus;
			self.focusModeLabel.text = [self focusModeLabelText];
			self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
			self.focusModeButton.enabled = YES;
			
			self.exposureMode = ExposureModeAutoExpose;
			self.exposureModelLabel.text = [self exposureModeLabelText];
			self.exposureDurationValueLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
			self.exposureModeButton.enabled = YES;
			
			self.evOffsetLabel.text = [NSString stringWithFormat:@"offset:%0.3fev", evOffset];
			self.evBiasLabel.text = [NSString stringWithFormat:@"bias:%0.3fev", evBias];
			self.evShiftButton.enabled = YES;
			self.evShiftMode = NO;
			
			self.isoButton.enabled = YES;
			self.isoValueLabel.text = [NSString stringWithFormat:@"%0.3fev", ISO];
			
			self.resetButton.hidden = YES;
			
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
					
					// スコープを一瞬だけ中央に表示
					self.scopeImageView.hidden = NO;
					[self resetScopeImageViewPositionToCenter];
					self.scopeImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.scopeImageView.alpha = 0.0;
									 } completion:^(BOOL finished) {
									 }];
					
					// スライダーを消す
					self.slider.hidden = YES;
					self.sliderCancelButton.hidden = YES;
					[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
					
					// TODO: ボタンの制御
					self.zoomModeButton.enabled = YES;
					
					// リセットボタンを消す
					self.resetButton.hidden = YES;
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
					
					// スライダーを表示する
					self.slider.hidden = NO;
					self.sliderCancelButton.hidden = NO;
					self.slider.minimumValue = 0.0; // 最も近い
					self.slider.maximumValue = 1.0; // 最も遠い
					if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
						self.slider.value = self.captureDevice.lensPosition; // 現在値
					} else {
						self.slider.value = 0.0;
					}
					self.slider.continuous = YES;
					[self.slider addTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
					
					// TODO: ボタンの制御
					self.zoomModeButton.enabled = NO;
					self.focusModeButton.enabled = NO;
					self.exposureModeButton.enabled = NO;
					self.isoButton.enabled = NO;
					self.evShiftButton.enabled = NO;
					self.resetButton.hidden = YES;
					self.scopeImageView.hidden = YES;
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
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureMode = ExposureModeAutoExpose;
					self.exposureModelLabel.text = [self exposureModeLabelText];
					
					// スライダーを消す
					self.slider.hidden = YES;
					self.sliderCancelButton.hidden = YES;
					[self.slider removeTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
				});
			}
		}
	} else if (exposureMode == ExposureModeWhileEnteringManualExpose) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeCustom]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeCustom;
				[self.captureDevice unlockForConfiguration];
				
				CMTime minExposureDuration = self.captureDevice.activeFormat.minExposureDuration;
				CMTime maxExposureDuration = self.captureDevice.activeFormat.maxExposureDuration;
				CMTime exposureDuration = self.captureDevice.exposureDuration;
				
				NSLog(@"exposureDuration: min=%f max=%f current=%f", CMTimeGetSeconds(minExposureDuration), CMTimeGetSeconds(maxExposureDuration), CMTimeGetSeconds(exposureDuration));
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureMode = ExposureModeManulaExpose;
					self.exposureModelLabel.text = [self exposureModeLabelText];
					
					// スライダーを表示する
					self.slider.hidden = NO;
					self.sliderCancelButton.hidden = NO;
					self.slider.minimumValue = CMTimeGetSeconds(minExposureDuration);
					self.slider.maximumValue = CMTimeGetSeconds(maxExposureDuration);
					self.slider.value = CMTimeGetSeconds(exposureDuration);
					//self.slider.minimumValue = self.captureDevice.activeFormat.minISO;
					//self.slider.maximumValue = self.captureDevice.activeFormat.maxISO;
					//self.slider.value = self.captureDevice.ISO;
					self.slider.continuous = YES;
					[self.slider addTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
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

- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

- (void)enableLeftSideButtons {
	self.zoomModeButton.enabled = YES;
	self.focusModeButton.enabled = NO;
	self.exposureModeButton.enabled = NO;
	if (self.exposureMode == ExposureModeManulaExpose) {
		self.isoButton.enabled = YES;
	} else {
		self.isoButton.enabled = NO;
	}
	self.evShiftButton.enabled = NO;
}

- (void)disableLeftSideButtons {
	self.zoomModeButton.enabled = NO;
	self.focusModeButton.enabled = NO;
	self.exposureModeButton.enabled = NO;
	self.isoButton.enabled = NO;
	self.evShiftButton.enabled = NO;
}

- (void)hideSlider {
	self.slider.hidden = YES;
	self.sliderCancelButton.hidden = YES;
	
	self.zoomModeButton.enabled = YES;
	self.focusModeButton.enabled = YES;
	self.exposureModeButton.enabled = YES;
	self.isoButton.enabled = YES;
	self.evShiftButton.enabled = YES;
	
	self.resetButton.hidden = NO;
	self.scopeImageView.hidden = NO;
	
	[self.slider removeTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.slider removeTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
	[self.slider removeTarget:self action:@selector(evShiftValueChanged:) forControlEvents:UIControlEventValueChanged];
}

- (IBAction)handleTapZoomButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	// ズームモードに入る
	self.zoomMode = YES;
	
	// スライダーを表示
	CGFloat maxZoom = 8.0;
	self.slider.minimumValue = 1.0;
	self.slider.hidden = NO;
	self.sliderCancelButton.hidden = NO;
	self.slider.maximumValue = self.maxZoomFactor;
	self.slider.maximumValue = self.slider.maximumValue > maxZoom ? maxZoom : self.slider.maximumValue;
	self.slider.value = self.captureDevice.videoZoomFactor;
	self.slider.continuous = YES;
	[self.slider addTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
	
	// ボタンを無効化
	self.zoomModeButton.enabled = NO;
	self.focusModeButton.enabled = NO;
	self.exposureModeButton.enabled = NO;
	self.isoButton.enabled = NO;
	self.evShiftButton.enabled = NO;
	self.resetButton.hidden = YES;
	self.scopeImageView.hidden = YES;
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
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	if (!self.evShiftMode) {
		
		if ([AVCaptureDevice instancesRespondToSelector:@selector(setExposureTargetBias:completionHandler:)]) {
			
			// 露出補正モードに入る
			self.evShiftMode = YES;
			
			// スライダーを表示
			self.slider.hidden = NO;
			self.sliderCancelButton.hidden = NO;
			self.slider.minimumValue = self.captureDevice.minExposureTargetBias;
			self.slider.maximumValue = self.captureDevice.maxExposureTargetBias;
			self.slider.value = 0.0;
			self.slider.continuous = YES;
			[self.slider addTarget:self action:@selector(evShiftValueChanged:) forControlEvents:UIControlEventValueChanged];
		}
		
	} else {
		// 露出補正モードから出る
		self.evShiftMode = NO;
		
		// スライダーを消す
		self.slider.hidden = YES;
		self.sliderCancelButton.hidden = YES;
		[self.slider removeTarget:self action:@selector(evShiftValueChanged:) forControlEvents:UIControlEventValueChanged];
	}
}

- (IBAction)handleTapISOButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
}

- (IBAction)hadleTapSliderCancelButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self hideSlider];
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
	if (!self.slider.hidden) {
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
		
		[self lockFocusAndExposureDurationWithInterestPoint:interestPoint showScope:YES scopePosition:tapOnPreviewView];
	}
}

- (void)lockFocusAndExposureDurationWithInterestPoint:(CGPoint)interestPoint showScope:(BOOL)presentScope scopePosition:(CGPoint)scopePosition {
	
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
	self.exposureModelLabel.text = [self exposureModeLabelText];
	
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
			
			dispatch_sync(dispatch_get_main_queue(), ^(void){
				
				if (!afl) {
					self.focusMode = oldFocusMode;
					self.focusModeLabel.text = [self focusModeLabelText];
				}
				
				if (!ael) {
					self.exposureMode = oldExposureMode;
					self.exposureModelLabel.text = [self exposureModeLabelText];
				}
				
				if ((ael || afl) && presentScope) {
					// 昔のアニメーションを中止
					[self.scopeImageView.layer removeAllAnimations];
					
					// scopeImageViewを表示し、1秒かけて徐々に薄くする
					self.scopeImageView.hidden = NO;
					[self setScopeImageViewPosition:scopePosition];
					self.scopeImageView.alpha = 1.0;
					[UIView animateWithDuration:1.0f
										  delay:0.0f
										options:UIViewAnimationOptionCurveEaseIn
									 animations:^{
										 self.scopeImageView.alpha = 0.5;
									 } completion:^(BOOL finished) {
									 }];
				}
			});
		}
	}];
}

- (void)resetScopeImageViewPositionToCenter {
	
	if ([self.view.constraints containsObject:self.scopeImageViewConstraintX]) {
		[self.view removeConstraint:self.scopeImageViewConstraintX];
		self.scopeImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.scopeImageViewConstraintY]) {
		[self.view removeConstraint:self.scopeImageViewConstraintY];
		self.scopeImageViewConstraintY = nil;
	}
	
	self.scopeImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.scopeImageView
																  attribute:NSLayoutAttributeCenterX
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterX
																 multiplier:1.0 constant:0.0];
	self.scopeImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.scopeImageView
																  attribute:NSLayoutAttributeCenterY
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeCenterY
																 multiplier:1.0 constant:0.0];
	[self.view addConstraint:self.scopeImageViewConstraintX];
	[self.view addConstraint:self.scopeImageViewConstraintY];
}

- (void)setScopeImageViewPosition:(CGPoint)position {
	
	if ([self.view.constraints containsObject:self.scopeImageViewConstraintX]) {
		NSLog(@"remove old constraintX");
		[self.view removeConstraint:self.scopeImageViewConstraintX];
		self.scopeImageViewConstraintX = nil;
	}
	
	if ([self.view.constraints containsObject:self.scopeImageViewConstraintY]) {
		NSLog(@"remove old constraintY");
		[self.view removeConstraint:self.scopeImageViewConstraintY];
		self.scopeImageViewConstraintY = nil;
	}
	NSLog(@"position=%@", NSStringFromCGPoint(position));
	self.scopeImageViewConstraintX = [NSLayoutConstraint constraintWithItem:self.scopeImageView
																  attribute:NSLayoutAttributeLeading
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeLeading
																 multiplier:1.0 constant:position.x - 25.0]; // ImageView高さ50の半分を差し引く
	self.scopeImageViewConstraintY = [NSLayoutConstraint constraintWithItem:self.scopeImageView
																  attribute:NSLayoutAttributeTop
																  relatedBy:NSLayoutRelationEqual
																	 toItem:self.previewView
																  attribute:NSLayoutAttributeTop
																 multiplier:1.0 constant:position.y - 25.0]; // ImageView幅50の半分を差し引く
	[self.view addConstraint:self.scopeImageViewConstraintX];
	[self.view addConstraint:self.scopeImageViewConstraintY];
}

- (void)zoomValueChanged:(UISlider *)slider {
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

- (void)focusValueChanged:(UISlider *)slider {
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

- (void)exposureValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"exposureValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	float exposureValue = slider.value;
	
	[self enqBlock:^(void){
		NSError *error;
		if ([self.class isManualFocusSupported]) {
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

- (void)evShiftValueChanged:(UISlider *)slider {
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
			self.focusStatusLabel.text = @"Focus Mode: Locked";
			if (self.focusMode == FocusModeWhileEnteringAutoFocusModeLocked) {
				self.focusMode = FocusModeAutoFocusLocked;
				self.focusModeLabel.text = [self focusModeLabelText];
				self.resetButton.hidden = NO;
			}
		} else if (focusMode == AVCaptureFocusModeAutoFocus) {
			self.focusStatusLabel.text = @"Focus Mode: Auto";
		} else if (focusMode == AVCaptureFocusModeContinuousAutoFocus) {
			self.focusStatusLabel.text = @"Focus Mode: Continuous Auto";
		}
	} else if ([keyPath isEqualToString:@"exposureMode"]) {
		AVCaptureExposureMode exposureMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (exposureMode == AVCaptureExposureModeLocked) {
			self.exposureStatusLabel.text = @"Exposure Mode: Locked";
			if (self.exposureMode == ExposureModeWhileEnteringAutoExposeLocked) {
				self.exposureMode = ExposureModeAutoExposeLocked;
				self.exposureModelLabel.text = [self exposureModeLabelText];
				self.resetButton.hidden = NO;
			}
		} else if (exposureMode == AVCaptureExposureModeAutoExpose) {
			self.exposureStatusLabel.text = @"Exposure Mode: Auto";
		} else if (exposureMode == AVCaptureExposureModeContinuousAutoExposure) {
			self.exposureStatusLabel.text = @"Exposure Mode: Continuous Auto";
		} else if (exposureMode == AVCaptureExposureModeCustom) {
			self.exposureStatusLabel.text = @"Exposure Mode: Custom";
		}
	} else if ([keyPath isEqualToString:@"exposureDuration"]) {
		CMTime time;
		[[change objectForKey:NSKeyValueChangeNewKey] getValue:&time];
		Float64 exposureDuration = CMTimeGetSeconds(time);
		self.exposureDurationValueLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
	} else if ([keyPath isEqualToString:@"lensPosition"]) {
		float lensPosition = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
	} else if ([keyPath isEqualToString:@"whiteBalanceMode"]) {
		AVCaptureWhiteBalanceMode whiteBalanceMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (whiteBalanceMode == AVCaptureWhiteBalanceModeLocked) {
			self.wbStatusLabel.text = @"White Balance Mode: Locked";
		} else if (whiteBalanceMode == AVCaptureWhiteBalanceModeAutoWhiteBalance) {
			self.wbStatusLabel.text = @"White Balance Mode: Auto";
		} else if (whiteBalanceMode == AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance) {
			self.wbStatusLabel.text = @"White Balance Mode: Continuous Auto";
		}
	} else if ([keyPath isEqualToString:@"exposureTargetOffset"]) {
		float exposureTargetOffset = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.evOffsetLabel.text = [NSString stringWithFormat:@"offset:%0.3fev", exposureTargetOffset];
	} else if ([keyPath isEqualToString:@"exposureTargetBias"]) {
		float exposureTargetBias = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.evBiasLabel.text = [NSString stringWithFormat:@"bias:%0.3fev", exposureTargetBias];
	} else if ([keyPath isEqualToString:@"ISO"]) {
		float ISO = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.isoValueLabel.text = [NSString stringWithFormat:@"%0.3fev", ISO];
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

@end
