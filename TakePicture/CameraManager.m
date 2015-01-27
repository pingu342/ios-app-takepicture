//
//  CameraManager.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CameraManager.h"

@implementation CameraManager

static CameraManager *sharedData_ = nil;

+ (CameraManager *)sharedManager
{
	@synchronized(self){
		if (!sharedData_) {
			[[self alloc] init]; // ここでは代入していない
		}
	}
	return sharedData_;
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		
		// カメラのリストを作成
		int cameraId = 0;
		
		NSMutableArray *list = [[NSMutableArray alloc] init];
		
		_frontCamera = nil;
		_backCamera = nil;
		
		NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
		for (AVCaptureDevice *d in devices) {
			Camera *cam = [[Camera alloc] initWithId:cameraId captureDevice:d];
			[list addObject:cam];
			
			if (d.position == AVCaptureDevicePositionFront && _frontCamera == nil) {
				_frontCamera = cam;
			} else if (d.position == AVCaptureDevicePositionBack && _backCamera == nil) {
				_backCamera = cam;
			}
			
			cameraId++;
		}
		
		_cameras = [[NSArray alloc] initWithArray:list];
	}
	return self;
}

+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		if (sharedData_ == nil) {
			sharedData_ = [super allocWithZone:zone];
			return sharedData_;  // 最初の割り当てで代入し、返す
		}
	}
	return nil; // 以降の割り当てではnilを返すようにする
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

/**
 * @public
 *
 * @brief CAMCameraインスタンスを取得する
 *
 * @param[in] cameraId カメラID
 *
 * @return CAMCameraインスタンス
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
- (Camera *)cameraWithId:(int)cameraId
{
	for (Camera *cam in self.cameras) {
		if (cam.cameraId == cameraId) {
			return cam;
		}
	}
	return nil;
}

/**
 * @public
 *
 * @brief 画面の回転角度(displayRotation)を向き(interfaceOrientation)に変換する
 *
 * @param[in] displayRotation 画面の回転角度。0 / 90 / 180 / 270のいずれか。
 *
 * @return 画面の向き(interfaceOrientation)。
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
+ (UIInterfaceOrientation)interfaceOrientationWithDisplayRotation:(int)displayRotation
{
	UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationPortrait;
	displayRotation = ((displayRotation / 90) * 90) % 360;
	if (displayRotation == 0) {
		/* 画面はPortraitで、ホームボタンは下 */
		interfaceOrientation = UIInterfaceOrientationPortrait;
	} else if (displayRotation == 90) {
		/* 画面はLandscapeで、ホームボタンは右 */
		interfaceOrientation = UIInterfaceOrientationLandscapeRight;
	} else if (displayRotation == 180) {
		/* 画面はPortraitで、ホームボタンは上 */
		interfaceOrientation = UIInterfaceOrientationPortraitUpsideDown;
	} else if (displayRotation == 270) {
		/* 画面はLandscapeで、ホームボタンは左 */
		interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
	}
	return interfaceOrientation;
}

/**
 * @public
 *
 * @brief 画面の向き(interfaceOrientation)を回転角度(displayRotation)に変換する
 *
 * @param[in] interfaceOrientation UIInterfaceOrientationPortrait / UIInterfaceOrientationLandscapeRight / UIInterfaceOrientationPortraitUpsideDown / UIInterfaceOrientationLandscapeLeft
 *
 * @return 画面の回転角度(displayRotation)。Portrait(ホームボタンは下)の向きからdisplayRotationだけ時計方向に画面を回転させるとinterfaceOrientationの画面の向きと一致。
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
+ (int)displayRotationWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	int displayRotation = 0;
	switch (interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			/* 画面はPortraitで、ホームボタンは下 */
			displayRotation = 0;
			break;
			
		case UIInterfaceOrientationLandscapeRight:
			/* 画面はLandscapeで、ホームボタンは右 */
			displayRotation = 90;
			break;
			
		case UIInterfaceOrientationPortraitUpsideDown:
			/* 画面はPortraitで、ホームボタンは上 */
			displayRotation = 180;
			break;
			
		case UIInterfaceOrientationLandscapeLeft:
			/* 画面はLandscapeで、ホームボタンは左 */
			displayRotation = 270;
			break;
			
		default:
			break;
	}
	return displayRotation;
}

/**
 * @public
 *
 * @brief ビューコントローラの画面の回転角度(displayRotation)を取得する
 *
 * @param[in] viewController ビューコントローラ
 *
 * @return 画面の回転角度(displayRotation)。
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
+ (int)displayRotationWithViewController:(UIViewController *)viewController
{
	return [CameraManager displayRotationWithInterfaceOrientation:viewController.interfaceOrientation];
}

/**
 * @public
 *
 * @brief 画面の回転角度(displayRotation)に対して適切なカメラキャプチャ映像の向き(videoOrientation)を取得する
 *
 * カメラキャプチャ映像(AVCaptureVideoDataOutputから出力されるサンプルバッファ)の天地と、実世界の天地を一致させるために、AVCaptureConnection#videoOrientationに設定すべき値を返す。
 *
 * @param[in] displayRotation 画面の向き。Portrait（ホームボタン下）を0、Landscape（ホームボタン左）を90、Portrait（ホームボタン上）を180、Landscape（ホームボタン右）を270とする。
 *
 * @return 適切なカメラキャプチャ映像の向き（AVCaptureConnection#videoOrientationに設定すべき値）
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
+ (AVCaptureVideoOrientation)appropriateVideoOrientationWithDisplayRotation:(int)displayRotation
{
	UIInterfaceOrientation interfaceOrientation = [CameraManager interfaceOrientationWithDisplayRotation:displayRotation];
	AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
	switch (interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			videoOrientation = AVCaptureVideoOrientationPortrait;
			break;
			
		case UIInterfaceOrientationLandscapeLeft:
			videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
			break;
			
		case UIInterfaceOrientationPortraitUpsideDown:
			videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
			break;
			
		case UIInterfaceOrientationLandscapeRight:
			videoOrientation = AVCaptureVideoOrientationLandscapeRight;
			break;
			
		default:
			break;
	}
	return videoOrientation;
}

@end
