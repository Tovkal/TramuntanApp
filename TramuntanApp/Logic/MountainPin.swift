//
//  MountainPin.swift
//  TFG
//
//  Created by Andrés Pizá on 19/4/15.
//  Copyright (c) 2015 Tovkal. All rights reserved.
//

import UIKit
import MapKit

class MountainPin : NSObject, MKAnnotation {
    
    var coordinate: CLLocationCoordinate2D
    var title: String
    var subtitle: String
    var url: String
    var distance: Double
    
    /**
    Initialitzer
    
    :param: coordinate Coordinates for the pin
    :param: title      Title for the pin
    :param: subtitle   Subtitle for the pin
    :param  url        Wiki url
    
    :returns: MKAnnotation pin
    */
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String, url: String, distance: Double) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.url = url
        self.distance = distance
    }
}
