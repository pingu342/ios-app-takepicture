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

@property (nonatomic, weak) IBOutlet UIView *cameraPreview;
//@property (nonatomic, weak) IBOutlet UIImageView *imagePreview;
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDevice *captureDevice;
@property (nonatomic) AVCaptureDeviceInput *captureInput;
@property (nonatomic) AVCaptureStillImageOutput *captureOutput;
@property (nonatomic) AVCaptureConnection *captureConnection;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak) IBOutlet UISlider *slider;
@property (nonatomic, weak) IBOutlet UIButton *zoomButton;
@property (nonatomic, weak) IBOutlet UILabel *zoomValue;
@property (nonatomic, weak) IBOutlet UIButton *focusButton;
@property (nonatomic, weak) IBOutlet UILabel *focusValue;
@property (nonatomic) BOOL zoomMode;
@property (nonatomic) MyFocusMode focusMode;

@end

@implementation TakePictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
	
	if ([DeviceSystemVersion sharedInstance].major <= 7) {
		self.focusButton.hidden = YES;
		self.focusValue.hidden = YES;
	}
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self setupCapture];
	
	self.slider.hidden = YES;
	self.zoomValue.text = @"x1.0";
	self.focusValue.text = @"自動";
	self.zoomMode = NO;
	self.focusMode = MyFocusModeAuto;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self teardownCapture];
}

- (void)viewDidLayoutSubviews {
	//NSLog(@"viewDidLayoutSubviews");
	[super viewDidLayoutSubviews];
	[self setCapturePreviewLayer:self.previewLayer];
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
	[self dismissViewControllerAnimated:YES completion:nil];
	[self teardownCapture];
}

- (IBAction)tapTakePictButton:(id)sender {
	[self takePicture];
}

- (void) teardownCapture {
	if (self.captureSession == nil) {
		return;
	}
	[self.captureSession stopRunning];
	[self.captureSession removeInput:self.captureInput];
	[self.captureSession removeOutput:self.captureOutput];
	[self.previewLayer removeFromSuperlayer];
	self.captureSession = nil;
	self.captureDevice = nil;
	self.captureInput = nil;
	self.captureOutput = nil;
	self.captureConnection = nil;
	self.previewLayer = nil;
}

- (void)setupCapture {
	NSError *error = nil;
	
	CameraManager *camManager = [CameraManager sharedManager];
	Camera *cam = camManager.backCamera;
	AVCaptureDevice *captureDevice = cam.captureDevice;
	if (captureDevice == nil || ![captureDevice hasMediaType:AVMediaTypeVideo]) {
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
	switch (captureDevice.focusMode) {
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
	if ([captureDevice hasFlash] ) {
		if ([captureDevice lockForConfiguration:&error]) {
			[captureDevice setFlashMode:AVCaptureFlashModeAuto];
			[captureDevice unlockForConfiguration];
		}
	}
	
	// フラッシュモードを確認
	switch (captureDevice.flashMode) {
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
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
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
	
	self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	
	[session startRunning];
	
	self.captureSession = session;
	self.captureDevice = captureDevice;
	self.captureInput = input;
	self.captureOutput = output;
	self.captureConnection = connection;
}

- (void) takePicture {
	
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

- (void)setCapturePreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
	
	previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
	previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	//previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	previewLayer.frame = self.cameraPreview.bounds;
	
	//NSLog(NSStringFromCGRect(self.cameraPreview.bounds));
	
	[self.cameraPreview.layer setMasksToBounds:YES];
	
	// 枠を付ける
	//[self.cameraPreview.layer setBorderWidth:1.0f];
	//[self.cameraPreview.layer setBorderColor:[[UIColor blueColor] CGColor]];
	
	// 回転させる
	int displayRotation = [CameraManager displayRotationWithViewController:self];
	if (previewLayer.connection.supportsVideoOrientation) {
		previewLayer.connection.videoOrientation = [CameraManager appropriateVideoOrientationWithDisplayRotation:displayRotation];
	}
	
	[self.cameraPreview.layer addSublayer:previewLayer];
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
				self.focusValue.text = @"自動";
				
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
				
				self.focusValue.text = @"手動";
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
				
				self.focusValue.text = @"固定";
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

- (void)zoomValueChanged:(UISlider *)slider {
	NSLog(@"zoomValueChanged %f", slider.value);
	NSError *error;
	
	if ([self.class isVideoZoomSupported]) {
		if ([self.captureDevice lockForConfiguration:&error]) {
			[self.captureDevice setVideoZoomFactor:slider.value];
			[self.captureDevice unlockForConfiguration];
			self.zoomValue.text = [NSString stringWithFormat:@"%0.1f", slider.value];
		}
	}
}

- (void)focusValueChanged:(UISlider *)slider {
	NSLog(@"focusValueChanged %f", slider.value);
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
