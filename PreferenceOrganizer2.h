#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSRootController.h>

@interface PSListController ()
-(id)controllerForSpecifier:(id)arg1 ;
@end

@interface PrefsRootController: PSRootController
-(id)rootListController;
@end

@interface PreferencesAppController: UIApplication
- (BOOL)preferenceOrganizerOpenTweakPane:(NSString *)name;
- (PrefsRootController*)rootController;
@end

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface AppleAppSpecifiersController : PSListController
@end

@interface TweakSpecifiersController : PSListController
@end

@interface AppStoreAppSpecifiersController : PSListController
@end

@interface PSUIPrefsListController : PSListController
@end