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

#import "DosPadViewController_iPhone.h"
#import "FileSystemObject.h"
#import "Common.h"
#import "AppDelegate.h"
#import "ColorTheme.h"


static struct {
	InputSourceType type;
	const char *onImageName;
	const char *offImageName;
} toggleButtonInfo [] = {
	{InputSource_PCKeyboard,    "modekeyon.png",          "modekeyoff.png"    },
	{InputSource_MouseButtons,  "mouseon.png",            "mouseoff.png"      },
	{InputSource_GamePad,       "modegamepadpressed.png", "modegamepad.png"   },
	{InputSource_Joystick,      "modejoypressed.png",     "modejoy.png"       },
	{InputSource_NumPad,        "modenumpadpressed.png",  "modenumpad.png"    },
	{InputSource_PianoKeyboard, "modepianopressed.png",   "modepiano.png"     },
};
#define NUM_BUTTON_INFO (sizeof(toggleButtonInfo)/sizeof(toggleButtonInfo[0]))

// TODO color with pattern image doesn't work well with transparency
// so we need to invent a new View subclass.
// Do we really need to do this?
@implementation ToolPanelView

- (id)initWithFrame:(CGRect)frame
{
	if (self = [super initWithFrame:frame])
	{
		self.backgroundColor = [UIColor clearColor];
	}
	return self;
}

- (void)drawRect:(CGRect)rect
{
	UIImage *backgroundImage = [UIImage imageNamed:@"bar-portrait-iphone"];
	[backgroundImage drawInRect:rect];
}

@end


@interface DosPadViewController_iPhone()
{
	// Only used in portrait mode
	UIView *_rootContainer;
}

@end

@implementation DosPadViewController_iPhone


