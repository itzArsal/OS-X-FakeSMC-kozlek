//
//  AppDelegate.m
//  HWMonitor
//
//  Created by kozlek on 22.06.12.
//  Copyright (c) 2012 Natan Zalkin <natan.zalkin@me.com>. All rights reserved.
//

#import "SystemUIPlugin.h"
#import "HWMonitorDefinitions.h"
#import "HWMonitorIcon.h"

#import "AppDelegate.h"

#define GetLocalizedString(key) \
[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

int CoreMenuExtraGetMenuExtra( CFStringRef identifier, void *menuExtra);
int CoreMenuExtraAddMenuExtra( CFURLRef path, int position, int whoCares, int whoCares2, int whoCares3, int whoCares4);
int CoreMenuExtraRemoveMenuExtra( void *menuExtra, int whoCares);

@implementation AppDelegate

@synthesize window = _window;
@synthesize menu = _menu;
@synthesize prefsController = _prefsController;
@synthesize graphsController = _graphsController;
@synthesize versionLabel = _versionLabel;
@synthesize toggleMenuButton = _toggleMenuButton;

@synthesize temperatureGraph = _temperatureGraph;
@synthesize frequencyGraph = _frequencyGraph;
@synthesize tachometerGraph = _tachometerGraph;
@synthesize voltageGraph = _voltageGraph;

@synthesize userInterfaceEnabled = _userInterfaceEnabled;

- (void)loadIconNamed:(NSString*)name
{
    if (!_icons)
        _icons = [[NSMutableDictionary alloc] init];
    
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"png"]];
    NSImage *altImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[name stringByAppendingString:@"_template"] ofType:@"png"]];
    
    [_icons setObject:[HWMonitorIcon iconWithName:name image:image alternateImage:altImage] forKey:name];
}

- (HWMonitorIcon*)getIconByName:(NSString*)name
{
    return [_icons objectForKey:name];
}

- (HWMonitorIcon*)getIconByGroup:(NSUInteger)group
{
    if ((group & kHWSensorGroupTemperature) || (group & kSMARTSensorGroupTemperature)) {
        return [self getIconByName:kHWMonitorIconTemperatures];
    }
    else if ((group & kSMARTSensorGroupRemainingLife) || (group & kSMARTSensorGroupRemainingBlocks)) {
        return [self getIconByName:kHWMonitorIconSsdLife];
    }
    else if (group & kHWSensorGroupFrequency) {
        return [self getIconByName:kHWMonitorIconFrequencies];
    }
    else if (group & kHWSensorGroupMultiplier) {
        return [self getIconByName:kHWMonitorIconMultipliers];
    }
    else if ((group & kHWSensorGroupPWM) || (group & kHWSensorGroupTachometer)) {
        return [self getIconByName:kHWMonitorIconTachometers];
    }
    else if (group & kHWSensorGroupVoltage) {
        return [self getIconByName:kHWMonitorIconVoltages];
    }
    
    return nil;
}

