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

typedef NS_ENUM(NSInteger, MyFocusMode) {
	MyFocusModeAuto,
	MyFocusModeManual,
	MyFocusModeLocked
};

@interface TakePictViewController () {
}

@property (nonatomic, weak) IBOutlet UIView *previewView;
@property (nonatomic, weak) IBOutlet UISlider *slider;
@property (nonatomic, weak) IBOutlet UIButton *zoomButton;
@property (nonatomic, weak) IBOutlet UILabel *zoomValueLabel;
@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UILabel *focusValueLabel;
@property (nonatomic, weak) IBOutlet UIImageView *scopeImageView;

@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDevice *captureDevice;
@property (nonatomic) AVCaptureDeviceInput *captureInput;
@property (nonatomic) AVCaptureStillImageOutput *captureOutput;
@property (nonatomic) AVCaptureConnection *captureConnection;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic) BOOL zoomMode;
@property (nonatomic) CGFloat zoomValue;
@property (nonatomic) MyFocusMode focusMode;
@property (nonatomic) BOOL autoFocusLockedTemporarily;

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
}

- (void)didReceiveMemoryWarning {
	NSLog(@"%s", __FUNCTION__);
	
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewWillAppear:animated];
	
	// ビューを初期化
	self.slider.hidden = YES;
	self.zoomValueLabel.text = @"x1.0";
	self.zoomValue = 1.0;
	self.zoomMode = NO;
	self.focusValueLabel.text = @"自動";
	self.focusMode = MyFocusModeAuto;
	self.autoFocusLockedTemporarily = NO;
	self.scopeImageView.hidden = YES;
	
	// カメラを開始
	[self setupCapture];
	if ([self resetCameraSettingsToDefault]) {
		NSLog(@"resetCameraSettingsToDefault");
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewWillDisappear:animated];
	[self teardownCapture];
}

- (void)viewDidLayoutSubviews {
	NSLog(@"%s", __FUNCTION__);
	
	[super viewDidLayoutSubviews];
	
	if (self.previewLayer == nil) {
		NSLog(@"create previewLayer");
		
		// プレビューレイヤーを作成
		self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
		self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
		self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
		//self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
		
		// 回転させる
		int displayRotation = [CameraManager displayRotationWithViewController:self];
		if (self.previewLayer.connection.supportsVideoOrientation) {
			self.previewLayer.connection.videoOrientation = [CameraManager appropriateVideoOrientationWithDisplayRotation:displayRotation];
		}
		
		// プレビューレイヤーをビューに追加
		self.previewLayer.frame = self.previewView.bounds;
		[self.previewView.layer addSublayer:self.previewLayer];
		[self.previewView.layer setMasksToBounds:YES];
		
		// 枠を付ける
		//[self.previewView.layer setBorderWidth:1.0f];
		//[self.previewView.layer setBorderColor:[[UIColor blueColor] CGColor]];
		
	} else {
		NSLog(@"previewLayer has already created");
		self.previewLayer.frame = self.previewView.bounds;
	}
	
	[self.view layoutIfNeeded];
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
	NSLog(@"%s", __FUNCTION__);
	
	[self dismissViewControllerAnimated:YES completion:nil];
	[self teardownCapture];
}

- (IBAction)tapTakePictButton:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	[self takePicture];
}

- (void) teardownCapture {
	NSLog(@"%s", __FUNCTION__);
	
	if (self.captureSession == nil) {
		return;
	}
	
	[self.captureSession stopRunning];
	[self.captureSession removeInput:self.captureInput];
	[self.captureSession removeOutput:self.captureOutput];
	[self.previewLayer removeFromSuperlayer];
	
	// オブザーバーを削除
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:AVCaptureDeviceSubjectAreaDidChangeNotification
												  object:nil];
	[self.captureDevice removeObserver:self forKeyPath:@"adjustingFocus"];
	
	self.captureSession = nil;
	self.captureDevice = nil;
	self.captureInput = nil;
	self.captureOutput = nil;
	self.captureConnection = nil;
	self.previewLayer = nil;
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
	if (![device isSubjectAreaChangeMonitoringEnabled]) {
		if ([device lockForConfiguration:&error]) {
			device.subjectAreaChangeMonitoringEnabled = YES;
			NSLog(@"enable subjectAreaChangeMonitoring");
			[device unlockForConfiguration];
			
			// 通知センターにAVCaptureDeviceSubjectAreaDidChangeNotificationを登録
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(subjectAreaDidChanged)
														 name:AVCaptureDeviceSubjectAreaDidChangeNotification
													   object:nil];
		}
	}
	
	// AVCaptureDevice adjustingFocusプロパティの変化通知をobserveValueForKeyPathメソッドで受け取る
	[device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:nil];
	
	[session startRunning];
	
	self.captureSession = session;
	self.captureDevice = device;
	self.captureInput = input;
	self.captureOutput = output;
	self.captureConnection = connection;
}