- (void)initUI
{
    //---------------------------------------------------
    // 1. Root View
    //---------------------------------------------------
	self.view.backgroundColor = HexColor(0x585458);
	self.view.userInteractionEnabled = YES;
	CGRect viewRect = [self safeRootRect];
	_rootContainer = [[UIView alloc] initWithFrame:viewRect];
    [self.view addSubview:_rootContainer];
	
    //---------------------------------------------------
    // 2. Create the toolbar in portrait mode
    //---------------------------------------------------

    toolPanel = [[ToolPanelView alloc] initWithFrame:CGRectMake(
    	viewRect.origin.x + (viewRect.size.width-320)/2,
    	viewRect.origin.y + 240,
    	320,25)];

    UIButton *btnOption = [[UIButton alloc] initWithFrame:CGRectMake(0,0,32,25)];
    UIButton *btnLeft = [[UIButton alloc] initWithFrame:CGRectMake(33,0,67,25)];
    UIButton *btnRight = [[UIButton alloc] initWithFrame:CGRectMake(100,0,67,25)];
    [btnLeft setImage:[UIImage imageNamed:@"leftmouse"] forState:UIControlStateHighlighted];
    [btnRight setImage:[UIImage imageNamed:@"rightmouse"] forState:UIControlStateHighlighted];
    
    [btnOption addTarget:self action:@selector(showOption:) forControlEvents:UIControlEventTouchUpInside];
    [btnLeft addTarget:self action:@selector(onMouseLeftDown) forControlEvents:UIControlEventTouchDown];
    [btnLeft addTarget:self action:@selector(onMouseLeftUp) forControlEvents:UIControlEventTouchUpInside];
    [btnRight addTarget:self action:@selector(onMouseRightDown) forControlEvents:UIControlEventTouchDown];
    [btnRight addTarget:self action:@selector(onMouseRightUp) forControlEvents:UIControlEventTouchUpInside];    
    [btnDPadSwitch addTarget:self action:@selector(onGamePadModeSwitch:) forControlEvents:UIControlEventTouchUpInside];

	// ---------------------------------------
    
    labCycles = [[UILabel alloc] initWithFrame:CGRectMake(272,6,43,12)];
    labCycles.backgroundColor = [UIColor clearColor];
    labCycles.textColor=[UIColor colorWithRed:74/255.0 green:1 blue:55/255.0 alpha:1];
    labCycles.font=[UIFont fontWithName:@"DBLCDTempBlack" size:12];
    labCycles.text=[self currentCycles];
    labCycles.textAlignment = NSTextAlignmentCenter;
    labCycles.baselineAdjustment=UIBaselineAdjustmentAlignCenters;
    fsIndicator = [FrameskipIndicator alloc];
    fsIndicator = [fsIndicator initWithFrame:CGRectMake(labCycles.frame.size.width-8,2,4,labCycles.frame.size.height-4)
                                       style:FrameskipIndicatorStyleVertical];
    fsIndicator.count = [self currentFrameskip];
    [labCycles addSubview:fsIndicator];

    [toolPanel addSubview:btnOption];
    [toolPanel addSubview:btnLeft];
    [toolPanel addSubview:btnRight];
    [toolPanel addSubview:labCycles];
    [_rootContainer addSubview:toolPanel];
    
    //---------------------------------------------------
    // 3. <null>
    //---------------------------------------------------
    
    //---------------------------------------------------
    // 4. <null>
    //---------------------------------------------------    
    
    //---------------------------------------------------
    // 6. Keyboard Show Button
    //---------------------------------------------------        
    btnShowKeyboard = [[UIButton alloc] initWithFrame:CGRectMake(190,0,44,25)];
	[btnShowKeyboard setImage:[UIImage imageNamed:@"kbd"] forState:UIControlStateNormal];
	[btnShowKeyboard addTarget:self action:@selector(togglePCKeyboard)
			  forControlEvents:UIControlEventTouchUpInside];
	[toolPanel addSubview:btnShowKeyboard];

    //---------------------------------------------------
    // 7. Banner at the top
    //---------------------------------------------------
    banner = [[UILabel alloc] initWithFrame:CGRectMake(0,0,viewRect.size.width,44)];
    banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    banner.backgroundColor = [UIColor clearColor];
    banner.text = @"Quit Game First";
    banner.textColor = [UIColor whiteColor];
    banner.textAlignment = NSTextAlignmentCenter;
    banner.alpha = 0;
   // [_rootContainer addSubview:banner];
    
    //---------------------------------------------------
    // 8. Navigation Bar Show Button
    //---------------------------------------------------  
#if 0
    if (!autoExit)
    {
        UIButton *btnTop = [[UIButton alloc] initWithFrame:CGRectMake(0,0,viewRect.size.width,30)];
        btnTop.backgroundColor=[UIColor clearColor];
        btnTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [btnTop addTarget:self action:@selector(showNavigationBar) forControlEvents:UIControlEventTouchUpInside];
        [_rootContainer addSubview:btnTop];
    }
#endif
    
    //---------------------------------------------------
    // 9. Fullscreen Panel
    //---------------------------------------------------     
    fullscreenPanel = [[FloatPanel alloc] initWithFrame:CGRectMake(0,0,480,32)];
    UIButton *btnExitFS = [[UIButton alloc] initWithFrame:CGRectMake(0,0,48,24)];
    btnExitFS.center=CGPointMake(44, 13);
    [btnExitFS setImage:[UIImage imageNamed:@"exitfull.png"] forState:UIControlStateNormal];
    [btnExitFS addTarget:self action:@selector(toggleScreenSize) forControlEvents:UIControlEventTouchUpInside];
    [fullscreenPanel.contentView addSubview:btnExitFS];


	// Create the button larger than the image, so we have a bigger clickable area,
	// while visually takes smaller place
	btnDPadSwitch = [[UIButton alloc] initWithFrame:CGRectMake(
		viewRect.size.width/2-38,
		viewRect.size.height-25,
		76,25)];
	btnDPadSwitch.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin
		| UIViewAutoresizingFlexibleLeftMargin
		| UIViewAutoresizingFlexibleRightMargin);
	UIImageView *imgTmp = [[UIImageView alloc] initWithFrame:CGRectMake(2, 2, 72, 16)];
	imgTmp.image = [UIImage imageNamed:@"switch"];
	[btnDPadSwitch addSubview:imgTmp];
	slider = [[UIImageView alloc] initWithFrame:CGRectMake(21,7,17,8)];
	slider.image = [UIImage imageNamed:@"switchbutton"];
	[btnDPadSwitch addSubview:slider];
	[btnDPadSwitch addTarget:self action:@selector(onGamePadModeSwitch:)
		forControlEvents:UIControlEventTouchUpInside];
	[_rootContainer addSubview:btnDPadSwitch];
   	btnDPadSwitch.hidden = YES;
}

