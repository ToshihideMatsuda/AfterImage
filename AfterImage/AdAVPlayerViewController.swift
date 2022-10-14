//
//  AdAVPlayerViewController.swift
//  ShadowClone
//
//  Created by tmatsuda on 2022/10/14.
//

import Foundation
import UIKit
import AVKit
import GoogleMobileAds

class AdAVPlayerViewController : AVPlayerViewController {
    
    private var bannerView : GADBannerView? = nil
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let bannerView = GADBannerView(frame: CGRect(origin: CGPoint(x: (self.view.frame.width - bannerSize.width)/2, y: 0), size: bannerSize))
        
        // GADBannerViewのプロパティを設定
        bannerView.adUnitID = bannerViewId()
        bannerView.rootViewController = self
        bannerView.adSize = .init(size: bannerSize, flags: 1)
        
        // 広告読み込み
        bannerView.load(GADRequest())
        self.view.addSubview(bannerView)
        self.bannerView = bannerView
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.bannerView?.frame = CGRect(origin: CGPoint(x: (self.view.frame.width - bannerSize.width)/2, y: 0), size: bannerSize)
    }
}
