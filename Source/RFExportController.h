//
//  RFExportController.h
//  Micro.blog
//
//  Created by Manton Reece on 7/4/21.
//  Copyright © 2021 Micro.blog. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFExportController : NSWindowController

@property (strong, nonatomic) IBOutlet NSTextField* statusField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressBar;
@property (strong, nonatomic) IBOutlet NSButton* cancelButton;

@property (strong) NSString* exportFolder;

@end

NS_ASSUME_NONNULL_END
