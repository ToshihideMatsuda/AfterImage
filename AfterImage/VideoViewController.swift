//
//  VideoViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/21.
//

import Foundation
import UIKit
import AVFoundation


class VideoViewController:CompositImageViewController {
    
    @IBOutlet weak var mainVideoView: AVPlayerLayerView!
    public var url:URL? = nil
    
    private let queueSize            = 5 ;
    private var cancel               = false ;
    private var imageQueue:[CIImage] = []
    
    
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

            DispatchQueue.main.sync {
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
        })
         
        
    }
    
    @IBAction func close(_ sender: Any) {
        self.cancel = true
        VisionManager.shared.cancel = true
        self.dismiss(animated: true)
    }
    
}

