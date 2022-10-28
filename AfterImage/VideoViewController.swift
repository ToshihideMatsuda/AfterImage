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

class VideoViewController:CompositImageViewController  {
    
    
    @IBOutlet weak var bannerView: GADBannerView!
    public var url:URL? = nil
    
    private var cancel               = false ;
    private var saveaction           = false ;
    private var processedVideoURL: URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //createInterstitial(delegate:self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // GADBannerViewのプロパティを設定
        bannerView.adUnitID = bannerViewId()
        bannerView.rootViewController = self
        bannerView.adSize = .init(size: bannerSize, flags: 1)
            
        // 広告読み込み
        bannerView.load(GADRequest())
        
        
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
        let vc = AdAVPlayerViewController()
        vc.player = AVPlayer(url: url)
        let saveaction = self.saveaction
        
        self.superVc?.present(vc, animated: true, completion:  {
            if saveaction {
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { (isCompleted, error) in
                    let message = isCompleted ?
                    NSLocalizedString("[成功] フォトライブラリに撮影したビデオを保存しました", comment: "") :
                    NSLocalizedString("[失敗] ビデオの保存に失敗しました", comment:"")
                    let alert = UIAlertController(title: NSLocalizedString("お知らせ", comment: ""), message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in
                        self.dismiss(animated: true)
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
        
        let alert = UIAlertController(title:NSLocalizedString("お知らせ", comment: ""),
                                      message: NSLocalizedString("ビデオの変換が完了しました\nこのビデオを保存しますか？",comment:""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("保存＆表示",comment: ""), style: .default) { _ in
            self.saveaction = true;
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("表示のみ",comment: ""), style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("キャンセル",comment:""), style: .default) { _ in
            self.processedVideoURL = nil
            self.dismiss(animated: true)
        })
        
        self.present(alert, animated: true){
            incCntDone()
        }
        
    }
    
}

