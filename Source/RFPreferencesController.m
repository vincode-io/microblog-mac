//
//  RFPreferencesController.m
//  Snippets
//
//  Created by Manton Reece on 10/12/17.
//  Copyright © 2017 Riverfold Software. All rights reserved.
//

#import "RFPreferencesController.h"

#import "RFConstants.h"
#import "RFAccount.h"
#import "RFAccountCell.h"
#import "RFSettings.h"
#import "RFMacros.h"
#import "RFXMLLinkParser.h"
#import "RFXMLRPCRequest.h"
#import "RFXMLRPCParser.h"
#import "RFWordpressController.h"
#import "NSString+Extras.h"
#import "UUHttpSession.h"
#import "UUString.h"
#import "SAMKeychain.h"
#import "NSAlert+Extras.h"

static CGFloat const kWordPressMenusHeight = 125;
static NSString* const kAccountCellIdentifier = @"AccountCell";

@implementation RFPreferencesController

- (instancetype) init
{
	self = [super initWithWindowNibName:@"Preferences"];
	if (self) {
	}
	
	return self;
}

- (void) windowDidLoad
{
	[super windowDidLoad];

	[self setupAccounts];
	[self setupFields];
	[self setupTextPopup];
	[self setupNotifications];
	[self setupColletionView];
	
	[self updateRadioButtons];
	[self updateMenus];
	
	[self hideMessage];
	[self hideWordPressMenus];
}

- (void) windowDidBecomeKeyNotification:(NSNotification *)notification
{
	[self loadCategories];
	RFDispatchSeconds (0.5, ^{
		// delay slightly to give message pane time to potentially finish
		[self showMenusIfWordPress];
	});
}

- (void) setupAccounts
{
	self.accounts = [RFSettings accounts];
	
	RFAccount* blank_a = [[RFAccount alloc] init];
	blank_a.username = @"";
	self.accounts = [self.accounts arrayByAddingObject:blank_a];
}

- (void) setupFields
{
	self.returnButton.alphaValue = 0.0;
	self.websiteField.delegate = self;
	
	NSString* s = [[NSUserDefaults standardUserDefaults] stringForKey:@"ExternalBlogURL"];
	if (s) {
		self.websiteField.stringValue = s;
	}
}

- (void) setupTextPopup
{
	for (NSMenuItem* item in self.textSizePopup.menu.itemArray) {
		if ([item.title isEqualToString:@"Tiny"]) {
			item.tag = kTextSizeTiny;
		}
		else if ([item.title isEqualToString:@"Small"]) {
			item.tag = kTextSizeSmall;
		}
		else if ([item.title isEqualToString:@"Medium"]) {
			item.tag = kTextSizeMedium;
		}
		else if ([item.title isEqualToString:@"Large"]) {
			item.tag = kTextSizeLarge;
		}
		else if ([item.title isEqualToString:@"Huge"]) {
			item.tag = kTextSizeHuge;
		}
	}

	NSInteger text_size = [[NSUserDefaults standardUserDefaults] integerForKey:kTextSizePrefKey];
	[self.textSizePopup selectItemWithTag:text_size];
}

- (void) setupNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:NSWindowDidBecomeKeyNotification object:self.window];
}

- (void) setupColletionView
{
	self.accountsCollectionView.delegate = self;
	self.accountsCollectionView.dataSource = self;
	
	[self.accountsCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"AccountCell" bundle:nil] forItemWithIdentifier:kAccountCellIdentifier];

//	self.accountsCollectionView.constant = 0;
}

- (void) loadCategories
{
	NSString* xmlrpc_endpoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalBlogEndpoint"];
	if (xmlrpc_endpoint) {
		[self.progressSpinner startAnimation:nil];

		NSString* xmlrpc_endpoint = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalBlogEndpoint"];
		NSString* blog_s = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalBlogID"];
		NSString* username = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExternalBlogUsername"];
		NSString* password = [SAMKeychain passwordForService:@"ExternalBlog" account:username];
		
		NSNumber* blog_id = [NSNumber numberWithInteger:[blog_s integerValue]];
		NSString* taxonomy = @"category";
		
		NSArray* params = @[ blog_id, username, password, taxonomy ];
		
		RFXMLRPCRequest* request = [[RFXMLRPCRequest alloc] initWithURL:xmlrpc_endpoint];
		[request sendMethod:@"wp.getTerms" params:params completion:^(UUHttpResponse* response) {
			RFXMLRPCParser* xmlrpc = [RFXMLRPCParser parsedResponseFromData:response.rawResponse];

			NSMutableArray* new_categories = [NSMutableArray array];
			NSMutableArray* new_ids = [NSMutableArray array];
			for (NSDictionary* cat_info in xmlrpc.responseParams.firstObject) {
				[new_categories addObject:cat_info[@"name"]];
				[new_ids addObject:cat_info[@"term_id"]];
			}

			RFDispatchMainAsync (^{
				[self.categoryPopup removeAllItems];
				
				for (NSInteger i = 0; i < new_ids.count; i++) {
					NSString* cat_title = new_categories[i];
					NSNumber* cat_id = new_ids[i];
					NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:cat_title action:NULL keyEquivalent:@""];
					item.tag = cat_id.integerValue;
					[self.categoryPopup.menu addItem:item];
				}
				
				self.hasLoadedCategories = YES;
				[self updateMenus];
				[self.progressSpinner stopAnimation:nil];
			});
		}];
	}
}

