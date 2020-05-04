#import "PerfectSettings13.h"
#import <Cephei/HBPreferences.h>

extern void initPreferenceOrganizer();

static HBPreferences *pref;
static BOOL enableCustomTitle;
static NSString *customTitle;
static BOOL disableEdgeToEdgeCells;
static BOOL circleIcons;
static BOOL hideIcons;
static BOOL hideArrow;
static BOOL hideCellSeparator;
static BOOL roundSearchBar;
static BOOL hideSearchBar;
static BOOL organizeSettings;

%group enableCustomTitleGroup

	%hook _UINavigationBarLargeTitleView

	- (void)setTitle: (NSString*)title
	{
		%orig(customTitle);
	}

	%end

	%hook _UINavigationBarContentView

	- (void)setTitle: (NSString*)title
	{
		%orig(customTitle);
	}
	
	%end

%end

// ------------------------- BETTER SETTINGS UI -------------------------

%group disableEdgeToEdgeCellsGroup

	%hook PSListController

	- (void)setEdgeToEdgeCells: (BOOL)arg
	{
		%orig(NO);
	}

	- (BOOL)_isRegularWidth
	{
		return YES;
	}

	%end

%end

// ------------------------- CIRCLE ICONS -------------------------

%group editPSTableCellGroup

	%hook PSTableCell

	- (void)layoutSubviews
	{
		%orig;

		if(circleIcons && [self imageView])
		{
			[[[self imageView] layer] setCornerRadius: 14.5]; // full width = 29
			[[[self imageView] layer] setMasksToBounds: YES];
		}

		if(hideArrow) [self setForceHideDisclosureIndicator: YES];
	}

	%end

%end

%group hideCellSeparatorGroup

	%hook _UITableViewCellSeparatorView

	- (void)layoutSubviews
	{
		[self setHidden: YES];
	}

	%end

%end

%group hideSearchBarGroup

	%hook PSKeyboardNavigationSearchController

	- (void)setSearchBar: (id)arg
	{

	}

	%end

%end

%group roundSearchBarGroup

	%hook _UISearchBarSearchFieldBackgroundView

	- (void)setCornerRadius: (double)arg
	{
		%orig(40);
	}

	%end

%end

%group hideIconsGroup

	%hook PSTableCell

	- (void)setIcon: (id)arg
	{
		
	}

	%end

%end

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.perfectsettings13prefs"];
		[pref registerDefaults:
		@{
			@"enableCustomTitle": @NO,
			@"customTitle": @"PerfectSettings",
			@"disableEdgeToEdgeCells": @NO,
			@"circleIcons": @NO,
			@"hideIcons": @NO,
			@"hideArrow": @NO,
			@"hideCellSeparator": @NO,
			@"roundSearchBar": @NO,
			@"hideSearchBar": @NO,
			@"organizeSettings": @NO
    	}];

		enableCustomTitle = [pref boolForKey: @"enableCustomTitle"];
		customTitle = [pref objectForKey: @"customTitle"];
		disableEdgeToEdgeCells = [pref boolForKey: @"disableEdgeToEdgeCells"];
		circleIcons = [pref boolForKey: @"circleIcons"];
		hideIcons = [pref boolForKey: @"hideIcons"];
		hideArrow = [pref boolForKey: @"hideArrow"];
		hideCellSeparator = [pref boolForKey: @"hideCellSeparator"];
		roundSearchBar = [pref boolForKey: @"roundSearchBar"];
		hideSearchBar = [pref boolForKey: @"hideSearchBar"];
		organizeSettings = [pref boolForKey: @"organizeSettings"];

		if(enableCustomTitle) %init(enableCustomTitleGroup);
		if(disableEdgeToEdgeCells) %init(disableEdgeToEdgeCellsGroup);
		if(circleIcons || hideArrow) %init(editPSTableCellGroup);
		if(hideIcons) %init(hideIconsGroup);
		if(hideCellSeparator) %init(hideCellSeparatorGroup);
		if(roundSearchBar) %init(roundSearchBarGroup);
		if(hideSearchBar) %init(hideSearchBarGroup);
		if(organizeSettings) initPreferenceOrganizer();
	}
}