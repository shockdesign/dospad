/*
 *  Copyright (C) 2010  Chaoji Li
 *
 *  DOSPAD is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "AppDelegate.h"
#import "DOSPadBaseViewController.h"
#import "Common.h"
#import <AVFoundation/AVFoundation.h>
#import "ColorTheme.h"
#import "ZipArchive.h"
#import "UIViewController+Alert.h"

@interface AppDelegate ()
{
	DOSPadBaseViewController *_emulatorController;
}
@end


@implementation AppDelegate
@synthesize frameskip;
@synthesize cycles;
@synthesize maxPercent;

/*
 * Unzip file into directory `dir'.
 */
- (void)unzip:(NSString*)filepath toDir:(NSString*)dir
{
	BOOL ret = NO;
	ZipArchive *ar = [[ZipArchive alloc] init];
	
	if ([ar UnzipOpenFile:filepath]) {
		[[FileSystemObject sharedObject] ensureDirectoryExists:dir];
		ret = [ar UnzipFileTo:dir overWrite:YES];
		[ar UnzipCloseFile];
		[[FileSystemObject sharedObject] removeFileAtPath:filepath];
	}	
}


/*
 * Import a zip package and unzip its content under `Documents' folder.
 * Warning: It will overwrite the contents of that folder.
 */
- (void)importFile:(NSURL*)url
{
	NSString *srcpath = [url path];
	NSString *filename = [srcpath lastPathComponent];
	if ([filename.pathExtension.lowercaseString isEqualToString:@"zip"]) {
		[self unzip:srcpath
			toDir:[[FileSystemObject sharedObject] documentsDirectory]
		];
	}
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
	sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	NSLog(@"openURL: %@", url);
	if (url.isFileURL)
	{
		if ([DOSPadEmulator sharedInstance].started)
		{
			// TODO: show alert can not open while it's running
			// quick first.
			[_emulatorController alert:@"Busy"
				message:@"Can not launch the iDOS package while emulator is running. Please terminate the app first."];
			return NO;
		}
		[url startAccessingSecurityScopedResource];
		[DOSPadEmulator sharedInstance].diskcDirectory = url.path;
	}
//	[self importFile:url];
	return YES;
}

-(SDL_uikitopenglview*)screen
{
    return screenView;
}

// iOS 4.x
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    dospad_resume();
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    dospad_pause();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    dospad_resume();
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    dospad_save_history();
}

// iOS 3.x
- (void)applicationWillTerminate:(UIApplication *)application
{
    dospad_save_history();
}

- (void)startDOS 
{
	[[DOSPadEmulator sharedInstance] start];
}

- (void)initColorTheme
{
	NSString *path = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"configs/colortheme.json"];
	ColorTheme *theme = [[ColorTheme alloc] initWithPath:path];
	[ColorTheme setDefaultTheme:theme];
}

- (void)registerDefaultSettings
{
	NSString *path = [[NSBundle mainBundle] bundlePath];
	path = [path stringByAppendingPathComponent:@"Settings.bundle"];
	path = [path stringByAppendingPathComponent:@"Root.plist"];
	NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:path];
	NSArray *prefs = settingsDict[@"PreferenceSpecifiers"];
	NSMutableDictionary *defs = [NSMutableDictionary dictionary];
	for (NSDictionary *item in prefs) {
		NSString *key = item[@"Key"];
		NSObject *obj = item[@"DefaultValue"];
		if (key && obj) {
			defs[key] = obj;
		}
	}
	if (defs.count > 0) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:defs];
	}
}

// Reference: https://developer.apple.com/library/ios/qa/qa1719/_index.html
- (BOOL)setBackupAttributeToItemAtPath:(NSString *)filePathString skip:(BOOL)skip
{
    NSURL* URL = [NSURL fileURLWithPath: filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
 
    NSError *error = nil;
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool:skip]
                                  forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (!success)
	{
        NSLog(
			@"Error %@ `%@' from backup: %@",
			(skip?@"excluding":@"including"),
			[URL lastPathComponent], error
		);
    }
    return success;
}

/*
 * Exclude or include Documents folder for iCloud/iTunes backup,
 * depending on user settings.
 */
- (void)initBackup
{
	if (DEFS_GET_BOOL(kiCloudBackupEnabled)) {
		[self setBackupAttributeToItemAtPath:DOCUMENTS_DIR skip:NO];
	} else {
		[self setBackupAttributeToItemAtPath:DOCUMENTS_DIR skip:YES];
	}
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
	NSLog(@"didFinishLaunchingWithOptions %@", launchOptions);
	[self registerDefaultSettings];
	[self initBackup];
	[self initColorTheme];

	// Make sure we are allowed to play in lock screen
	NSError *setCategoryErr = nil;
	NSError *activationErr  = nil;
	[[AVAudioSession sharedInstance]
		setCategory: AVAudioSessionCategoryPlayback
		error: &setCategoryErr];
	[[AVAudioSession sharedInstance]
		setActive: YES
		error: &activationErr];

    screenView = [[SDL_uikitopenglview alloc] initWithFrame:CGRectMake(0,0,640,400)];
    _emulatorController = [DOSPadBaseViewController dospadController];
    _emulatorController.screenView = screenView;
	uiwindow.rootViewController = _emulatorController;
    [uiwindow makeKeyAndVisible];
	[super applicationDidFinishLaunching:application];
#ifdef THREADED
	// FIXME at present it is a must to delay emulation thread
    [self performSelector:@selector(startDOS) withObject:nil afterDelay:1];
#endif
    return YES;
}


-(void)setWindowTitle:(char *)title
{
    char buf[8];
    NSAssert([NSThread isMainThread], @"Should work in main thread");
    if (strstr(title, "max"))
    {
        sscanf(title, "Cpu speed: max %d%% cycles, Frameskip %d", &maxPercent, &frameskip);
        sprintf(buf, "%3d%%", maxPercent);
        cycles = 0;
    } 
    else
    {
        sscanf(title, "Cpu speed: %d cycles, Frameskip %d", &cycles, &frameskip);
        sprintf(buf, "%4d", cycles);
        maxPercent = 0;
    }
    
    [_emulatorController updateCpuCycles:@(buf)];
	[_emulatorController updateFrameskip:@(frameskip)];
}

-(void)onLaunchExit
{
	[_emulatorController onLaunchExit];
}

@end
