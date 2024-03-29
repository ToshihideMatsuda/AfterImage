//
//  ViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import UIKit
import PhotosUI
import AVKit
import GoogleMobileAds
import SwiftUI
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate,UIPickerViewDataSource,UIPickerViewDelegate  {
    public static var shared: ViewController? = nil
    @IBOutlet weak var bannerView: GADBannerView!  //追加

    @IBOutlet weak var intervalTitleLabel: UILabel!
    @IBOutlet weak var interValSlider: UISlider!
    @IBOutlet weak var intervalText: UILabel!
    @IBOutlet weak var clonesTitleLabel: UILabel!
    @IBOutlet weak var clonesSlider: UISlider!
    @IBOutlet weak var clonesText: UILabel!
    @IBOutlet weak var aiQualityLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var qualityPicker: UIPickerView!
    @IBOutlet weak var settingButton: UIButton!
    @IBOutlet weak var appReviewButton: UIButton!
    let intervalDefault:Float = 0.1
    let clonesDefault:Float = 10
    
    var settingCollection: [UIView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.shared = self
        StoreManager.setup()
        self.interValSlider.value = intervalDefault
        self.clonesSlider.value = clonesDefault
        settingCollection = [
            resetButton,
            intervalTitleLabel, interValSlider, intervalText,
            clonesTitleLabel,   clonesSlider,   clonesText,
            aiQualityLabel, qualityPicker,
        ]
        settingCollection.forEach{ $0.isHidden = true }
        
        // GADBannerViewのプロパティを設定
        bannerView.adUnitID = bannerViewId()
        bannerView.rootViewController = self
        bannerView.adSize = .init(size: bannerSize, flags: 2)
        
        // 広告読み込み
        bannerView.load(GADRequest())
            
        self.qualityPicker.selectRow(1, inComponent: 0, animated: false)
        VisionManager.shared.personSegmentationRequest?.qualityLevel = qualityList[1]
        appReviewButton.isHidden = true

        // Do any additional setup after loading the view.
    }
    
    public func premiumChng() {
        appReviewButton.isHidden = true
        bannerView.isHidden = true
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestAppStoreReview()
        appReviewButton.isHidden = !appReviewShow()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestAppStoreReview()
        appReviewButton.isHidden = !appReviewShow()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        requestAppStoreReview()
        appReviewButton.isHidden = !appReviewShow()
    }
    @IBAction func tapPhotoButton(_ sender: Any?) {
        PHPhotoLibrary.requestAuthorization(for:.readWrite) { status in
            
            switch status {
            case .authorized:   break
            case .limited:      break
            case .restricted:   break
            case .denied, .notDetermined:
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: NSLocalizedString("お知らせ", comment: ""),
                                                  message: NSLocalizedString("写真へのアクセスが許可されていません\nアクセスを許可してください", comment: ""),
                                                  preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in
                        guard let url = URL(string:UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url, options:[:],completionHandler: nil)
                    } )
                    self.present(alert, animated: true)
                }
                
                return
            @unknown default:   return
            }
            
            self.showUI()
        }
    }
    
    @IBAction func tapCameraButton(_ sender: Any?) {
        var accessOK = true
        AVCaptureDevice.requestAccess(for: .video){ accessOK = accessOK && $0 }
        AVCaptureDevice.requestAccess(for: .audio){ accessOK = accessOK && $0 }
        PHPhotoLibrary.requestAuthorization(for:.readWrite) {
            if $0 == .denied { accessOK = accessOK && false }
        }
        
        if(accessOK == false) {
            let alert = UIAlertController(title: NSLocalizedString("お知らせ", comment: ""),
                                          message: NSLocalizedString("写真/カメラ/マイクへのアクセスが許可されていません\nアクセスを許可してください", comment:""),
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in
                guard let url = URL(string:UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url, options:[:],completionHandler: nil)
            } )
            self.present(alert, animated: true)
            return
        }
        
        
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
    
    private var hidden = true
    @IBAction func onSettingTap(_ sender: Any) {
        hidden.toggle()
        self.settingButton.isSelected = !hidden
        settingCollection.forEach{ $0.isHidden = hidden }
    }
    
    @IBAction func onReset(_ sender: Any) {
        self.interValSlider.value = intervalDefault
        self.clonesSlider.value = clonesDefault
        self.chngIntervalSecond(nil)
        self.chngClones(nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if( isPhone ) {
            return UIInterfaceOrientationMask.init(rawValue:
                                                    UIInterfaceOrientationMask.portrait.rawValue +
                                                    UIInterfaceOrientationMask.portraitUpsideDown.rawValue)
        }
        else {
            return .all
        }
    }
    
    private let dataList                                                     = [  NSLocalizedString("品質優先", comment: ""),
                                                                                  NSLocalizedString("バランス", comment: ""),
                                                                                  NSLocalizedString("速度優先", comment: "") ]
    private let qualityList:[VNGeneratePersonSegmentationRequest.QualityLevel] = [ .accurate, .balanced, .fast ]
    private var selectedQuality:VNGeneratePersonSegmentationRequest.QualityLevel = .balanced
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return qualityPicker.frame.size.height
    }

    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let label = (view as? UILabel) ?? UILabel(frame: CGRect(x: 0, y: 0, width: qualityPicker.frame.size.width, height: qualityPicker.frame.size.height))
        label.text = self.dataList[row]
        label.textColor = .black
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17)
        return label
    }
    
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return dataList[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int,  inComponent component: Int) {
        VisionManager.shared.personSegmentationRequest?.qualityLevel = qualityList[row]
    }
    
    @IBAction func tapAppReview(_ sender: Any) {
        reviewRequest()
    }
    
}

