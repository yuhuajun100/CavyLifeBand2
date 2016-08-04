//
//  SCLocationManager.swift
//  GeocoderDemo
//
//  Created by xuemincai on 16/2/11.
//  Copyright © 2016年 xuemincai. All rights reserved.
//

import Foundation
import CoreLocation


/*
 功能：
 1.获取经纬度坐标
 
 SCLocationManager.shareInterface.startUpdateLocation({ coordinate in
 
 let parameter = [UserNetRequsetKey.Cmd.rawValue: UserNetRequestMethod.ReportCoordinate.rawValue,
 UserNetRequsetKey.UserID.rawValue: self.userId,
 UserNetRequsetKey.Longitude.rawValue: "\(coordinate.longitude)",
 UserNetRequsetKey.Latitude.rawValue: "\(coordinate.latitude)"]
 
 self.netPostRequestAdapter(CavyDefine.webApiAddr, para: parameter)
 
 }, cityComplete: nil)
 
 2.获取城市名称
 
 SCLocationManager.shareInterface.startUpdateLocation {
    Log.error("\($0)")
 }
 
 */


class SCLocationManager: NSObject, CLLocationManagerDelegate {
    
    static var shareInterface: SCLocationManager = SCLocationManager()
    
    var coordinate: CLLocationCoordinate2D?
    var locationManager: CLLocationManager!
    var complete: (CLLocationCoordinate2D -> Void)?
    var cityComplete: (String -> Void)?
    
    override init(){
        
        super.init()
        
       
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        locationManager.requestWhenInUseAuthorization()
        
    }
    
    /**
     更新GSP位置
     */
    func startUpdateLocation(complete: (CLLocationCoordinate2D -> Void)? = nil) {
        
        
        
        if CLLocationManager.authorizationStatus() == .Denied || CLLocationManager.authorizationStatus() == .Restricted {
            return
        }
        
        locationManager.startUpdatingLocation()
        self.complete = complete
    
    }
    
    func startUpdateLocationCity(cityComplete: (String -> Void)? = nil) {
        
        if CLLocationManager.authorizationStatus() == .Denied || CLLocationManager.authorizationStatus() == .Restricted {
            
            return
        }
        
        locationManager.startUpdatingLocation()
        self.cityComplete = cityComplete
        
    }
    
    /**
     接收GPS信息
     
     - parameter manager:
     - parameter locations:
     */
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        locationManager.stopUpdatingLocation()
        
        let geocoder = CLGeocoder()
        
        self.coordinate = locations[0].coordinate
        
        let locationObj = CLLocation(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(locationObj) { (placemark, error) -> Void in
            
            if error != nil {
                return
            }
            
            guard let placemarks = placemark else {
                return
            }
            
            _ = placemarks.map {
                self.cityComplete?($0.locality ?? "")
            }
            
        }
        
        translationToBaiduLocation(locations[0].coordinate) { [unowned self] (coordinate) in
            self.complete?(coordinate)
        }
        
    }
    
    /**
     转换苹果自带定位系统坐标至百度地图坐标
     
     - parameter coordinate:
     - parameter compeleteBolck: 
     */
    func translationToBaiduLocation(coordinate: CLLocationCoordinate2D, compeleteBolck: ((CLLocationCoordinate2D) -> Void)){
        
        let urlStr = "http://api.map.baidu.com/geoconv/v1/?coords=\(coordinate.longitude),\(coordinate.latitude)&ak=\(CavyDefine.baiduServerKey)&output=json"
        
        guard let url = NSURL.init(string: urlStr) else {
            compeleteBolck(coordinate)
            return
        }

        let request = NSURLRequest.init(URL: url)
        
        let queue = NSOperationQueue()
        
        NSURLConnection.sendAsynchronousRequest(request, queue: queue) { (response, data, error) in
            
            guard error == nil else {
                compeleteBolck(coordinate)
                return
            }
            
            guard data != nil else {
                compeleteBolck(coordinate)
                return
            }
            
            do {
                
                let jsonDic = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableLeaves)
                
                guard jsonDic["status"] as? Int == 0 else {
                    compeleteBolck(coordinate)
                    return
                }
                
                guard let result = jsonDic["result"] else {
                    compeleteBolck(coordinate)
                    return
                }
                
                guard let latitude = result![0]["y"] as? Double else {
                    compeleteBolck(coordinate)
                    return
                }
                
                guard let longitude = result![0]["x"] as? Double else {
                    compeleteBolck(coordinate)
                    return
                }
                
                
                let baiduCoordinate = CLLocationCoordinate2DMake(latitude, longitude)
                compeleteBolck(baiduCoordinate)
                
            } catch {
                compeleteBolck(coordinate)
            }

        }
        
    }

}
