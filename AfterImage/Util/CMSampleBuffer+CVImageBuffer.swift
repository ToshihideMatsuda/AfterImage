//
//  CMSampleBuffer+CVImageBuffer.swift
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

import Foundation
import AVFoundation

extension CMSampleBuffer {
    func offsettingTiming(by offsetTime: CMTime) throws -> CMSampleBuffer {
        // offSetTimeだけマイナスする
        var copyBuffer : CMSampleBuffer?
        var count: CMItemCount = 1
        var info = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: count, arrayToFill: &info, entriesNeededOut: &count)
        info.presentationTimeStamp = CMTimeSubtract(info.presentationTimeStamp, offsetTime)
        CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,sampleBuffer: self,sampleTimingEntryCount: 1,sampleTimingArray: &info,sampleBufferOut: &copyBuffer)
        return copyBuffer ?? self
    }

    public func imageBuffer()  -> (CVImageBuffer?, CGSize) {
        guard let inputImageBuffer = CMSampleBufferGetImageBuffer(self) else { return (nil, CGSize(width:0,height:0))}
        let size = CVImageBufferGetDisplaySize(inputImageBuffer)
        return (inputImageBuffer, size)
    }

    public func avAudioPCMBuffer(_ format:AVAudioFormat? = nil) -> AVAudioPCMBuffer? {
        let sampleBuffer = self
        guard let description: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let sampleRate: Float64 = description.audioStreamBasicDescription?.mSampleRate,
              let channelsPerFrame: UInt32 = description.audioStreamBasicDescription?.mChannelsPerFrame /*,
                                                                                                         let numberOfChannels = description.audioChannelLayout?.numberOfChannels */
        else {
            return nil
        }

        guard let blockBuffer: CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        let samplesCount = CMSampleBufferGetNumSamples(sampleBuffer)
        //let length: Int = CMBlockBufferGetDataLength(blockBuffer)

        let audioFormat = format ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: AVAudioFrameCount(samplesCount))!

        buffer.frameLength = buffer.frameCapacity
        // GET BYTES
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
        guard var channel: UnsafeMutablePointer<Float32> = buffer.floatChannelData?[0],
              let data = dataPointer else {
            return nil
        }

        var data16 = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
        for _ in 0...samplesCount - 1 {
            channel.pointee = Float32(data16.pointee) / Float32(Int16.max)
            channel += 1
            for _ in 0...channelsPerFrame - 1 {
                data16 += 1
            }
        }
        return buffer
    }
}
