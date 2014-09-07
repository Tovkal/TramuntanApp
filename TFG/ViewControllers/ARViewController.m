//
//  AugmentedRealityViewController.m
//  TFG
//
//  Created by Tovkal on 19/07/14.
//  Copyright (c) 2014 Tovkal. All rights reserved.
//

#import "ARViewController.h"
#import "TargetShape.h"
#import "APBXMLElement.h"
#import "APBXMLParser.h"
#import "Mountain.h"

@interface ARViewController ()

//TODO temporary
@property (weak, nonatomic) CAShapeLayer *targetLayer;

//Array for XML Data
@property (strong, nonatomic) NSMutableArray *data;
@property (strong, nonatomic) NSArray *pointsOfInterest;

//Location
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *location;

//Motion
@property (strong, nonatomic) CMMotionManager *motionManager;

//POIs
@property (strong, nonatomic) NSMutableArray *pointsOfInterestCoordinates;

@end

@implementation ARViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	//ARView *arView = (ARView *)self.view;
	ARView *arView = [[ARView alloc] initWithFrame:self.view.frame];
	arView.delegate = self;
	self.view = arView;
	
	[self parseXML];
	[self initARData];
	
	arView.pointsOfInterest = self.pointsOfInterest;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self drawTarget];
	
	ARView *arView = (ARView *)self.view;
	[arView start];
	[self startLocation];
	[self startMotion];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	ARView *arView = (ARView *)self.view;
	[arView stop];
	[self startLocation];
	[self stopMotion];
}

#pragma mark - Target view TEMPORARY
//TODO Find better location for this
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self drawTarget];
}

- (void)drawTarget
{
	[self removeTarget];
	
	CGRect bounds = self.view.bounds;
    CGPoint center = CGPointMake((bounds.size.width/(2+bounds.origin.x)), (bounds.size.height/(2+bounds.origin.y)));
    CAShapeLayer *targetLayer = [TargetShape createTargetView:center];
    
    self.targetLayer = targetLayer;
    
    [self.view.layer addSublayer:targetLayer];
}

- (void)removeTarget
{
	if (self.targetLayer != nil) {
		[self.targetLayer removeFromSuperlayer];
	}
}

- (void)doNothing:(ARView *)arView{}

#pragma mark - XML Data

- (void)parseXML
{
	APBXMLParser *parser  = [[APBXMLParser alloc] init];
	APBXMLElement *rootElement = [parser parseXML:@"muntanyes_dev"];
	
	[self toArray:rootElement];
}

- (void)toArray:(APBXMLElement *)rootElement
{
	APBXMLElement *database = rootElement.subElements[1];
	
	for (APBXMLElement *mountainElement in database.subElements) {
		
		NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
		
		NSArray *attributeArray = @[@"name", @"alt_name", @"lat", @"lon", @"alt_lat", @"alt_lon", @"ele", @"alt_ele", @"postal_code"];
		
		for (APBXMLElement *attribute in mountainElement.subElements) {
			NSArray *values = [attribute.attributes allValues];
			NSInteger item = [attributeArray indexOfObject:values[0]];
			
			switch (item) {
				case 0: //name
				case 1: //alt_name
				case 2: //lat
				case 3: //lon
				case 4: //alt_lat
				case 5: //alt_lon
				case 6: //ele
				case 7: //alt_ele
					[dictionary setObject:attribute.text forKey:attributeArray[item]];
					break;
				case 8: //postal code
					[dictionary setObject:[attribute.text componentsSeparatedByString:@", "] forKey:attributeArray[item]];
					break;
				case NSIntegerMax: break;
				default:
					NSLog(@"Error converting XML Data to Array, attribute key not found: %@", attribute.attributes);
					break;
			}
		}
		
		[self.data addObject:dictionary];
		
	}
}

- (NSMutableArray *)data
{
	if (_data == nil) {
		_data = [[NSMutableArray alloc] init];
	}
	
	return _data;
}

- (void)initARData
{
	NSMutableArray *mountainArray = [[NSMutableArray alloc] init];
	for (NSDictionary *mountain in self.data) {
		
		UILabel *label = [[UILabel alloc] init];
		label.adjustsFontSizeToFitWidth = NO;
		label.opaque = NO;
		label.backgroundColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:0.5f];
		label.center = CGPointMake(200.0f, 200.0f);
		label.textAlignment = NSTextAlignmentCenter;
		label.textColor = [UIColor whiteColor];
		label.attributedText = [[NSAttributedString alloc] initWithString:[mountain valueForKey:@"name"]];
		CGSize size = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
		label.bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);

		
		Mountain *m = [[Mountain alloc] initWithName:[mountain valueForKey:@"name"]
									 alternativeName:[mountain valueForKey:@"alt_name"]
												 lat:[[mountain valueForKey:@"lat"] doubleValue]
												 lon:[[mountain valueForKey:@"lon"] doubleValue]
									  alternativeLat:[[mountain valueForKey:@"alt_lat"] doubleValue]
									  alternativeLon:[[mountain valueForKey:@"alt_lon"] doubleValue]
												 alt:[[mountain valueForKey:@"ele"] doubleValue]
								 alternativeAltitude:[[mountain valueForKey:@"alt_ele"] doubleValue]
										  postalCode:[mountain valueForKey:@"postal code"]
											withView:label];
		
		[mountainArray addObject:m];
	}
	
	self.pointsOfInterest = mountainArray;
}

