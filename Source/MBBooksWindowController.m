//
//  MBBooksWindowController.m
//  Micro.blog
//
//  Created by Manton Reece on 5/19/22.
//  Copyright © 2022 Micro.blog. All rights reserved.
//

#import "MBBooksWindowController.h"

#import "RFBookshelf.h"
#import "MBBook.h"
#import "MBBookCell.h"
#import "RFClient.h"
#import "RFMacros.h"
#import "RFConstants.h"
#import "NSString+Extras.h"

@implementation MBBooksWindowController

- (instancetype) initWithBookshelf:(RFBookshelf *)bookshelf
{
	self = [super initWithWindowNibName:@"BooksWindow"];
	if (self) {
		self.bookshelf = bookshelf;
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	
	[self setupTitle];
	[self setupTable];
	[self setupNotifications];
	[self setupBooksCount];
	[self setupBrowser];
	
	[self fetchBooks];
	[self fetchBookshelves];
}

- (void) setupTitle
{
	self.window.title = self.bookshelf.title;
}

- (void) setupTable
{
	[self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"BookCell" bundle:nil] forIdentifier:@"BookCell"];
	[self.tableView setTarget:self];
	self.window.initialFirstResponder = self.tableView;
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addBookNotification:) name:kAddBookNotification object:nil];
}

- (void) setupBooksCount
{
	if ([self isSearch]) {
		self.booksCountField.hidden = YES;
	}
	else {
		NSString* s;
		if (self.allBooks.count == 0) {
			s = @"";
		}
		else if (self.allBooks.count == 1) {
			s = @"1 book";
		}
		else {
			s = [NSString stringWithFormat:@"%lu books", (unsigned long)self.allBooks.count];
		}
		self.booksCountField.stringValue = s;
		self.booksCountField.hidden = NO;
	}
}

- (void) setupBrowser
{
	NSString* browser_s = @"Open in Browser";
	
	NSURL* example_url = [NSURL URLWithString:@"https://micro.blog/"];
	NSURL* app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:example_url];
	if ([app_url.lastPathComponent containsString:@"Chrome"]) {
		browser_s = @"Open in Chrome";
	}
	else if ([app_url.lastPathComponent containsString:@"Firefox"]) {
		browser_s = @"Open in Firefox";
	}
	else if ([app_url.lastPathComponent containsString:@"Safari"]) {
		browser_s = @"Open in Safari";
	}

	self.browserMenuItem.title = browser_s;
}

- (void) setupBookshelvesMenu
{
	for (RFBookshelf* shelf in self.bookshelves) {
		NSMenuItem* new_item = [self.contextMenu addItemWithTitle:shelf.title action:@selector(assignToBookshelf:) keyEquivalent:@""];
		new_item.representedObject = shelf;
	}
}

#pragma mark -

- (void) fetchBooks
{
	self.allBooks = @[];
	self.currentBooks = @[];
	
	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:[NSString stringWithFormat:@"/books/bookshelves/%@", self.bookshelf.bookshelfID]];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_books = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				MBBook* b = [[MBBook alloc] init];
				b.bookID = [item objectForKey:@"id"];
				b.title = [item objectForKey:@"title"];
				b.coverURL = [item objectForKey:@"image"];
				b.isbn = [[item objectForKey:@"_microblog"] objectForKey:@"isbn"];

				NSMutableArray* author_names = [NSMutableArray array];
				for (NSDictionary* info in [item objectForKey:@"authors"]) {
					[author_names addObject:[info objectForKey:@"name"]];
				}
				b.authors = author_names;

				[new_books addObject:b];
			}
			
			RFDispatchMainAsync (^{
				self.allBooks = new_books;
				self.currentBooks = new_books;
				self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
				[self.tableView reloadData];
				[self setupBooksCount];
			});
		}
	}];
}

