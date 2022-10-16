//
//  adsConst.swift
//  ShadowClone
//
//  Created by 松田敏秀 on 2022/10/13.
//

import Foundation

fileprivate let debug = false;

public func bannerViewId() -> String{
    return debug ? "ca-app-pub-3940256099942544/2934735716" : "ca-app-pub-1643629923616505/4567849365";
}
public let bannerSize:CGSize = CGSize(width: 320, height: 50)


public func interstitialId() -> String{
    return debug ? "ca-app-pub-3940256099942544/4411468910" : "ca-app-pub-1643629923616505/7865517420";
}
