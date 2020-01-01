//
//  ViewController.swift
//  VanGogh'sEye
//
//  Created by Aung Ko Min on 2/1/20.
//  Copyright © 2020 Aung Ko Min. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    typealias FilteringCompletion = ((UIImage?, Error?) -> ())
    
    @IBOutlet private var segmentedControl: UISegmentedControl!
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var loader: UIActivityIndicatorView!
    @IBOutlet private var buttonHolderView: UIView!
    @IBOutlet private var applyButton: UIButton!
    @IBOutlet private var loaderWidthConstraint: NSLayoutConstraint!
    
    
    var selectedNSTModel: NSTDemoModel = .starryNight
    var imagePicker = UIImagePickerController()
    var selectedImage = UIImage(named: "paris")
    
    var isProcessing : Bool = false {
        didSet {
            self.applyButton.isEnabled = !isProcessing
            self.isProcessing ? self.loader.startAnimating() : self.loader.stopAnimating()
            self.loaderWidthConstraint.constant = self.isProcessing ? 20.0 : 0.0
            UIView.animate(withDuration: 0.3) {
                self.isProcessing
                    ? self.applyButton.setTitle("Processing...", for: .normal)
                    : self.applyButton.setTitle("Apply Style", for: .normal)
                self.view.layoutIfNeeded()
            }
        }
    }
    
    //MARK:- Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.isProcessing = false
        
        self.segmentedControl.removeAllSegments()
        for (index, model) in NSTDemoModel.allCases.enumerated() {
            self.segmentedControl.insertSegment(withTitle: model.rawValue, at: index, animated: false)
        }
        self.segmentedControl.selectedSegmentIndex = 0
        
        self.applyButton.titleLabel?.textAlignment = .center
        self.applyButton.superview!.layer.cornerRadius = 4
    }
    
    //MARK: - Utils
    func showError(_ error: Error) {
        
        self.buttonHolderView.backgroundColor = UIColor(red: 220/255, green: 50/255, blue: 50/255, alpha: 1)
        self.applyButton.setTitle(error.localizedDescription, for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { // Change `2.0` to the desired number of seconds.
            self.applyButton.setTitle("Apply Style", for: .normal)
            self.buttonHolderView.backgroundColor = UIColor(red: 5/255, green: 122/255, blue: 255/255, alpha: 1)
        }
    }
    
    //MARK:- CoreML
    
    func process(input: UIImage, completion: @escaping FilteringCompletion) {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var outputImage: UIImage?
        var nstError: Error?
        
        // Next step is pretty heavy, better process it
        // asynchronously to prevent UI freeze
        DispatchQueue.global().async {
            
            // Load model and launch prediction
            do {
                let modelProvider = try self.selectedNSTModel.modelProvider()
                outputImage = try modelProvider.prediction(inputImage: input)
            } catch let error {
                nstError = error
            }
            
            // Hand result to main thread
            DispatchQueue.main.async {
                if let outputImage = outputImage {
                    completion(outputImage, nil)
                } else if let nstError = nstError{
                    completion(nil, nstError)
                } else {
                    completion(nil, NSTError.unknown)
                }
                
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("Time elapsed for NST process: \(timeElapsed) s.")
            }
        }
    }
    
    //MARK:- Actions
    
    @IBAction func segmentedControlValueChanged() {
        self.selectedNSTModel = NSTDemoModel.allCases[self.segmentedControl.selectedSegmentIndex]
        self.imageView.image = self.selectedImage
    }
    
    @IBAction func importFromLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            self.imagePicker.delegate = self
            self.imagePicker.sourceType = .photoLibrary
            self.imagePicker.allowsEditing = false
            self.present(self.imagePicker, animated: true)
        } else {
            print("Photo Library not available")
        }
    }
    
    @IBAction func applyNST() {
        
        guard let image = self.imageView.image else {
            print("Select an image first")
            return
        }
        
        self.isProcessing = true
        self.process(input: image) { filteredImage, error in
            self.isProcessing = false
            if let filteredImage = filteredImage {
                self.imageView.image = filteredImage
            } else if let error = error {
                self.showError(error)
            } else {
                self.showError(NSTError.unknown)
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            self.selectedImage = pickedImage
            self.imageView.image = pickedImage
            self.imageView.backgroundColor = .clear
        }
        self.dismiss(animated: true)
    }
}