- (void)toggleInputSource:(id)sender
{
    btnDPadSwitch.hidden = YES;
    UIButton *btn = (UIButton*)sender;
    InputSourceType type = (InputSourceType)[btn tag];
    if ([self isInputSourceActive:type]) {
        [self removeInputSource:type];
    } else {
        [self addInputSourceExclusively:type];
    }
    [self refreshFullscreenPanel];
}

- (void)refreshFullscreenPanel
{
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:16];
    
    UIImageView *cpuWindow = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,48,24)];
    cpuWindow.image = [UIImage imageNamed:@"cpuwindow.png"];
    
    if (labCycles2 == nil)
    {
        labCycles2 = [[UILabel alloc] initWithFrame:CGRectMake(1,8,43,12)];
        labCycles2.backgroundColor = [UIColor clearColor];
        labCycles2.textColor=[UIColor colorWithRed:74/255.0 green:1 blue:55/255.0 alpha:1];
        labCycles2.font=[UIFont fontWithName:@"DBLCDTempBlack" size:12];
        labCycles2.text=[self currentCycles];
        labCycles2.textAlignment= NSTextAlignmentCenter;
        labCycles2.baselineAdjustment=UIBaselineAdjustmentAlignCenters;
        fsIndicator2 = [FrameskipIndicator alloc];
        fsIndicator2 = [fsIndicator2 initWithFrame:CGRectMake(labCycles2.frame.size.width-8,2,4,labCycles2.frame.size.height-4)
                                             style:FrameskipIndicatorStyleVertical];
        fsIndicator2.count = [self currentFrameskip];
        [labCycles2 addSubview:fsIndicator2];
    }
    [cpuWindow addSubview:labCycles2];
    [items addObject:cpuWindow];

    for (int i = 0; i < NUM_BUTTON_INFO; i++) {
		if ([self isInputSourceEnabled:toggleButtonInfo[i].type]) {
            UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0,0,48,24)];
            NSString *on = [NSString stringWithUTF8String:toggleButtonInfo[i].onImageName];
            NSString *off = [NSString stringWithUTF8String:toggleButtonInfo[i].offImageName];
            BOOL active = [self isInputSourceActive:toggleButtonInfo[i].type];
            [btn setImage:[UIImage imageNamed:active?on:off] forState:UIControlStateNormal];
            [btn setImage:[UIImage imageNamed:on] forState:UIControlStateHighlighted];
            [btn setTag:toggleButtonInfo[i].type];
            [btn addTarget:self action:@selector(toggleInputSource:) forControlEvents:UIControlEventTouchUpInside];
            [items addObject:btn];
        }
    }
        
    UIButton *btnOption = [[UIButton alloc] initWithFrame:CGRectMake(380,0,48,24)];
    [btnOption setImage:[UIImage imageNamed:@"options.png"] forState:UIControlStateNormal];
    [btnOption addTarget:self action:@selector(showOption:) forControlEvents:UIControlEventTouchUpInside];
    [items addObject:btnOption];
    
    UIButton *btnRemap = [[UIButton alloc] initWithFrame:CGRectMake(340,0,20,24)];
//    [btnRemap setTitle:@"R" forState:UIControlStateNormal];
    [btnRemap setImage:[UIImage imageNamed:@"ic_bluetooth_white_18pt"] forState:UIControlStateNormal];
    [btnRemap addTarget:self action:@selector(openMfiMapper:) forControlEvents:UIControlEventTouchUpInside];
    [items addObject:btnRemap];
    
    [fullscreenPanel setItems:items];
}

- (void)hideNavigationBar
{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)showNavigationBar
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNavigationBar) object:nil];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self performSelector:@selector(hideNavigationBar) withObject:nil afterDelay:3];
}

-(void)updateFrameskip:(NSNumber*)skip
{
    fsIndicator.count=[skip intValue];
    fsIndicator2.count=[skip intValue];
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft||
        self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        [fullscreenPanel showContent];
    }
}