#pragma mark -

- (IBAction) setHostedBlog:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ExternalBlogIsPreferred"];
	[self updateRadioButtons];
	[self showMenusIfWordPress];
}

- (IBAction) setWordPressBlog:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ExternalBlogIsPreferred"];
	[self updateRadioButtons];
	[self showMenusIfWordPress];
}

- (IBAction) returnButtonPressed:(id)sender
{
	[self hideReturnButton];
	[self checkWebsite];
}

- (IBAction) postFormatChanged:(NSPopUpButton *)sender
{
	NSString* s = [[sender selectedItem] title];
	[[NSUserDefaults standardUserDefaults] setObject:s forKey:@"ExternalBlogFormat"];
}

- (IBAction) categoryChanged:(NSPopUpButton *)sender
{
	NSInteger tag = [[sender selectedItem] tag];
	NSString* s = [NSString stringWithFormat:@"%ld", (long)tag];
	[[NSUserDefaults standardUserDefaults] setObject:s forKey:@"ExternalBlogCategory"];
}

- (void) controlTextDidChange:(NSNotification *)notification
{
	NSString* s = self.websiteField.stringValue;
	if (s.length > 0) {
		[self showReturnButton];
	}
	else {
		[self hideReturnButton];
	}
}

- (IBAction) websiteTextChanged:(NSTextField *)sender
{
	[self hideReturnButton];
	if (sender.stringValue.length > 0) {
		[self checkWebsite];
	}
}

- (IBAction) textSizeChanged:(NSPopUpButton *)sender
{
	NSInteger tag = [[sender selectedItem] tag];
	[[NSUserDefaults standardUserDefaults] setInteger:tag forKey:kTextSizePrefKey];

	NSString* username = [[NSUserDefaults standardUserDefaults] stringForKey:@"AccountUsername"];
	NSString* token = [SAMKeychain passwordForService:@"Micro.blog" account:username];

	NSString* url = [NSString stringWithFormat:@"https://micro.blog/hybrid/signin?token=%@&fontsize=%ld", token, (long)tag];
	[UUHttpSession get:url queryArguments:nil completionHandler:^(UUHttpResponse* response) {
		RFDispatchMainAsync (^{
			[[NSNotificationCenter defaultCenter] postNotificationName:kRefreshTimelineNotification object:self];
		});
	}];
}

#pragma mark -

- (void) showMessage:(NSString *)message
{
	self.messageField.stringValue = message;
	
	if (self.messageTopConstraint.constant < -1) {
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
			NSRect win_r = self.window.frame;
			win_r.size.height += self.messageHeader.bounds.size.height;
			win_r.origin.y -= self.messageHeader.bounds.size.height;

			context.duration = [self.window animationResizeTime:win_r];
			
			self.messageTopConstraint.animator.constant = -1;
			[self.window.animator setFrame:win_r display:YES];
		} completionHandler:^{
		}];
	}
}

- (void) hideMessage
{
	self.messageTopConstraint.constant = -(self.messageHeader.bounds.size.height);
	
	NSSize win_size = self.window.frame.size;
	win_size.height -= self.messageHeader.bounds.size.height;
	[self.window setContentSize:win_size];
}

- (void) showMenusIfWordPress
{
	NSRect win_r = self.window.frame;

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"ExternalBlogIsPreferred"] && [[defaults objectForKey:@"ExternalBlogApp"] isEqualToString:@"WordPress"]) {
		if (!self.isShowingWordPressMenus) {
			win_r.size.height += kWordPressMenusHeight;
			win_r.origin.y -= kWordPressMenusHeight;
			[self.window.animator setFrame:win_r display:YES];
			self.isShowingWordPressMenus = YES;
		}
	}
	else {
		if (self.isShowingWordPressMenus) {
			win_r.size.height -= kWordPressMenusHeight;
			win_r.origin.y += kWordPressMenusHeight;
			[self.window.animator setFrame:win_r display:YES];
			self.isShowingWordPressMenus = NO;
		}
	}
}

- (void) hideWordPressMenus
{
	NSRect win_r = self.window.frame;
	win_r.size.height -= kWordPressMenusHeight;
	win_r.origin.y += kWordPressMenusHeight;
	[self.window setFrame:win_r display:YES];
	self.isShowingWordPressMenus = NO;
}

- (void) updateRadioButtons
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ExternalBlogIsPreferred"]) {
		self.publishHostedBlog.state = NSControlStateValueOn;
		self.publishWordPressBlog.state = NSControlStateValueOff;
		self.websiteField.enabled = NO;
	}
	else {
		self.publishHostedBlog.state = NSControlStateValueOff;
		self.publishWordPressBlog.state = NSControlStateValueOn;
		self.websiteField.enabled = YES;
	}
}

