//
//  VisionManager.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import Vision
import UIKit
import AVFoundation
import CoreImage

public class  VisionManager {
    public init() {}

    lazy var personSegmentationRequest:VNImageBasedRequest? = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        return request
    }()

    public func setQualityLevel(_ level:VNGeneratePersonSegmentationRequest.QualityLevel) {
        guard let personSegmentationRequest = self.personSegmentationRequest as? VNGeneratePersonSegmentationRequest else { return }
        personSegmentationRequest.qualityLevel = level
    }

    public func setOutputPicelFormt(_ format:OSType) {
        guard let personSegmentationRequest = self.personSegmentationRequest as? VNGeneratePersonSegmentationRequest else { return }
        personSegmentationRequest.outputPixelFormat = format
    }

    lazy var humanRectanglesRequest:VNDetectHumanRectanglesRequest = {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = false
        return request
    }()

    let ciContext = CIContext()
    // MARK: Segmentation
    
    public func personMaskImage(uiImage:UIImage) -> UIImage? {
        let newImage = getCorrectOrientationUIImage(uiImage:uiImage)
        guard let ciImage = CIImage(image: newImage),
              let scaledMask =  personMaskImage(ciImage: ciImage).image ,
              let safeCGImage = ciContext.createCGImage(scaledMask, from: scaledMask.extent) else {
            print("Image processing failed.Please try with another image.") ;
            return nil
        }
        return UIImage(cgImage: safeCGImage)
    }

    public func personMaskImage(ciImage:CIImage, needHumanRect:Bool = false) -> (image:CIImage?, humanRect:[CGRect]?) {
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            let result :VNPixelBufferObservation

            // request
            guard let personSegmentationRequest = personSegmentationRequest else { return (nil, nil) }
            let request: [VNRequest] = needHumanRect ? [personSegmentationRequest, humanRectanglesRequest] : [personSegmentationRequest]

            // perform
            try handler.perform(request)
            // result
            
            guard let resultObj = personSegmentationRequest.results?.first as? VNPixelBufferObservation else { print("Image processing failed.Please try with another image.") ; return (nil, nil) }
            result = resultObj

            let maskCIImage = CIImage(cvPixelBuffer: result.pixelBuffer)
            let size = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
            if needHumanRect {
                //人物型にくり抜く
                if let humanResults = humanRectanglesRequest.results, humanResults.count > 0
                {
                    let humanRects = humanResults.compactMap{ VNImageRectForNormalizedRect(($0.boundingBox),Int(size.width), Int(size.height)) }
                    return (maskCIImage.resize(as: size), humanRects)
                }
            }

            return (maskCIImage.resize(as: size), nil)
            
        } catch let error {
            print("Vision error \(error)")
            return (nil, nil)
        }
    }

    fileprivate var clearBackground:CIImage? = nil
    public func initClearBackground(cameraSize:CGSize) {
        clearBackground = nil
        UIGraphicsBeginImageContext(cameraSize)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let layer = CALayer()
        layer.frame = CGRect(origin: CGPoint(x:0,y:0), size: cameraSize)
        layer.backgroundColor = CGColor.init(gray: 0, alpha: 0)
        layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image = image { clearBackground = CIImage(image:image) }
    }

    public func personImage(ciImage:CIImage, needHumanRect:Bool = false) -> (image:CIImage?, humanRects:[CGRect]?) {
        let personResult = personMaskImage(ciImage:ciImage, needHumanRect:needHumanRect)
        guard let maskImage = personResult.image else { return (nil, nil)}

        if let background = clearBackground {
            guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputBackgroundImageKey:background,
                kCIInputMaskImageKey:maskImage])?.outputImage,
            let safeCGImage = self.ciContext.createCGImage(blended, from: blended.extent) else { return (ciImage, nil)}
            let outCIImage = CIImage(cgImage: safeCGImage)
            if needHumanRect, let humanRect = personResult.humanRect{
                return (outCIImage, humanRect);
            } else {
                return (outCIImage, nil)
            }
        } else {
            return (ciImage, nil)
        }
    }

    public func swapBackgroundOfPerson(personUIImage: UIImage, backgroundUIImage: UIImage) -> UIImage? {
        let newPersonUIImage = getCorrectOrientationUIImage(uiImage:personUIImage)
        let newBackgroundUIImage = getCorrectOrientationUIImage(uiImage:backgroundUIImage)

        guard let personCIImage = CIImage(image: newPersonUIImage),
              let backgroundCIImage = CIImage(image: newBackgroundUIImage),
              let maskUIImage = personMaskImage(uiImage: newPersonUIImage),
              let maskCIImage = CIImage(image: maskUIImage) else { return nil }

        let backgroundImageSize = backgroundCIImage.extent
        let originalSize = personCIImage.extent
        var scale:CGFloat = 1
        let widthScale =  originalSize.width / backgroundImageSize.width
        let heightScale = originalSize.height / backgroundImageSize.height
        if widthScale > heightScale {
            scale = personCIImage.extent.width / backgroundImageSize.width
        } else {
            scale = personCIImage.extent.height / backgroundImageSize.height
        }

        let scaledBG = backgroundCIImage.resize(as: CGSize(width: backgroundCIImage.extent.width*scale, height: backgroundCIImage.extent.height*scale))
        let BGCenter = CGPoint(x: scaledBG.extent.width/2, y: scaledBG.extent.height/2)
        let originalExtent = personCIImage.extent
        let cropRect = CGRect(x: BGCenter.x-(originalExtent.width/2), y: BGCenter.y-(originalExtent.height/2), width: originalExtent.width, height: originalExtent.height)
        let croppedBG = scaledBG.cropped(to: cropRect)
        let translate = CGAffineTransform(translationX: -croppedBG.extent.minX, y: -croppedBG.extent.minY)
        let traslatedBG = croppedBG.transformed(by: translate)

        guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: personCIImage,
            kCIInputBackgroundImageKey:traslatedBG,
            kCIInputMaskImageKey:maskCIImage])?.outputImage else { return nil }

        guard let safeCGImage = ciContext.createCGImage(blended, from: blended.extent) else { print("Image processing failed.Please try with another image.") ; return nil }
        let blendedUIImage = UIImage(cgImage: safeCGImage)
        return blendedUIImage
    }

    public func swapBackgroundOfPersonFromCIImage(personCIImage: CIImage, backgroundUIImage: UIImage) -> CIImage? {
        let newBackgroundUIImage = getCorrectOrientationUIImage(uiImage:backgroundUIImage)
        guard let backgroundCIImage = CIImage(image: newBackgroundUIImage) else { return nil }

        return swapBackgroundOfPersonFrom2CIImage(personCIImage: personCIImage, backgroundCIImage: backgroundCIImage)
    }

    public func swapBackgroundOfPersonFrom2CIImage(personCIImage: CIImage, backgroundCIImage: CIImage) -> CIImage? {
        guard let maskCIImage = personMaskImage(ciImage: personCIImage).image else { return nil }
        let backgroundImageSize = backgroundCIImage.extent
        let originalSize = personCIImage.extent
        var scale:CGFloat = 1
        let widthScale =  originalSize.width / backgroundImageSize.width
        let heightScale = originalSize.height / backgroundImageSize.height

        if widthScale > heightScale {
            scale = personCIImage.extent.width / backgroundImageSize.width
        } else {
            scale = personCIImage.extent.height / backgroundImageSize.height
        }

        let scaledBG = backgroundCIImage.resize(as: CGSize(width: backgroundCIImage.extent.width*scale, height: backgroundCIImage.extent.height*scale))
        let BGCenter = CGPoint(x: scaledBG.extent.width/2, y: scaledBG.extent.height/2)
        let originalExtent = personCIImage.extent
        let cropRect = CGRect(x: BGCenter.x-(originalExtent.width/2), y: BGCenter.y-(originalExtent.height/2), width: originalExtent.width, height: originalExtent.height)
        let croppedBG = scaledBG.cropped(to: cropRect)
        let translate = CGAffineTransform(translationX: -croppedBG.extent.minX, y: -croppedBG.extent.minY)
        let traslatedBG = croppedBG.transformed(by: translate)

        guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: personCIImage,
            kCIInputBackgroundImageKey:traslatedBG,
            kCIInputMaskImageKey:maskCIImage])?.outputImage,
              let safeCGImage = self.ciContext.createCGImage(blended, from: blended.extent) else { return personCIImage }
            let outCIImage = CIImage(cgImage: safeCGImage)
        return outCIImage
    }

    // MARK: Rectangle
    public func swapBackgroundOfPersonVideo(videoURL:URL, backgroundUIImage: UIImage, codec: AVVideoCodecType, _ completion: ((_ err: NSError?, _ filteredVideoURL: URL?) -> Void)?) {

        guard var bgCIImage = CIImage(image: backgroundUIImage) else { print("background image is nil") ; return}

        applyProcessingOnVideo(videoURL: videoURL, codec: codec, { ciImage in
            let personCIImage = ciImage
            let backgroundCIImage = bgCIImage
            var maskCIImage:CIImage
            let handler = VNImageRequestHandler(ciImage: personCIImage, options: [:])
            do {
                    guard let personSegmentationRequest = self.personSegmentationRequest as? VNGeneratePersonSegmentationRequest else { return nil }
                    try handler.perform([personSegmentationRequest])
                    guard let result = personSegmentationRequest.results?.first
                           else { print("Image processing failed.Please try with another image.") ; return nil }
                    let maskImage = CIImage(cvPixelBuffer: result.pixelBuffer)
                    let scaledMask = maskImage.resize(as: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))
                    guard let safeCGImage = self.ciContext.createCGImage(scaledMask, from: scaledMask.extent) else { print("Image processing failed.Please try with another image.") ; return nil }
                    maskCIImage = CIImage(cgImage: safeCGImage)
            } catch let error {
                print("Vision error \(error)")
                return ciImage
            }

            let backgroundImageSize = backgroundCIImage.extent
            let originalSize = personCIImage.extent
            var scale:CGFloat = 1
            let widthScale =  originalSize.width / backgroundImageSize.width
            let heightScale = originalSize.height / backgroundImageSize.height
            if widthScale > heightScale {
                scale = personCIImage.extent.width / backgroundImageSize.width
            } else {
                scale = personCIImage.extent.height / backgroundImageSize.height
            }
            let scaledBG = backgroundCIImage.resize(as: CGSize(width: backgroundCIImage.extent.width*scale, height: backgroundCIImage.extent.height*scale))
            let BGCenter = CGPoint(x: scaledBG.extent.width/2, y: scaledBG.extent.height/2)
            let originalExtent = personCIImage.extent
            let cropRect = CGRect(x: BGCenter.x-(originalExtent.width/2), y: BGCenter.y-(originalExtent.height/2), width: originalExtent.width, height: originalExtent.height)
            let croppedBG = scaledBG.cropped(to: cropRect)
            let translate = CGAffineTransform(translationX: -croppedBG.extent.minX, y: -croppedBG.extent.minY)
            let traslatedBG = croppedBG.transformed(by: translate)
            guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: personCIImage,
                kCIInputBackgroundImageKey:traslatedBG,
                kCIInputMaskImageKey:maskCIImage])?.outputImage,
                  let safeCGImage = self.ciContext.createCGImage(blended, from: blended.extent) else { return ciImage}
                    let outCIImage = CIImage(cgImage: safeCGImage)
            return outCIImage
        } , { err, processedVideoURL in
            guard err == nil else { print(err?.localizedDescription); return }
            completion?(err,processedVideoURL)
        })
    }

    public func ciFilterVideo(videoURL:URL, ciFilter: CIFilter, _ completion: ((_ err: NSError?, _ filteredVideoURL: URL?) -> Void)?) {
        applyProcessingOnVideo(videoURL: videoURL, { ciImage in
            ciFilter.setValue(ciImage, forKey: kCIInputImageKey)
            let outCIImage = ciFilter.outputImage
            return outCIImage
        } , { err, processedVideoURL in
            guard err == nil else { print(err?.localizedDescription as Any); return }
            completion?(err,processedVideoURL)
        })
    }

    public func applyProcessingOnVideo(videoURL:URL, codec: AVVideoCodecType = .h264, _ processingFunction: @escaping ((CIImage) -> CIImage?), _ completion: ((_ err: NSError?, _ processedVideoURL: URL?) -> Void)?) {
        var frame:Int = 0
        var isFrameRotated = false
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.value
        let frameRate = asset.preferredRate
        let totalFrame = frameRate * Float(duration)
        let err: NSError = NSError.init(domain: " VisionManager", code: 999, userInfo: [NSLocalizedDescriptionKey: "Video Processing Failed"])
        let writingDestinationUrl: URL  = videoURL.deletingLastPathComponent().appendingPathComponent("\(Date())" + ".mp4")

        // setup
        guard let reader: AVAssetReader = try? AVAssetReader.init(asset: asset) else {
            completion?(err, nil)
            return
        }

        guard let writer: AVAssetWriter = try? AVAssetWriter(outputURL: writingDestinationUrl, fileType: AVFileType.mov) else {
            completion?(err, nil)
            return
        }

        // setup finish closure
        var audioFinished: Bool = false
        var videoFinished: Bool = false
        let writtingFinished: (() -> Void) = {
            if audioFinished == true && videoFinished == true {
                writer.finishWriting {
                    completion?(nil, writingDestinationUrl)
                }
                reader.cancelReading()
            }
        }

        // prepare video reader
        let readerVideoOutput: AVAssetReaderTrackOutput = AVAssetReaderTrackOutput(
            track: asset.tracks(withMediaType: AVMediaType.video)[0],
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            ]
        )

        reader.add(readerVideoOutput)
        // prepare audio reader

        var readerAudioOutput: AVAssetReaderTrackOutput!
        if asset.tracks(withMediaType: AVMediaType.audio).count <= 0 {
            audioFinished = true
        } else {
            readerAudioOutput = AVAssetReaderTrackOutput.init(
                track: asset.tracks(withMediaType: AVMediaType.audio)[0],
                outputSettings: [
                    AVSampleRateKey: 44100,
                    AVFormatIDKey:   kAudioFormatLinearPCM,
                ]
            )

            if reader.canAdd(readerAudioOutput) {
                reader.add(readerAudioOutput)
            } else {
                print("Cannot add audio output reader")
                audioFinished = true
            }
        }

        // prepare video input
        let transform = asset.tracks(withMediaType: AVMediaType.video)[0].preferredTransform
        let radians = atan2(transform.b, transform.a)
        let degrees = (radians * 180.0) / .pi

        var writerVideoInput: AVAssetWriterInput
        switch degrees {
        case 90:
            let rotateTransform = CGAffineTransform(rotationAngle: 0)
            writerVideoInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.video,
                outputSettings:
                    [
                    AVVideoCodecKey:                 codec,
                    AVVideoWidthKey:                 asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.height,
                    AVVideoHeightKey:                asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.width,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: asset.tracks(withMediaType: AVMediaType.video)[0].estimatedDataRate,
                        AVVideoProfileLevelKey : codec == .hevc ? "HEVC_Main_AutoLevel" : "H264_Main_AutoLevel"
                    ],
                ]
            )
            writerVideoInput.expectsMediaDataInRealTime = false
            isFrameRotated = true
            writerVideoInput.transform = rotateTransform
        default:
            writerVideoInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.video,
                outputSettings:
                [
                    AVVideoCodecKey:                 codec,
                    AVVideoWidthKey:                 asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.width,
                    AVVideoHeightKey:                asset.tracks(withMediaType: AVMediaType.video)[0].naturalSize.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: asset.tracks(withMediaType: AVMediaType.video)[0].estimatedDataRate,
                        AVVideoProfileLevelKey : codec == .hevc ? "HEVC_Main_AutoLevel" : "H264_Main_AutoLevel"
                    ],
                ]
            )
            writerVideoInput.expectsMediaDataInRealTime = false
            isFrameRotated = false
            writerVideoInput.transform = asset.tracks(withMediaType: AVMediaType.video)[0].preferredTransform
        }
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerVideoInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        writer.add(writerVideoInput)

        // prepare writer input for audio
        var writerAudioInput: AVAssetWriterInput! = nil
        if asset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            let formatDesc: [Any] = asset.tracks(withMediaType: AVMediaType.audio)[0].formatDescriptions
            var channels: UInt32 = 1
            var sampleRate: Float64 = 44100.000000
            for i in 0 ..< formatDesc.count {
                guard let bobTheDesc: UnsafePointer<AudioStreamBasicDescription> = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc[i] as! CMAudioFormatDescription) else {
                    continue
                }
                channels = bobTheDesc.pointee.mChannelsPerFrame
                sampleRate = bobTheDesc.pointee.mSampleRate
                break
            }

            writerAudioInput = AVAssetWriterInput.init(
                mediaType: AVMediaType.audio,
                outputSettings: [
                    AVFormatIDKey:         kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: channels,
                    AVSampleRateKey:       sampleRate,
                ]
            )
            writerAudioInput.expectsMediaDataInRealTime = true
            writer.add(writerAudioInput)
        }

        // write
        let videoQueue = DispatchQueue.init(label: "videoQueue")
        let audioQueue = DispatchQueue.init(label: "audioQueue")
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        // write video
        writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            while writerVideoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if let buffer = readerVideoOutput.copyNextSampleBuffer(),let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
                        frame += 1
                        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                        if isFrameRotated {
                            ciImage = ciImage.oriented(CGImagePropertyOrientation.right)
                        }

                        guard let outCIImage = processingFunction(ciImage) else { print("Video Processing Failed") ; return }
                        let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(buffer)
                        var pixelBufferOut: CVPixelBuffer?
                        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBufferOut)
                        self.ciContext.render(outCIImage, to: pixelBufferOut!)
                        pixelBufferAdaptor.append(pixelBufferOut!, withPresentationTime: presentationTime)