-(void)updateCpuCycles:(NSString*)title
{
    labCycles.text=title;
    labCycles2.text=title;
    if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft||
        self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        [fullscreenPanel showContent];    
    }
}

-(float)floatAlpha
{
    NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
    return 1-[defs floatForKey:kTransparency];    
}


-(void)updateAlpha
{
    float a = [self floatAlpha];
    kbd.alpha = a;
    if ([self isLandscape])
    {
        gamepad.alpha=a;
        gamepad.dpadMovable = DEFS_GET_INT(kDPadMovable);
    }
    numpad.alpha=a;
    btnMouseLeft.alpha=a;
    btnMouseRight.alpha=a;
}

- (void)createMouseButtons
{    
    // Left Mouse Button
    CGFloat vw = self.view.bounds.size.width;
    CGFloat vh = self.view.bounds.size.height;
    btnMouseLeft = [[UIButton alloc] initWithFrame:CGRectMake(vw-40,vh-160,48,80)];
    [btnMouseLeft setTitle:@"L" forState:UIControlStateNormal];
    [btnMouseLeft setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [btnMouseLeft setBackgroundImage:[UIImage imageNamed:@"longbutton.png"] 
                           forState:UIControlStateNormal];
    [btnMouseLeft addTarget:self
                    action:@selector(onMouseLeftDown)
          forControlEvents:UIControlEventTouchDown];
    [btnMouseLeft addTarget:self
                    action:@selector(onMouseLeftUp)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnMouseLeft];
    
    // Right Mouse Button
    btnMouseRight = [[UIButton alloc] initWithFrame:CGRectMake(vw-40,vh-240,48,80)];
    [btnMouseRight setTitle:@"R" forState:UIControlStateNormal];
    [btnMouseRight setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [btnMouseRight setBackgroundImage:[UIImage imageNamed:@"longbutton.png"] 
                            forState:UIControlStateNormal];
    [btnMouseRight addTarget:self
                     action:@selector(onMouseRightDown)
           forControlEvents:UIControlEventTouchDown];
    [btnMouseRight addTarget:self
                    action:@selector(onMouseRightUp)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnMouseRight];
    
    // Transparency
    btnMouseLeft.alpha=[self floatAlpha];
    btnMouseRight.alpha=[self floatAlpha];   
}


- (void)createNumpad
{
	if (numpad != nil) {
		[numpad removeFromSuperview];
		numpad = nil;
	}
	numpad = [[KeyboardView alloc] initWithType:KeyboardTypeNumPad frame:CGRectMake(self.view.bounds.size.width-160,120,160,200)];
	numpad.alpha = [self floatAlpha];
	[self.view addSubview:numpad];
	
	CGPoint ptOld = numpad.center;
	numpad.center = CGPointMake(ptOld.x, ptOld.y+numpad.frame.size.height);
	[UIView beginAnimations:nil context:NULL];
	numpad.center = ptOld;
	[UIView commitAnimations];
}

- (void)togglePCKeyboard
{
	if (kbd != nil)
	{
		[kbd removeFromSuperview];
		kbd = nil;
	}
	else
	{
		[self createPCKeyboard];
	}
}

- (void)createPCKeyboard
{
	if (kbd != nil)
	{
		[kbd removeFromSuperview];
		kbd = nil;
	}
	CGRect rect;
	if ([self isPortrait]) {
		rect = _rootContainer.bounds;
		float maxHeight = 300;
		rect.origin.y = 265;
		rect.size.height -= 265;
		if (rect.size.height > maxHeight) {
			rect.origin.y += rect.size.height - maxHeight;
			rect.size.height = maxHeight;
		}
	} else {
		rect = CGRectMake(0, self.view.bounds.size.height-175, self.view.bounds.size.width, 175);
	}
	kbd = [[KeyboardView alloc] initWithType:[self isPortrait]?KeyboardTypePortrait: KeyboardTypeLandscape
									   frame:rect];
	if ([self isLandscape]) {
		kbd.alpha = [self floatAlpha];
		[self.view addSubview:kbd];
	} else {
		kbd.backgroundColor = [[ColorTheme defaultTheme] colorByName:@"keyboard-background"];
		[_rootContainer addSubview:kbd];
	}
}

- (GamePadView*)createGamepadHelper:(GamePadMode)mod
{
	GamePadView * gpad = nil;
	
	CGRect rect = self.view.bounds;
	float maxSize = MAX(rect.size.width, rect.size.height);
	NSString *section = [NSString stringWithFormat:@"[gamepad.%@.%@]",
		maxSize > 480 ? @"iphone5" : @"iphone",
		[self isPortrait] ? @"portrait" : @"landscape"];
	
	NSString *ui_cfg = [[DOSPadEmulator sharedInstance] uiConfigFile];
	if (ui_cfg != nil)
	{
		gpad = [[GamePadView alloc] initWithConfig:ui_cfg section:section];
		gpad.mode = mod;
		DEBUGLOG(@"mode %d  rect: %f %f %f %f", gpad.mode,
				 gpad.frame.origin.x, gpad.frame.origin.y,
				 gpad.frame.size.width, gpad.frame.size.height);
		if ([self isPortrait])
		{
			CGRect grect = gpad.frame;
			CGRect r = _rootContainer.bounds;
			CGFloat maxHeight = 300;

			// In portrait mode, we assume gamepad width is 320
			grect.size.width = 320;
			grect.origin.x = (r.size.width - grect.size.width) / 2;
			
			if (r.size.height - grect.origin.y > maxHeight)
				grect.origin.y = r.size.height - maxHeight;
			gpad.frame = grect;
			NSAssert(toolPanel.superview == _rootContainer, @"Bad tool panel state");
			[_rootContainer insertSubview:gpad belowSubview:toolPanel];
		}
		else
		{
            // On landscape mode, adjust buttons on the right half of gamepad
            // as if the blank space in between expands.
            CGRect r = gpad.frame;
            float offset = rect.size.width - r.size.width;
            for (UIView *v in gpad.subviews) {
                if (v.center.x > r.size.width/2)
                    v.center = CGPointMake(v.center.x+offset, v.center.y);
            }
            r.size.width = rect.size.width;
            gpad.frame = r;
			gpad.dpadMovable = DEFS_GET_INT(kDPadMovable);
			[self.view insertSubview:gpad belowSubview:fullscreenPanel];
		}
	}
	return gpad;
}

- (void)createJoystick
{
	if (joystick != nil) {
		[joystick removeFromSuperview];
		joystick = nil;
	}
    joystick = [self createGamepadHelper:GamePadJoystick];
}

- (void)createGamepad
{
	if (gamepad != nil) {
		[gamepad removeFromSuperview];
		gamepad = nil;
	}
    btnDPadSwitch.hidden = NO;
    gamepad = [self createGamepadHelper:GamePadDefault];
}

- (void)removeGamepad
{
	if (gamepad != nil) {
		[gamepad removeFromSuperview];
		gamepad = nil;
	}
	btnDPadSwitch.hidden = YES;
}

- (void)updateBackground:(UIInterfaceOrientation)interfaceOrientation
{
}

- (void)updateBackground
{
    [self updateBackground:self.interfaceOrientation];
}

// Here is where the UI is defined. We decide what should be shown
// and where to show it.
- (void)updateUI
{
	if ([self isPortrait])
	{
		self.view.backgroundColor = HexColor(0x585458);

		_rootContainer.frame = [self safeRootRect];
		toolPanel.alpha=1;
        
		[self removeInputSource:InputSource_PCKeyboard];
		[self createGamepad];
		[fullscreenPanel removeFromSuperview];
		[self.view bringSubviewToFront:self.screenView];
	}
	else
	{
		self.view.backgroundColor = [UIColor blackColor];
		if (self.view != fullscreenPanel.superview)
		{
			CGRect rc = fullscreenPanel.frame;
			rc.origin.x = (self.view.bounds.size.width-rc.size.width)/2;
			fullscreenPanel.frame = rc;
			[self.view addSubview:fullscreenPanel];
			[fullscreenPanel showContent];
		}
		toolPanel.alpha=0;
		[self refreshFullscreenPanel];
        [self removeGamepad];
	}
	[self updateScreen];
	[self updateBackground];
	[self updateAlpha];
}

- (void)emulatorWillStart:(DOSPadEmulator *)emulator
{
	[super emulatorWillStart:emulator];
	[self updateUI];
}

// Place toolpanel right below the screen view
- (void)updateToolpanel
{
	CGRect screenRect = [_rootContainer convertRect:self.screenView.frame fromView:self.view];
	CGFloat scale = screenRect.size.width / toolPanel.bounds.size.width;
	CGFloat cx = CGRectGetMidX(screenRect);
	CGFloat cy = CGRectGetMaxY(screenRect) + toolPanel.bounds.size.height*scale/2;
	toolPanel.center = CGPointMake(cx,cy);
    toolPanel.transform = CGAffineTransformMakeScale(scale,scale);
	toolPanel.alpha = 1;
}

-(void)updateScreen
{
	CGRect viewRect = [self safeRootRect];
	if ([self isPortrait])
	{
		CGRect screenRect = [self putScreen:CGRectMake(viewRect.origin.x, viewRect.origin.y,
			viewRect.size.width, viewRect.size.width*3/4)];
		[self updateToolpanel];
	}
	else
	{
		[self putScreen:CGRectMake(viewRect.origin.x, viewRect.origin.y,
		 viewRect.size.width, shouldShrinkScreen ? viewRect.size.height-160 : viewRect.size.height)];
	}
}

- (void)toggleScreenSize
{
    shouldShrinkScreen = !shouldShrinkScreen;
    [self updateUI];
}

- (void)onGamePadModeSwitch:(id)btn
{
    mode = (mode == GamePadDefault ? GamePadJoystick : GamePadDefault);
    gamepad.mode = mode;
    
    [UIView beginAnimations:nil context:nil];
    
    if (mode == GamePadDefault)
    {
        slider.frame = CGRectMake(21,7,17,8);
    }
    else
    {
        slider.frame = CGRectMake(40,7,17,8);
    }

    [UIView commitAnimations];
}

- (void)viewDidLayoutSubviews
{
	NSLog(@"viewDidLayoutSubviews");
	[super viewDidLayoutSubviews];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    mode = GamePadDefault;
	[self initUI];
}


-(void) keyboardWillShow:(NSNotification *)note
{

}

-(void) keyboardWillHide:(NSNotification *)note
{
    // Do nothing..
}

-(void)viewWillAppear:(BOOL)animated
{    
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillShow:)
     name:UIKeyboardWillShowNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillHide:)
     name:UIKeyboardWillHideNotification
     object:nil];
        
    [self updateUI];
    