-  (void) updateMenus
{
	NSString* selected_format = [[NSUserDefaults standardUserDefaults] stringForKey:@"ExternalBlogFormat"];
	NSString* selected_category = [[NSUserDefaults standardUserDefaults] stringForKey:@"ExternalBlogCategory"];

	if (self.hasLoadedCategories) {
		self.postFormatPopup.enabled = YES;
		self.categoryPopup.enabled = YES;
	}

	if (selected_format) {
		[self.postFormatPopup selectItemWithTitle:selected_format];
	}
	
	if (selected_category) {
		[self.categoryPopup selectItemWithTag:selected_category.integerValue];
	}
}

- (void) showReturnButton
{
	self.returnButton.animator.alphaValue = 1.0;
}

- (void) hideReturnButton
{
	self.returnButton.animator.alphaValue = 0.0;
}

- (void) checkWebsite
{
	[self.progressSpinner startAnimation:nil];

	NSString* full_url = [self normalizeURL:self.websiteField.stringValue];
	[[NSUserDefaults standardUserDefaults] setObject:full_url forKey:@"ExternalBlogURL"];

	UUHttpRequest* request = [UUHttpRequest getRequest:full_url queryArguments:nil];
	[UUHttpSession executeRequest:request completionHandler:^(UUHttpResponse* response) {
		RFXMLLinkParser* rsd_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"EditURI"];
		if ([rsd_parser.foundURLs count] > 0) {
			NSString* rsd_url = [rsd_parser.foundURLs firstObject];
            RFDispatchMainAsync (^{
				[self.progressSpinner stopAnimation:nil];

                self.wordpressController = [[RFWordpressController alloc] initWithWebsite:full_url rsdURL:rsd_url];
				[self.window beginSheet:self.wordpressController.window completionHandler:^(NSModalResponse returnCode) {
					if (returnCode == NSModalResponseOK) {
						[self showMessage:@"Weblog settings have been updated."];
					}
				}];
            });
		}
		else {
			RFXMLLinkParser* micropub_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"micropub"];
			if ([micropub_parser.foundURLs count] > 0) {
				RFXMLLinkParser* auth_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"authorization_endpoint"];
				RFXMLLinkParser* token_parser = [RFXMLLinkParser parsedResponseFromData:response.rawResponse withRelValue:@"token_endpoint"];
				if (([auth_parser.foundURLs count] > 0) && ([token_parser.foundURLs count] > 0)) {
					NSString* auth_endpoint = [auth_parser.foundURLs firstObject];
					NSString* token_endpoint = [token_parser.foundURLs firstObject];
					NSString* micropub_endpoint = [micropub_parser.foundURLs firstObject];
					
					NSString* micropub_state = [[[NSString uuGenerateUUIDString] lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];

					NSMutableString* auth_with_params = [auth_endpoint mutableCopy];
					if (![auth_with_params containsString:@"?"]) {
						[auth_with_params appendString:@"?"];
					}
					[auth_with_params appendFormat:@"me=%@", [full_url rf_urlEncoded]];
					[auth_with_params appendFormat:@"&redirect_uri=%@", [@"https://micro.blog/micropub/redirect" rf_urlEncoded]];
					[auth_with_params appendFormat:@"&client_id=%@", [@"https://micro.blog/" rf_urlEncoded]];
					[auth_with_params appendFormat:@"&state=%@", micropub_state];
					[auth_with_params appendString:@"&scope=create"];
					[auth_with_params appendString:@"&response_type=code"];

					[[NSUserDefaults standardUserDefaults] setObject:micropub_state forKey:@"ExternalMicropubState"];
					[[NSUserDefaults standardUserDefaults] setObject:token_endpoint forKey:@"ExternalMicropubTokenEndpoint"];
					[[NSUserDefaults standardUserDefaults] setObject:micropub_endpoint forKey:@"ExternalMicropubPostingEndpoint"];

					RFDispatchMainAsync (^{
						[self.progressSpinner stopAnimation:nil];
						[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:auth_with_params]];
					});
				}
			}
			else {
				RFDispatchMainAsync (^{
					[self.progressSpinner stopAnimation:nil];
					[NSAlert rf_showOneButtonAlert:@"Error Discovering Settings" message:@"Could not find the XML-RPC endpoint or Micropub API for your weblog." button:@"OK" completionHandler:NULL];
				});
			}
		}
	}];
}

- (NSString *) normalizeURL:(NSString *)url
{
	NSString* s = url;
	if (![s containsString:@"http"]) {
		s = [@"http://" stringByAppendingString:s];
	}
	
	return s;
}

#pragma mark -

- (NSInteger) collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.accounts.count;
}

- (NSCollectionViewItem *) collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	RFAccount* a = [self.accounts objectAtIndex:indexPath.item];
	
	RFAccountCell* item = (RFAccountCell *)[collectionView makeItemWithIdentifier:kAccountCellIdentifier forIndexPath:indexPath];
	[item setupWithAccount:a];

	return item;
}

- (void) collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	NSIndexPath* index_path = [indexPaths anyObject];
}

@end
