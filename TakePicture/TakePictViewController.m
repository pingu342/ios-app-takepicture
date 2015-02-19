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

typedef NS_ENUM(NSInteger, FocusState) {
	FocusStateCurrentModeIsAuto,
	FocusStateWhileChangingModeAutoToManual,
	FocusStateCurrentModeIsManual,
	FocusStateWhileChangingModeManualToLocked,
	FocusStateCurrentModeIsLocked,
	FocusStateWhileChangingModeLockedToAuto
};

typedef NS_ENUM(NSInteger, ExposureState) {
	ExposureStateCurrentModeIsAuto,
	ExposureStateWhileChangingModeAutoToManual,
	ExposureStateCurrentModeIsManual,
	ExposureStateWhileChangingModeManualToLocked,
	ExposureStateCurrentModeIsLocked,
	ExposureStateWhileChangingModeLockedToAuto
};

@interface TakePictViewController () {
}

// UI
@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UISlider *slider;
@property (nonatomic, weak) IBOutlet UIButton *zoomButton;
@property (nonatomic, weak) IBOutlet UILabel *zoomValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UILabel *focusValueLabel;
@property (nonatomic, weak) IBOutlet UILabel *focusLensPositionLabel;
@property (nonatomic, weak) IBOutlet UIButton *exposureButton;
@property (nonatomic, weak) IBOutlet UILabel *exposureValueLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureDurationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *scopeImageView;
@property (nonatomic, weak) IBOutlet UIButton *resetButton;
@property (nonatomic, weak) IBOutlet UILabel *focusStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *exposureStatusLabel;
@property (nonatomic, weak) IBOutlet UIButton *isoButton;
@property (nonatomic, weak) IBOutlet UILabel *isoValueLabel;

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
@property (nonatomic) FocusState focusState;
@property (nonatomic) ExposureState exposureState;
@property (nonatomic) BOOL autoFocusLockedTemporarily;
@property (nonatomic) NSLayoutConstraint *scopeImageViewConstraintX;
@property (nonatomic) NSLayoutConstraint *scopeImageViewConstraintY;

@property (nonatomic) dispatch_queue_t queue;

@end

@implementation TakePictViewController

- (void)viewDidLoad {
	NSLog(@"%s", __FUNCTION__);
	
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	if ([DeviceSystemVersion sharedInstance].major <= 7) {
		self.focusButton.hidden = YES;
		self.focusValueLabel.hidden = YES;
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
	self.zoomValueLabel.text = @"x1.0";
	self.zoomValue = 1.0;
	self.zoomButton.enabled = NO;
	self.zoomMode = NO;
	self.focusValueLabel.text = @"自動";
	self.focusLensPositionLabel.text = @" ";
	self.focusState = FocusStateCurrentModeIsAuto;
	self.focusButton.enabled = NO;
	self.focusStatusLabel.text = @"Focus:";
	self.exposureValueLabel.text = @"自動";
	self.exposureDurationLabel.text = @" ";
	self.exposureState = ExposureStateCurrentModeIsAuto;
	self.exposureButton.enabled = NO;
	self.exposureStatusLabel.text = @"Exposure:";
	self.autoFocusLockedTemporarily = NO;
	self.scopeImageView.hidden = YES;
	self.resetButton.hidden = YES;
	
	// カメラを開始
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
		[self enqBlock:^(void){
			[self setFocusMode:AVCaptureFocusModeAutoFocus
		  focusPointOfInterest:self.captureDevice.focusPointOfInterest
				  exposureMode:AVCaptureExposureModeAutoExpose
	   exposurePointOfInterest:self.captureDevice.exposurePointOfInterest];
		}];
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
	[self.captureDevice removeObserver:self forKeyPath:@"lensPosition"];
	[self.captureDevice removeObserver:self forKeyPath:@"exposureMode"];
	[self.captureDevice removeObserver:self forKeyPath:@"exposureDuration"];
	
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
	[device addObserver:self forKeyPath:@"lensPosition" options:NSKeyValueObservingOptionNew context:nil];
	[device addObserver:self forKeyPath:@"exposureMode" options:NSKeyValueObservingOptionNew context:nil];
	[device addObserver:self forKeyPath:@"exposureDuration" options:NSKeyValueObservingOptionNew context:nil];
	
	[session startRunning];
	
	self.captureSession = session;
	self.captureDevice = device;
	self.captureInput = input;
	self.captureOutput = output;
	self.captureConnection = connection;
	
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
	if ([self setFocusMode:AVCaptureFocusModeContinuousAutoFocus
	  focusPointOfInterest:CGPointMake(0.5, 0.5)
			  exposureMode:AVCaptureExposureModeContinuousAutoExposure
   exposurePointOfInterest:CGPointMake(0.5, 0.5)]) {
		
		Float64 exposureDuration = CMTimeGetSeconds(self.captureDevice.exposureDuration);
		float lensPosition = self.captureDevice.lensPosition;
		
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
			
			self.slider.hidden = YES;
			self.zoomValueLabel.text = @"x1.0";
			self.zoomValue = 1.0;
			self.zoomButton.enabled = YES;
			self.zoomMode = NO;
			self.focusValueLabel.text = @"自動";
			self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
			self.focusState	= FocusStateCurrentModeIsAuto;
			self.focusButton.enabled = YES;
			self.exposureValueLabel.text = @"自動";
			self.exposureDurationLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
			self.exposureState = ExposureStateCurrentModeIsAuto;
			self.exposureButton.enabled = YES;
			self.resetButton.hidden = YES;
			self.autoFocusLockedTemporarily = NO;
			
		});
	}
}

