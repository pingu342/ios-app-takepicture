//
//  ViewController.m
//  TakePicture
//
//  Created by Masakiyo on 2015/01/26.
//  Copyright (c) 2015年 saka. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (BOOL) startCameraControllerFromViewController: (UIViewController*) controller
								   usingDelegate: (id <UIImagePickerControllerDelegate, UINavigationControllerDelegate>) delegate {
	
	if (([UIImagePickerController isSourceTypeAvailable:
		  UIImagePickerControllerSourceTypeCamera] == NO)
		|| (delegate == nil)
		|| (controller == nil))
		return NO;
	
	UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
	cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
 // ユーザが写真またはムービーのキャプチャを選択するためのコントロールを表示する
 // （写真とムービーの両方が利用可能な場合）
	//cameraUI.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType: UIImagePickerControllerSourceTypeCamera];	//指定されたSourceTypeで利用可能な全てのMediaTypeをImagePickerControllerに指定する（写真とムービーが利用可能）
	cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];	//写真のみ指定する
 // 写真の移動と拡大縮小、または
 // ムービーのトリミングのためのコントロールを隠す。代わりにコントロールを表示するには、YESを使用する。
	cameraUI.allowsEditing = NO;
	cameraUI.delegate = delegate;
	[controller presentViewController: cameraUI animated: YES completion:nil];
	
	return YES;
}

// 「キャンセル(Cancel)」をタップしたユーザへの応答.
- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

// 新規にキャプチャした写真やムービーを受理したユーザへの応答
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info {
	NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
	UIImage *originalImage, *editedImage, *imageToSave;
	// 静止画像のキャプチャを処理する
	if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
		editedImage = (UIImage *) [info objectForKey: UIImagePickerControllerEditedImage];
		originalImage = (UIImage *) [info objectForKey: UIImagePickerControllerOriginalImage];
		if (editedImage) {
			imageToSave = editedImage;
		} else {
			imageToSave = originalImage;
		}
		
		// （オリジナルまたは編集後の）新規画像を「カメラロール(Camera Roll)」に保存する
		UIImageWriteToSavedPhotosAlbum (imageToSave, nil, nil , nil);
	}
	// ムービーのキャプチャを処理する
	if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
		NSURL *mediaUrl = [info objectForKey: UIImagePickerControllerMediaURL];
		NSString *moviePath = [mediaUrl path];
		if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath)) {
			UISaveVideoAtPathToSavedPhotosAlbum(moviePath, nil, nil, nil);
		}
	}
	[[picker parentViewController] dismissViewControllerAnimated: YES completion:nil];
}

- (IBAction)tapButton:(id)sender {
	[self startCameraControllerFromViewController:self usingDelegate:self];
}

@end
