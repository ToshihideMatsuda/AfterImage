//
//  AppUtil.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/21.
//

import Foundation

public var isPhone:Bool = {
    let machine = ObjcUtil.hardwareName()
    
    let value = machine.components(separatedBy: ",")
    if value.count == 0 { return false }
    
    let model = value[0]
    if model.contains("iPhone") { return true }
    else { return false }
}()

public var isNeuralEngine:Bool = {
    let machine = ObjcUtil.hardwareName()
    
    let value = machine.components(separatedBy: ",")
    if value.count == 0 { return false }
    
    let model = value[0]
    
    if model.contains("iPad")
    {
        let from = model.index(model.startIndex, offsetBy: 4)
        guard let number =  Int(model[from ..< model.endIndex]) else { return false}
        // A11以上の搭載機種
        // iPad 8th 以上    (iPad11,6, or iPad11,7）
        // iPad Air 3th以上 (iPad11,3, or iPad11,4）
        // iPad Pro 3th以上 (iPad8,x） //iPad9,xとiPad10,xはこの世に存在しない
        if(8 <= number)
        {
            return true
        }
        else {
            return false
        }
    } else if model.contains("iPhone") {
        let from = model.index(model.startIndex, offsetBy: 6)
        guard let number =  Int(model[from ..< model.endIndex]) else { return false}
        // A11以上の搭載機種
        // iPhone 8 以上    (iPhone10,x）
        if(10 <= number)
        {
            return true
        }
        else {
            return false
        }
    }
    else {
        return true
    }
}()
