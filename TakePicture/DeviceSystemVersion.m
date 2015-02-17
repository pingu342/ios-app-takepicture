//
//  DeviceSystemVersion.m
//  TakePicture
//
//  Created by Masakiyo on 2015/02/17.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "DeviceSystemVersion.h"
#import <UIKit/UIKit.h>

@implementation DeviceSystemVersion

static DeviceSystemVersion *sharedInstance_ = nil;

+ (DeviceSystemVersion *)sharedInstance {
	@synchronized(self){
		if (!sharedInstance_) {
			[[self alloc] init]; // ここでは代入していない
		}
	}
	return sharedInstance_;
}

- (instancetype)init {
	self = [super init];
	if (self != nil) {
		NSString *osversion = [UIDevice currentDevice].systemVersion;
		NSArray *a = [osversion componentsSeparatedByString:@"."];
		_major = [[a objectAtIndex:0] integerValue];
		_minor = [[a objectAtIndex:1] integerValue];
	}
	return self;
}

+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		if (sharedInstance_ == nil) {
			sharedInstance_ = [super allocWithZone:zone];
			return sharedInstance_;  // 最初の割り当てで代入し、返す
		}
	}
	return nil; // 以降の割り当てではnilを返すようにする
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

@end
