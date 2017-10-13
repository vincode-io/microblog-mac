//
//  RFPreferencesController.h
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFPreferencesController : NSWindowController <NSTextFieldDelegate>

@property (strong, nonatomic) IBOutlet NSTextField* messageField;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* messageTopConstraint;
@property (strong, nonatomic) IBOutlet NSButton* publishHostedBlog;
@property (strong, nonatomic) IBOutlet NSButton* publishWordPressBlog;
@property (strong, nonatomic) IBOutlet NSButton* returnButton;
@property (strong, nonatomic) IBOutlet NSTextField* websiteField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressSpinner;

- (void) showMessage:(NSString *)message;

@end
