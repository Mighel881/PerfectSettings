/*
Copyright (c) 2013-2019, Karen/あけみ, Eliz, Julian Weiss (insanj), ilendemli, Hiraku (hirakujira), Gary Lin (garynil).
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "PreferenceOrganizer2.h"

// Static specifier-overriding arrays (used when populating PSListController/etc)
static NSMutableArray *AppleAppSpecifiers, *TweakSpecifiers, *AppStoreAppSpecifiers;

static NSMutableArray *unorganisedSpecifiers = nil;

static BOOL ddiIsMounted = 0;
static BOOL deviceShowsTVProviders = 0;

// Sneaky implementations of vanilla PSListControllers with the proper hidden specifiers
@implementation AppleAppSpecifiersController

- (NSArray*)specifiers
{
	if(!_specifiers)
		self.specifiers = AppleAppSpecifiers;
	return _specifiers;
}

@end

@implementation TweakSpecifiersController

- (NSArray*)specifiers
{
	if(!_specifiers)
		self.specifiers = TweakSpecifiers;
	return _specifiers;
}

@end

@implementation AppStoreAppSpecifiersController

- (NSArray*)specifiers
{
	if(!_specifiers)
		self.specifiers = AppStoreAppSpecifiers;
	return _specifiers;
}

@end

void removeOldAppleThirdPartySpecifiers(NSMutableArray <PSSpecifier*> *specifiers)
{
	NSMutableArray *itemsToDelete = [NSMutableArray array];
	for(PSSpecifier *spec in specifiers)
	{
		NSString *Id = spec.identifier;
		if([Id isEqualToString: @"com.apple.news"] || [Id isEqualToString: @"com.apple.iBooks"] || [Id isEqualToString: @"com.apple.podcasts"] || [Id isEqualToString: @"com.apple.itunesu"])
			[itemsToDelete addObject: spec];
	}
	[specifiers removeObjectsInArray: itemsToDelete];
}

void fixupThirdPartySpecifiers(PSListController *self, NSArray <PSSpecifier*> *thirdParty, NSDictionary *appleThirdParty)
{
	NSMutableArray *specifiers = [[NSMutableArray alloc] initWithArray: ((PSListController*)self).specifiers]; // Then add all third party specifiers into correct categories Also remove them from the original locations
	NSArray *appleThirdPartySpecifiers = [appleThirdParty allValues];
	
	removeOldAppleThirdPartySpecifiers(AppleAppSpecifiers);
	[AppleAppSpecifiers addObjectsFromArray: appleThirdPartySpecifiers];
	[specifiers removeObjectsInArray: appleThirdPartySpecifiers];
	
	[AppStoreAppSpecifiers removeAllObjects];
	[AppStoreAppSpecifiers addObjectsFromArray: thirdParty];
	[specifiers removeObjectsInArray: thirdParty];

	((PSListController*)self).specifiers = specifiers;
}

%hook PSUIPrefsListController

- (NSMutableArray*)specifiers
{
	NSMutableArray *specifiers = %orig;
	
	if(!(MSHookIvar<NSArray*>(self, "_thirdPartySpecifiers")))
		return specifiers;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, 
	^{
		if(unorganisedSpecifiers == nil) // Save the original, unorganised specifiers
			unorganisedSpecifiers = specifiers.copy;

		int groupID = 0; // Okay, let's start pushing paper.
		NSMutableDictionary *organizableSpecifiers = [[NSMutableDictionary alloc] init];
		NSString *currentOrganizableGroup = nil;
		
		// Loop that runs through all specifiers in the main Settings area. Once it cycles through all the specifiers for the pre-"Apple Apps" groups, starts filling the organizableSpecifiers array.
		// This currently compares identifiers to prevent issues with extra groups (such as the single "Developer" group). STORE -> ... -> DEVELOPER_SETTINGS -> ...
		for(int i = 0; i < specifiers.count; i++) // We can't fast enumerate when order matters
		{
			PSSpecifier *s = (PSSpecifier*) specifiers[i];
			NSString *identifier = s.identifier ?: @"";
			
			if(s.cellType != 0) // If we're not a group cell...
			{
				if([identifier isEqualToString: @"DEVELOPER_SETTINGS"]) // If we're hitting the Developer settings area, regardless of position, we need to steal its group specifier from the previous group and leave it out of everything.
				{
					NSMutableArray *lastSavedGroup = organizableSpecifiers[currentOrganizableGroup];
					[lastSavedGroup removeObjectAtIndex: lastSavedGroup.count - 1];
					ddiIsMounted = 1; // If DEVELOPER_SETTINGS is present, then that means the DDI must have been mounted.
				}
				else if([identifier isEqualToString: @"STORE"]) // If we're in the first item of the iCloud/Mail/Notes... group, setup the key string, grab the group from the previously enumerated specifier, and get ready to shift things into it.
				{
					currentOrganizableGroup = identifier;
					
					NSMutableArray *newSavedGroup = [[NSMutableArray alloc] init];
					[newSavedGroup addObject: specifiers[i - 1]];
					[newSavedGroup addObject: s];

					[organizableSpecifiers setObject: newSavedGroup forKey: currentOrganizableGroup];
				}
				else if(currentOrganizableGroup)
					[organizableSpecifiers[currentOrganizableGroup] addObject: s];
			}

			// If we've already encountered groups before, but THIS specifier is a group specifier, then it COULDN'T have been any previously encountered group, but is still important to PreferenceOrganizer's organization. So, it must either be the Tweaks or Apps section.
			else if(currentOrganizableGroup)
			{
				if([identifier isEqualToString: @"VIDEO_SUBSCRIBER_GROUP"])
					deviceShowsTVProviders = 1;

				if(groupID < 2 + ddiIsMounted + deviceShowsTVProviders) // If the DDI is mounted, groupIDs will all shift down by 1, causing the categories to be sorted incorrectly. If an iOS 11 device is in a locale where the TV Provider option will show, groupID must be adjusted
				{
					groupID++;
					currentOrganizableGroup = @"STORE";
				}
				else if(groupID == 2 + ddiIsMounted + deviceShowsTVProviders)
				{
					groupID++;
					currentOrganizableGroup = @"TWEAKS";
				}
				else
				{
					groupID++;
					currentOrganizableGroup = @"APPS";
				}

				NSMutableArray *newSavedGroup = organizableSpecifiers[currentOrganizableGroup];
				if(!newSavedGroup)
					newSavedGroup = [[NSMutableArray alloc] init];

				[newSavedGroup addObject: s];
				[organizableSpecifiers setObject: newSavedGroup forKey: currentOrganizableGroup];
			}
			if(i == specifiers.count - 1 && groupID != 4 + ddiIsMounted)
			{
				groupID++;
				currentOrganizableGroup = @"APPS";
				NSMutableArray *newSavedGroup = organizableSpecifiers[currentOrganizableGroup];
				if(!newSavedGroup)
					newSavedGroup = [[NSMutableArray alloc] init];
				[organizableSpecifiers setObject: newSavedGroup forKey: currentOrganizableGroup];
			}
		}
		AppleAppSpecifiers = organizableSpecifiers[@"STORE"];

		NSMutableArray *tweaksGroup = organizableSpecifiers[@"TWEAKS"];
		if([tweaksGroup count] != 0 && ((PSSpecifier*)tweaksGroup[0]).cellType == 0 && ((PSSpecifier*)tweaksGroup[1]).cellType == 0)
			[tweaksGroup removeObjectAtIndex: 0];

		TweakSpecifiers = tweaksGroup;

		AppStoreAppSpecifiers = organizableSpecifiers[@"APPS"];
		
		if(AppleAppSpecifiers)
		{
			for(PSSpecifier* specifier in AppleAppSpecifiers) // Workaround for a bug in iOS 10 If all Apple groups (APPLE_ACCOUNT_GROUP, etc.) are deleted, it will crash
			{
				// We'll handle this later in insertMovedThirdPartySpecifiersAnimated
				if([specifier.identifier isEqualToString: @"MEDIA_GROUP"] || [specifier.identifier isEqualToString: @"ACCOUNTS_GROUP"] || [specifier.identifier isEqualToString: @"APPLE_ACCOUNT_GROUP"])
					continue;
				else
					[specifiers removeObject: specifier];
			}
			
			PSSpecifier *appleSpecifier = [PSSpecifier preferenceSpecifierNamed: @"System Apps" target: self set: NULL get: NULL detail: [AppleAppSpecifiersController class] cell: [PSTableCell cellTypeFromString: @"PSLinkCell"] edit: nil];
			[appleSpecifier setProperty: [UIImage _applicationIconImageForBundleIdentifier: @"com.apple.Preferences" format: 0 scale: [UIScreen mainScreen].scale] forKey: @"iconImage"];

			[appleSpecifier setIdentifier: @"APPLE_APPS"]; // Setting this identifier for later use...
			[specifiers insertObject: appleSpecifier atIndex: 3];
		}

		if(TweakSpecifiers)
		{
			[specifiers removeObjectsInArray: TweakSpecifiers];
			PSSpecifier *cydiaSpecifier = [PSSpecifier preferenceSpecifierNamed: @"Tweaks" target: self set: NULL get: NULL detail: [TweakSpecifiersController class] cell: [PSTableCell cellTypeFromString: @"PSLinkCell"] edit: nil];
			[cydiaSpecifier setProperty: [UIImage imageWithContentsOfFile: @"/Library/PreferenceBundles/PerfectSettings13Prefs.bundle/Tweaks.png"] forKey: @"iconImage"];
			[specifiers insertObject: cydiaSpecifier atIndex: 4];
		}

		if(AppStoreAppSpecifiers)
		{
			[specifiers removeObjectsInArray: AppStoreAppSpecifiers];
			PSSpecifier *appstoreSpecifier = [PSSpecifier preferenceSpecifierNamed: @"App Store Apps" target: self set: NULL get: NULL detail: [AppStoreAppSpecifiersController class] cell: [PSTableCell cellTypeFromString: @"PSLinkCell"] edit: nil];
			[appstoreSpecifier setProperty: [UIImage _applicationIconImageForBundleIdentifier: @"com.apple.AppStore" format: 0 scale: [UIScreen mainScreen].scale] forKey: @"iconImage"];
			[specifiers insertObject: appstoreSpecifier atIndex: 5];
		}

		[specifiers insertObject: [PSSpecifier groupSpecifierWithName: nil] atIndex: 6]; // add group to separate from the group below
		
		if(AppleAppSpecifiers)
		{
			NSMutableArray *specifiersToRemove = [[NSMutableArray alloc] init]; // Move deleted group specifiers to the end...
			for(int i = 0; i < specifiers.count; i++)
			{
				PSSpecifier *specifier = (PSSpecifier*) specifiers[i];
				
				if([specifier.identifier isEqualToString: @"MEDIA_GROUP"] || [specifier.identifier isEqualToString: @"ACCOUNTS_GROUP"] || [specifier.identifier isEqualToString: @"APPLE_ACCOUNT_GROUP"])
					[specifiersToRemove addObject: specifier];
			}
			[specifiers removeObjectsInArray: specifiersToRemove];
		}
	});
	
	[specifiers removeObjectsInArray: [MSHookIvar<NSMutableDictionary*>(self, "_movedThirdPartySpecifiers") allValues]]; // If we found Apple's third party apps, we really won't add them because this would mess up the UITableView row count check after the update
	return specifiers;
}

- (void)updateRestrictedSettings // This method may add some Apple's third party specifiers with respect to restriction settings and results in duplicate entries, so fix it here
{
	%orig;
	[((PSListController*)self).specifiers removeObjectsInArray: [MSHookIvar<NSMutableDictionary*>(self, "_movedThirdPartySpecifiers") allValues]];
	removeOldAppleThirdPartySpecifiers(AppleAppSpecifiers);
	[AppleAppSpecifiers addObjectsFromArray: [MSHookIvar<NSMutableDictionary*>(self, "_movedThirdPartySpecifiers") allValues]];
}

- (void)insertMovedThirdPartySpecifiersAnimated: (BOOL)animated // Redirect all of Apple's third party specifiers to AppleAppSpecifiers
{
	if(AppleAppSpecifiers.count)
	{
		NSArray <PSSpecifier*> *movedThirdPartySpecifiers = [MSHookIvar<NSMutableDictionary*>(self, "_movedThirdPartySpecifiers") allValues];
		removeOldAppleThirdPartySpecifiers(AppleAppSpecifiers);
		[AppleAppSpecifiers addObjectsFromArray: movedThirdPartySpecifiers];
	}
	else
		%orig;
}

- (void)_reallyLoadThirdPartySpecifiersForApps: (NSArray*)apps withCompletion: (void (^)(NSArray <PSSpecifier*> *thirdParty, NSDictionary *appleThirdParty))completion
{
	void (^newCompletion)(NSArray <PSSpecifier*> *, NSDictionary*) = ^(NSArray <PSSpecifier*> *thirdParty, NSDictionary *appleThirdParty) // thirdParty - self->_thirdPartySpecifiers, appleThirdParty - self->_movedThirdPartySpecifiers
	{
		if(completion)
			completion(thirdParty, appleThirdParty);
		fixupThirdPartySpecifiers(self, thirdParty, appleThirdParty);
	};
	%orig(apps, newCompletion);
}

%end

%hook PreferencesAppController

%new
- (BOOL)preferenceOrganizerOpenTweakPane: (NSString*)name // Push the requested tweak specifier controller.
{
	name = [name stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]; // Replace the percent escapes in an iOS 6-friendly way (deprecated in iOS 9).
	BOOL foundMatch = NO; // Set up return value.

	for(PSSpecifier *specifier in TweakSpecifiers) // Loop the registered TweakSpecifiers.
	{
		if([name caseInsensitiveCompare: [specifier name]] == NSOrderedSame && [specifier target]) // If we have a match, and that match has a non-nil target, let's do this.
		{
			foundMatch = YES; // We have a valid match.
			[[[specifier target] navigationController] pushViewController: [(PSListController*)[specifier target] controllerForSpecifier: specifier] animated: NO]; // Push the requested controller.	
			PSSpecifier *tweaksSpecifier = [[[self rootController] rootListController] specifierForID: @"Tweaks"]; // Get the specifier for TweaksSpecifier.
			
			if(tweaksSpecifier) // If we got a specifier for TweaksSpecifier...
			{
				TweakSpecifiersController *tweakSpecifiersController = [(PSListController*)[[self rootController] rootListController] controllerForSpecifier: tweaksSpecifier]; // Get the TweakSpecifiersController.
				if(tweakSpecifiersController) // If we got a controller for TweakSpecifiers...
				{
					int stackCount = [[specifier target] navigationController].viewControllers.count; // Get the navigation stack count.
					NSMutableArray *mutableStack; // Declare a NSMutableArray to manipulate the navigation stack (if necessary).
					
					switch(stackCount) // Switch on the navigation stack count and manipulate the stack accordingly.
					{
						case 3: // Three controllers in the navigation stack (rootListController, unknown controller, and controllerForSpecifier). Check the controller at index 1 and replace it if necessary.
							if(![[[[specifier target] navigationController].viewControllers objectAtIndex: 1] isMemberOfClass: [TweakSpecifiersController class]]) // If the user was already on the TweakSpecifiersController, then we're good.
							{
								mutableStack = [NSMutableArray arrayWithArray: [[specifier target] navigationController].viewControllers]; // Get a mutable copy of the navigation stack.
								[[tweakSpecifiersController navigationItem] setTitle: @"Tweaks"]; // Set the TweakSpecifiersController navigationItem title.
								[mutableStack replaceObjectAtIndex: 1 withObject: tweakSpecifiersController]; // Replace the intermediate controller with the TweakSpecifiersController.
								[[specifier target] navigationController].viewControllers = [NSArray arrayWithArray: mutableStack]; // Update the navigation stack.
							}
							break;
						case 2: // Two controllers in the navigation stack (rootListController and controllerForSpecifier). Insert the TweakSpecifiersController as an intermediate.
							
							mutableStack = [NSMutableArray arrayWithArray: [[specifier target] navigationController].viewControllers]; // Get a mutable copy of the navigation stack.
							[[tweakSpecifiersController navigationItem] setTitle: @"Tweaks"]; // Set the TweakSpecifiersController navigationItem title.
							[mutableStack insertObject: tweakSpecifiersController atIndex: 1]; // Insert the TweakSpecifiersController as an intermediate controller.
							[[specifier target] navigationController].viewControllers = [NSArray arrayWithArray: mutableStack]; // Update the navigation stack.
							break;
						case 1: // One controller in the navigation stack should not be possible after we push the controllerForSpecifier, and zero controllers is legitimately impossible, so Get out of here!
						case 0:
							break;
						default: // Too many controllers to manage.  Dump everything in the navigation stack except the first and last controllers.
							mutableStack = [NSMutableArray arrayWithArray: [[specifier target] navigationController].viewControllers]; // Get a mutable copy of the navigation stack.
							[mutableStack removeObjectsInRange: NSMakeRange(1, stackCount - 2)]; // Remove everything in the middle.
							[[tweakSpecifiersController navigationItem] setTitle: @"Tweaks"]; // Set the TweakSpecifiersController navigationItem title.
							[mutableStack insertObject: tweakSpecifiersController atIndex: 1]; // Insert the TweakSpecifiersController as an intermediate controller.
							[[specifier target] navigationController].viewControllers = [NSArray arrayWithArray: mutableStack]; // Update the navigation stack.
					}
				}
			}
			break;
		}
	}
	return foundMatch;
}

// Parses the given URL to check if it's in a PreferenceOrganizer2-API conforming format, that is to say, it has a root=Tweaks, and a &path= corresponding to a tweak name. If %path= is present and it points to a valid tweak name, try to launch it.
// If preferenceOrganizerOpenTweakPane fails, just open the root tweak pane (even if they've renamed it).

- (void)applicationOpenURL: (NSURL*)url
{
	NSString *parsableURL = [url absoluteString];
	if(parsableURL.length >= 11 && [parsableURL rangeOfString: @"root=Tweaks"].location != NSNotFound)
	{
		NSString *truncatedPrefsURL = [@"prefs: root=" stringByAppendingString: [@"Tweaks" stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
		url = [NSURL URLWithString: truncatedPrefsURL];
		NSRange tweakPathRange = [parsableURL rangeOfString: @"path="];

		if(tweakPathRange.location != NSNotFound)
		{
			NSInteger tweakPathOrigin = tweakPathRange.location + tweakPathRange.length;
			if([self preferenceOrganizerOpenTweakPane: [parsableURL substringWithRange: NSMakeRange(tweakPathOrigin, parsableURL.length - tweakPathOrigin)]]) // If specified tweak was found, don't call the original method;
				return;
		}
	}
	%orig(url);
}

%end

void initPreferenceOrganizer()
{
	%init;
}
