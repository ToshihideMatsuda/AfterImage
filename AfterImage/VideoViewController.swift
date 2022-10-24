//
//  VideoViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/21.
//

import Foundation
import UIKit
import AVFoundation
import AVKit
import PhotosUI
import GoogleMobileAds

class VideoViewController:CompositImageViewController, GADFullScreenContentDelegate  {
    
    
    @IBOutlet weak var bannerView: GADBannerView!
    public var url:URL? = nil
    
    private var cancel               = false ;
    private var saveaction           = false ;
    private var processedVideoURL: URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createInterstitial(delegate:self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if getPlan() == .basic {
            // GADBannerViewのプロパティを設定
            bannerView.adUnitID = bannerViewId()
            bannerView.rootViewController = self
            bannerView.adSize = .init(size: bannerSize, flags: 1)
            
            // 広告読み込み
            bannerView.load(GADRequest())
        }
        
        
        guard let url = url else { return }
        let asset = AVAsset(url: url)
        let videoSize = asset.naturalSize
        self.mainVideoView?.setVideoSize(size: videoSize)
        VisionManager.shared.initClearBackground(cameraSize: videoSize )
        
        VisionManager.shared.applyProcessingOnVideo(videoURL: url,
                                                    { imageBuffer, currentTime, isFrameRotated in
            if self.cancel { return nil }
            let compositImage = self.createCompositImage(imageBuffer: imageBuffer, currentTime:currentTime, isFrameRotated: isFrameRotated)

            DispatchQueue.main.async {
                //CGImage
                self.mainVideoView?.mainlayer?.contents = ciContext.createCGImage(compositImage,
                                                                                 from: CGRect(origin: CGPoint(x: 0, y: 0),
                                                                                 size: compositImage.extent.size))
            }
            
            return compositImage
        },
        { err, processedVideoURL in
            if self.cancel { return }
            guard err == nil else { print(err?.localizedDescription ?? "" ); return }
            guard let url = processedVideoURL else { return }
            
            self.processedVideoURL = url
            DispatchQueue.main.async {
                if self.cancel { return }
                self.close(self)
            }
            
        })
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let url = processedVideoURL else { return }
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: url)
        let saveaction = self.saveaction
        
        self.superVc?.present(vc, animated: true, completion:  {
            if saveaction {
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { (isCompleted, error) in
                    let message = isCompleted ?
                        "[成功] フォトライブラリに撮影したビデオを保存しました" :
                        "[失敗] ビデオの保存に失敗しました"
                    let alert = UIAlertController(title: "お知らせ", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in
                        if let interstitial = self.interstitial {
                            interstitial.present(fromRootViewController: self)
                        } else {
                            self.dismiss(animated: true)
                        }
                    })
                    DispatchQueue.main.async {
                        vc.present(alert, animated: true)
                    }
                }
            }
        })
        
    }
    
    
    
    @IBAction func close(_ sender: Any) {
        self.cancel = true
        VisionManager.shared.cancel = true
        
        let alert = UIAlertController(title: "お知らせ",
                                      message: "ビデオの変換が完了しました\nこのビデオを保存しますか？",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "保存＆表示", style: .default) { _ in
            self.saveaction = true;
            if let interstitial = self.interstitial {
                interstitial.present(fromRootViewController: self)
            } else {
                self.dismiss(animated: true)
            }
        })
        
        
        alert.addAction(UIAlertAction(title: "表示のみ", style: .default) { _ in
            if let interstitial = self.interstitial {
                interstitial.present(fromRootViewController: self)
            } else {
                self.dismiss(animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .default) { _ in
            self.processedVideoURL = nil
            if let interstitial = self.interstitial {
                interstitial.present(fromRootViewController: self)
            } else {
                self.dismiss(animated: true)
            }
        })
        
        self.present(alert, animated: true){
            incCntDone()
        }
        
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
        self.dismiss(animated: true)
    }
}