- (void) takePicture {
	NSLog(@"%s", __FUNCTION__);
	
	if (self.captureOutput == nil) {
		return;
	}
	
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
		 [self teardownCapture];
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

- (IBAction)zoomButtonTapped:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// ズームモード切替（固定(NO) -> ズーム(YES)）
	BOOL zoomMode = !self.zoomMode;
	
	if (zoomMode) {
		NSLog(@"videoMaxZoomFactor=%f", self.captureDevice.activeFormat.videoMaxZoomFactor);
		self.zoomMode = YES;
		
		// スライダーを表示
		CGFloat maxZoom = 8.0;
		self.slider.minimumValue = 1.0;
		self.slider.hidden = NO;
		self.slider.maximumValue = self.captureDevice.activeFormat.videoMaxZoomFactor;
		self.slider.maximumValue = self.slider.maximumValue > maxZoom ? maxZoom : self.slider.maximumValue;
		self.slider.value = self.captureDevice.videoZoomFactor;
		self.slider.continuous = YES;
		[self.slider addTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
		
		// フォーカスとズームを同時に操作することは禁止
		self.focusButton.enabled = NO;
	} else {
		self.zoomMode = NO;
		
		// スライダーを消す
		self.slider.hidden = YES;
		[self.slider removeTarget:self action:@selector(zoomValueChanged:) forControlEvents:UIControlEventValueChanged];
		
		// フォーカスのモード変更を許可
		self.focusButton.enabled = YES;
	}
}

- (IBAction)focusButtonTapped:(id)sender {
	NSLog(@"%s", __FUNCTION__);
	
	MyFocusMode focusMode;
	NSError *error;
	
	// フォーカスモード切替 (自動 -> 手動 -> 固定)
	if (self.focusMode == MyFocusModeAuto) {
		focusMode = MyFocusModeManual;
	} else if (self.focusMode == MyFocusModeManual) {
		focusMode = MyFocusModeLocked;
	} else {
		focusMode = MyFocusModeAuto;
	}
	
	if (focusMode == MyFocusModeAuto) {
		// カメラが自動でフォーカスするモードに切り換える
		// このモードではfocusModeをContinuousAutoFocusに設定する
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
				[self.captureDevice unlockForConfiguration];
				
				self.focusMode = MyFocusModeAuto;
				self.autoFocusLockedTemporarily = NO;
				self.focusValueLabel.text = @"自動";
				
				// スライダーを消す
				self.slider.hidden = YES;
				[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
				
				// ズームモードを許可
				self.zoomButton.enabled = YES;
			}
		}
	} else if (focusMode == MyFocusModeManual) {
		// スライダー操作によりマニュアルでフォーカスを設定するモードに切り替える
		// このモードではfocusModeをLockedに設定する
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked] &&
			[self.class isManualFocusSupported]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeLocked;
				[self.captureDevice unlockForConfiguration];
				
				self.focusValueLabel.text = @"手動";
				self.focusMode = MyFocusModeManual;
				
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
			}
		}
	} else {
		if ([self.captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
			if ([self.captureDevice lockForConfiguration:&error]) {
				self.captureDevice.focusMode = AVCaptureFocusModeLocked;
				[self.captureDevice unlockForConfiguration];
				
				self.focusValueLabel.text = @"固定";
				self.focusMode = MyFocusModeLocked;
				
				// スライダーを消す
				self.slider.hidden = YES;
				[self.slider removeTarget:self action:@selector(focusValueChanged:) forControlEvents:UIControlEventValueChanged];
				
				// ズームモードを許可
				self.zoomButton.enabled = YES;
			}
		}
	}
}

