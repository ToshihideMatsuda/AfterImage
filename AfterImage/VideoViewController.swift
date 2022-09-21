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
    
    @IBOutlet weak var mainVideoView: AVPlayerLayerView!
    weak var superVc:UIViewController? = nil
    public var url:URL? = nil
    
    private let queueSize            = 5 ;
    private var cancel               = false ;
    private var imageQueue:[CIImage] = []
    private var processedVideoURL: URL? = nil
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        guard let url = url else { return }
        
        VisionManager.shared.applyProcessingOnVideo(videoURL: url,
                                                    { imageBuffer, currentTime, isFrameRotated in
            if self.cancel { return nil }
            let compositImage = self.createCompositImage(imageBuffer: imageBuffer, currentTime:currentTime, isFrameRotated: isFrameRotated)

            DispatchQueue.main.async {
                //CGImage
                self.mainVideoView.mainlayer?.contents = ciContext.createCGImage(compositImage,
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
        guard let url = processedVideoURL else { return }
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: url)
        self.superVc?.present(vc, animated: true) {
            
            PHPhotoLibrary.shared().performChanges({
              PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { (isCompleted, error) in
              if isCompleted {
                // フォトライブラリに書き出し成功
                do {
                  try FileManager.default.removeItem(atPath: url.path)
                  print("フォトライブラリ書き出し・ファイル削除成功 : \(url.lastPathComponent)")
                }
                catch {
                  print("フォトライブラリ書き出し後のファイル削除失敗 : \(url.lastPathComponent)")
                }
              }
              else {
                print("フォトライブラリ書き出し失敗 : \(url.lastPathComponent)")
              }
            }
        }
    }
    
    
    
    @IBAction func close(_ sender: Any) {
        self.cancel = true
        VisionManager.shared.cancel = true
        self.dismiss(animated: true) 
    }
    
}