- (void)addItemsFromDictionary:(NSDictionary*)sensors inGroup:(NSUInteger)mainGroup
{
    HWMonitorIcon* icon = [self getIconByGroup:mainGroup];
    
    if (icon && ![_prefsController favoritesContainKey:[icon name]])
        [_prefsController addAvailableItem:GetLocalizedString([icon name]) icon:[icon image] key:[icon name]];
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    for (NSDictionary *item in [sensors allValues]) {
        NSUInteger group = [[item valueForKey:kHWMonitorKeyGroup] intValue];
        
        if (mainGroup & group)
            [items addObject:item];
    }
    
    [items sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSNumber *index1 = [obj1 valueForKey:kHWMonitorKeyIndex];
        NSNumber *index2 = [obj2 valueForKey:kHWMonitorKeyIndex];
        
        return [index1 compare:index2];
    }];
    
    for (NSDictionary *item in items) {

        NSString *title = [item valueForKey:kHWMonitorKeyTitle];
        NSString *value = [item valueForKey:kHWMonitorKeyValue];
        NSString *key = [item valueForKey:kHWMonitorKeyName];
        NSNumber *favorite = [item valueForKey:kHWMonitorKeyFavorite];
        
        icon = [self getIconByGroup:[[item valueForKey:kHWMonitorKeyGroup] intValue]];

        if (![favorite boolValue]) {
            NSMutableDictionary *availableItem = [_prefsController addAvailableItem];
            
            [availableItem setValuesForKeysWithDictionary:
             [NSDictionary dictionaryWithObjectsAndKeys:
              title, kHWMonitorKeyName,
              icon ? [icon image] : nil, kHWMonitorKeyIcon,
              value, kHWMonitorKeyValue,
              [item valueForKey:kHWMonitorKeyVisible], kHWMonitorKeyVisible,
              key, kHWMonitorKeyKey,
              nil]];
        }
        
        NSUInteger group = [[item valueForKey:kHWMonitorKeyGroup] intValue];
        
        if (group & kHWSensorGroupTemperature ||
            group & kSMARTSensorGroupTemperature ||
            group & kHWSensorGroupFrequency ||
            group & kHWSensorGroupTachometer ||
            group & kHWSensorGroupVoltage) {
            
            if ((_colorIndex + 1) * 0.07 > 1)
                _colorIndex = 0;
            NSColor *color = [NSColor colorWithCalibratedHue:(_colorIndex++) * 0.07 saturation:0.8 brightness:0.8 alpha:1.0];
            
            /*NSColor *color;
            CGFloat intensity;
            
            do {
                color = [_graphsColors colorWithKey:[[_graphsColors allKeys] objectAtIndex:_colorIndex++]];
                intensity = ([color redComponent] + [color greenComponent] + [color blueComponent]) / 3.0;
                
                if (_colorIndex >= [[_graphsColors allKeys] count])
                    _colorIndex = 0;
                
            } while (intensity <= 0.28 || intensity >= 0.7);*/
            
            [_graphsController addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          color, kHWMonitorKeyColor,
                                          [NSNumber numberWithBool:YES], kHWMonitorKeyEnabled,
                                          title, kHWMonitorKeyTitle,
                                          value, kHWMonitorKeyValue,
                                          key, kHWMonitorKeyKey,
                                          [NSNumber numberWithLong:mainGroup], kHWMonitorKeyGroup,
                                          nil]];
        }
    }
}

