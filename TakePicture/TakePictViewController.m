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

#import <ImageIO/ImageIO.h>

@interface TakePictViewController ()

@property (nonatomic, weak) IBOutlet UIView *cameraPreview;
//@property (nonatomic, weak) IBOutlet UIImageView *imagePreview;
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDeviceInput *captureInput;
@property (nonatomic) AVCaptureStillImageOutput *captureOutput;
@property (nonatomic) AVCaptureConnection *captureConnection;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation TakePictViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self setupCapture];
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
	
	NSString *sessionPreset = AVCaptureSessionPreset640x480;
	if ([session canSetSessionPreset:sessionPreset]) {
		[session setSessionPreset:sessionPreset];
	} else {
		NSLog(@"session preset error");
		return;
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
	
	AVCaptureStillImageOutput *output = [[AVCaptureStillImageOutput alloc] init];
	NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
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
		 }
		 
		 // 入力された画像データからJPEGフォーマットとしてデータを取得
		 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
		 
		 // JPEGデータからUIImageを作成
		 UIImage *image = [[UIImage alloc] initWithData:imageData];
		 //[self.imagePreview setImage:image];
		 //[self.imagePreview setContentMode:UIViewContentModeScaleAspectFit];
		 
		 PreviewPictViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PreviewPictViewController"];
		 viewController.image = image;
		 [self presentViewController:viewController animated:YES completion:nil];
		 
		 NSLog(@"completed");
		 
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

- (BOOL)prefersStatusBarHidden {
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

@end
