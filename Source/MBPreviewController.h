//
//  MBPreviewController.h
//  Micro.blog
//
//  Created by Manton Reece on 1/8/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MBPreviewController : NSWindowController

@property (strong, nonatomic) IBOutlet WKWebView* webview;

@property (strong, nonatomic) NSString* html;

@end

NS_ASSUME_NONNULL_END