- (void)recieveItems:(NSNotification*)aNotification
{
    [_prefsController removeAllItems];
    
    [_graphsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[_graphsController arrangedObjects] count])]];
    
    [_prefsController setFirstFavoriteItem:GetLocalizedString(@"Menu bar items:") firstAvailableItem:GetLocalizedString(@"Available items:")];
    
    if ([aNotification object] && [aNotification userInfo]) {
        NSArray *favoritesList = [(NSString*)[aNotification object] componentsSeparatedByString:@","];
        NSDictionary *sensorsList = [aNotification userInfo];
        
        for (NSString *favoriteName in favoritesList) {
            
            HWMonitorIcon *icon = [self getIconByName:favoriteName];
            
            if (icon) {
                [_prefsController addFavoriteItem:GetLocalizedString([icon name]) icon:[icon image] key:[icon name]];
            }
            else {
                NSDictionary *item = [sensorsList valueForKey:favoriteName];
                
                if (item) {

                    icon = [self getIconByGroup:[[item valueForKey:@"Group"] intValue]];
                    
                    NSMutableDictionary *favoriteItem = [_prefsController addFavoriteItem];
                    
                    [favoriteItem setValuesForKeysWithDictionary:
                     [NSDictionary dictionaryWithObjectsAndKeys:
                      [item valueForKey:kHWMonitorKeyTitle], kHWMonitorKeyName,
                      icon ? [icon image] : nil, kHWMonitorKeyIcon,
                      [item valueForKey:kHWMonitorKeyValue], kHWMonitorKeyValue,
                      [item valueForKey:kHWMonitorKeyVisible], kHWMonitorKeyVisible,
                      [item valueForKey:kHWMonitorKeyName], kHWMonitorKeyKey,
                      nil]];
                }
            }
        }
        
        if (![_prefsController favoritesContainKey:kHWMonitorIconThermometer]) {
            
            HWMonitorIcon *icon = [self getIconByName:kHWMonitorIconThermometer];
            
            if ([[_prefsController getFavoritesItems] count] == 0)
                [_prefsController addFavoriteItem:GetLocalizedString([icon name]) icon:[icon image] key:[icon name]];
            else
                [_prefsController addAvailableItem:GetLocalizedString([icon name]) icon:[icon image] key:[icon name]];
        }
        
        _colorIndex = 0;
        
        [self addItemsFromDictionary:sensorsList inGroup:kHWSensorGroupTemperature];
        [self addItemsFromDictionary:sensorsList inGroup:kSMARTSensorGroupTemperature];
        [self addItemsFromDictionary:sensorsList inGroup:kSMARTSensorGroupRemainingLife];
        [self addItemsFromDictionary:sensorsList inGroup:kSMARTSensorGroupRemainingBlocks];
        [self addItemsFromDictionary:sensorsList inGroup:kHWSensorGroupMultiplier | kHWSensorGroupFrequency];
        [self addItemsFromDictionary:sensorsList inGroup:kHWSensorGroupPWM |kHWSensorGroupTachometer];
        [self addItemsFromDictionary:sensorsList inGroup:kHWSensorGroupVoltage];

        [self setUserInterfaceEnabled:[[NSObject alloc] init]];
    }
    else {
        [self setUserInterfaceEnabled:nil];
    }
}

-(void)valuesChanged:(NSNotification *)aNotification
{
    if ([aNotification userInfo]) {
        NSDictionary *list = [aNotification userInfo];
        
        for (NSMutableDictionary *item in [_prefsController arrangedObjects]) {
            
            NSString *key = [item objectForKey:kHWMonitorKeyKey];
            
            if ([[list allKeys] containsObject:key])
                [item setValue:[[list objectForKey:key] objectForKey:kHWMonitorKeyValue] forKey:kHWMonitorKeyValue];
        }
        
        for (NSMutableDictionary *item in [_graphsController arrangedObjects]) {
            
            NSString *key = [item objectForKey:kHWMonitorKeyKey];
            
            if ([[list allKeys] containsObject:key])
                [item setValue:[[list objectForKey:key] objectForKey:kHWMonitorKeyValue] forKey:kHWMonitorKeyValue];
        }
        
        [_temperatureGraph captureDataToHistoryFromDictionary:list];
        [_frequencyGraph captureDataToHistoryFromDictionary:list];
        [_tachometerGraph captureDataToHistoryFromDictionary:list];
        [_voltageGraph captureDataToHistoryFromDictionary:list];
    }
}

