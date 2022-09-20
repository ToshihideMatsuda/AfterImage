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
    
    private func showUI() {
        
        let photoLibraryPicker = UIImagePickerController()
        photoLibraryPicker.mediaTypes = [UTType.movie.identifier]
        photoLibraryPicker.sourceType = .photoLibrary
        photoLibraryPicker.delegate = self
        
        DispatchQueue.main.async {
            self.present(photoLibraryPicker, animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        let vc = AVPlayerViewController()
        let player = AVPlayer(url: url)
        vc.player = player
         
         picker.present(vc, animated: true)
     }
    
    
 }