- (void)setFocusModeFocusState:(id)object {
	NSError *error;
	FocusState focusState = [(NSNumber *)object integerValue];
	
	if (focusState == FocusStateWhileChangingModeLockedToAuto) {
		// カメラが自動でフォーカスするモードに切り換える
		// このモードではfocusModeをContinuousAutoFocusに設定する
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
				self.captureDevice.focusPointOfInterest = CGPointMake(0.5, 0.5);
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					
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
					
					self.focusState = FocusStateCurrentModeIsAuto;
					self.autoFocusLockedTemporarily = NO;
					self.focusValueLabel.text = @"自動";
					
					// スライダーを消す
					self.slider.hidden = YES;
					[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
					
					// ズームモードを許可
					self.zoomButton.enabled = YES;
					self.resetButton.hidden = YES;
					self.scopeImageView.hidden = NO;
				});
			}
		}
		
	} else if (focusState == FocusStateWhileChangingModeAutoToManual) {
		// スライダー操作によりマニュアルでフォーカスを設定するモードに切り替える
		// このモードではfocusModeをLockedに設定する
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked] &&
			[self.class isManualFocusSupported]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeLocked;
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.focusValueLabel.text = @"手動";
					self.focusState = FocusStateCurrentModeIsManual;
					
					// スライダーを表示する
					self.slider.hidden = NO;
					self.slider.minimumValue = 0.0; // 最も近い
					self.slider.maximumValue = 1.0; // 最も遠い
					if ([AVCaptureDevice instancesRespondToSelector:@selector(lensPosition)]) {
						self.slider.value = self.captureDevice.lensPosition; // 現在値
					} else {
						self.slider.value = 0.0;
					}
					self.slider.continuous = YES;
					[self.slider addTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
					
					// フォーカスとズームを同時に操作することは禁止
					self.zoomButton.enabled = NO;
					self.resetButton.hidden = YES;
					self.scopeImageView.hidden = YES;
				});
			}
		}
		
	} else if (focusState == FocusStateWhileChangingModeManualToLocked) {
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeLocked;
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.focusValueLabel.text = @"固定";
					self.focusState	= FocusStateCurrentModeIsLocked;
					
					// スライダーを消す
					self.slider.hidden = YES;
					[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
					
					// ズームモードを許可
					self.zoomButton.enabled = YES;
					self.resetButton.hidden = YES;
					self.scopeImageView.hidden = YES;
				});
			}
		}
	}
}