- (IBAction)toggleMenu:(id)sender
{
    void *menuExtra = nil;
    
    int error = CoreMenuExtraGetMenuExtra((__bridge CFStringRef)@"org.hwsensors.HWMonitorExtra", &menuExtra);
    
    if (error) {
        [sender setState:NO];
        return;
    }
    
    if ((int)menuExtra > 0) {
        CoreMenuExtraRemoveMenuExtra(menuExtra, 0);
        [self setUserInterfaceEnabled:nil];
        [sender setState:NO];
    }
    else {
        
        /*if (floor(NSAppKitVersionNumber) >= 900) {
            NSString *command = [NSString stringWithFormat:@"open -g %@" ,[[NSBundle mainBundle] pathForResource:@"HWMonitorExtra" ofType:@"menu"]];
            
			error = system([command cStringUsingEncoding:NSUTF16StringEncoding]); //nicier
		}
		else {
            
            NSString *command = [NSString stringWithFormat:@"open %@" ,[[NSBundle mainBundle] pathForResource:@"HWMonitorExtra" ofType:@"menu"]];
            
			error = system([command cStringUsingEncoding:NSUTF16StringEncoding]); //more compatible
        }*/
        
        //[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"MenuCracker" ofType:@"menu"]];
        
        //sleep(1);
        
        //[[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"HWMonitorExtra" ofType:@"menu"]];
 
        [sender setEnabled:NO];
        
        CoreMenuExtraAddMenuExtra((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"MenuCracker" ofType:@"menu"]], 0, 0, 0, 0, 0);
        CoreMenuExtraAddMenuExtra((__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"HWMonitorExtra" ofType:@"menu"]], 0, 0, 0, 0, 0);
        
        menuExtra = nil;
        error = 0;
        int count = 0;
        
        do {
            count++;
            sleep(1);
            error = CoreMenuExtraGetMenuExtra((__bridge CFStringRef)@"org.hwsensors.HWMonitorExtra", &menuExtra);
        } while ((!menuExtra || error) && count < 3);
        
        [sender setState:!error && menuExtra];
        [sender setEnabled:YES];
    }
}

-(IBAction)favoritesChanged:(id)sender
{   
    NSArray *favorites = [_prefsController getFavoritesItems];
    NSMutableArray *list = [[NSMutableArray alloc] init];
    
    for (NSDictionary *item in favorites)
        [list addObject:[item valueForKey:@"Key"]];
    
    NSString *favoritesList = [list componentsJoinedByString:@","];
    
    NSArray *items = [_prefsController getAllItems];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    
    for (NSDictionary *item in items) {
        NSNumber *visible = [item valueForKey:@"Visible"];
        
        if (visible) {
            [info setObject:visible forKey:[item valueForKey:@"Key"]];
        }
    }
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorFavoritesChanged object:favoritesList userInfo:info deliverImmediately:YES];
}

-(IBAction)useFahrenheitChanged:(id)sender
{
    NSMatrix *matrix = (NSMatrix*)sender;
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorUseFahrenheitChanged object:![[matrix cellAtRow:0 column:0] state] ? HWMonitorBooleanYES : HWMonitorBooleanNO userInfo:nil deliverImmediately:YES];
}

-(IBAction)useBigFontChanged:(id)sender
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorUseBigFontChanged object:[sender state] ? HWMonitorBooleanYES : HWMonitorBooleanNO userInfo:nil deliverImmediately:YES];
}

-(IBAction)useShadowEffectChanged:(id)sender
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorUseShadowsChanged object:[sender state] ? HWMonitorBooleanYES : HWMonitorBooleanNO userInfo:nil deliverImmediately:YES];
}

-(IBAction)showBSDNamesChanged:(id)sender
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorShowBSDNamesChanged object:[sender state] ? HWMonitorBooleanYES : HWMonitorBooleanNO userInfo:nil deliverImmediately:YES];
}

- (IBAction)graphsTableViewClicked:(id)sender
{
    [_temperatureGraph setNeedsDisplay:YES];
    [_frequencyGraph setNeedsDisplay:YES];
    [_tachometerGraph setNeedsDisplay:YES];
    [_voltageGraph setNeedsDisplay:YES];
}

