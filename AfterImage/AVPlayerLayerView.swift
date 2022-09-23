//
//  AVPlayerLayerView.swift
//  AfterImage
//
//  Created by 松田敏秀 on 2022/09/24.
//

import Foundation
import UIKit
import AVFoundation


class AVPlayerLayerView:UIView {
    public var videoSize:CGSize? = nil
    public func setVideoSize(size :CGSize? = nil) {
        guard let size = size ?? videoSize else { return }
        
        videoSize = size
        let aspect:Double = size.height / size.width
        let width  = self.bounds.width
        let height = self.bounds.height
        let mainViewSize:CGSize;
        
        if width * aspect <= height { mainViewSize = CGSize(width: width,           height: width * aspect) }
        else {                        mainViewSize = CGSize(width: height / aspect, height: height) }
        
        mainlayer?.frame.size = mainViewSize
        mainlayer?.position = self.center
    }
    
    
    public lazy var mainlayer:AVPlayerLayer? = {
        let layer = AVPlayerLayer()
        self.layer.addSublayer(layer)
        return layer
    }();
}
