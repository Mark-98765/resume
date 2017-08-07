//
//  MapViewController.swift
//  WhatsHere
//
//  Created by Mark Macpherson on 10/03/2017.
//  Copyright © 2017 UsefulTechnology. All rights reserved.
//

import UIKit
import MapKit

extension Constants {
    static let DefaultLatitudeDeltaForFirstSpan: Double = 1.0
    static let DefaultLongitudeDeltaForFirstSpan: Double = 1.0
    static let MinLatitudeDeltaSpan: Double = 0.01
    static let MinLongitudeDeltaSpan: Double = 0.01
    static let MaxLatitudeDeltaSpan: Double = 3.0
    static let MaxLongitudeDeltaSpan: Double = 3.0
    
    static let HotSpotText = "Hot Spot"
    
    static let PostSegueIdentifier = "PostSegueIdentifier"
    static let FacebookLoginSegueIdentifier = "FacebookLoginSegueIdentifier"
    
    // Testing...
    static let UseRectangleMapOverlay = false // false = use MapCircle
}

class MapViewController: UIViewController {
    
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var gotoCurrentLocationButton: UIButton!
    
    @IBAction func gotoCurrentLocationButtonAction(_ sender: UIButton) {
        gotoCurrentLocation()
        
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var postButton: UIButton!
    
    @IBAction func postButtonAction(_ sender: UIButton) {
        if let tbc = self.tabBarController as? TabBarViewController {
            tbc.postAction()
        }
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorContainerView: UIView!
    
    @IBOutlet weak var hotSpotButton: UIButton!
    @IBAction func hotSpotButtonAction(_ sender: UIButton) {
        hotSpotAction()
    }
    
    
    fileprivate struct Storyboard {
        static let ShowFirstLoad1SegueIdentifier = "ShowFirstLoad1SegueIdentifier"
        static let WhepAnnotationIdentifier = "WhepAnnotationIdentifier"
        static let ColorsViewHeightRestraintConstant: CGFloat = 20.0
        
        static let ColorLabelFrameHeight: CGFloat = 20.0
        static let ColorLabelFrameWidth: CGFloat = 20.0
        static let ColorDescriptionLabelFrameHeight: CGFloat = 20.0
        static let ColorDescriptionLabelFrameWidth: CGFloat = 35.0
        static let GapBetweenColorLabels: CGFloat = 3.0
        static let LegendViewGap: CGFloat = 10.0
    }
    
    let locationManager = CLLocationManager()
    let useSignificantLocationChanges = true
    
    var tabBarViewController: TabBarViewController? // Used to hold the wheps array
    
    var regionDidChangeAnimatedCompletion: (() -> Void)?
    
    var showPinAnnotationsForAllWheps = false // Testing stuff
    // var showOverlaysForWheps = true // Testing stuff
    // var showPinsWithinOverlays = false // Testing
    
    var showHotSpot = false
    var colorLegendView: UIView?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.postButton.isHidden = true // Not used anymore
        
        if let tbc = self.tabBarController as? TabBarViewController {
            self.tabBarViewController = tbc
        }
        
        self.tabBarItem.title = Constants.MapSearchText
        self.tabBarItem.image = UIImage(named: "401-globe")
        
        self.mapView.delegate = self
        
        self.titleLabel.attributedText = NSAttributedString(string: Constants.LocateText, attributes: navigationBarTitleTextAttributes())
        self.titleLabel.textColor = systemColor()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
        
        self.activityIndicator.stopAnimating() // Just in case...
        self.activityIndicator.color = systemColor()
        self.activityIndicatorContainerView.backgroundColor = .white
        self.activityIndicatorContainerView.isHidden = true
        self.activityIndicatorContainerView.layer.cornerRadius = Constants.ImageViewLayerCornerRadius
        self.activityIndicatorContainerView.clipsToBounds = true
        
        self.hotSpotButton.setTitle(Constants.HotSpotText, for: .normal)
        self.hotSpotButton.layer.cornerRadius = Constants.ImageViewLayerCornerRadius
        self.hotSpotButton.clipsToBounds = true
        setHotSpotButton()
        
        initLocationAndMap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !UserPrefs.hasShownFirstLoadViews() {
            // Set up the user prefs defaults
            UserPrefs.setDefaults()
            printLog("MapViewController viewDidAppear About to segue to FirstLoad1VC")
            performSegue(withIdentifier: Storyboard.ShowFirstLoad1SegueIdentifier, sender: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var shouldAutorotate: Bool {
        get {
            return super.shouldAutorotate // false
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if colorLegendView != nil {
            colorLegendView!.isHidden = true
        }
        
        let completion: (UIViewControllerTransitionCoordinatorContext) -> Void = { [weak self] (coordinatorContext) -> Void in
            guard let strongSelf = self else { return }
            printLog("viewWillTransition completion")
            if strongSelf.showHotSpot {
                strongSelf.reloadMapOverlayData()
            }
        }
        
        coordinator.animate(alongsideTransition: nil, completion: completion)
    }
    
    // MARK: - Init/Setup methods
    
    func initLocationAndMap() {
        if UserPrefs.hasShownFirstLoadViews() {
            printLog("MapViewController initLocationAndMap() setupLocationMonitoring()")
            setupLocationMonitoring()
        }
        
        if let currentMapRegion = UserPrefs.currentMapRegion() {
            printLog("MapViewController initLocationAndMap() got map region")
            self.mapView.setRegion(mapCoordinateRegionFrom(mapRegion: currentMapRegion), animated: true)
        } else {
            printLog("MapViewController initLocationAndMap() No map region")
            // No map region saved yet.
            if let lastLocation = UserPrefs.lastLocation() {
                printLog("MapViewController initLocationAndMap() No map region But got a location")
                // Got a location fix, construct a "default" map region and show that
                let span = MKCoordinateSpan(latitudeDelta: Constants.DefaultLatitudeDeltaForFirstSpan, longitudeDelta: Constants.DefaultLongitudeDeltaForFirstSpan)
                let center = CLLocationCoordinate2DMake(lastLocation.0, lastLocation.1)
                let coordinateRegion = MKCoordinateRegion(center: center, span: span)
                self.mapView.setRegion(coordinateRegion, animated: true)
            } else {
                printLog("MapViewController initLocationAndMap() No map region And no location as well")
                // Got nothing yet. Just let it fall through and let the user play with it.
            }
        }
    }
    
    func initWhepDensityColorLegend(whepGridArray: [WhepGrid]) {
        printLog("initWhepDensityColorLegend()")
        // The colors will depend on the max whep count...
        
        let descriptionFont = UIFont.systemFont(ofSize: 10.0)
        
        // Remove any old ones
        if self.colorLegendView != nil {
            self.colorLegendView!.isHidden = true
            for subview in colorLegendView!.subviews {
                if subview.isKind(of: WhepDensityColorLabel.self) {
                    subview.removeFromSuperview()
                } else if subview.isKind(of: WhepDensityColorDescriptionLabel.self) {
                    subview.removeFromSuperview()
                }
            }
            self.colorLegendView!.removeFromSuperview()
            self.colorLegendView = nil
        }
        
        // Just grab any one of the grid elements, they'll all know about the color distribution
        if whepGridArray.count == 0 {
            // Nothing to do here...
            return
        }
        
        let maxCount = whepGridArray[0].maxCountForAllGrids
        let colorsLegend = WhepDensityColor.whepDensityColorsLegend(maxCount: maxCount)
        printLog("initWhepDensityColorLegend() whepGridArray[0].maxCountForAllGrids=\(whepGridArray[0].maxCountForAllGrids)")
        if colorsLegend.count == 0 {
            // Problems...
            return
        }
        
        let legendView = UIView()
        let colorLabelFrame = CGRect(x: 0, y: 0, width: Storyboard.ColorLabelFrameWidth, height: Storyboard.ColorLabelFrameHeight)
        let colorDescriptionLabelFrame = CGRect(x: Storyboard.ColorLabelFrameWidth + Storyboard.GapBetweenColorLabels, y: 0, width: Storyboard.ColorDescriptionLabelFrameWidth, height: Storyboard.ColorDescriptionLabelFrameHeight)
        
        let startIndex = colorsLegend.count - 1
        printLog("initWhepDensityColorLegend() startIndex=\(startIndex)")
        for index in (0...startIndex).reversed() {
            let newColorLabel = WhepDensityColorLabel(color: colorsLegend[index].color.withAlphaComponent(WhepDensityColor.alpha))
            var originY: CGFloat = colorLabelFrame.origin.y + (CGFloat((startIndex - index)) * colorLabelFrame.size.height)
            
            newColorLabel.frame = CGRect(x: colorLabelFrame.origin.x, y: originY, width: colorLabelFrame.size.width, height: colorLabelFrame.size.height)
            
            let newColorDescriptionLabel = WhepDensityColorDescriptionLabel(text: colorsLegend[index].description, font: descriptionFont)
            originY = colorDescriptionLabelFrame.origin.y + (CGFloat((startIndex - index)) * colorDescriptionLabelFrame.size.height)
            newColorDescriptionLabel.frame = CGRect(x: colorDescriptionLabelFrame.origin.x, y: originY, width: colorDescriptionLabelFrame.size.width, height: colorDescriptionLabelFrame.size.height)
            
            legendView.addSubview(newColorLabel)
            legendView.addSubview(newColorDescriptionLabel)
        }
        
        let hotSpotButtonFrame = self.hotSpotButton.frame
        let legendViewHeight = Storyboard.ColorLabelFrameHeight * CGFloat(colorsLegend.count)
        let legendViewWidth = Storyboard.ColorLabelFrameWidth + Storyboard.ColorDescriptionLabelFrameWidth
        let legendViewY = hotSpotButtonFrame.origin.y - legendViewHeight - Storyboard.LegendViewGap // Add a gap too
        let legendViewX = hotSpotButtonFrame.origin.x + ((hotSpotButtonFrame.size.width - legendViewWidth)/2.0)
        let legendViewFrame = CGRect(x: legendViewX, y: legendViewY, width: legendViewWidth, height: legendViewHeight)
        legendView.frame = legendViewFrame
        legendView.backgroundColor = .white
        
        self.colorLegendView = legendView
        self.colorLegendView?.isHidden = true
        self.view.addSubview(self.colorLegendView!)
        
    }
    
    func showColorsLegend() {
        if self.colorLegendView != nil {
            self.colorLegendView!.isHidden = false
        }
    }
    
    func showHidePins() {
        // Show Pins. For testing only...
        showPinAnnotationsForAllWheps = !showPinAnnotationsForAllWheps
        if showPinAnnotationsForAllWheps {
            if let wheps = self.tabBarViewController?.wheps {
                addAnnotationsForAllWheps(wheps)
            }
        } else {
            removeAnnotations(type: .other)
        }
    }
    
    // MARK: - Notifications
    
    func applicationDidBecomeActive() {
        // We have to re-start the location monitoring
        printLog("MapViewController applicationDidBecomeActive()")
        if UserPrefs.hasShownFirstLoadViews() {
            printLog("MapViewController applicationDidBecomeActive() setupLocationMonitoring()")
            setupLocationMonitoring()
        }
    }
    
    // MARK: - Action methods
    
    func hotSpotAction() {
        showHotSpot = !showHotSpot
        setHotSpotButton()
        if showHotSpot {
            let makeHotSpotBiggerCompletion: ((Bool) -> Void)? = { (done) in
                UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.5, options: [.curveEaseIn], animations: {
                    // Put the source view back to normal, with a bounce
                    let transformScaled = CGAffineTransform
                        .identity
                        .scaledBy(x: 1.0, y: 1.0)
                    self.hotSpotButton.transform = transformScaled
                    // And show the menu view
                    UIView.animate(withDuration: 0.0, animations: {
                        self.showColorsLegend()
                        // self.reloadMapOverlayData()
                    })
                }, completion: { (done) in
                    // self.showColorsLegend()
                    self.reloadMapOverlayData()
                })
            }
            
            UIView.animate(withDuration: 0.5, animations: {
                // Make the view smaller
                let transformScaled = CGAffineTransform
                    .identity
                    .scaledBy(x: 0.3, y: 0.3)
                
                self.hotSpotButton.transform = transformScaled
            }, completion: makeHotSpotBiggerCompletion)
            
            // reloadMapOverlayData()
            // showColorsLegend()
        } else {
            removeOverlays()
            if self.colorLegendView != nil {
                self.colorLegendView!.isHidden = true
            }
        }
        // getWheps()
    }
    
    func setHotSpotButton() {
        if showHotSpot {
            self.hotSpotButton.backgroundColor = .green
        } else {
            self.hotSpotButton.backgroundColor = .red
        }
    }
    
    func showActivityIndicator() {
        self.activityIndicator.startAnimating()
        self.activityIndicatorContainerView.isHidden = false
    }
    
    func hideActivityIndicator() {
        self.activityIndicator.stopAnimating()
        self.activityIndicatorContainerView.isHidden = true
    }
    
    func gotoCurrentLocation() {
        if let lastLocation = UserPrefs.lastLocation() {
            let center = CLLocationCoordinate2DMake(lastLocation.0, lastLocation.1)
            let currentSpan = self.mapView.region.span
            let coordinateRegion = MKCoordinateRegion(center: center, span: currentSpan)
            self.mapView.setRegion(coordinateRegion, animated: true)
        }
    }
    
    // MARK: - Remove annotations and overlays methods
    
    func removeAnnotations(type: WhepAnnotationType) {
        
        var annotationsToRemove = [MKAnnotation]()
        for annotation in self.mapView.annotations {
            // if annotation.isKind(of: WhepAnnotation.self) {
            if let pinAnnotation = annotation as? WhepAnnotation {
                if pinAnnotation.whepAnnotationType == type {
                    annotationsToRemove.append(pinAnnotation)
                }
            }
        }
        self.mapView.removeAnnotations(annotationsToRemove)
    }
    
    func removeOverlays() {
        var overlaysToRemove = [MKOverlay]()
        for overlay in self.mapView.overlays {
            // We have 2 types, for testing...
            if overlay.isKind(of: WhepDensityOverlay.self) {
                overlaysToRemove.append(overlay)
            }
            if overlay.isKind(of: WhepDensityCircleOverlay.self) {
                overlaysToRemove.append(overlay)
            }
        }
        self.mapView.removeOverlays(overlaysToRemove)
        
        // And the annotations
        removeAnnotations(type: .selectedWhep)
        removeAnnotations(type: .withinOverlay) // Testing one
        removeAnnotations(type: .remainingWhep)
        removeAnnotations(type: .other) // Testing one
    }
    
    // MARK: - Add annotations methods
    
    func addAnnotationForWhep(_ whep: Whep) {
        if let latitude = whep.latitude, let longitude = whep.longitude {
            removeAnnotations(type: .selectedWhep)
            
            printLog("MapViewController addAnnotationForWhep() ")
            let selectedWhepAnnotation = WhepAnnotation(coordinate: CLLocationCoordinate2DMake(latitude, longitude))
            selectedWhepAnnotation.whepAnnotationType = .selectedWhep
            self.mapView.addAnnotation(selectedWhepAnnotation)
        }
    }
    
    func addAnnotationForWhepAndMoveToLocation(for whep: Whep) {
        if let latitude = whep.latitude, let longitude = whep.longitude {
            removeAnnotations(type: .selectedWhep)
            
            printLog("MapViewController addAnnotationForWhepAndMoveToLocation() ")
            let annotationCoordinate = CLLocationCoordinate2DMake(latitude, longitude)
            let selectedWhepAnnotation = WhepAnnotation(coordinate: annotationCoordinate)
            selectedWhepAnnotation.whepAnnotationType = .selectedWhep
            
            regionDidChangeAnimatedCompletion = { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.mapView.addAnnotation(selectedWhepAnnotation)
            }
            
            var region = self.mapView.region
            region.center = annotationCoordinate
            self.mapView.setRegion(region, animated: true)
        }
    }
    
    func addAnnotationsForWhepsWithinOverlays(_ wheps: [Whep]) {
        // These are for testing only
        removeAnnotations(type: .withinOverlay)
        for whep in wheps {
            if let latitude = whep.latitude, let longitude = whep.longitude {
                let selectedWhepAnnotation = WhepAnnotation(coordinate: CLLocationCoordinate2DMake(latitude, longitude))
                selectedWhepAnnotation.whepAnnotationType = .withinOverlay
                
                selectedWhepAnnotation.title = "\(whep.whepId!)"
                var latitude = whep.latitude!
                var longitude = whep.longitude!
                selectedWhepAnnotation.subtitle = "\(latitude.roundToPlaces(3))/\(longitude.roundToPlaces(3))"
                
                self.mapView.addAnnotation(selectedWhepAnnotation)
            }
        }
    }
    
    func addAnnotationsForRemainingWheps(_ wheps: [Whep]) {
        // These are for testing only
        removeAnnotations(type: .remainingWhep)
        for whep in wheps {
            if let latitude = whep.latitude, let longitude = whep.longitude {
                let selectedWhepAnnotation = WhepAnnotation(coordinate: CLLocationCoordinate2DMake(latitude, longitude))
                selectedWhepAnnotation.whepAnnotationType = .remainingWhep
                
                selectedWhepAnnotation.title = "\(whep.whepId!)"
                var latitude = whep.latitude!
                var longitude = whep.longitude!
                selectedWhepAnnotation.subtitle = "\(latitude.roundToPlaces(3))/\(longitude.roundToPlaces(3))"
                
                self.mapView.addAnnotation(selectedWhepAnnotation)
            }
        }
    }
    
    func addAnnotationsForAllWheps(_ wheps: [Whep]) {
        removeAnnotations(type: .selectedWhep)
        removeAnnotations(type: .withinOverlay)
        removeAnnotations(type: .remainingWhep)
        removeAnnotations(type: .other)
        for whep in wheps {
            if let latitude = whep.latitude, let longitude = whep.longitude {
                let selectedWhepAnnotation = WhepAnnotation(coordinate: CLLocationCoordinate2DMake(latitude, longitude))
                selectedWhepAnnotation.whepAnnotationType = .other
                self.mapView.addAnnotation(selectedWhepAnnotation)
            }
        }
    }

    // MARK: - Location
    
    func setupLocationMonitoring() {
        
        if !CLLocationManager.locationServicesEnabled() {
            printLog("MapViewController setupLocation !CLLocationManager.locationServicesEnabled()")
            return
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        let status = CLLocationManager.authorizationStatus()
        printLog("MapViewController setupLocation status=\(status.rawValue)")
        if status != .denied {
            if status != .authorizedWhenInUse {
                printLog("MapViewController setupLocation status != .authorizedWhenInUse")
                locationManager.requestWhenInUseAuthorization()
            } else {
                printLog("MapViewController setupLocation locationManager.requestLocation()")
                locationManager.requestLocation()
                
                if self.useSignificantLocationChanges {
                    printLog("MapViewController locationManager.startMonitoringSignificantLocationChanges()")
                    if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                        locationManager.startMonitoringSignificantLocationChanges()
                    } else {
                        printLog("MapViewController locationManager.significantLocationChangeMonitoringAvailable() NOT AVAILABLE")
                    }
                } else {
                    // locationManager.requestLocation()
                    locationManager.startUpdatingLocation()
                }
            }
        } else {
            // denied. Do nothing.
        }
    }
    
    // MARK: - Data processing
    
    func reloadMapOverlayData() {
        printLog("MapViewController: reloadMapOverlayData()")
        removeOverlays()
        
        guard let wheps = self.tabBarViewController?.wheps else { return }
        printLog("MapViewController: reloadMapOverlayData() wheps.count=\(wheps.count)")
        
        guard let mapRegion = UserPrefs.currentMapRegion() else { printLog("MapViewController reloadMapOverlayData() no saved map region"); return }
        
        guard var whepGridArray = makeWhepDensityGrid(for: mapRegion, using: wheps) else { printLog("MapViewController makeWhepDensityGrid() returned nil"); return }
        
        // We need to know the weight of counts against the max count for all the grids
        // so we can calulate the relative fillColor schemes
        
        let maxCountForAllGrids = whepGridArray.reduce(0) { (maxCount, whepGrid) -> Int in
            if whepGrid.count > maxCount {
                return whepGrid.count
            }
            return maxCount
        }
        
        printLog("MapViewController reloadMapOverlayData() maxCountForAllGrids\(maxCountForAllGrids)")
        
        // Add the overlays
        // And add annotations for all the pins within the overlays (testing)
        var allWhepsInAllGrids = [Whep]()
        // And we need to update the whepGridArray (to get the maxCountForAllGrids in there)
        var updatedWhepGridArray = [WhepGrid]()
        
        for whepGrid in whepGridArray {
            var whepGridToAdd = whepGrid
            whepGridToAdd.maxCountForAllGrids = maxCountForAllGrids
            
            // Swap between, for testing...
            if Constants.UseRectangleMapOverlay {
                // MKPolygon
                var coordinates = whepGrid.polygonCoordinates()
                let whepDensityOverlay = WhepDensityOverlay(coordinates: &coordinates, count: coordinates.count)
                whepDensityOverlay.whepGrid = whepGridToAdd
                mapView.add(whepDensityOverlay)
            } else {
                // MKCircle
                let whepDensityOverlay = WhepDensityCircleOverlay(center: whepGridToAdd.center, radius: whepGridToAdd.radius)
                whepDensityOverlay.whepGrid = whepGridToAdd
                mapView.add(whepDensityOverlay)
            }
            
            updatedWhepGridArray.append(whepGridToAdd)
            
            // Testing...
            // Note. We create the grid by removing wheps after each pass through, so there shouldn't be duplicate wheps.
            let allWhepsInThisGrid = [whepGrid.centerWhep] + whepGrid.otherWheps
            allWhepsInAllGrids += allWhepsInThisGrid
        }
        
        // Replace with the updated one
        whepGridArray = updatedWhepGridArray
        
        // Print these, for testing...
        allWhepsInAllGrids.sort {
            if $0.whepId == nil || $1.whepId == nil {
                return false
            }
            return $0.whepId! < $1.whepId!
        }
        
        // Now we know how the grid looks we can setup the color legend
        initWhepDensityColorLegend(whepGridArray: whepGridArray)
        if showHotSpot {
            // And show it, if required
            showColorsLegend()
        }
        
        printLog("All Wheps In All Grids count=\(allWhepsInAllGrids.count) Start ---------------------------")
        for whep in allWhepsInAllGrids {
            printLog("whepId=\(whep.whepId!)")
        }
        printLog("All Wheps In All Grids End ---------------------------")
        
    }
    
    func makeWhepDensityGrid(for mapRegion: MapRegion, using wheps: [Whep]) -> [WhepGrid]? {
        return makeWhepDensityGridRemovingAlreadyConsideredWheps(for: mapRegion, using: wheps)
    }
    
    func makeWhepDensityGridRemovingAlreadyConsideredWheps(for mapRegion: MapRegion, using wheps: [Whep]) -> [WhepGrid]? {
        
        // This method repeatedly goes through the wheps in the array, finding the one with the most counts (around it)
        // then removing ALL thos wheps and going through all the remaining. Etc. 
        // Until we reach maxLoopCycles or run out of wheps (<2)
        guard let latitude_ll = mapRegion.latitude_ll, let latitude_ur = mapRegion.latitude_ur,
            let longitude_ll = mapRegion.longitude_ll, let longitude_ur = mapRegion.longitude_ur else { return nil }
        
        let maxWhepsToCount: Int = 1 // 2
        let maxLoopCycles: Int = 2 // 15 // The max number of overlays on the map
        let deltaFraction = 0.15 // 0.20 // Percent
        let maxDelta = 0.1 // The maximum delta allowed for the smallest delta
        
        if wheps.count < maxWhepsToCount {
            return nil
        }
        
        // Calculate the deltas for the region
        let latitudeDelta = latitude_ur - latitude_ll
        var longitudeDelta = longitude_ur - longitude_ll
        if longitude_ll > longitude_ur {
            // Straddles 180
            longitudeDelta = (180.0 - longitude_ll) + (longitude_ur + 180.0)
        }
        
        var finalWhepGrid = [WhepGrid]()
        
        var gridLatitudeDelta = latitudeDelta * deltaFraction
        var gridLongitudeDelta = longitudeDelta * deltaFraction
        
        printLog("makeWhepDensityGrid() Original gridLatitudeDelta=\(gridLatitudeDelta) gridLongitudeDelta=\(gridLongitudeDelta)")
        
        let smallestDelta = min(gridLatitudeDelta, gridLongitudeDelta)
        if  smallestDelta > maxDelta {
            // The smallest delta is too big
            let ratio = maxDelta / smallestDelta
            gridLatitudeDelta = gridLatitudeDelta * ratio
            gridLongitudeDelta = gridLongitudeDelta * ratio
            printLog("makeWhepDensityGrid() After gridLatitudeDelta=\(gridLatitudeDelta) gridLongitudeDelta=\(gridLongitudeDelta)")
        }
        
        var remainingWheps = wheps // Start with all of them
        var whepsToCheck = remainingWheps
        
        printLog("makeWhepDensityGrid() START remainingWheps.count=\(remainingWheps.count)")
        
        for index in 1...maxLoopCycles { // But we may not get to the end
            printLog("makeWhepDensityGrid() index=\(index)")
            var tempWhepGrid = [WhepGrid]()
            
            // Cycle through the wheps one by one, capturing all the wheps within the deltas of the center whep
            
            printLog("makeWhepDensityGrid() index=\(index) whepsToCheck.count=\(whepsToCheck.count)")
            for whep in whepsToCheck {
                guard let whepId = whep.whepId else { continue }
                guard let latitude = whep.latitude, let longitude = whep.longitude else { continue }
                let whepGridLatitude_ll = latitude - (gridLatitudeDelta/2.0)
                let whepGridLatitude_ur = latitude + (gridLatitudeDelta/2.0)
                let whepGridLongitude_ll = longitude - (gridLongitudeDelta/2.0)
                let whepGridLongitude_ur = longitude + (gridLongitudeDelta/2.0)
                
                // Get the wheps within the bounds of the deltas above (but not including the center whep)
                let otherWheps = remainingWheps.filter({ (remainingWhep) -> Bool in
                    guard let remainingWhepId = remainingWhep.whepId else { return false }
                    guard let remainingWhepLatitude = remainingWhep.latitude, let remainingWhepLongitude = remainingWhep.longitude else { return false }
                    if remainingWhepId == whepId {
                        return false
                    }
                    if remainingWhepLatitude > whepGridLatitude_ll &&
                        remainingWhepLatitude <= whepGridLatitude_ur &&
                        remainingWhepLongitude > whepGridLongitude_ll &&
                        remainingWhepLongitude <= whepGridLongitude_ur {
                        return true
                    }
                    return false
                })
                
                let wepGrid = WhepGrid(centerWhep: whep, otherWheps: otherWheps, centerLatitude: latitude, centerLongitude: longitude, latitudeDelta: gridLatitudeDelta, longitudeDelta: gridLongitudeDelta)
                tempWhepGrid.append(wepGrid)
            }
            
            printLog("makeWhepDensityGrid() index=\(index) tempWhepGrid.count=\(tempWhepGrid.count)")
            
            // So, tempWhepGrid contains a record for EVERY whep (remainingWheps).
            
            // Find which one of these has the greatest "count" on wheps (count may include views too, remember)
            guard let maxCountWhepGrid = WhepGrid.getGridWithMaxCount(tempWhepGrid) else {
                // May be nil!!!. Finished in that case!
                // return finalWhepGrid
                printLog("makeWhepDensityGrid() index=\(index) maxCountWhepGrid == nil. Break Loop")
                break
            }
            
            printLog("makeWhepDensityGrid() index=\(index) maxCountWhepGrid.count=\(maxCountWhepGrid.count) centerWhep.whepId=\(String(describing: maxCountWhepGrid.centerWhep.whepId))")
            
            // If the max count is 1, we're done! (And don't add this one to the finalWhepGrid array)
            if maxCountWhepGrid.count == 1 {
                printLog("makeWhepDensityGrid() index=\(index) maxCountWhepGrid.count == 1. Break Loop")
                break
            }
            
            // Add this one to the final whep grid array
            finalWhepGrid.append(maxCountWhepGrid)
            
            // Remove all the wheps in the finalWhepGrid array of WhpeGrids from the wheps remaining for consideration
            let tempRemainingWheps = WhepGrid.removeAllWheps(from: remainingWheps, using: finalWhepGrid)
            remainingWheps = tempRemainingWheps
            printLog("makeWhepDensityGrid() index=\(index) remainingWheps.count=\(remainingWheps.count)")
            
            // If there's only 1 left, we're done!
            if remainingWheps.count < maxWhepsToCount {
                printLog("makeWhepDensityGrid() index=\(index) remainingWheps.count < maxWhepsToCount. Break Loop")
                break
            }
            
            // Reset the array
            whepsToCheck = remainingWheps
            
            // Go around again
            // index += 1
        }
        
        printLog("makeWhepDensityGrid() END index=\(index) finalWhepGrid.count=\(finalWhepGrid.count)")
        return finalWhepGrid
    }
    
    func makeWhepDensityGridNotRemovingWheps(for mapRegion: MapRegion, using wheps: [Whep]) -> [WhepGrid]? {
        
        // This method only goes through the whep array once, calculating the counts of wheps around
        // every whep and then displaying the ones with the most counts (maxLoopCycles)
        
        guard let latitude_ll = mapRegion.latitude_ll, let latitude_ur = mapRegion.latitude_ur,
            let longitude_ll = mapRegion.longitude_ll, let longitude_ur = mapRegion.longitude_ur else { return nil }
        
        let maxWhepsToCount: Int = 1 // 2
        let maxLoopCycles: Int = 2 // 10 // The max number of overlays on the map
        let deltaFraction = 0.15 // 0.20 // Percent
        
        
        if wheps.count < maxWhepsToCount { // ???
            return nil
        }
        
        // Calculate the deltas for the region
        let latitudeDelta = latitude_ur - latitude_ll
        var longitudeDelta = longitude_ur - longitude_ll
        if longitude_ll > longitude_ur {
            // Straddles 180
            longitudeDelta = (180.0 - longitude_ll) + (longitude_ur + 180.0)
        }
        
        var finalWhepGrid = [WhepGrid]()
        
        let gridLatitudeDelta = latitudeDelta * deltaFraction
        let gridLongitudeDelta = longitudeDelta * deltaFraction
        
        let remainingWheps = wheps // Start with all of them
        let whepsToCheck = remainingWheps
        
        printLog("makeWhepDensityGrid() START remainingWheps.count=\(remainingWheps.count)")
        
        var tempWhepGrid = [WhepGrid]()
        
        // Cycle through the wheps one by one, capturing all the wheps within the deltas of the center whep
        
        printLog("makeWhepDensityGrid() whepsToCheck.count=\(whepsToCheck.count)")
        for whep in whepsToCheck {
            guard let whepId = whep.whepId else { continue }
            guard let latitude = whep.latitude, let longitude = whep.longitude else { continue }
            let whepGridLatitude_ll = latitude - (gridLatitudeDelta/2.0)
            let whepGridLatitude_ur = latitude + (gridLatitudeDelta/2.0)
            let whepGridLongitude_ll = longitude - (gridLongitudeDelta/2.0)
            let whepGridLongitude_ur = longitude + (gridLongitudeDelta/2.0)
            
            // Get the wheps within the bounds of the deltas above (but not including the center whep)
            let otherWheps = remainingWheps.filter({ (remainingWhep) -> Bool in
                guard let remainingWhepId = remainingWhep.whepId else { return false }
                guard let remainingWhepLatitude = remainingWhep.latitude, let remainingWhepLongitude = remainingWhep.longitude else { return false }
                if remainingWhepId == whepId {
                    return false
                }
                if remainingWhepLatitude > whepGridLatitude_ll &&
                    remainingWhepLatitude <= whepGridLatitude_ur &&
                    remainingWhepLongitude > whepGridLongitude_ll &&
                    remainingWhepLongitude <= whepGridLongitude_ur {
                    return true
                }
                return false
            })
            
            let wepGrid = WhepGrid(centerWhep: whep, otherWheps: otherWheps, centerLatitude: latitude, centerLongitude: longitude, latitudeDelta: gridLatitudeDelta, longitudeDelta: gridLongitudeDelta)
            tempWhepGrid.append(wepGrid)
        }
        
        printLog("makeWhepDensityGrid() tempWhepGrid.count=\(tempWhepGrid.count)")
        
        // So, tempWhepGrid contains a record for EVERY whep (remainingWheps).
        
        // Find which one of these has the greatest "count" on wheps (count may include views too, remember)
        let maxCountWhepGrid = WhepGrid.getGridWithMaxCount(tempWhepGrid)
        
        printLog("makeWhepDensityGrid() maxCountWhepGrid.count=\(String(describing: maxCountWhepGrid?.count))")
        
        // If the max count is 1, we're done! (And don't add this one to the finalWhepGrid array)
        if maxCountWhepGrid == nil || maxCountWhepGrid!.count == 1 {
            printLog("makeWhepDensityGrid() maxCountWhepGrid.count == 1. Break Loop")
            // break
        }
        
        // Now, out of tempWhepGrid (which is ALL wheps) we only want to display the top few of them (maxLoopCycles)
        // Sort them first
        tempWhepGrid.sort {
            $0.count >= $1.count
        }
        
        // Get the first maxLoopCycles of them
        var index: Int = 0
        for orderedWhepGrid in tempWhepGrid {
            if index >= maxLoopCycles {
                break
            }
            finalWhepGrid.append(orderedWhepGrid)
            index += 1
        }
        
        printLog("makeWhepDensityGrid() END index=\(index) finalWhepGrid.count=\(finalWhepGrid.count)")
        return finalWhepGrid
    }

    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var destination = segue.destination
        if let identifier = segue.identifier {
            switch identifier {
            case Constants.PostSegueIdentifier:
                printLog("PostSegueIdentifier")
                if let navCon = destination as? UINavigationController {
                    destination = navCon.visibleViewController!
                }
            default: break
            }
        }
    }
    
    @IBAction func prepareForUnwindFromFirstLoad1(_ segue: UIStoryboardSegue) {
        printLog("prepareForUnwindFromFirstLoad1")
    }
    
}

// MARK: - Extension - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        printLog("MapViewController regionDidChangeAnimated -----------------")
        
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedWhenInUse && !UserPrefs.hasObtainedFirstLocationFix() {
            printLog("MapViewController regionDidChangeAnimated No location fix")
            return
        }
        
        var coordinateRegionThatFits = mapView.region // We may need to change this
        
        printLog("MapViewController regionDidChangeAnimated mapViewRegion Span=\(coordinateRegionThatFits.span)")
        
        if coordinateRegionThatFits.span.latitudeDelta > Constants.MaxLatitudeDeltaSpan {
            // Too big. Zoom in.
            printLog("MapViewController regionDidChangeAnimated mapRegion is too big")
            let span = MKCoordinateSpan(latitudeDelta: Constants.MaxLatitudeDeltaSpan, longitudeDelta: Constants.MaxLongitudeDeltaSpan)
            let coordinateMapRegionFirstAttempt = MKCoordinateRegion(center: coordinateRegionThatFits.center, span: span)
            coordinateRegionThatFits = self.mapView.regionThatFits(coordinateMapRegionFirstAttempt)
            printLog("MapViewController regionDidChangeAnimated coordinateRegionThatFits Span=\(coordinateRegionThatFits.span)")
            printLog("MapViewController regionDidChangeAnimated About to set region to coordinateRegionThatFits")
            self.mapView.setRegion(coordinateRegionThatFits, animated: true)
        } else if coordinateRegionThatFits.span.latitudeDelta < Constants.MinLatitudeDeltaSpan {
            // Too small. Zoom out.
            printLog("MapViewController regionDidChangeAnimated mapRegion is too small")
            let span = MKCoordinateSpan(latitudeDelta: Constants.MinLatitudeDeltaSpan, longitudeDelta: Constants.MinLongitudeDeltaSpan)
            let coordinateMapRegionFirstAttempt = MKCoordinateRegion(center: coordinateRegionThatFits.center, span: span)
            coordinateRegionThatFits = self.mapView.regionThatFits(coordinateMapRegionFirstAttempt)
            printLog("MapViewController regionDidChangeAnimated coordinateRegionThatFits Span=\(coordinateRegionThatFits.span)")
            printLog("MapViewController regionDidChangeAnimated About to set region to coordinateRegionThatFits")
            self.mapView.setRegion(coordinateRegionThatFits, animated: true)
        }
        
        // So, all the region changes are taken care of. Save the map co-ordinates and re-get the data
        let mapRegion = mapRegionFrom(coordinateRegion: coordinateRegionThatFits)
        printLog("MapViewController regionDidChangeAnimated Set UserPrefs to mapRegion=\(mapRegion)")
        UserPrefs.setCurrentMapRegion(mapRegion)
        
        getWheps()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // printLog("MapViewController viewFor annotation")
        
        if annotation.isKind(of: MKUserLocation.self) {
            return nil
        }
        
        if let pinAnnotation = annotation as? WhepAnnotation {
            var view: MKPinAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: Storyboard.WhepAnnotationIdentifier)
                as? MKPinAnnotationView {
                dequeuedView.annotation = pinAnnotation
                dequeuedView.pinTintColor = pinAnnotation.pinTintColor
                view = dequeuedView
            } else {
                // Create one
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: Storyboard.WhepAnnotationIdentifier)
                view.canShowCallout = true // false
                view.animatesDrop = true
                view.pinTintColor = pinAnnotation.pinTintColor
            }
            return view
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // printLog("MapViewController rendererFor overlay")
        
        if let overlayView = overlay as? WhepDensityCircleOverlay {
            //  MKCircle
            guard let whepGrid = overlayView.whepGrid else { return MKOverlayRenderer(overlay: overlay) }
            
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = whepGrid.fillColor
            circleRenderer.strokeColor = whepGrid.strokeColor
            circleRenderer.lineWidth = whepGrid.lineWidth
            return circleRenderer
        }
        
        if let overlayView = overlay as? WhepDensityOverlay {
            //  MKPolygon
            guard let whepGrid = overlayView.whepGrid else { return MKOverlayRenderer(overlay: overlay) }
            
            let polygonRenderer = MKPolygonRenderer(overlay: overlay)
            polygonRenderer.fillColor = whepGrid.fillColor
            polygonRenderer.strokeColor = whepGrid.strokeColor
            polygonRenderer.lineWidth = whepGrid.lineWidth
            return polygonRenderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - Extension - CLLocationManagerDelegate

extension MapViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            printLog("MapViewController Current location: timestamp=\(location.timestamp) latitude=\(location.coordinate.latitude) longitude=\(location.coordinate.longitude)")
            UserPrefs.setLastLocation((location.coordinate.latitude,location.coordinate.longitude))
            
            // First time through. Go to current location.
            if !UserPrefs.hasObtainedFirstLocationFix() {
                UserPrefs.setHasObtainedFirstLocationFix(true)
                printLog("MapViewController didUpdateLocations no location processing begin1")
                if let lastLocation = UserPrefs.lastLocation() {
                    printLog("MapViewController didUpdateLocations no location processng begin2")
                    let center = CLLocationCoordinate2DMake(lastLocation.0, lastLocation.1)
                    let currentSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5) // self.mapView.region.span
                    let coordinateRegion = MKCoordinateRegion(center: center, span: currentSpan)
                    mapView.setRegion(coordinateRegion, animated: false)
                    
                    let mapRegion = mapRegionFrom(coordinateRegion: mapView.region)
                    UserPrefs.setCurrentMapRegion(mapRegion)
                    
                    if !appUsesServerCalls {
                        printLog("MapViewController Testing didUpdateLocations About to getData()")
                        // And for testing only, re-set the data array and get some data for this location
                        TestingDataSource.getNewData()
                        getWheps()
                    } else {
                        // Real server calls. We need to get the wheps here
                        printLog("MapViewController didUpdateLocations First time. About to getData()")
                        getWheps()
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        printLog("MapViewController locationManager didFailWithError error=\(error)")
    }

}

// MARK: - Extension - UIPopoverPresentationControllerDelegate

extension MapViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
}


// MARK: - Extension - Data retrieval/Server methods

extension MapViewController {
    
    func getWheps() {
        if !appIsValid() {
            printLog("MapViewController getWheps() App is Invalid")
            return
        }
        
        printLog("MapViewController getWheps()")
        
        guard let mapRegion = UserPrefs.currentMapRegion() else { printLog("MapViewController getWheps() no saved map region"); return }
        printLog("MapViewController getWheps() mapRegion=\(mapRegion)")
        
        self.tabBarViewController?.getWhepsRequestSource = .map // So if we switch to the list before the server return we do a reload()
        
        showActivityIndicator()
        TransactionService.getWheps(for: mapRegion) { [weak self] (response, mapRegionUsedForRequest, data) in
            guard let strongSelf = self else { return }
            printLog("TransactionService.getWheps() call completed")
            
            // Is UserPrefs value captured at the start??
            printLog("MapViewController getWheps() completion block UserPrefs.currentMapRegion()=\(String(describing: UserPrefs.currentMapRegion()))")
            
            if mapRegionUsedForRequest != UserPrefs.currentMapRegion() {
                // They've moved the map in the meantime. Don't worry about this request.
                printLog("MapViewController  TransactionService.getWheps() map region has changed. Aborting.")
                
                DispatchQueue.main.async {
                    strongSelf.hideActivityIndicator()
                }
                return
            }
            
            strongSelf.tabBarViewController?.wheps = nil
            if response.status == .success {
                if let responseData = Whep.whepsFrom(serverResponseData: data) {
                    let wheps = responseData
                    printLog("MapViewController  TransactionService.getWheps() return == success")
                    strongSelf.tabBarViewController?.processWhepsOnServerReturn(wheps)
                } else {
                    // Successful return but no data. That's OK here.
                    printLog("MapViewController  TransactionService.getWheps() return but no data. ")
                }
                DispatchQueue.main.async {
                    // strongSelf.activityIndicator.stopAnimating()
                    strongSelf.hideActivityIndicator()
                    // Reload the map data...
                    printLog("MapViewController TransactionService.getWheps() About to reloadMapOverlayData()")
                    if strongSelf.showHotSpot {
                        strongSelf.reloadMapOverlayData()
                    } else {
                        strongSelf.removeOverlays()
                    }
                    if strongSelf.showPinAnnotationsForAllWheps { // Testing...
                        if let wheps = strongSelf.tabBarViewController?.wheps {
                            strongSelf.addAnnotationsForAllWheps(wheps)
                        }
                    }
                    
                    if strongSelf.regionDidChangeAnimatedCompletion != nil {
                        strongSelf.regionDidChangeAnimatedCompletion!()
                        strongSelf.regionDidChangeAnimatedCompletion = nil
                    }
                }
            } else {
                // Error
                DispatchQueue.main.async {
                    // strongSelf.activityIndicator.stopAnimating()
                    strongSelf.hideActivityIndicator()
                    TransactionService.processServerError(response, presentingViewController: strongSelf)
                }
            }
        }
        
    }
    
}


