//
//  Camera.h
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface Camera : NSObject

@property (nonatomic, readonly) int cameraId;
@property (nonatomic, readonly) int orientation;
@property (nonatomic, readonly) AVCaptureDevice *captureDevice;
@property (nonatomic, readonly, getter = isFrontCamera) BOOL frontCamera;
@property (nonatomic, readonly) AVCaptureVideoOrientation videoOrientation;

- (id)initWithId:(int)cameraId captureDevice:(AVCaptureDevice *)captureDevice;
- (AVCaptureVideoOrientation)videoOrientationWithRotation:(int)rotation;

@end
