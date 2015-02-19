//
//  DeviceSystemVersion.h
//  TakePicture
//
//  Created by Masakiyo on 2015/02/17.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeviceSystemVersion : NSObject

@property (nonatomic, readonly) NSInteger major;
@property (nonatomic, readonly) NSInteger minor;

+ (DeviceSystemVersion *)sharedInstance;

@end
