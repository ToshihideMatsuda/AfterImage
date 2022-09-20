//
//  CameraViewController.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import UIKit
import AVFoundation

public let cameraSaveQueue = DispatchQueue.init(label: "CameraViewController.saveQueue")

class CameraViewController:UIViewController, VideoListener, AudioListener {
    
    @IBOutlet weak var mainVideoView: AVPlayerLayerView!
    private var preset     :AVCaptureSession.Preset = .high
    
    private var isRec:Bool = false
    
    private var frameNumber :Int = 0
    private var firstFrameNo:Int = 0
    private var interval    :Double = 1.0
    private var startTime   :CMTime = CMTime.zero
    private var prevTime    :CMTime = CMTime.zero
    private var endTime     :CMTime = CMTime.zero
    
    private var assetWriter : AVAssetWriter? = nil
    private var videoAssetInput: AVAssetWriterInput? = nil
    private var audioAssetInput: AVAssetWriterInput? = nil
    private var videoPixcelBuffer: AVAssetWriterInputPixelBufferAdaptor? = nil
    
    private let queueSize            = 5;
    private var imageQueue:[CIImage] = []
    
    override func viewWillAppear(_ animated: Bool) {
        AVCaptureManager.shared.addVideoListener(listener: self)
        AVCaptureManager.shared.addAudioListener(listener: self)
        AVCaptureManager.shared.initializeCamera(true, frameRateInput: 20, preset: preset)
        VisionManager.shared.initClearBackground(cameraSize: AVCaptureManager.shared.getVideoSize() ?? CGSize(width: 720, height: 1280))
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        AVCaptureManager.shared.removeVideoListener(listener: self)
        AVCaptureManager.shared.removeVideoListener(listener: self)
    }
    
    public func videoCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //video
        
        let (imageBufferObj, size) = sampleBuffer.imageBuffer()
        guard let imageBuffer = imageBufferObj else { return }
        
        let videoImage  : CIImage = CIImage(cvPixelBuffer: imageBuffer)
        let currentImage = VisionManager.shared.personImage(ciImage: videoImage)
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameTime   = CMTimeSubtract(currentTime, self.prevTime)
        
        let currentImageQueue = imageQueue + [currentImage]
        var compositImage = videoImage
        
        if(imageQueue.count >= 1) {
            for i in 0 ..< currentImageQueue.count {
                guard let image = currentImageQueue[i],
                      let blended = CIFilter(name:"CISourceOverCompositing", parameters:[
                        kCIInputImageKey            : image,
                        kCIInputBackgroundImageKey  : compositImage
                      ])?.outputImage else { break; }
                compositImage = blended
            }
        }
        
        DispatchQueue.main.sync {
            //CGImage
            self.mainVideoView.mainlayer?.contents = ciContext.createCGImage(compositImage,
                                                                             from: CGRect(origin: CGPoint(x: 0, y: 0),
                                                                             size: videoImage.extent.size))
        }
        
        if self.prevTime == CMTime.zero {
            self.prevTime = currentTime
        } else if frameTime.seconds >= interval {
            // 次回のためにQueueを更新
            self.prevTime = currentTime
            if let currentImage = currentImage {
                imageQueue += [currentImage]
                while( imageQueue.count > queueSize ) { imageQueue.removeFirst() }
            }

        }
        
        if isRec {
            if frameNumber < firstFrameNo {
                //最初のフレームを無視（暗転しているため）
                frameNumber += 1
                return
            }
            
            if(frameNumber == firstFrameNo) {
                startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let frameTime = CMTimeSubtract(timestamp, startTime)
            
            frameNumber += 1;
            cameraSaveQueue.async { self.saveVideoBuffer(size, videoImage:videoImage, frameTime:frameTime) }
        }
    }
    
    public func audioCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //audio
        
        if isRec {
            if frameNumber <= firstFrameNo {
                //必ずvideoを先に記録
                return
            }
        }
        cameraSaveQueue.async { self.saveAudioBuffer(sampleBuffer) }
    }
    
    public func saveVideoBuffer (_ size:CGSize, videoImage:CIImage, frameTime:CMTime) {
        
        guard let input = assetWriter?.inputs.filter ({ $0.mediaType == .video }).first else { return }

        if input.isReadyForMoreMediaData {
            if let pixcelBuffer = videoImage.pixelBuffer(cgSize: size),
               let videoPixcelBuffer = videoPixcelBuffer {
                let ok = videoPixcelBuffer.append(pixcelBuffer, withPresentationTime: frameTime);
                if(!ok) {
                    DispatchQueue.main.sync{ print("video: ng") }
                }
                endTime = frameTime
            }
        } else {
            // not Ready
            cameraSaveQueue.async { self.saveVideoBuffer(size, videoImage:videoImage, frameTime:frameTime) }
        }
    }

    public func saveAudioBuffer (_ sampleBuffer:CMSampleBuffer) {
        guard let input = assetWriter?.inputs.filter ({ $0.mediaType == .audio }).first else { return }
        if input.isReadyForMoreMediaData {
            do {
                let copyBuffer = try sampleBuffer.offsettingTiming(by: self.startTime)
                let ok = input.append(copyBuffer)
                if(!ok) {
                    DispatchQueue.main.sync { print("audio: ng") }
                }
            } catch {
                DispatchQueue.main.sync { print("audio:err") }
            }
        } else {
            cameraSaveQueue.async { self.saveAudioBuffer(sampleBuffer) }
        }
    }
    
    public func startRecordingToOutputFileURL(_ url:URL){
        // バッファでの出力（ニューラルエンジン搭載）
        let videoSettings       = AVCaptureManager.shared.recommendedVideoSettingsForAssetWriter(writingTo: AVFileType.mp4)
        let videoAssetInput     = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

        self.videoAssetInput    = videoAssetInput

        videoAssetInput.expectsMediaDataInRealTime = true;
        videoPixcelBuffer       = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoAssetInput,
                                                                       sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String : Int(AVCaptureManager.pixcelFormat)])

        let audioSettings       = AVCaptureManager.shared.recommendedAudioSettingsForAssetWriter(writingTo: AVFileType.mp4)
        let audioAssetInput     = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        self.audioAssetInput    = audioAssetInput
        audioAssetInput.expectsMediaDataInRealTime = true;
        audioAssetInput.preferredVolume = 1.0
        frameNumber = 0;

        do {
            let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            self.assetWriter = assetWriter
            
            if assetWriter.canAdd(audioAssetInput) { assetWriter.add(audioAssetInput) }
            if assetWriter.canAdd(videoAssetInput) { assetWriter.add(videoAssetInput) }
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: CMTime.zero)
        } catch {
            print("error: ", error)
        }
    }

    @objc func stopRecording() {
        // バッファでの出力（ニューラルエンジン搭載）
        guard let videoAssetInput = videoAssetInput, let audioAssetInput = audioAssetInput, let assetWriter = assetWriter else { return }
        
        videoAssetInput.markAsFinished()
        audioAssetInput.markAsFinished()
        assetWriter.endSession(atSourceTime: endTime)

        assetWriter.finishWriting {
            self.videoAssetInput = nil
            self.audioAssetInput = nil
            self.assetWriter = nil
            self.frameNumber = 0;
            self.startTime = CMTime.zero
            self.endTime = CMTime.zero
        }
    }
}



class AVPlayerLayerView:UIView {
    
    public lazy var mainlayer:AVPlayerLayer? = {
        let layer = AVPlayerLayer()
        self.layer.addSublayer(layer)
        layer.frame = self.bounds
        return layer
    }();
}
