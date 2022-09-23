//
//  ViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import UIKit
import PhotosUI
import AVKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {

    @IBOutlet weak var intervalText: UITextField!
    @IBOutlet weak var maxClone: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func tapPhotoButton(_ sender: Any) {
        let status = PHPhotoLibrary.authorizationStatus(for:.readWrite)
        
        switch status {
        case .authorized:   break
        case .limited:      break
        case .restricted:   break
        case .denied:       print("denied")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:   self.tapPhotoButton(self)
                case .limited:      self.tapPhotoButton(self)
                case .restricted:   self.tapPhotoButton(self)
                default: break
                }
            }
        @unknown default:   return
        }
        
        self.showUI()
    }
    
    @IBAction func tapCameraButton(_ sender: Any) {
        guard let cameraVc = storyboard?.instantiateViewController(withIdentifier: "CameraViewController")  as? CameraViewController  else { return }
        cameraVc.modalPresentationStyle = .fullScreen;
        if let interval = self.intervalText.text {
            cameraVc.interval = Double(interval) ?? cameraVc.interval
        }
        if let max = self.maxClone.text {
            cameraVc.queueSize = Int(max) ?? cameraVc.queueSize
        }
        self.present(cameraVc, animated: true)
    }
    private func showUI() {        
        DispatchQueue.main.async {
            let photoLibraryPicker = UIImagePickerController()
            photoLibraryPicker.mediaTypes = [UTType.movie.identifier]
            photoLibraryPicker.sourceType = .photoLibrary
            photoLibraryPicker.delegate = self
            
            self.present(photoLibraryPicker, animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        
        guard let videoVc = storyboard?.instantiateViewController(withIdentifier: "VideoViewController") as? VideoViewController else { return }
        videoVc.url = url
        videoVc.superVc = self
        
        if let interval = self.intervalText.text {
            videoVc.interval = Double(interval) ?? videoVc.interval
        }
        if let max = self.maxClone.text {
            videoVc.queueSize = Int(max) ?? videoVc.queueSize
        }
        
        picker.dismiss(animated: true) {
            self.present(videoVc, animated: true)
        }
        
     }
    
    
 }