- (void)setExposureModeExposureState:(id)object {
	NSError *error;
	ExposureState exposureState = [(NSNumber *)object integerValue];
	
	if (exposureState == ExposureStateWhileChangingModeLockedToAuto) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureValueLabel.text = @"自動";
					self.exposureState = ExposureStateCurrentModeIsAuto;
					
					// スライダーを消す
					self.slider.hidden = YES;
					[self.slider removeTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
				});
			}
		}
	} else if (exposureState == ExposureStateWhileChangingModeAutoToManual) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeCustom]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeCustom;
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureValueLabel.text = @"手動";
					self.exposureState = ExposureStateCurrentModeIsManual;
					
					// スライダーを表示する
					self.slider.hidden = NO;
					self.slider.minimumValue = 0.0;
					self.slider.maximumValue = 1.0;
					self.slider.continuous = YES;
					[self.slider addTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
				});
			}
		}
	} else if (exposureState == ExposureStateWhileChangingModeManualToLocked) {
		if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.exposureMode = AVCaptureExposureModeLocked;
				[self.captureDevice unlockForConfiguration];
				
				dispatch_sync(dispatch_get_main_queue(), ^(void){
					self.exposureValueLabel.text = @"固定";
					self.exposureState = ExposureStateCurrentModeIsLocked;
					
					// スライダーを消す
					self.slider.hidden = YES;
					[self.slider removeTarget:self action:@selector(exposureValueChanged:) forControlEvents:UIControlEventValueChanged];
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

- (IBAction)handleTapZoomButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	// ズームモード切替（固定(NO) -> ズーム(YES)）
	if (!self.zoomMode) {
		// ズームモードに入る
		self.zoomMode = YES;
		
		// スライダーを表示
		CGFloat maxZoom = 8.0;
		self.slider.minimumValue = 1.0;
		self.slider.hidden = NO;
		self.slider.maximumValue = self.maxZoomFactor;
		self.slider.maximumValue = self.slider.maximumValue > maxZoom ? maxZoom : self.slider.maximumValue;
		self.slider.value = self.captureDevice.videoZoomFactor;
		self.slider.continuous = YES;
		[self.slider addTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
		
		// フォーカスとズームを同時に操作することは禁止
		self.focusButton.enabled = NO;
		self.resetButton.hidden = YES;
		self.scopeImageView.hidden = YES;
		
	} else {
		// ズームモードから出る
		self.zoomMode = NO;
		
		// スライダーを消す
		self.slider.hidden = YES;
		[self.slider removeTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
		
		// フォーカスのモード変更を許可
		self.focusButton.enabled = YES;
		self.resetButton.hidden = !self.autoFocusLockedTemporarily;
		self.scopeImageView.hidden = !self.autoFocusLockedTemporarily;
	}
}

- (IBAction)handleTapFocusButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	FocusState newFocusState;
	
	// フォーカスモード切替 (自動 -> 手動 -> 固定)
	if (self.focusState == FocusStateCurrentModeIsAuto) {
		newFocusState = FocusStateWhileChangingModeAutoToManual;
	} else if (self.focusState == FocusStateCurrentModeIsManual) {
		newFocusState = FocusStateWhileChangingModeManualToLocked;
	} else if (self.focusState == FocusStateCurrentModeIsLocked) {
		newFocusState = FocusStateWhileChangingModeLockedToAuto;
	} else {
		return;
	}
	
	self.focusState = newFocusState;
	
	NSNumber *object = [NSNumber numberWithInteger:newFocusState];
	[self enqSel:@selector(setFocusModeFocusState:) withObject:object];
}

- (IBAction)handleTapExposureButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	ExposureState newExposureState;
	
	// フォーカスモード切替 (自動 -> 手動 -> 固定)
	if (self.exposureState == ExposureStateCurrentModeIsAuto) {
		newExposureState = ExposureStateWhileChangingModeAutoToManual;
	} else if (self.exposureState == ExposureStateCurrentModeIsManual) {
		newExposureState = ExposureStateWhileChangingModeManualToLocked;
	} else if (self.exposureState == ExposureStateCurrentModeIsLocked) {
		newExposureState = ExposureStateWhileChangingModeLockedToAuto;
	} else {
		return;
	}
	
	self.exposureState = newExposureState;
	
	NSNumber *object = [NSNumber numberWithInteger:newExposureState];
	[self enqSel:@selector(setExposureModeExposureState:) withObject:object];
}

- (IBAction)handlePreviewViewTapGesture:(UIGestureRecognizer *)sender {
	NSLog(@"%s", __FUNCTION__);
	
	//CGPoint tapOnSuperView = [sender locationInView:self.view];
	CGPoint tapOnPreviewView = [sender locationInView:self.previewView];
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	// ズームモード間はタップを無視
	if (self.zoomMode) {
		return;
	}
	
	if (self.focusState == FocusStateCurrentModeIsAuto) {
		
		// カメラプレビューのビューの領域
		CGRect previewRect = self.previewView.bounds;	// 画面はランドスケープ固定
		//NSLog(@"preview rect=%@", NSStringFromCGRect(previewRect));
		
		// カメラプレビューのビュー内部でカメラ映像が描画されている領域
		CGRect drowRect;
		drowRect.size.width = previewRect.size.height * 4.0 / 3.0;
		drowRect.size.height = previewRect.size.width * 3.0 / 4.0;
		if (drowRect.size.width <= previewRect.size.width) {
			drowRect.size.height = previewRect.size.height;
		} else {
			drowRect.size.width = previewRect.size.width;
		}
		drowRect.origin.x = (previewRect.size.width - drowRect.size.width) / 2.0;
		drowRect.origin.y = (previewRect.size.height - drowRect.size.height) / 2.0;
		//NSLog(@"drow rect=%@", NSStringFromCGRect(drowRect));
		
		// カメラプレビューのビュー内部のタップされた位置
		CGPoint interestPoint = tapOnPreviewView;
		interestPoint.x -= drowRect.origin.x;
		interestPoint.y -= drowRect.origin.y;
		
		// カメラプレビューのビュー内部がタップされたら処理を実行
		if (0.0 <= interestPoint.x && interestPoint.x <= drowRect.size.width) {
			if (0.0 <= interestPoint.y && interestPoint.y <= drowRect.size.height) {
				
				// タップされた位置にフォーカスを合わせる
				// interestPointはランドスケープ座標系(ホームボタン右)、interestもランドスケープ座標系(ホームボタン右)
				interestPoint.x /= drowRect.size.width;
				interestPoint.y /= drowRect.size.height;
				NSLog(@"interestPoint=%@ zoom=%0.1f", NSStringFromCGPoint(interestPoint), self.zoomValue);
				// ズームを補正（ビューの中心を原点とする座標系に変換してからズームを補正後に左上原点の座標系に戻す）
				interestPoint = CGPointMake((interestPoint.x - 0.5) / self.zoomValue + 0.5,
											(interestPoint.y - 0.5) / self.zoomValue + 0.5);
				//NSLog(@"interest point=%@", NSStringFromCGPoint(interest));
				[self enqBlock:^(void){
					NSError *error;
					if ([self.captureDevice isFocusPointOfInterestSupported] &&
						[self.captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
						if (![self.captureDevice isAdjustingFocus] &&
							![self.captureDevice isAdjustingExposure]) {
							if ([self.captureDevice lockForConfiguration:&error]) {
								NSLog(@"setFocusPointOfInterest interestPoint=%@", NSStringFromCGPoint(interestPoint));
								
								dispatch_sync(dispatch_get_main_queue(), ^(void){
								
									// 昔のアニメーションを中止
									[self.scopeImageView.layer removeAllAnimations];
									
									// scopeImageViewを表示し、1秒かけて徐々に消す
									self.scopeImageView.hidden = NO;
									[self setScopeImageViewPosition:tapOnPreviewView];
									self.scopeImageView.alpha = 1.0;
									[UIView animateWithDuration:1.0f
														  delay:0.0f
														options:UIViewAnimationOptionCurveEaseIn
													 animations:^{
														 self.scopeImageView.alpha = 0.5;
													 } completion:^(BOOL finished) {
													 }];
									self.autoFocusLockedTemporarily = YES;
									self.resetButton.hidden = NO;
								});
								
								// タップされた位置にフォーカスと露出（シャッタースピード）をロックした状態に入る
								self.captureDevice.focusPointOfInterest = interestPoint;
								self.captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
								self.captureDevice.exposurePointOfInterest = interestPoint;
								self.captureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
								[self.captureDevice unlockForConfiguration];
							}
						}
					}
				}];
			}
		}
	}
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
	
	NSError *error;
	
	if ([self.class isVideoZoomSupported]) {
		if ([self.captureDevice lockForConfiguration:&error]) {
			[self.captureDevice setVideoZoomFactor:slider.value];
			[self.captureDevice unlockForConfiguration];
			self.zoomValue = slider.value;
			self.zoomValueLabel.text = [NSString stringWithFormat:@"x%0.1f", self.zoomValue];
		}
	}
}

- (void)focusValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"focusValue=%f", slider.value);
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	NSError *error;
	
	if ([self.class isManualFocusSupported]) {
		if (![self.captureDevice isAdjustingFocus]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				[self.captureDevice setFocusModeLockedWithLensPosition:slider.value completionHandler:^(CMTime syncTime) {
					//unlockForConfigurationは勝手にやってくれている？
				}];
			}
		}
	}
}

