//
//  FileReader.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 6/20/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import AudioToolbox
import ScoreFollower
import Accelerate

open class FileReader {
	fileprivate let process: ([Double]) -> ()
	public init(process: @escaping ([Double]) -> ()) {
		self.process = process
	}
	open func readFile(_ URL: Foundation.URL) {
		var file: ExtAudioFileRef? = nil//ExtAudioFileRef()
		//print(NSBundle.mainBundle().bundlePath)
		//ExtAudioFileOpenURL(NSBundle.mainBundle().URLForResource("Templates", withExtension: "wav")!, &file)
		//let path = self.bundle.pathForResource("Templates", ofType: "wav")
		ExtAudioFileOpenURL(URL as CFURL, &file)
		print("file opened")
		
		var audioDescription = AudioStreamBasicDescription()
		audioDescription.mSampleRate = 44100.0;
		audioDescription.mFormatID = kAudioFormatLinearPCM;
		audioDescription.mFramesPerPacket = 1; //For uncompressed audio, the value is 1. For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC
		audioDescription.mChannelsPerFrame = 2;
		audioDescription.mBytesPerFrame = audioDescription.mChannelsPerFrame * 4;
		audioDescription.mBytesPerPacket = audioDescription.mFramesPerPacket * audioDescription.mBytesPerFrame;
		audioDescription.mBitsPerChannel = 16;
		audioDescription.mReserved = 0;
		audioDescription.mFormatFlags =  kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kLinearPCMFormatFlagIsPacked;
		
		var frames: UInt32 = 0
		var propertySize = UInt32(MemoryLayout<Int>.size)
		ExtAudioFileGetProperty(file!, kExtAudioFileProperty_FileLengthFrames, &propertySize, &frames)
		print("frames: \(frames)")
		
		var bufferList = AudioBufferList()
		bufferList.mNumberBuffers = 1
		bufferList.mBuffers.mNumberChannels = 2
		bufferList.mBuffers.mDataByteSize = audioDescription.mBytesPerFrame * frames
		bufferList.mBuffers.mData = malloc(Int(audioDescription.mBytesPerFrame * frames))
		print("buffers: \(bufferList.mNumberBuffers)")
		
		ExtAudioFileRead(file!, &frames, &bufferList)
		print("file read")
		
		let buffers = UnsafeBufferPointer<AudioBuffer>(start: &bufferList.mBuffers, count: Int(bufferList.mNumberBuffers))
		
		for buffer in buffers {
			print("buffer opened")
            let samples = UnsafeMutableBufferPointer<Int16>(start: unsafeBitCast(buffer.mData, to: UnsafeMutablePointer<Int16>.self), count: Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size)
			print("samples read")
			print(samples.count)
			var sample = Signal.samplesPerFrame
			var data = samples[0..<Signal.windowSize].map() { Double($0) }
			while sample + Signal.samplesPerFrame < samples.count {
				for _ in 0..<Signal.samplesPerFrame {
					data.removeFirst()
				}
				for i in sample + 1...sample + Signal.samplesPerFrame {
					data.append(Double(samples[i]))
				}
				process(data)
				sample += Signal.samplesPerFrame
				/*if Double(sample) / Double(Signal.samplesPerFrame) * Signal.frameLength > 2.0 {
					var hannWindow = [Double](count: Signal.windowSize, repeatedValue: 0.0)
					vDSP_hann_windowD(&hannWindow, vDSP_Length(Signal.windowSize), Int32(vDSP_HANN_NORM))
					var windowedSamples = [Double](count: Signal.windowSize, repeatedValue: 0.0)
					vDSP_vmulD(data, 1, hannWindow, 1, &windowedSamples, 1, vDSP_Length(Signal.windowSize))
					let powerSpectrum = Signal.cqt(data)
					for x in Utils.normalize(powerSpectrum) {
						print(x)
					}
					print()
				}*/
			}
		}
	}
}