-(void)localizeView:(NSView*)view
{
    if ([view isKindOfClass:[NSMatrix class]]) {
        NSMatrix *matrix = (NSMatrix*)view;
        
        NSUInteger row, column;
        
        for (row = 0 ; row < [matrix numberOfRows]; row++) {
            for (column = 0; column < [matrix numberOfColumns] ; column++) {
                NSButtonCell* cell = [matrix cellAtRow:row column:column];
                
                NSString *title = [cell title];
                
                [cell setTitle:GetLocalizedString(title)];
            }
        }
    }
    else if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton*)view;
        
        NSString *title = [button title];

        [button setTitle:GetLocalizedString(title)];
        [button setAlternateTitle:GetLocalizedString([button alternateTitle])];
    }
    else if ([view isKindOfClass:[NSTextField class]]) {
        NSTextField *textField = (NSTextField*)view;
        
        NSString *title = [[textField cell] title];
        
        [[textField cell] setTitle:GetLocalizedString(title)];
    }
    else if ([view isKindOfClass:[NSTabView class]]) {
        for (NSTabViewItem *item in [(NSTabView*)view tabViewItems])
            [item setLabel:GetLocalizedString([item label])];
    }
    else {
        if ([view respondsToSelector:@selector(setAlternateTitle:)]) {
            NSString *title = [(id)view alternateTitle];
            [(id)view setAlternateTitle:GetLocalizedString(title)];
        }
        if ([view respondsToSelector:@selector(setTitle:)]) {
            NSString *title = [(id)view title];
            [(id)view setTitle:GetLocalizedString(title)];
        }
    }
    
    for(NSView *subView in [view subviews])
        [self localizeView:subView];
}

-(void)localizeMenu:(NSMenu*)menu
{
    if (menu) {
        [menu setTitle:GetLocalizedString([menu title])];

        for (id subItem in [menu itemArray]) {
            if ([subItem isKindOfClass:[NSMenuItem class]]) {
                NSMenuItem* menuItem = subItem;
                
                [menuItem setTitle:GetLocalizedString([menuItem title])];
                
                if ([menuItem hasSubmenu])
                    [self localizeMenu:[menuItem submenu]];
            }
        }
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _graphsColors = [NSColorList colorListNamed:@"Crayons"];
    //_graphsColors = [[NSColorList availableColorLists] lastObject];
    
    //NSLog(@"color count: %ld", [[_graphsColors allKeys] count]);
    
    [_temperatureGraph setGroup:kHWSensorGroupTemperature | kSMARTSensorGroupTemperature];
    [_frequencyGraph setGroup:kHWSensorGroupFrequency];
    [_tachometerGraph setGroup:kHWSensorGroupTachometer];
    [_voltageGraph setGroup:kHWSensorGroupVoltage];
    
    void *menuExtra = nil;
    
    int error = CoreMenuExtraGetMenuExtra((__bridge CFStringRef)@"org.hwsensors.HWMonitorExtra", &menuExtra);
    
    [_toggleMenuButton setState:!error && menuExtra];
    
    _defaults = [[BundleUserDefaults alloc] initWithPersistentDomainName:@"org.hwsensors.HWMonitor"];
    
    // undocumented call
    [[NSUserDefaultsController sharedUserDefaultsController] _setDefaults:_defaults];
    
    [self loadIconNamed:kHWMonitorIconThermometer];
    [self loadIconNamed:kHWMonitorIconTemperatures];
    [self loadIconNamed:kHWMonitorIconHddTemperatures];
    [self loadIconNamed:kHWMonitorIconSsdLife];
    [self loadIconNamed:kHWMonitorIconMultipliers];
    [self loadIconNamed:kHWMonitorIconFrequencies];
    [self loadIconNamed:kHWMonitorIconTachometers];
    [self loadIconNamed:kHWMonitorIconVoltages];
    
    // Update version label
	NSString *version = [[NSString alloc] initWithFormat:@"v%@ (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    
    [_versionLabel setTitleWithMnemonic:version];
    
    [_window setTitle:GetLocalizedString([_window title])];
    
    [self localizeView:[_window contentView]];
    [self localizeMenu:_menu];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(recieveItems:) name:HWMonitorRecieveItems object: NULL];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(valuesChanged:) name:HWMonitorValuesChanged object: NULL];
    
    // Request items
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorRequestItems object:nil userInfo:nil deliverImmediately:YES];
    
    // Set active app status
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorAppIsActive object:HWMonitorBooleanYES userInfo:nil deliverImmediately:YES];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    // Set active app status
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:HWMonitorAppIsActive object:HWMonitorBooleanNO userInfo:nil deliverImmediately:YES];
    
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