- (void)exposureValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"exposureValue=%f", slider.value);
	
	NSError *error;
	
	if ([self.class isManualFocusSupported]) {
		if (![self.captureDevice isAdjustingExposure]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				Float64 min = CMTimeGetSeconds(self.captureDevice.activeVideoMinFrameDuration);
				Float64 max = CMTimeGetSeconds(self.captureDevice.activeVideoMaxFrameDuration);
				Float64 distance = max - min;
				Float64 exposureDuration = distance * slider.value + min;
				NSLog(@"min=%0.3f max=%0.3f %0.3fs", min, max, exposureDuration);
				[self.captureDevice setExposureModeCustomWithDuration:CMTimeMakeWithSeconds(exposureDuration, 1000000000)
																  ISO:AVCaptureISOCurrent
													completionHandler:^(CMTime syncTime) {
					//unlockForConfigurationは勝手にやってくれている？
				}];
			}
		}
	}
}

- (void)subjectAreaDidChanged{
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"interest=%@", NSStringFromCGPoint(self.captureDevice.focusPointOfInterest));
	
	// キャプチャ中でなければなにもしない
	if (!self.previewing) {
		return;
	}
	
	if (self.focusState == FocusStateCurrentModeIsAuto) {
		if (self.autoFocusLockedTemporarily) {
			//[self enqSel:@selector(resetCameraSettingsToDefault)];
			//self.autoFocusLockedTemporarily = NO;
		}
	}
}

