//
//  AVCaptureManager.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import AVFoundation
import UIKit

public protocol VideoListener  {
    func videoCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

public protocol AudioListener  {
    func audioCapture(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

public class AVCaptureManager : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public static let shared : AVCaptureManager = AVCaptureManager()
    public static var pixcelFormat: OSType  = {
        let osTypes = AVCaptureVideoDataOutput().availableVideoPixelFormatTypes
        if ObjcUtil.enableAction ({
            AVCaptureVideoDataOutput().videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : kCVPixelFormatType_OneComponent32Float]
        }), osTypes.contains(kCVPixelFormatType_OneComponent32Float) {
            
            //kCVPixelFormatType_OneComponent32Floatが指定可能
            return kCVPixelFormatType_OneComponent32Float
        } else if osTypes.contains(kCVPixelFormatType_32BGRA) {
            //kCVPixelFormatType_OneComponent32Floatが指定不可
            return kCVPixelFormatType_32BGRA
        } else {
            return osTypes.first ?? kCVPixelFormatType_32BGRA
        }
    }()

    private var videolistenerDic:[String:VideoListener] = [:]
    private var audiolistenerDic:[String:AudioListener] = [:]
    private let videoOutputQueue = DispatchQueue.init(label: "toshihide.matsuda.AVCaptureManager.videoOutputQueue")
    private let audioOutputQueue = DispatchQueue.init(label: "toshihide.matsuda.AVCaptureManager.audioOutputQueue")

    private var captureSession : AVCaptureSession?
    private var device         : AVCaptureDevice?

    private lazy var audioOutput : AVCaptureAudioDataOutput = {
        let captureAudioOutput = AVCaptureAudioDataOutput()
        captureAudioOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        return captureAudioOutput
    }()

    private lazy var videoOutput : AVCaptureVideoDataOutput = {
        let captureVideoOutput = AVCaptureVideoDataOutput()
        captureVideoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        captureVideoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : AVCaptureManager.pixcelFormat]
        return captureVideoOutput
    }()

    // 外部から初期化不可能にしておく
    private override init() {}

    public func initializeCamera(_ isFront:Bool = true, frameRateInput:Int32 = 20, preset:AVCaptureSession.Preset = .low) {

        if captureSession != nil{
            stopCapture()
        }

        let captureSession = AVCaptureSession();
        self.captureSession = captureSession
        
        captureSession.beginConfiguration()

        videoCaptureSettingInTransaction(captureSession, isFront:isFront, frameRateInput:frameRateInput, preset:preset)
        audioCaptureSettingInTransaction(captureSession)

        captureSession.commitConfiguration()
        captureSession.startRunning()

    }

    public func getPreviewLayer(size:CGSize) -> AVCaptureVideoPreviewLayer? {
        if let captureSession = self.captureSession {
            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.frame.size = size
            preview.videoGravity = .resizeAspect
            
            return preview
        }
        return nil
    }