- (void) fetchBooksForSearch:(NSString *)search
{
	self.booksCountField.hidden = YES;
	[self.progressSpinner startAnimation:nil];

	NSString* url = @"https://www.googleapis.com/books/v1/volumes";
	
	NSDictionary* args = @{
		@"q": search
	};
	
	UUHttpRequest* request = [UUHttpRequest getRequest:url queryArguments:args];
	[UUHttpSession executeRequest:request completionHandler:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_books = [NSMutableArray array];
			
			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				NSDictionary* volume_info = [item objectForKey:@"volumeInfo"];

				NSString* title = [volume_info objectForKey:@"title"];
				NSArray* authors = [volume_info objectForKey:@"authors"];
				if (authors.count == 0) {
					authors = @[];
				}
				NSString* description = [volume_info objectForKey:@"description"];

				NSString* cover_url = @"";
				if ([volume_info objectForKey:@"imageLinks"] != nil) {
					cover_url = [[volume_info objectForKey:@"imageLinks"] objectForKey:@"smallThumbnail"];
					if ([cover_url containsString:@"http://"]) {
						cover_url = [cover_url stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
					}
				}

				NSString* best_isbn = @"";
				NSMutableArray* isbns = [volume_info objectForKey:@"industryIdentifiers"];
				if (isbns != nil) {
					for (NSDictionary* isbn in isbns) {
						if ([[isbn objectForKey:@"type"] isEqualToString:@"ISBN_13"]) {
							best_isbn = [isbn objectForKey:@"identifier"];
							break;
						}
						else if ([[isbn objectForKey:@"type"] isEqualToString:@"ISBN_10"]) {
							best_isbn = [isbn objectForKey:@"identifier"];
						}
					}
				}

				MBBook* b = [[MBBook alloc] init];
				b.title = title;
				b.authors = authors;
				b.coverURL = cover_url;
				b.isbn = best_isbn;
				b.bookDescription = description;

				[new_books addObject:b];
			}

			RFDispatchMainAsync (^{
				self.currentBooks = new_books;
				[self.progressSpinner stopAnimation:nil];
				self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
				[self.tableView reloadData];
			});
		}
	}];
}

- (void) fetchBookshelves
{
	self.bookshelves = @[];

	NSDictionary* args = @{};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/books/bookshelves"];
	[client getWithQueryArguments:args completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			NSMutableArray* new_bookshelves = [NSMutableArray array];

			NSArray* items = [response.parsedResponse objectForKey:@"items"];
			for (NSDictionary* item in items) {
				RFBookshelf* shelf = [[RFBookshelf alloc] init];
				shelf.bookshelfID = [item objectForKey:@"id"];
				shelf.title = [item objectForKey:@"title"];
				shelf.booksCount = [[item objectForKey:@"_microblog"] objectForKey:@"books_count"];

				[new_bookshelves addObject:shelf];
			}
			
			RFDispatchMainAsync (^{
				self.bookshelves = new_bookshelves;
				[self setupBookshelvesMenu];
			});
		}
	}];
}

- (void) addBook:(MBBook *)book toBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* params = @{
		@"title": book.title,
		@"author": [book.authors firstObject],
		@"isbn": book.isbn,
		@"cover_url": book.coverURL,
		@"bookshelf_id": bookshelf.bookshelfID
	};
	
	RFClient* client = [[RFClient alloc] initWithPath:@"/books"];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self.searchField setStringValue:@""];
				[self fetchBooks];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasAddedNotification object:self];
			});
		}
	}];
}

- (void) removeBook:(MBBook *)book fromBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	RFClient* client = [[RFClient alloc] initWithFormat:@"/books/bookshelves/%@/remove/%@", bookshelf.bookshelfID, book.bookID];
	[client deleteWithObject:nil completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self fetchBooks];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasRemovedNotification object:self];
			});
		}
	}];
}

- (void) assignBook:(MBBook *)book toBookshelf:(RFBookshelf *)bookshelf
{
	[self.progressSpinner startAnimation:nil];

	NSDictionary* params = @{
		@"book_id": book.bookID
	};
	
	RFClient* client = [[RFClient alloc] initWithFormat:@"/books/bookshelves/%@/assign", bookshelf.bookshelfID];
	[client postWithParams:params completion:^(UUHttpResponse* response) {
		if ([response.parsedResponse isKindOfClass:[NSDictionary class]]) {
			RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];
				[self fetchBooks];

				[[NSNotificationCenter defaultCenter] postNotificationName:kBookWasAddedNotification object:self];
			});
		}
	}];
}

- (BOOL) isSearch
{
	return [[self.searchField stringValue] length] > 0;
}

