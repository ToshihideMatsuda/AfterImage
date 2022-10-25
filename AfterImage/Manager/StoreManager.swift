//
//  StoreManager.swift
//  ShadowClone
//
//  Created by tmatsuda on 2022/10/24.
//

import Foundation
import StoreKit

let premiumId  = "7fDew35yuwqDhtr563dvbgyjJrtgEf34vdq44ghr4tyTNYT645rgsfbUJYKYUthbrmutrterygedbrfgRETGER6r4Gny63fw2edg"

class StoreManager: NSObject, SKPaymentTransactionObserver {
    static var shared = StoreManager()
    var products: [SKProduct] = []

    // product idの一覧を定義する
    let productsIdentifiers: Set<String> = [premiumId]

    // AppDelegateや課金処理前に呼び出してproduct一覧を取得する
    static func setup() {
        shared.validateProductsIdentifiersWithRequest()
    }

    // product情報をStoreから取得
    private func validateProductsIdentifiersWithRequest() {
        let request = SKProductsRequest(productIdentifiers: productsIdentifiers)
        request.delegate = self
        request.start()
    }
    
    // 購入
    func purchaseProduct(_ productsIdentifiers: String) {
        // productIdentifierに該当するproduct情報があるかチェック
        guard let product = products.first(where: { $0.productIdentifier == productsIdentifiers } ) else { return }
        
        // 購入リクエスト
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    // 該当のproduct情報はproductsに存在するか確認
    private func productForIdentifiers(_ productsIdentifiers: String) -> SKProduct? {
        return products.filter{ return $0.productIdentifier == productsIdentifiers }.first
    }
    
    // transactionsが変わるたびに呼ばれる
    // Transactionの状態により処理したい内容を記述する
    // トランザクションを終了すると消耗型のレシートは消失し、そのTransactionは復元できないので注意
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing: // キューに追加された
                break;
            case .purchased:  // 購入が完了
                if transaction.payment.productIdentifier == premiumId {
                    setPlan(plan: .premium)
                    PurchaseView.hostingViewController?.dismiss(animated: true)
                    PurchaseView.hostingViewController = nil
                    ViewController.shared?.premiumChng()
                }
                break
            case .restored: // 購入履歴から復元が完了
                if transaction.payment.productIdentifier == premiumId {
                    setPlan(plan: .premium)
                    PurchaseView.hostingViewController?.dismiss(animated: true)
                    PurchaseView.hostingViewController = nil
                    ViewController.shared?.premiumChng()
                }
            case .deferred: // 購入処理は保留されており、承認まち
                break
            case .failed:   // キューに追加される前にリクエストが失敗
                break;
            default:
                break
            }
        }
    }
}
// 取得処理の結果は`SKProductsRequestDelegate`に通知される
extension StoreManager: SKProductsRequestDelegate {
    // product情報の取得完了
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products
    }
}
