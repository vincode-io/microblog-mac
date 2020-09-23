//
//  RFPhotoCell.h
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFPhotoCell : NSCollectionViewItem

@property (strong, nonatomic) IBOutlet NSImageView* thumbnailImageView;
@property (strong, nonatomic) IBOutlet NSView* selectionOverlayView;
@property (strong, nonatomic) IBOutlet NSImageView* iconView;

@end
