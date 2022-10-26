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
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

public enum Plan : String {
    case basic = "basic"
    case premium = "premium"
}



public let reviewRequestFlg = "DidAppStoreReviewRequested"
public let cntDoneFlg       = "CntDoneFlg"
public let logoFlg          = "logoFlg"
public let logoFlg_on       = 0
public let logoFlg_off      = 1
public let planFlg          = "planFlag"

public func requestAppStoreReview() {
    if UserDefaults.standard.integer(forKey: cntDoneFlg) >= 3 { // camera
        if UserDefaults.standard.bool(forKey: reviewRequestFlg) == true { return } // request
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



public func getPlan() -> Plan {
    return .basic
    /*
    let planStr = UserDefaults.standard.string(forKey: planFlg)
    
    if planStr == Plan.basic.rawValue { return .basic }
    else if planStr == Plan.premium.rawValue { return .premium }
    
    return .basic
     */
}

public func setPlan(plan:Plan)  {
    UserDefaults.standard.set(plan.rawValue, forKey: planFlg)
}
