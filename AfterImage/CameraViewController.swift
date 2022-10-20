//
//  CameraViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import UIKit
import AVFoundation
import PhotosUI
import GoogleMobileAds

public let cameraSaveQueue = DispatchQueue.init(label: "CameraViewController.saveQueue")

class CameraViewController:CompositImageViewController, VideoListener, AudioListener, GADFullScreenContentDelegate  {
    
    @IBOutlet weak var bannerView: GADBannerView!
    private var preset     :AVCaptureSession.Preset = .high
    
    private var isRec:Bool = false
    private var url:URL? = nil
    
    private var frameNumber :Int = 0
    private var firstFrameNo:Int = 0
    private var startTime   :CMTime = CMTime.zero
    private var endTime     :CMTime = CMTime.zero
    
    private var assetWriter : AVAssetWriter? = nil
    private var videoAssetInput: AVAssetWriterInput? = nil
    private var audioAssetInput: AVAssetWriterInput? = nil
    private var videoPixcelBuffer: AVAssetWriterInputPixelBufferAdaptor? = nil
    
    @IBOutlet weak var recBottonContainer: UIView!
    @IBOutlet weak var recBottonView: UIView!
    @IBOutlet weak var constraintHeight: NSLayoutConstraint!
    @IBOutlet weak var constraintWidth: NSLayoutConstraint!
    @IBOutlet weak var timeLabel: UILabel!
    private var timer:Timer? = nil
    private var count:Int = 0
    
