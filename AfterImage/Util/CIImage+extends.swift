//
//  CIImage+extends.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import CoreImage
import AVFoundation


extension CIImage {
    func sampleBuffer(cgSize size:CGSize, originalBuffer:CMSampleBuffer) -> CMSampleBuffer? {
        var cvSampleBuffer: CMSampleBuffer? = originalBuffer
        if let pixcelBuffer = self.pixelBuffer(cgSize: size){
            let timestamp = CMSampleBufferGetPresentationTimeStamp(originalBuffer)
            var timimgInfo = CMSampleTimingInfo(duration:              CMSampleBufferGetDuration(originalBuffer),
                                                presentationTimeStamp: timestamp,
                                                decodeTimeStamp:       CMSampleBufferGetDecodeTimeStamp(originalBuffer))
            var videoInfo: CMVideoFormatDescription!
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixcelBuffer, formatDescriptionOut: &videoInfo)
            CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                imageBuffer: pixcelBuffer,
                                                dataReady: true,
                                                makeDataReadyCallback: nil,
                                                refcon: nil,
                                                formatDescription: videoInfo,
                                                sampleTiming: &timimgInfo,
                                                sampleBufferOut: &cvSampleBuffer)
        }
        return cvSampleBuffer
    }

    func pixelBuffer(cgSize size:CGSize, pixcelFormat:OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width:Int = Int(size.width)
        let height:Int = Int(size.height)
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            pixcelFormat,
                            attrs,
                            &pixelBuffer)

        // put bytes into pixelBuffer
        let context = CIContext()
        context.render(self, to: pixelBuffer!)
        return pixelBuffer
    }

    func resizeInContainer(container:CGSize, resizeQ:CGSize?=nil) -> CIImage? {
        let resize:CGSize = resizeQ ?? container
        var image = self
        do {
            let scale = min(resize.width / image.extent.width, resize.height / image.extent.height)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        //container分の透明なフチを確保
        let point = CGPoint(x: (image.extent.width  - container.width)/2,
                            y: (image.extent.height - container.height)/2)
        let rect:CGRect = CGRect.init(origin: point, size: container)
        guard let cgImage = ciContext.createCGImage(image, from: rect) else { return nil }
        return CIImage(cgImage: cgImage)
    }

    func resize(as size: CGSize) -> CIImage {
        let selfSize = extent.size
        let transform = CGAffineTransform(scaleX: size.width / selfSize.width, y: size.height / selfSize.height)
        return transformed(by: transform)
    }

    func inContainer(container:CGSize, point:CGPoint? = nil) -> CIImage? {
        //container分の透明なフチを確保
        let point = point ??  CGPoint(x: (self.extent.width  - container.width)/2,
                                      y: (self.extent.height - container.height)/2)

        let rect:CGRect = CGRect.init(origin: point, size: container)
        guard let cgImage = ciContext.createCGImage(self, from: rect) else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
