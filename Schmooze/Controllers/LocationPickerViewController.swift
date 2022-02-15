//
//  LocationPickerViewController.swift
//  Schmooze
//
//  Created by MAD2 on 10/2/22.
//

import UIKit
import CoreLocation
import MapKit
import SwiftUI

class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pick Location"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButtonTapped))
        view.addSubview(map)
        map.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
        gesture.numberOfTapsRequired = 1
        map.addGestureRecognizer(gesture)
        // Do any additional setup after loading the view.
    }
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    @objc func didTapMap(_ gesture: UITapGestureRecognizer){
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        //drop pin
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    

}
