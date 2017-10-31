//
//  NSImage+Extras.h
//  Snippets
//
//  Created by Manton Reece on 10/29/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Extras)

- (NSImage *) rf_scaleToWidth:(CGFloat)maxWidth;
- (NSImage *) rf_scaleToSize:(NSSize)newSize;

@end