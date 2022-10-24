//
//  SwiftUIView.swift
//  ShadowClone
//
//  Created by tmatsuda on 2022/10/24.
//

import SwiftUI

struct PurchaseView: View {
    public static let `default` = PurchaseView(pageName: "プレミアム　購入特典",
                                               pros: ["動画の時間制限が無制限",
                                                      "全ての広告が非表示",
                                                      "動画のロゴ表示が選択可能" ],
                                               cons: [])
    let pageName:String
    let pros: [String]
    let cons: [String]
    
    var body: some View {
        GeometryReader { geomReader in
            VStack {
                PositiveLabel("HIDDEN SPACER").hidden()
                Text(pageName)
                    .foregroundColor(.primary)
                    .padding(.bottom)
                    // Pad the view a total of 25% (12.5% on each side).
                    .padding(.horizontal, geomReader.size.width / 12.5)
                    .multilineTextAlignment(.center)
                
                Divider()
                
                PositiveLabel("HIDDEN SPACER").hidden()
                Text("プレミアムを購入すると\n以下の機能が永久的に使用可能")
                    .foregroundColor(.primary)
                    .padding(.bottom)
                    // Pad the view a total of 25% (12.5% on each side).
                    .padding(.horizontal, geomReader.size.width / 12.5)
                    .multilineTextAlignment(.center)
                
                ProConListView(pros: pros, cons: cons)
                    .padding()
                Button("プレミアム　購入", action: {
                    StoreManager.shared.purchaseProduct(premiumId)
                }).font(Font.system(size: 20))
                Spacer()
            }
            .frame(width: geomReader.size.width, height: geomReader.size.height)
        }
        .navigationBarTitle(pageName, displayMode: .inline)
       
    }
}

struct ProConListView: View {
    let pros: [String]
    let cons: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(pros, id: \.self) { pro in
                PositiveLabel(pro)
                PositiveLabel("HIDDEN SPACER").hidden()
            }
            PositiveLabel("HIDDEN SPACER").hidden()
            ForEach(cons, id: \.self) { con in
                NegativeLabel(con)
            }
        }
    }
}

/// This label uses the `.secondary` color for its text and has a green checkmark icon. It's used to
/// denote good capture practices.
struct PositiveLabel: View {
    let text: String
    
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Group {
            Label(title: {
                Text(text)
                    .foregroundColor(.secondary)
            }, icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.green)
            })
        }
    }
}


/// This label uses the `.secondary` color for its text and has a red X icon. It's used to denote bad
/// capture practices.
struct NegativeLabel: View {
    let text: String
    
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Group {
            Label(title: {
                Text(text)
                    .foregroundColor(.secondary)
            }, icon: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(Color.red)
            })
        }
    }
}


struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView.default
    }
}