- (BOOL)setFocusMode:(AVCaptureFocusMode)focusMode focusPointOfInterest:(CGPoint)focusPointOfInterest exposureMode:(AVCaptureExposureMode)exposureMode exposurePointOfInterest:(CGPoint)exposurePointOfInterest {
	NSLog(@"%s", __FUNCTION__);
	NSError *error;
	
	if ([self.captureDevice lockForConfiguration:&error]) {
		self.captureDevice.focusPointOfInterest = focusPointOfInterest;
		self.captureDevice.focusMode = focusMode;
		self.captureDevice.exposurePointOfInterest = exposurePointOfInterest;
		self.captureDevice.exposureMode = exposureMode;
		[self.captureDevice unlockForConfiguration];
		return YES;
	}
	
	return NO;
}

- (BOOL)setFocusMode:(AVCaptureFocusMode)focusMode interestPoint:(CGPoint)interest {
	NSError *error;
	
	if ([self.captureDevice lockForConfiguration:&error]) {
		self.captureDevice.focusPointOfInterest = interest;
		self.captureDevice.focusMode = focusMode;
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
			self.focusStatusLabel.text = @"Focus: Locked";
		} else if (focusMode == AVCaptureFocusModeAutoFocus) {
			self.focusStatusLabel.text = @"Focus: Auto";
		} else if (focusMode == AVCaptureFocusModeContinuousAutoFocus) {
			self.focusStatusLabel.text = @"Focus: ContinuousAuto";
		}
	} else if ([keyPath isEqualToString:@"exposureMode"]) {
		AVCaptureExposureMode exposureMode = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		if (exposureMode == AVCaptureExposureModeLocked) {
			self.exposureStatusLabel.text = @"Exposure: Locked";
		} else if (exposureMode == AVCaptureExposureModeAutoExpose) {
			self.exposureStatusLabel.text = @"Exposure: Auto";
		} else if (exposureMode == AVCaptureExposureModeContinuousAutoExposure) {
			self.exposureStatusLabel.text = @"Exposure: ContinuousAuto";
		} else if (exposureMode == AVCaptureExposureModeCustom) {
			self.exposureStatusLabel.text = @"Exposure: Custom";
		}
	} else if ([keyPath isEqualToString:@"exposureDuration"]) {
		CMTime time;
		[[change objectForKey:NSKeyValueChangeNewKey] getValue:&time];
		Float64 exposureDuration = CMTimeGetSeconds(time);
		self.exposureDurationLabel.text = [NSString stringWithFormat:@"%0.3fs", exposureDuration];
	} else if ([keyPath isEqualToString:@"lensPosition"]) {
		float lensPosition = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
		self.focusLensPositionLabel.text = [NSString stringWithFormat:@"%0.3f", lensPosition];
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

@end