#pragma mark - Core Location

- (void)startLocation
{
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	
	//TODO test if this filter is enough
	self.locationManager.distanceFilter = 10; //meters
	
	[self.locationManager startUpdatingLocation];

}

- (void)stopLocation
{
	[self.locationManager stopUpdatingLocation];
	self.locationManager = nil;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
	self.location = [locations lastObject];
	if (self.pointsOfInterest != nil) {
		[self updatePointsOfInterestCoordinates];
	}
}

#pragma mark - Core Motion

- (void)startMotion
{
	self.motionManager = [[CMMotionManager alloc] init];

	self.motionManager.deviceMotionUpdateInterval = 0.05; //seconds
	
	//Show calibration HUD when required.
	self.motionManager.showsDeviceMovementDisplay = YES;
	
	[self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXTrueNorthZVertical];
}

- (void)stopMotion
{
	[self.motionManager stopDeviceMotionUpdates];
	self.motionManager = nil;
}

- (CMAttitude *)fetchAttitude
{
	return self.motionManager.deviceMotion.attitude;
}

//From pARk
#pragma mark - POI management

- (void)updatePointsOfInterestCoordinates
{
	if (self.pointsOfInterestCoordinates != nil) {
		self.pointsOfInterestCoordinates = nil;
	}
	
	self.pointsOfInterestCoordinates = [[NSMutableArray alloc] initWithCapacity:[self.pointsOfInterest count]];
	
	int i = 0;
	
	double myX, myY, myZ;
	latLonToEcef(self.location.coordinate.latitude, self.location.coordinate.longitude, self.location.altitude, &myX, &myY, &myZ);
	
	// Array of NSData instances, each of which contains a struct with the distance to a POI and the
	// POI's index into placesOfInterest
	// Will be used to ensure proper Z-ordering of UIViews
	typedef struct {
		float distance;
		int index;
	} DistanceAndIndex;
	NSMutableArray *orderedDistances = [NSMutableArray arrayWithCapacity:[self.pointsOfInterest count]];
	
	// Compute the world coordinates of each place-of-interest
	for (Mountain *poi in self.pointsOfInterest) {
		double poiX, poiY, poiZ, e, n, u;
		
		latLonToEcef(poi.location.coordinate.latitude, poi.location.coordinate.longitude, poi.altitude, &poiX, &poiY, &poiZ);
		ecefToEnu(self.location.coordinate.latitude, self.location.coordinate.longitude, myX, myY, myZ, poiX, poiY, poiZ, &e, &n, &u);
		
		NSArray *coordinates = @[[NSNumber numberWithDouble:n], [NSNumber numberWithDouble:-e], [NSNumber numberWithDouble:u], [NSNumber numberWithDouble:1.0]];
		
		[self.pointsOfInterestCoordinates addObject:coordinates];
		
		// Add struct containing distance and index to orderedDistances
		DistanceAndIndex distanceAndIndex;
		distanceAndIndex.distance = sqrtf(n*n + e*e);
		distanceAndIndex.index = i;
		[orderedDistances insertObject:[NSData dataWithBytes:&distanceAndIndex length:sizeof(distanceAndIndex)] atIndex:i++];
	}
	
	// Sort orderedDistances in ascending order based on distance from the user
	[orderedDistances sortUsingComparator:(NSComparator)^(NSData *a, NSData *b) {
		const DistanceAndIndex *aData = (const DistanceAndIndex *)a.bytes;
		const DistanceAndIndex *bData = (const DistanceAndIndex *)b.bytes;
		if (aData->distance < bData->distance) {
			return NSOrderedAscending;
		} else if (aData->distance > bData->distance) {
			return NSOrderedDescending;
		} else {
			return NSOrderedSame;
		}
	}];
	
	ARView *view = (ARView *)self.view;
	
	// Add subviews in descending Z-order so they overlap properly
	for (NSData *d in [orderedDistances reverseObjectEnumerator]) {
		const DistanceAndIndex *distanceAndIndex = (const DistanceAndIndex *)d.bytes;
		Mountain *poi = (Mountain *)[self.pointsOfInterest objectAtIndex:distanceAndIndex->index];
		[view addSubview:poi.view];
	}
	
	view.pointsOfInterestCoordinates = self.pointsOfInterestCoordinates;

}

@end
