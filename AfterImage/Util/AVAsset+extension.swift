//
//  Asset+extents.swift
//  AfterImage
//
//  Created by 松田敏秀 on 2022/09/24.
//

import Foundation
import AVFoundation
import UIKit

extension AVAsset {

  public var size: CGSize {
      return tracks(withMediaType: .video).first?.naturalSize ?? .zero
  }

  public var orientation: UIInterfaceOrientation {
    guard let transform = tracks(withMediaType: .video).first?.preferredTransform else { return .portrait }

    switch (transform.tx, transform.ty) {
    case (0, 0):
      return .landscapeRight
    case (size.width, size.height):
      return .landscapeLeft
    case (0, size.width):
      return .portraitUpsideDown
    default:
      return .portrait
    }
  }
    
    public var naturalSize: CGSize {
        switch self.orientation {
        case .portrait:
            return CGSize(width: size.height, height: size.width)
        case .portraitUpsideDown:
            return CGSize(width: size.height, height: size.width)
        default:
            return size
        }
    }
}
