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
    private let frameRate:Double = 10.0
    private var prevTime = CMTime.zero
    public static var shared : VisionManager = VisionManager()
    public var cancel : Bool = false {
        didSet {
            if cancel {
                VisionManager.shared = VisionManager()
            }
        }
    }
    private init() {}

    lazy var personSegmentationRequest:VNGeneratePersonSegmentationRequest? = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        return request
    }()
    

    public func setQualityLevel(_ level:VNGeneratePersonSegmentationRequest.QualityLevel) {
        guard let personSegmentationRequest = self.personSegmentationRequest else { return }
        personSegmentationRequest.qualityLevel = level
    }

    public func setOutputPicelFormt(_ format:OSType) {
        guard let personSegmentationRequest = self.personSegmentationRequest  else { return }
        personSegmentationRequest.outputPixelFormat = format
    }

    
    // MARK: Segmentation
    private var clearBackground:CIImage? = nil
    private func getClearBackground(cameraSize:CGSize) -> CIImage? {
        if clearBackground == nil || clearBackground?.extent.size != cameraSize {
            self.initClearBackground(cameraSize: cameraSize)
        }
        return clearBackground
    }
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
    public func personImage(ciImage:CIImage) -> CIImage? {
        guard let maskImage = personMaskImage(ciImage:ciImage) else { return ciImage }

        if let background = getClearBackground(cameraSize:ciImage.extent.size) {
            guard let blended = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputBackgroundImageKey:background,
                kCIInputMaskImageKey:maskImage])?.outputImage  else { return ciImage }
            return blended
        } else {
            return ciImage
        }
    }
    
    private func personMaskImage(ciImage:CIImage) -> CIImage? {
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            // request
            guard let personSegmentationRequest = personSegmentationRequest else { return nil }
            let request: [VNRequest] = [personSegmentationRequest]
            // perform
            try handler.perform(request)
            // result
            guard let result = personSegmentationRequest.results?.first as? VNPixelBufferObservation else { print("Image processing failed.Please try with another image.") ; return nil }

            let maskCIImage = CIImage(cvPixelBuffer: result.pixelBuffer)
            let size = CGSize(width: ciImage.extent.width, height: ciImage.extent.height)
            return maskCIImage.resize(as: size)
            
        } catch let error {
            print("Vision error \(error)")
            return nil
        }
    }


    // MARK: Rectangle
    public func swapBackgroundOfPersonVideo(videoURL:URL, backgroundUIImage: UIImage, codec: AVVideoCodecType, _ completion: ((_ err: NSError?, _ filteredVideoURL: URL?) -> Void)?) {

        guard let _ = CIImage(image: backgroundUIImage) else { print("background image is nil") ; return}

        applyProcessingOnVideo(videoURL: videoURL, codec: codec, { pixelBuffer, _, isFrameRotated in
            
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if isFrameRotated {
                ciImage = ciImage.oriented(CGImagePropertyOrientation.right)
            }
            
            let personCIImage = ciImage
            let backgroundCIImage = ciImage
            var maskCIImage:CIImage
            let handler = VNImageRequestHandler(ciImage: personCIImage, options: [:])
            do {
                guard let personSegmentationRequest = self.personSegmentationRequest  else { return ciImage }
                try handler.perform([personSegmentationRequest])
                guard let result = personSegmentationRequest.results?.first
                        else { print("Image processing failed.Please try with another image.") ; return ciImage }
                let maskImage = CIImage(cvPixelBuffer: result.pixelBuffer)
                let scaledMask = maskImage.resize(as: CGSize(width: ciImage.extent.width, height: ciImage.extent.height))
                guard let safeCGImage = ciContext.createCGImage(scaledMask, from: scaledMask.extent) else { print("Image processing failed.Please try with another image.") ; return ciImage }
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
                kCIInputMaskImageKey:maskCIImage])?.outputImage else { return ciImage }
            return blended
            
        } , { err, processedVideoURL in
            guard err == nil else { print(err?.localizedDescription ?? "" ); return }
            completion?(err,processedVideoURL)
        })
    }

    public func applyProcessingOnVideo(videoURL:URL, codec: AVVideoCodecType = .hevc, _ processingFunction: @escaping ((CVImageBuffer, CMTime, Bool) -> CIImage?), _ completion: ((_ err: NSError?, _ processedVideoURL: URL?) -> Void)?) {
        var frame:Int = 0
        var isFrameRotated = false
        let asset = AVURLAsset(url: videoURL)
        let err: NSError = NSError.init(domain: " VisionManager", code: 999, userInfo: [NSLocalizedDescriptionKey: "Video Processing Failed"])
        let writingDestinationUrl: URL  = URL(fileURLWithPath: (NSTemporaryDirectory() + UUID().uuidString + ".mp4"))
        
        // setup
        guard let reader: AVAssetReader = try? AVAssetReader.init(asset: asset) else {
            completion?(err, nil)
            return
        }

        guard let writer: AVAssetWriter = try? AVAssetWriter(outputURL: writingDestinationUrl, fileType: AVFileType.mov) else {
            completion?(err, nil)
            return
        }
        
        var onetimeCompletion = completion
        // setup finish closure
        var audioFinished: Bool = false
        var videoFinished: Bool = false
        var completed:     Bool = false
        let writtingFinished: (() -> Void) = {
            if audioFinished == true && videoFinished == true {
                writer.finishWriting {
                    onetimeCompletion?(nil, writingDestinationUrl)
                    onetimeCompletion = nil
                    completed = true
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
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerVideoInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(AVCaptureManager.pixcelFormat)])
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
        
        self.prevTime = CMTime.zero
        // write video
        writerVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            while writerVideoInput.isReadyForMoreMediaData{
                if completed { return }
                autoreleasepool {
                    if let buffer = readerVideoOutput.copyNextSampleBuffer(),
                       let pixelBuffer = CMSampleBufferGetImageBuffer(buffer),
                       !self.cancel {
                        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
                        let currentTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                        
                        if self.prevTime == CMTime.zero {
                            // nop
                        } else if CMTimeSubtract(currentTime, self.prevTime).seconds < (1.0 / self.frameRate) {
                            // framerate以下は削除
                            //return;
                        }
                        
                        self.prevTime = currentTime
                        
                        frame += 1

                        guard let outCIImage = processingFunction(pixelBuffer, currentTime, isFrameRotated) else { print("Video Processing Failed") ; return }
                        let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(buffer)
                        guard let convImageBuffer = outCIImage.pixelBuffer(cgSize: outCIImage.extent.size, pixcelFormat: pixelFormat) else { return }

                        pixelBufferAdaptor.append(convImageBuffer, withPresentationTime: presentationTime)
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
                    if completed { return }
                    autoreleasepool {
                        let buffer = readerAudioOutput.copyNextSampleBuffer()
                        if buffer != nil, !self.cancel {
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