- (IBAction) search:(id)sender
{
	NSString* s = [sender stringValue];
	if (s.length == 0) {
		self.currentBooks = self.allBooks;
		self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
		[self.tableView reloadData];
		[self setupBooksCount];
	}
	else if (s.length >= 3) {
		[self fetchBooksForSearch:s];
	}
}

- (void) addBookNotification:(NSNotification *)notification
{
	MBBook* b = [[notification userInfo] objectForKey:kAddBookKey];
	RFBookshelf* shelf = [[notification userInfo] objectForKey:kAddBookBookshelfKey];
	if ([shelf.bookshelfID isEqualToNumber:self.bookshelf.bookshelfID]) {
		[self addBook:b toBookshelf:self.bookshelf];
	}
}

- (IBAction) delete:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		
		NSAlert* sheet = [[NSAlert alloc] init];
		sheet.messageText = [NSString stringWithFormat:@"Remove \"%@\"?", b.title];
		sheet.informativeText = [NSString stringWithFormat:@"This book will be removed from the bookshelf \"%@\".", self.bookshelf.title];
		[sheet addButtonWithTitle:@"Remove"];
		[sheet addButtonWithTitle:@"Cancel"];
		[sheet beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == 1000) {
				[self removeBook:b fromBookshelf:self.bookshelf];
			}
		}];
	}
}

- (IBAction) startNewPost:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		
		NSString* link = [b microblogURL];
		NSString* s;
		if (b.authors.count > 0) {
			s = [NSString stringWithFormat:@"%@: [%@](%@) by %@ 📚", self.bookshelf.title, b.title, link, [b.authors firstObject]];
		}
		else {
			s = [NSString stringWithFormat:@"%@: [%@](%@) 📚", self.bookshelf.title, b.title, link];
		}
				
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"microblog://post?text=%@", [s rf_urlEncoded]]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) openInBrowser:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		NSURL* url = [NSURL URLWithString:[b microblogURL]];
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
}

- (IBAction) copyLink:(id)sender
{
	NSInteger row = self.tableView.selectedRow;
	if (row >= 0) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		NSPasteboard* pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
		[pb setString:[b microblogURL] forType:NSPasteboardTypeString];
	}
}

- (IBAction) assignToBookshelf:(NSMenuItem *)sender
{
	RFBookshelf* shelf = sender.representedObject;
	if (shelf) {
		NSInteger row = self.tableView.selectedRow;
		if (row >= 0) {
			MBBook* b = [self.currentBooks objectAtIndex:row];
			[self assignBook:b toBookshelf:shelf];
		}
	}
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if (item.action == @selector(assignToBookshelf:)) {
		RFBookshelf* shelf = item.representedObject;
		if ([shelf.bookshelfID isEqualToNumber:self.bookshelf.bookshelfID]) {
			[item setState:NSControlStateValueOn];
		}
		else {
			[item setState:NSControlStateValueOff];
		}
	}
	else if (item.action == @selector(performFindPanelAction:)) {
		return YES;
	}

	return ![self isSearch];
}

- (void) performFindPanelAction:(id)sender
{
	[self.searchField becomeFirstResponder];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.currentBooks.count;
}

- (NSTableRowView *) tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	MBBookCell* cell = [tableView makeViewWithIdentifier:@"BookCell" owner:self];

	if (row < self.currentBooks.count) {
		MBBook* b = [self.currentBooks objectAtIndex:row];
		[cell setupWithBook:b inBookshelf:self.bookshelf];
	}

	return cell;
}

- (void) tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	MBBook* b = [self.currentBooks objectAtIndex:row];
	
	if (b.coverImage == nil) {
		NSString* url = [NSString stringWithFormat:@"https://micro.blog/photos/300x/%@", [b.coverURL rf_urlEncoded]];

		[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
			if ([response.parsedResponse isKindOfClass:[NSImage class]]) {
				NSImage* img = response.parsedResponse;
				RFDispatchMain(^{
					b.coverImage = img;
					@try {
						NSIndexSet* selected_rows = [tableView selectedRowIndexes];
						[tableView reloadData];
						[tableView selectRowIndexes:selected_rows byExtendingSelection:NO];
					}
					@catch (NSException* e) {
					}
				});
			}
		}];
	}
}

- (BOOL) tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return ![self isSearch];
}

@end
