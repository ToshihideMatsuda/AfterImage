//
//  CompositImageViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/21.
//

import Foundation
import UIKit
import AVFoundation

class CompositImageViewController: UIViewController{
    private let queueSize            = 5 ;
    private var interval    :Double = 1.0
    private var imageQueue:[CIImage] = []
    private var prevTime    :CMTime = CMTime.zero
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        VisionManager.shared.initClearBackground(cameraSize: AVCaptureManager.shared.getVideoSize() ?? CGSize(width: 720, height: 1280))
    }
    
    func createCompositImage(imageBuffer:CVImageBuffer, currentTime:CMTime, isFrameRotated:Bool = false) -> CIImage {
        
        var videoImage = CIImage(cvPixelBuffer: imageBuffer)
        if isFrameRotated {
            videoImage = videoImage.oriented(CGImagePropertyOrientation.right)
        }
        
        let frameTime   = CMTimeSubtract(currentTime, self.prevTime)
        
        let currentPersonImage = VisionManager.shared.personImage(ciImage: videoImage)
        
        let currentImageQueue = imageQueue + [currentPersonImage]
        var compositImage = videoImage
        
        if(imageQueue.count >= 1) {
            for i in 0 ..< currentImageQueue.count {
                guard let image = currentImageQueue[i],
                      let blended = CIFilter(name:"CISourceOverCompositing", parameters:[
                        kCIInputImageKey            : image,
                        kCIInputBackgroundImageKey  : compositImage
                      ])?.outputImage else { break; }
                compositImage = blended
            }
        }
        registImageIntoQueue(currentTime: currentTime, frameTime: frameTime, currentPersonImage: currentPersonImage)
        
        return compositImage
        
    }
    
    func registImageIntoQueue(currentTime:CMTime, frameTime:CMTime, currentPersonImage:CIImage?) {
        
        if self.prevTime == CMTime.zero {
            self.prevTime = currentTime
        } else if frameTime.seconds >= interval {
            // 次回のためにQueueを更新
            self.prevTime = currentTime
            if let currentPersonImage = currentPersonImage {
                imageQueue += [currentPersonImage]
                while( imageQueue.count > queueSize ) { imageQueue.removeFirst() }
            }
        }
    }
}
