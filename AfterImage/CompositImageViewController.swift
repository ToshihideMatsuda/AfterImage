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
    public weak var superVc:ViewController? = nil
    public var mainVideoView: AVPlayerLayerView? = nil

    public  var queueSize            = 5 ;
    public  var interval    :Double  = 1.0
    var imageQueue:[CIImage] = []
    private var prevTime    :CMTime = CMTime.zero
    private var icon    :CIImage? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainVideoView = UINib(nibName: "AVPlayerLayerView", bundle: nil).instantiate(withOwner: self, options: nil).first as? AVPlayerLayerView
        
        guard let uiImage = UIImage(named: "ShadowCloneIcon"),
            let icon = CIImage(image: uiImage) else { return }
        self.icon = icon
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let main = mainVideoView {
            self.view.addSubview(main)
            self.view.sendSubviewToBack(main)
            main.frame = self.view.bounds
            main.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin ,.flexibleLeftMargin, .flexibleRightMargin]
            self.mainVideoView?.setVideoSize(size:AVCaptureManager.shared.getVideoSize())
        }
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
        
        guard let icon = self.icon,
              let blended = CIFilter(name:"CISourceOverCompositing", parameters:[
                kCIInputImageKey            : icon,
                kCIInputBackgroundImageKey  : compositImage
              ])?.outputImage else { return compositImage }
        compositImage = blended
        
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