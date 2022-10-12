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

class VideoViewController:CompositImageViewController {
    
    public var url:URL? = nil
    
    private var cancel               = false ;
    private var processedVideoURL: URL? = nil
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
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
        self.superVc?.present(vc, animated: true)
    }
    
    
    
    @IBAction func close(_ sender: Any) {
        self.cancel = true
        VisionManager.shared.cancel = true
        
        guard let url = processedVideoURL else {
            self.dismiss(animated:true)
            return
        }
        
        let alert = UIAlertController(title: "Convert Completed",
                                      message: "Your video has been converted.\n Which action do you select ?",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Save & Show", style: .default) { _ in
            self.saveVideo(alert: alert, url: url)
        })
        
        alert.addAction(UIAlertAction(title: "Only Save", style: .default) { _ in
            self.processedVideoURL = nil
            self.saveVideo(alert: alert, url: url)
        })
        
        alert.addAction(UIAlertAction(title: "Only Show", style: .default) { _ in
            self.dismiss(animated:true)
        })
        
        alert.addAction(UIAlertAction(title: "Close", style: .default))
        
        self.present(alert, animated: true)
        
    }
    
    private func saveVideo(alert: UIAlertController, url:URL) {
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { (isCompleted, error) in
            DispatchQueue.main.async {
                alert.dismiss(animated: true ) {
                    let message = isCompleted ?
                    "[Success] Your video has been saved in photolibrary." :
                    "[Fail] It failed to save your video."
                    let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default){ _ in self.dismiss(animated:true)})
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

