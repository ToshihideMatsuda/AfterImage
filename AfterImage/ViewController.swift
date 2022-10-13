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

    @IBOutlet weak var interValSlider: UISlider!
    @IBOutlet weak var intervalText: UILabel!
    @IBOutlet weak var clonesSlider: UISlider!
    @IBOutlet weak var clonesText: UILabel!
    let intervalDefault:Float = 1.0
    let clonesDefault:Float = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.interValSlider.value = intervalDefault
        self.clonesSlider.value = clonesDefault
        // Do any additional setup after loading the view.
    }

    @IBAction func tapPhotoButton(_ sender: Any?) {
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
    
    @IBAction func tapCameraButton(_ sender: Any?) {
        guard let cameraVc = storyboard?.instantiateViewController(withIdentifier: "CameraViewController")  as? CameraViewController  else { return }
        cameraVc.modalPresentationStyle = .fullScreen
        cameraVc.interval  = floor(Double(self.interValSlider.value) * 10.0) / 10.0
        cameraVc.queueSize = Int(self.clonesSlider.value)
        
        cameraVc.superVc = self
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
        videoVc.interval  = floor(Double(self.interValSlider.value) * 10.0) / 10.0
        videoVc.queueSize = Int(self.clonesSlider.value)
        
        picker.dismiss(animated: true) {
            self.present(videoVc, animated: true)
        }
        
     }
    @IBAction func chngIntervalSecond(_ sender: Any?) {
        let val = floor(Double(self.interValSlider.value) * 10.0) / 10.0
        self.intervalText.text = "\(val)s"
    }
    @IBAction func chngClones(_ sender: Any?) {
        self.clonesText.text = "\(Int(self.clonesSlider.value))"
    }
    
    @IBAction func onReset(_ sender: Any) {
        self.interValSlider.value = intervalDefault
        self.clonesSlider.value = clonesDefault
        self.chngIntervalSecond(nil)
        self.chngClones(nil)
    }
    
 }