- (IBAction)handleTapGesture:(UIGestureRecognizer *)sender {
	NSLog(@"%s", __FUNCTION__);
	
	// ズームモード間はタップを無視
	if (self.zoomMode) {
		return;
	}
	
	if (self.focusMode == MyFocusModeAuto) {
		NSError *error;
		
		// カメラプレビュー用のビューの領域
		CGRect previewRect = self.previewView.bounds;	// 画面はランドスケープ固定
		//NSLog(@"preview rect=%@", NSStringFromCGRect(previewRect));
		
		// 実際にカメラの映像が描画されている領域
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
		
		CGPoint tap = [sender locationInView:self.previewView];
		tap.x -= drowRect.origin.x;
		tap.y -= drowRect.origin.y;
		//NSLog(@"tap point=%@", NSStringFromCGPoint(tap));
		
		if (0.0 <= tap.x && tap.x <= drowRect.size.width) {
			if (0.0 <= tap.y && tap.y <= drowRect.size.height) {
				
				// タップされた位置にフォーカスを合わせる
				CGPoint interest = tap; // tapはランドスケープ座標系(ホームボタン右)、interestもランドスケープ座標系(ホームボタン右)
				interest.x /= drowRect.size.width;
				interest.y /= drowRect.size.height;
				NSLog(@"point=%@ zoom=%0.1f", NSStringFromCGPoint(interest), self.zoomValue);
				// ズームを補正（ビューの中心を原点とする座標系に変換してからズームを補正後に左上原点の座標系に戻す）
				interest = CGPointMake((interest.x - 0.5) / self.zoomValue + 0.5,
									   (interest.y - 0.5) / self.zoomValue + 0.5);
				//NSLog(@"interest point=%@", NSStringFromCGPoint(interest));
				if ([self.captureDevice isFocusPointOfInterestSupported] &&
					[self.captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
					if (![self.captureDevice isAdjustingFocus] &&
						![self.captureDevice isAdjustingExposure]) {
						if ([self.captureDevice lockForConfiguration:&error]) {
							NSLog(@"setFocusPointOfInterest newInterest=%@", NSStringFromCGPoint(interest));
							
							// 昔のアニメーションを中止
							[self.scopeImageView.layer removeAllAnimations];
							
							// self.scopeImageViewを表示する位置を取得
							// self.scopeImageViewはself.viewの子ビューであることに注意
							CGPoint p = [sender locationInView:self.view];
							
							// scopeImageViewを表示し、1秒かけて徐々に消す
							self.scopeImageView.hidden = NO;
							self.scopeImageView.center = p;
							self.scopeImageView.alpha = 1.0;
							[UIView animateWithDuration:1.0f
												  delay:0.0f
												options:UIViewAnimationOptionCurveEaseIn
											 animations:^{
												 self.scopeImageView.alpha = 0.5;
											 } completion:^(BOOL finished) {
											 }
							 ];
							
							// タップされた位置にフォーカスと露出（シャッタースピード）をロックした状態に入る
							self.autoFocusLockedTemporarily = YES;
							self.captureDevice.focusPointOfInterest = interest;
							self.captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
							//self.captureDevice.exposurePointOfInterest = interest;
							//self.captureDevice.exposureMode = AVCaptureExposureModeAutoExpose;
							[self.captureDevice unlockForConfiguration];
						}
					}
				}
			}
		}
	}
}

- (void)zoomValueChanged:(UISlider *)slider {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"zoomValue=%f", slider.value);
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

- (void)subjectAreaDidChanged{
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"interest=%@", NSStringFromCGPoint(self.captureDevice.focusPointOfInterest));
	
	if (self.focusMode == MyFocusModeAuto) {
		if (self.autoFocusLockedTemporarily) {
			[self resetCameraSettingsToDefault];
			self.autoFocusLockedTemporarily = NO;
		}
	}
}

- (BOOL)resetCameraSettingsToDefault {
	NSLog(@"%s", __FUNCTION__);
	if ([self setFocusMode:AVCaptureFocusModeContinuousAutoFocus
			  exposureMode:AVCaptureExposureModeContinuousAutoExposure
			 interestPoint:CGPointMake(0.5, 0.5)]) {
		// scopeImageViewを表示し、1秒かけて徐々に薄くする
		self.scopeImageView.hidden = NO;
		self.scopeImageView.center = CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0);
		self.scopeImageView.alpha = 1.0;
		[UIView animateWithDuration:1.0f
							  delay:0.0f
							options:UIViewAnimationOptionCurveEaseIn
						 animations:^{
							 self.scopeImageView.alpha = 0.3;
						 } completion:^(BOOL finished) {
						 }];
		return YES;
	}
	return NO;
}

- (BOOL)setFocusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode interestPoint:(CGPoint)interest {
	NSLog(@"%s", __FUNCTION__);
	NSError *error;
	
	if ([self.captureDevice lockForConfiguration:&error]) {
		self.captureDevice.focusPointOfInterest = interest;
		self.captureDevice.focusMode = focusMode;
		//self.captureDevice.exposurePointOfInterest = CGPointMake(0.5, 0.5);
		//self.captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
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
	if ([keyPath isEqualToString:@"adjustingFocus"]) {
		BOOL adjustingFocus = [ [change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1] ];
		NSLog(@"Is adjusting focus? %@", adjustingFocus ? @"YES" : @"NO" );
		NSLog(@"Change dictionary: %@", change);
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

@end
