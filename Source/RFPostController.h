//
//  RFPostController.h
//  Snippets
//
//  Created by Manton Reece on 10/4/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RFHighlightingTextStorage;
@class RFPhotoAltController;
@class RFPost;
@class MBDateController;

@interface RFPostController : NSViewController <NSTextViewDelegate, NSTextStorageDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource, NSDraggingDestination, NSPopoverDelegate>

@property (strong, nonatomic) IBOutlet NSTextField* titleField;
@property (strong, nonatomic) IBOutlet NSTextView* textView;
@property (strong, nonatomic) IBOutlet NSTextField* remainingField;
@property (strong, nonatomic) IBOutlet NSTextField* blognameField;
@property (strong, nonatomic) IBOutlet NSButton* photoButton;
@property (strong, nonatomic) IBOutlet NSCollectionView* photosCollectionView;
@property (strong, nonatomic) IBOutlet NSCollectionView* categoriesCollectionView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* textTopConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* photosHeightConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* categoriesHeightConstraint;

@property (assign, nonatomic) BOOL isSent;
@property (assign, nonatomic) BOOL isReply;
@property (assign, nonatomic) BOOL isDraft;
@property (assign, nonatomic) BOOL isShowingTitle;
@property (assign, nonatomic) BOOL isShowingCategories;
@property (strong, nonatomic) RFPost* editingPost;
@property (strong, nonatomic) NSString* replyPostID;
@property (strong, nonatomic) NSString* replyUsername;
@property (strong, nonatomic) NSString* initialText;
@property (strong, nonatomic) NSString* channel;
@property (strong, nonatomic) NSArray* attachedPhotos; // RFPhoto
@property (strong, nonatomic) NSArray* queuedPhotos; // RFPhoto
@property (strong, nonatomic) NSArray* categories; // NSString
@property (strong, nonatomic) RFHighlightingTextStorage* textStorage;
@property (strong, nonatomic) NSUndoManager* textUndoManager;
@property (strong, nonatomic) NSPopover* blogsMenuPopover;
@property (strong, nonatomic) RFPhotoAltController* altController;
@property (strong, nonatomic) NSArray* destinations; // NSDictionary
@property (strong, nonatomic) NSDate* postedAt;

- (id) initWithPost:(RFPost *)post;
- (id) initWithChannel:(NSString *)channel;
- (id) initWithText:(NSString *)text;
- (id) initWithPostID:(NSString *)postID username:(NSString *)username;
- (void) finishClose;
- (IBAction) sendPost:(id)sender;
- (IBAction) save:(id)sender;
- (NSString *) postButtonTitle;

- (NSString *) currentTitle;
- (NSString *) currentText;

@end
