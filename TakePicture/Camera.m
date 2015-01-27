//
//  Camera.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "Camera.h"

@interface Camera()

@property (nonatomic) int indexOfVideoOrientMap;
@property (nonatomic) const AVCaptureVideoOrientation *videoOrientationMap;

@end

@implementation Camera

static const AVCaptureVideoOrientation frontCameraVideoOrientationMap[] = {
	/* Portrait(ホームボタンは下)を基準として、
	 * そこから時計とは逆方向に90度ずつ回転させていく。
	 */
	AVCaptureVideoOrientationPortrait,
	AVCaptureVideoOrientationLandscapeRight,
	AVCaptureVideoOrientationPortraitUpsideDown,
	AVCaptureVideoOrientationLandscapeLeft
};

static const AVCaptureVideoOrientation backCameraVideoOrientationMap[] = {
	/* Portrait(ホームボタンは下)を基準として、
	 * そこから時計方向に90度ずつ回転させていく。
	 */
	AVCaptureVideoOrientationPortrait,
	AVCaptureVideoOrientationLandscapeLeft,
	AVCaptureVideoOrientationPortraitUpsideDown,
	AVCaptureVideoOrientationLandscapeRight
};

- (id)initWithId:(int)cameraId captureDevice:(AVCaptureDevice *)captureDevice
{
	self = [super init];
	if (self != nil) {
		_cameraId = cameraId;
		_captureDevice = captureDevice;
		_frontCamera = (self.captureDevice.position == AVCaptureDevicePositionFront);
		/* front facing camera is mounted AVCaptureVideoOrientationLandscapeLeft,
		 * and the back-facing camera is mounted AVCaptureVideoOrientationLandscapeRight.
		 */
		if (_frontCamera) {
			/* 前面カメラから得られる映像は、デバイスの向きがLandscape(ホームボタンは左)の時、
			 * 映像の天地と実世界の天地が一致する。
			 */
			_videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
			_videoOrientationMap = frontCameraVideoOrientationMap;
			_indexOfVideoOrientMap = 3;
			
			/* デバイスの向きがPortrait(ホームボタンは下)の状態で、実世界の天地と一致した映像を得るには、
			 * カメラキャプチャ映像を時計方向に90度だけ回転する必要がある
			 */
			_orientation = 90;
		} else {
			/* 背面カメラから得られる映像は、デバイスの向きがLandscape(ホームボタンは右)の時、
			 * 映像の天地と実世界の天地が一致する。
			 */
			_videoOrientation = AVCaptureVideoOrientationLandscapeRight;
			_videoOrientationMap = backCameraVideoOrientationMap;
			_indexOfVideoOrientMap = 3;
			
			/* デバイスの向きがPortrait(ホームボタンは下)の状態で、実世界の天地と一致した映像を得るには、
			 * カメラキャプチャ映像を時計方向に90度だけ回転する必要がある
			 */
			_orientation = 90;
		}
	}
	return self;
}

/**
 * @public
 *
 * @brief カメラキャプチャ映像の回転角度を向き(videoOrientation)に変換する
 *
 * カメラキャプチャ映像を時計方向にrotationだけ回転させるためにAVCaptureConnection#videoOrientationに指定すべき値を返す。
 *
 * @param[in] rotation 時計方向の回転角度
 *
 * @return カメラキャプチャ映像の向き（AVCaptureConnection#videoOrientationに設定すべき値）
 *
 * @note
 *
 * @attention
 *
 * @date
 *
 */
- (AVCaptureVideoOrientation)videoOrientationWithRotation:(int)rotation
{
	int tmp;
	if (rotation < 0) {
		rotation = 0;
	}
	rotation %= 360;
	tmp = (self.indexOfVideoOrientMap + (rotation / 90)) % 4;
	return self.videoOrientationMap[tmp];
}

@end