    private var cameraRotate = false
    private var initialized = true
    private let frameRate:Int32  = 20
    private var additionalMessage = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createInterstitial(delegate:self)
        bannerView.isHidden = true
    }
    
    
    /// Tells the delegate that the ad failed to present full screen content.
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad did fail to present full screen content.")
        ad.fullScreenContentDelegate = nil
    }

    /// Tells the delegate that the ad will present full screen content.
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }

    /// Tells the delegate that the ad dismissed full screen content.
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        ad.fullScreenContentDelegate = nil
        self.dismiss(animated: true){
            guard let url = URL(string: "photos-redirect://") else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AVCaptureManager.shared.addVideoListener(listener: self)
        AVCaptureManager.shared.addAudioListener(listener: self)
        AVCaptureManager.shared.initializeCamera(self.cameraRotate, frameRateInput: self.frameRate, preset: self.preset)
        VisionManager.shared.initClearBackground(cameraSize: AVCaptureManager.shared.getVideoSize() ?? CGSize(width: 1280, height: 720))
        
        self.count = 0
        self.showTimerView();
        
        recBottonContainer.layer.borderWidth  = 1
        recBottonContainer.layer.borderColor  = CGColor.init(red: 0, green: 0, blue: 0, alpha: 1)
        recBottonContainer.layer.cornerRadius = recBottonContainer.frame.size.width / 2.0
        constraintHeight.constant = recBottonContainer.frame.height - 6
        constraintWidth.constant = recBottonContainer.frame.height - 6
        recBottonView.layer.cornerRadius =  recBottonContainer.frame.size.width / 2.0
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        // GADBannerViewのプロパティを設定
        bannerView.adUnitID = bannerViewId()
        bannerView.rootViewController = self
        bannerView.adSize = .init(size: bannerSize, flags: 1)

        // 広告読み込み
        bannerView.load(GADRequest())
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AVCaptureManager.shared.removeVideoListener(listener: self)
        AVCaptureManager.shared.removeAudioListener(listener: self)
    }
    
    @IBAction func rotateCamera(_ sender: Any) {
        self.cameraRotate.toggle()
        imageQueue = []
        AVCaptureManager.shared.initializeCamera(cameraRotate, frameRateInput: frameRate, preset: preset)
        VisionManager.shared.initClearBackground(cameraSize: AVCaptureManager.shared.getVideoSize() ?? CGSize(width: 1280, height: 720))
    }
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func onRec(_ sender: Any?) {
        isRec.toggle()
        
        self.onRecButtonView(true)
        
        if isRec {
            imageQueue = []
            // Rec start
            let url  = URL(fileURLWithPath: (NSTemporaryDirectory() + UUID().uuidString + ".mp4"))
            startRecordingToOutputFileURL(url);
            self.url = url
            self.count = 0;
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                self.count += 1
                self.showTimerView();
            })
        } else if let url = self.url {
            // Rec end
            self.timer?.invalidate()
            self.timer = nil
            self.count = 0
            self.showTimerView();
            
            stopRecording()
            
            
            let alert = UIAlertController(title: "Info",
                                          message: self.additionalMessage + "Do you save a current video?",
                                          preferredStyle: .alert)
            self.additionalMessage = ""
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                
                PHPhotoLibrary.shared().performChanges({
                  PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { (isCompleted, error) in
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true ) {
                            let message = isCompleted ?
                            "[Success] Your video has been saved in photolibrary." :
                            "[Fail] It failed to save your video."
                            let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in
                                self.interstitial?.present(fromRootViewController: self)
                            })
                            self.present(alert, animated: true)
                        }
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }
    
    private func onRecButtonView(_ animation:Bool = false) {
        
        let radius:CGFloat
        let len:CGFloat?
        if isRec {
            constraintHeight.constant = recBottonContainer.frame.height - 20
            constraintWidth.constant = recBottonContainer.frame.width - 20
            len = nil
            radius = self.recBottonContainer.frame.size.width / 6.0
        } else {
            len = recBottonContainer.frame.height - 6
            radius = recBottonContainer.frame.size.width / 2.0
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.0, animations: {
            self.recBottonView.layer.cornerRadius = radius
        }, completion: { ret in
            if ret {
                if let length = len {
                    self.constraintHeight.constant = length
                    self.constraintWidth.constant  = length
                }
            }
        })
    }
    
    private func showTimerView() {
        let hours:Int   = self.count / ( 60 * 60 )
        let minutes:Int = ( self.count - hours * 60 * 60) / 60
        let seconds:Int = ( self.count - hours * 60 * 60 - minutes * 60 )
        
        var hoursStr   = "\(hours)"
        var minutesStr = "\(minutes)"
        var secondsStr = "\(seconds)"
        
        if hoursStr.count   == 1 { hoursStr   = "0" + hoursStr }
        if minutesStr.count == 1 { minutesStr = "0" + minutesStr }
        if secondsStr.count == 1 { secondsStr = "0" + secondsStr }
        
        self.timeLabel.text = "\(hoursStr):\(minutesStr):\(secondsStr)"
        
        if minutes >= 1 {
            self.additionalMessage = "You can only save a video within 60 seconds\n"
            self.onRec(nil)
        }
    }
    
    public func videoCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //video
        
        let (imageBufferObj, size) = sampleBuffer.imageBuffer()
        guard let imageBuffer = imageBufferObj else { return }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let compositImage = createCompositImage(imageBuffer: imageBuffer, currentTime:currentTime)
        
        DispatchQueue.main.async {
            //CGImage
            self.mainVideoView?.mainlayer?.contents = ciContext.createCGImage(compositImage,
                                                                             from: CGRect(origin: CGPoint(x: 0, y: 0),
                                                                             size: compositImage.extent.size))
        }
        
        if isRec {
            if frameNumber < firstFrameNo {
                //最初のフレームを無視（暗転しているため）
                frameNumber += 1
                return
            }
            
            if(frameNumber == firstFrameNo) {
                startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let frameTime = CMTimeSubtract(timestamp, startTime)
            
            frameNumber += 1;
            cameraSaveQueue.async { self.saveVideoBuffer(size, videoImage:compositImage, frameTime:frameTime) }
        }
    }
    
    public func audioCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //audio
        
        if isRec {
            if frameNumber <= firstFrameNo {
                //必ずvideoを先に記録
                return
            }
        }
        cameraSaveQueue.async { self.saveAudioBuffer(sampleBuffer) }
    }
    
    public func saveVideoBuffer (_ size:CGSize, videoImage:CIImage, frameTime:CMTime) {
        
        guard let input = assetWriter?.inputs.filter ({ $0.mediaType == .video }).first else { return }
        
        if input.isReadyForMoreMediaData, assetWriter?.status == .writing {
            if let pixcelBuffer = videoImage.pixelBuffer(cgSize: size),
               let videoPixcelBuffer = videoPixcelBuffer {
                let ok = videoPixcelBuffer.append(pixcelBuffer, withPresentationTime: frameTime);
                if(!ok) {
                    DispatchQueue.main.sync{ print("video: ng") }
                }
                endTime = frameTime
            }
        } else {
            // not Ready
            cameraSaveQueue.async { self.saveVideoBuffer(size, videoImage:videoImage, frameTime:frameTime) }
        }
    }

    public func saveAudioBuffer (_ sampleBuffer:CMSampleBuffer) {
        guard let input = assetWriter?.inputs.filter ({ $0.mediaType == .audio }).first else { return }
        if input.isReadyForMoreMediaData, assetWriter?.status == .writing {
            do {
                let copyBuffer = try sampleBuffer.offsettingTiming(by: self.startTime)
                let ok = input.append(copyBuffer)
                if(!ok) {
                    DispatchQueue.main.sync { print("audio: ng") }
                }
            } catch {
                DispatchQueue.main.sync { print("audio:err") }
            }
        } else {
            cameraSaveQueue.async { self.saveAudioBuffer(sampleBuffer) }
        }
    }
    
    public func startRecordingToOutputFileURL(_ url:URL){
        // バッファでの出力（ニューラルエンジン搭載）
        let videoSettings       = AVCaptureManager.shared.recommendedVideoSettingsForAssetWriter(writingTo: AVFileType.mp4)
        let videoAssetInput     = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

        self.videoAssetInput    = videoAssetInput

        videoAssetInput.expectsMediaDataInRealTime = true;
        videoPixcelBuffer       = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoAssetInput,
                                                                       sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String : Int(AVCaptureManager.pixcelFormat)])

        let audioSettings       = AVCaptureManager.shared.recommendedAudioSettingsForAssetWriter(writingTo: AVFileType.mp4)
        let audioAssetInput     = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        self.audioAssetInput    = audioAssetInput
        audioAssetInput.expectsMediaDataInRealTime = true;
        audioAssetInput.preferredVolume = 1.0
        frameNumber = 0;

        do {
            let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            self.assetWriter = assetWriter
            
            if assetWriter.canAdd(audioAssetInput) { assetWriter.add(audioAssetInput) }
            if assetWriter.canAdd(videoAssetInput) { assetWriter.add(videoAssetInput) }
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: CMTime.zero)
        } catch {
            print("error: ", error)
        }
    }

    @objc func stopRecording() {
        // バッファでの出力（ニューラルエンジン搭載）
        guard let videoAssetInput = videoAssetInput, let audioAssetInput = audioAssetInput, let assetWriter = assetWriter else { return }
        
        videoAssetInput.markAsFinished()
        audioAssetInput.markAsFinished()
        assetWriter.endSession(atSourceTime: endTime)

        assetWriter.finishWriting {
            self.videoAssetInput = nil
            self.audioAssetInput = nil
            self.assetWriter = nil
            self.frameNumber = 0;
            self.startTime = CMTime.zero
            self.endTime = CMTime.zero
        }
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.mainVideoView?.mainlayer?.contents = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isRec {
                self.stopRecording()
            }
            self.dismiss(animated: true) {
                self.superVc?.tapCameraButton(nil)
            }
        }
    }
}