    fileprivate func videoCaptureSettingInTransaction(_ captureSession:AVCaptureSession, isFront:Bool, frameRateInput:Int32, preset:AVCaptureSession.Preset) {
        // DeviceSetting
        let cap = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInWideAngleCamera],
                                                   mediaType: .video,
                                                   position: .unspecified)
        let devices = cap.devices
        var backCamera:AVCaptureDevice? = nil
        var frontCamera:AVCaptureDevice? = nil;

        for device in devices {
            do { try device.lockForConfiguration() } catch { return; }
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 20)
            device.unlockForConfiguration()

            if ( device.position == .back) {
                backCamera = device;
            }
            else {
                frontCamera = device;
            }
        }

        let input:AVCaptureDeviceInput
        self.device = isFront ? frontCamera : backCamera
        guard let device = self.device else { return }

        do { try input = AVCaptureDeviceInput(device: device ) } catch { return; }
        captureSession.addInput(input)
        
        do {
            // preset
            captureSession.sessionPreset = preset;
            var frameRate = frameRateInput
            if frameRateInput == 0 {
                frameRate = Int32(max(1.00000001/CMTimeGetSeconds(device.activeVideoMinFrameDuration),
                                      1.00000001/CMTimeGetSeconds(device.activeVideoMaxFrameDuration)))
            }

            do{
                try device.lockForConfiguration()
                let supported = device.activeFormat.videoSupportedFrameRateRanges
                if supported.isEmpty {
                // nop
                } else {
                    device.activeVideoMinFrameDuration = max(CMTimeMake(value:1, timescale: frameRate), supported[0].minFrameDuration);
                    device.activeVideoMaxFrameDuration = supported[0].maxFrameDuration;
                }

                device.unlockForConfiguration();
            } catch { /* nop*/ }
        }

        if  captureSession.canAddOutput(self.videoOutput)  {
            captureSession.addOutput(self.videoOutput)
            // videoConnection の方向を直す
            settingVirtualVideoLayer()
        } else {
            print("fail add videoOutput")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { self.initializeCamera() })
        }
    }

    fileprivate func audioCaptureSettingInTransaction(_ captureSession:AVCaptureSession) {
        let audioDevice = AVCaptureDevice.default(for: .audio)
        let audioInput:AVCaptureDeviceInput;
        do { try audioInput = AVCaptureDeviceInput(device: audioDevice! ) } catch { return; }

        captureSession.addInput(audioInput)
        if captureSession.canAddOutput(self.audioOutput)  {
            captureSession.addOutput(self.audioOutput)
        } else {
            print("fail add audioOutput")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { self.initializeCamera() })
        }
    }

    public func settingVirtualVideoLayer() {
        // videoConnection の方向を直す
        guard let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.windowScene?.interfaceOrientation else { return }
        self.videoOutput.connections.forEach{
            if self.device?.position == .back {
                $0.isVideoMirrored = false
            } else {
                $0.isVideoMirrored = true
            }
            $0.videoOrientation = orientation == .landscapeLeft       ? .landscapeLeft :
                                  orientation == .landscapeRight      ? .landscapeRight :
                                  orientation == .portrait            ? .portrait :
                                  orientation == .portraitUpsideDown  ? .portraitUpsideDown : $0.videoOrientation
        }
    }

    public func settingLegacyVideoLayer(videoLayer:AVCaptureVideoPreviewLayer) {
        guard let captureSession = captureSession,
              let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.windowScene?.interfaceOrientation else { return }
        
        if let tmp:AVCaptureVideoOrientation
                   =    orientation == .landscapeLeft      ? .landscapeLeft :
                        orientation == .landscapeRight     ? .landscapeRight :
                        orientation == .portrait           ? .portrait :
                        orientation == .portraitUpsideDown ? .portraitUpsideDown : videoLayer.connection?.videoOrientation
        {
            videoLayer.connection?.videoOrientation =  tmp
            captureSession.connections.forEach{
                if $0.isVideoOrientationSupported { $0.videoOrientation = tmp }
            }
        }
    }

    

    public func cameraPosition() -> AVCaptureDevice.Position? {
        guard let captureSession = self.captureSession,
              let current = captureSession.inputs
                                          .compactMap({ $0 as? AVCaptureDeviceInput })
                                          .first(where: { $0.device.hasMediaType(.video) }) else { return nil }
        return current.device.position
    }

    fileprivate func stopCapture() {
        guard let captureSession = captureSession else { return }
        captureSession.stopRunning()
        captureSession.inputs.forEach{ captureSession.removeInput($0) }
        captureSession.outputs.forEach{ captureSession.removeOutput($0) }

        self.captureSession = nil
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // nop
    }
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if(!CMSampleBufferDataIsReady(sampleBuffer)){
            return;
        }
        let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
        if CMFormatDescriptionGetMediaType(description) == kCMMediaType_Video {
            videolistenerDic.values.forEach{ $0.videoCapture(output, didOutput: sampleBuffer, from: connection) }
        } else {
            audiolistenerDic.values.forEach{ $0.audioCapture(output, didOutput: sampleBuffer, from: connection) }
        }
    }

    public func getVideoSize() -> CGSize? {
        guard let captureSession = self.captureSession else {
            return nil
        }
        
        guard let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.windowScene?.interfaceOrientation,
              let size =  [
            AVCaptureSession.Preset.low         : CGSize(width: 192 , height: 144),   // 3G環境でのリアルタイム配信に適したビットレート
            AVCaptureSession.Preset.medium      : CGSize(width: 480 , height: 360),   // Wifi環境でのリアルタイム配信に適したビットレート
            AVCaptureSession.Preset.high        : CGSize(width: 1920, height: 1080),  // デフォルトではこの設定
            AVCaptureSession.Preset.photo       : CGSize(width: 3088, height: 2316),  // 写真のクオリティ（詳細不明）
            AVCaptureSession.Preset.cif352x288      : CGSize(width: 352,  height: 288),
            AVCaptureSession.Preset.vga640x480      : CGSize(width: 640,  height: 480),
            AVCaptureSession.Preset.hd1280x720      : CGSize(width: 1280, height: 720),
            AVCaptureSession.Preset.hd1920x1080     : CGSize(width: 1920, height: 1080),
            AVCaptureSession.Preset.hd4K3840x2160   : CGSize(width: 3840, height: 2160),
            AVCaptureSession.Preset.iFrame960x540   : CGSize(width: 960,  height: 540),
            AVCaptureSession.Preset.iFrame1280x720  : CGSize(width: 1280, height: 720),
            AVCaptureSession.Preset.inputPriority   : CGSize(width: 0,      height: 0),
        ] [captureSession.sessionPreset] else { return nil }
        
        if(orientation == .landscapeLeft || orientation == .landscapeRight) {
            return size
        } else {
            return CGSize(width: size.height, height: size.width)
        }
    }

    public func recommendedVideoSettingsForAssetWriter(writingTo fileType:AVFileType) -> [String:Any]?  {
        return videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: fileType)
    }

    public func recommendedAudioSettingsForAssetWriter(writingTo fileType: AVFileType) -> [String:Any]?  {
        return audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: fileType)
    }

    public func availableHEVC(fileType: AVFileType) -> Bool {
        return  videoOutput.availableVideoCodecTypesForAssetWriter(writingTo: fileType).contains(.hevc)
    }
}

extension AVCaptureManager {

    public func addVideoListener(listener:VideoListener, key keyInput:String? = nil) {
        let key:String = keyInput ?? String(describing: type(of: listener))
        videolistenerDic[key] = listener
    }

    public func removeVideoListener(listener:VideoListener, key keyInput:String? = nil) {
        let key:String = keyInput ?? String(describing: type(of: listener))
        videolistenerDic.removeValue(forKey: key)
        if nolisner() { stopCapture() }
    }

    public func addAudioListener(listener:AudioListener, key keyInput:String? = nil) {
        let key:String = keyInput ?? String(describing: type(of: listener))
        audiolistenerDic[key] = listener
    }
    
    public func removeAudioListener(listener:AudioListener, key keyInput:String? = nil) {
        let key:String = keyInput ?? String(describing: type(of: listener))
        audiolistenerDic.removeValue(forKey: key)
        if nolisner() { stopCapture() }
    }

    private func nolisner() -> Bool {
        if audiolistenerDic.count == 0,
           videolistenerDic.count == 0 {
            return true
        }
        return false
    }
}
