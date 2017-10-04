//
//  RFTimelineController.m
//  Snippets for Mac
//
//  Created by Manton Reece on 9/21/15.
//  Copyright © 2015 Riverfold Software. All rights reserved.
//

#import "RFTimelineController.h"

#import "RFMenuCell.h"
#import "RFOptionsController.h"

static CGFloat const kDefaultSplitViewPosition = 170.0;

@implementation RFTimelineController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Timeline"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupTable];
	[self setupSplitView];
	[self setupWebView];
}

//- (void) setupTextView
//{
//	self.textView.font = [NSFont systemFontOfSize:15 weight:NSFontWeightLight];
//	self.textView.backgroundColor = [NSColor colorWithCalibratedWhite:0.973 alpha:1.000];
//}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"MenuCell" bundle:nil] forIdentifier:@"MenuCell"];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
}

- (void) setupSplitView
{
	[self.splitView setPosition:kDefaultSplitViewPosition ofDividerAtIndex:0];
	self.splitView.delegate = self;
}

- (void) setupWebView
{
	[self showTimeline:nil];
}

- (IBAction) showTimeline:(id)sender
{
	NSString* token = [[NSUserDefaults standardUserDefaults] objectForKey:@"SnippetsToken"];
	CGFloat pane_width = self.webView.bounds.size.width;
	int timezone_minutes = 0;
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/signin?token=%@&width=%f&minutes=%d&desktop=1", token, pane_width, timezone_minutes];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];
	
	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
}

- (IBAction) showMentions:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/mentions"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
}

- (IBAction) showFavorites:(id)sender
{
	NSString* url = [NSString stringWithFormat:@"http://micro.blog/hybrid/favorites"];
	NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
	[[self.webView mainFrame] loadRequest:request];

	[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:2] byExtendingSelection:NO];

	[self.optionsPopover performClose:nil];
}

- (IBAction) signOut:(id)sender
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SnippetsToken"];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"RFSignOut" object:self];
}

- (void) showOptionsMenuWithPostID:(NSString *)postID
{
	[self.optionsPopover performClose:nil];

	RFOptionsController* options_controller = [[RFOptionsController alloc] init];
	self.optionsPopover = [[NSPopover alloc] init];
	self.optionsPopover.contentViewController = options_controller;

	NSRect r = [self rectOfPostID:postID];
	[self.optionsPopover showRelativeToRect:r ofView:self.webView preferredEdge:NSRectEdgeMinY];
}

- (NSRect) rectOfPostID:(NSString *)postID
{
	NSString* top_js = [NSString stringWithFormat:@"$('#post_%@').position().top;", postID];
	NSString* height_js = [NSString stringWithFormat:@"$('#post_%@').height();", postID];
	
	NSString* top_s = [self.webView stringByEvaluatingJavaScriptFromString:top_js];
	NSString* height_s = [self.webView stringByEvaluatingJavaScriptFromString:height_js];

	CGFloat top_f = [top_s floatValue];
	top_f -= 0; // self.webView.scrollView.contentOffset.y;
	
	// adjust to full cell width
	CGFloat left_f = 0.0;
	CGFloat width_f = self.webView.bounds.size.width;
	
	return NSMakeRect (left_f, top_f, width_f, [height_s floatValue]);
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return 3;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	RFMenuCell* cell = [tableView makeViewWithIdentifier:@"MenuCell" owner:self];
	
	if (row == 0) {
		cell.titleField.stringValue = @"Timeline";
	}
	else if (row == 1) {
		cell.titleField.stringValue = @"Mentions";
	}
	else if (row == 2) {
		cell.titleField.stringValue = @"Favorites";
	}

	return cell;
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	if (row == 0) {
		[self showTimeline:nil];
	}
	else if (row == 1) {
		[self showMentions:nil];
	}
	else if (row == 2) {
		[self showFavorites:nil];
	}

	return YES;
}

#pragma mark -

- (CGFloat) splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

- (CGFloat) splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return kDefaultSplitViewPosition;
}

@end
