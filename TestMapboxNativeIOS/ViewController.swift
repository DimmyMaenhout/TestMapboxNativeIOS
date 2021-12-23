//
//  ViewController.swift
//  TestMapboxNativeIOS
//
//  Created by Dimmy Maenhout on 20/12/2021.
//

import UIKit
import MapboxNavigation
import MapboxDirections
import MapboxCoreNavigation
import Mapbox

class ViewController: UIViewController {
    
    // MARK: - Properties
    
    private var route: Route?
    private var config: MapboxNavigationModuleConfig?
    private var mapView: NavigationMapView!
    
    private var enableBannerInstructions = false
    
    private let key = "pk.eyJ1Ijoic2VudGFzIiwiYSI6ImNramg0dmxhazk3eWEzMXFqbHY0cGc3ZWkifQ.B6kmxSEPA6W_lida1p6MWQ"
    
    private var navigationViewController: NavigationViewController!
    private var navigationService: MapboxNavigationService!
    private var navigationLocationManager: NavigationLocationManager!
    
    private var voiceController: RouteVoiceController!
    
    private let startCoordinate = CLLocationCoordinate2D(latitude: 4.375606188596978, longitude: 51.14121566158028)
    private let endCoordinate = CLLocationCoordinate2D(latitude: 4.441955998895892, longitude: 51.14179615098452)
    
    private var isNavigationActive: Bool = false {
        didSet {
            startNavigationButton.isHidden = isNavigationActive
        }
    }
    
    // MARK: - UI
    
    private let startNavigationButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start navigation", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.cornerRadius = 6
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.widthAnchor.constraint(equalToConstant: 150).isActive = true
        button.addTarget(self, action: #selector(startNavigation), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Init
    
    func initialize(_ accessToken: String, language: String, enableLogging: Bool) {
        config = MapboxNavigationModuleConfig(
            accessToken: accessToken,
            locale: language,
            enableLogging: enableLogging)
    }
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialize(key,
                   language: "nl_BE",
                   enableLogging: true)
        
        setupMapView()
        setupStartNavigationButton()
    }
    
    // MARK: - methods
    
    private func setupMapView() {
        mapView =  NavigationMapView(frame: view.bounds)
        mapView.delegate = self
        mapView.tintColor = .red
        mapView.attributionButton.tintColor = .lightGray
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        mapView.routeLineTracksTraversal = true
        mapView.tracksUserCourse = true
                
        view.addSubview(mapView)
    }
    
    private func setupStartNavigationButton() {
        view.addSubview(startNavigationButton)

        NSLayoutConstraint.activate([
            startNavigationButton.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -32),
            startNavigationButton.centerXAnchor.constraint(equalTo: mapView.centerXAnchor)
        ])
    }
    
    @objc private func startNavigation() {
        
        isNavigationActive = true
        
        // Define two waypoints to travel between
        let origin = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 51.14121566158028, longitude: 4.375606188596978))
        let destination = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 51.14179615098452, longitude: 4.441955998895892))
        
        mapView.setCenter(origin.coordinate, zoomLevel: 14.0, animated: false)

        // Set options
        let navigationRouteOptions = NavigationRouteOptions(waypoints: [origin, destination])
        
        // Request a route using MapboxDirections
        Directions.shared.calculate(navigationRouteOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                strongSelf.navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: navigationRouteOptions)
                strongSelf.navigationService.delegate = self
                let credentials = strongSelf.navigationService.directions.credentials
                strongSelf.voiceController = RouteVoiceController(navigationService: strongSelf.navigationService, accessToken: credentials.accessToken, host: credentials.host.absoluteString)
                
                strongSelf.mapView.show([route]) // route aan meegeven
                
                //self?.mapView.tracksUserCourse = true
                
                self?.mapView.userTrackingMode = .followWithCourse
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.navigationService.start()
                }
                
