//
//  SceneDelegate.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import UIKit
import StoreKit

public let ciContext = CIContext()

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}

public let reviewRequestFlg = "DidAppStoreReviewRequested"
public let cntDoneFlg       = "CntDoneFlg"
public let logoFlg          = "logoFlg"
public let logoFlg_on       = 0
public let logoFlg_off      = 1

public func requestAppStoreReview() {
    if UserDefaults.standard.integer(forKey: cntDoneFlg) >= 3 {
        if UserDefaults.standard.bool(forKey: reviewRequestFlg) == true { return }
        reviewRequest()
        UserDefaults.standard.set(true, forKey: reviewRequestFlg)
    }
}

public func reviewRequest() {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
    }
}

public func incCntDone() {
    let cnt = UserDefaults.standard.integer(forKey: cntDoneFlg)
    UserDefaults.standard.set(cnt+1, forKey: cntDoneFlg)
}
public func appReviewShow() -> Bool {
    return UserDefaults.standard.integer(forKey: cntDoneFlg) >= 3
}
