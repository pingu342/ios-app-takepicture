//
//  CameraManager.h
//  TakePicture
//
//  Created by Masakiyo on 2015/01/27.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Camera.h"

@interface CameraManager : NSObject

@property (nonatomic, readonly) Camera *frontCamera;
@property (nonatomic, readonly) Camera *backCamera;
@property (nonatomic, readonly) NSArray *cameras;

+ (CameraManager *)sharedManager;
- (Camera *)cameraWithId:(int)cameraId;
+ (UIInterfaceOrientation)interfaceOrientationWithDisplayRotation:(int)displayRotation;
+ (int)displayRotationWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
+ (int)displayRotationWithViewController:(UIViewController *)viewController;
+ (AVCaptureVideoOrientation)appropriateVideoOrientationWithDisplayRotation:(int)displayRotation;

@end