#ifdef IDOS
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait||
        self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        if (!autoExit)
        {        
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNavigationBar) object:nil];
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [self performSelector:@selector(hideNavigationBar) withObject:nil afterDelay:1];
        }
    }
#endif
}

-(void)viewWillDisappear:(BOOL)animated
{    
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillShowNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillHideNotification
     object:nil];    

#ifdef IDOS
    if (!autoExit)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNavigationBar) object:nil];
    }
#endif
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	// Do a clean rotate animation
	if ([self isLandscape] && ISPORTRAIT(toInterfaceOrientation))
	{
		[fullscreenPanel hideContent];
		[self removeInputSource:InputSource_NumPad];
		[self removeInputSource:InputSource_MouseButtons];
		[self removeInputSource:InputSource_PianoKeyboard];
	}
	[self removeInputSource:InputSource_PCKeyboard];
	[self removeInputSource:InputSource_GamePad];
	[self removeInputSource:InputSource_Joystick];
	toolPanel.alpha=0;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateUI];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (CGRect)safeRootRect
{
	if (@available(iOS 11.0, *)) {
		UIEdgeInsets i = self.view.safeAreaInsets;
		CGRect rect = self.view.bounds;
		rect.origin.x = i.left;
		rect.origin.y = i.top;
		rect.size.width -= i.left + i.right;
		rect.size.height -= i.top + i.bottom;
		return rect;
	} else {
		return self.view.bounds;
	}
}

- (void)viewSafeAreaInsetsDidChange
{
	NSLog(@"viewSafeAreaInsetsDidChange");
	[self updateUI];
	[super viewSafeAreaInsetsDidChange];
}


@end