//                        if frame % 100 == 0 {
//                            print("\(frame) / \(totalFrame) frames were processed..")
//                        }
                    } else {
                        writerVideoInput.markAsFinished()
                        DispatchQueue.main.async {
                            videoFinished = true
                            writtingFinished()
                        }
                    }
                }
            }
        }
        if writerAudioInput != nil {
            writerAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                while writerAudioInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        let buffer = readerAudioOutput.copyNextSampleBuffer()
                        if buffer != nil {
                            writerAudioInput.append(buffer!)
                        } else {
                            writerAudioInput.markAsFinished()
                            DispatchQueue.main.async {
                                audioFinished = true
                                writtingFinished()
                            }
                        }
                    }
                }
            }
        }
    }

    func scaleMaskImage(maskCIImage:CIImage, originalCIImage:CIImage) -> CIImage {
        let scaledMaskCIImage = maskCIImage.resize(as: originalCIImage.extent.size)
        return scaledMaskCIImage
    }

    public func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
            var newImage = UIImage()
            switch uiImage.imageOrientation.rawValue {
            case 1:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                      let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                newImage = UIImage(cgImage: cgImage)

            case 3:
                guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                        let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
                newImage = UIImage(cgImage: cgImage)

            default:
                newImage = uiImage
            }

        return newImage

    }

}