//                // Pass the generated route to the the NavigationViewController
//                self?.navigationViewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: navigationRouteOptions)
//                self?.navigationViewController.modalPresentationStyle = .fullScreen
//                self?.navigationViewController.routeLineTracksTraversal = true
//                self?.present((self?.navigationViewController)!, animated: true, completion: nil)
            }
        }
    }

    
}

extension ViewController {
    // MARK: - de/serialize
    
    private func convertObjectToJsonString<T: Encodable>(object: T) -> String? {
        do {
            let jsonData = try JSONEncoder().encode(object)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func convertJsonStringToMapboxRoute<T: Decodable>(jsonString: NSString) -> T? {
        do {
            let data: Data = jsonString.data(using: String.Encoding.utf8.rawValue)!
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            print("json: \(String(describing: json))")
            guard let json = json,
                  let tempRouteOptions = json["routeOptions"] as? [String:Any] else { return nil }
            let coordinates = tempRouteOptions["coordinates"] as? [[Double]]
            guard let waypoints: [Waypoint] = coordinates?.map({ coors in
                Waypoint(coordinate: CLLocationCoordinate2D(latitude: coors[0], longitude: coors[1]))
            }) else { return nil }
            let routeOptions = RouteOptions(waypoints: waypoints)
            
            let decoder = JSONDecoder()
            decoder.userInfo[.options] = routeOptions

            let object = try? decoder.decode(T.self, from: data)
            print("object: \(String(describing: object))")
            return object
        } catch {
            print("convertJsonStringToObject, error: \(error)")
            return nil
        }
    }
    
    private func convertJsonStringToObject<T: Decodable>(jsonString: String) -> T? {
        do {
            let jsonData: Data = Data(jsonString.utf8)
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            return nil
        }
    }
}

extension ViewController: NavigationServiceDelegate {
    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        let routeProgressString = convertObjectToJsonString(object: progress)
        
//        print("line 184 didUpdate progress, routeProgress: \(routeProgressString)")\
        
        print(progress.currentLegProgress.fractionTraveled)
        
        mapView.updateUpcomingRoutePointIndex(routeProgress: progress)
        mapView.updateTraveledRouteLine(location.coordinate)
        mapView.updateRoute(progress)
        
        mapView.show([progress.route])
        
        mapView.updateCourseTracking(location: location, animated: true)
        
    }
    
    func navigationService(_ service: NavigationService, didPassVisualInstructionPoint instruction: VisualInstructionBanner, routeProgress: RouteProgress) {
        let routeProgressString = convertObjectToJsonString(object: routeProgress)
//        print("line 191 didPassVisualInstructionPoint, routeProgress: \(routeProgressString)")
    }
    
    func navigationService(_ service: NavigationService, didPassSpokenInstructionPoint instruction: SpokenInstruction, routeProgress: RouteProgress) {
        let routeProgressString = convertObjectToJsonString(object: routeProgress)
//        print("line 196 didPassSpokenInstructionPoint, routeProgress: \(routeProgressString)")
        
    }
    
//    func navigationService(_ service: NavigationService, willArriveAt waypoint: Waypoint, after remainingTimeInterval: TimeInterval, distance: CLLocationDistance) {
//
//        print()
//        print()
//    }
    
    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) -> Bool {
        
        print()
        isNavigationActive = false
        navigationService.stop()
        return true
    }
    
    func navigationService(_ service: NavigationService, didRefresh routeProgress: RouteProgress) {
        
        print("Refresh")
        print(routeProgress)
        //mapView.show([routeProgress.route])
        
        mapView.updateUpcomingRoutePointIndex(routeProgress: routeProgress)
//        mapView.updateTraveledRouteLine(navigationService.router.location?.coordinate)
        mapView.updateRoute(routeProgress)
    }
    
    func navigationService(_ service: NavigationService, willEndSimulating progress: RouteProgress, becauseOf reason: SimulationIntent) {
        print(reason)
        
    }
    
    func navigationService(_ service: NavigationService, didEndSimulating progress: RouteProgress, becauseOf reason: SimulationIntent) {
        print(reason)
    }
    
    
}

extension ViewController: MGLMapViewDelegate {
    
    
    
}


