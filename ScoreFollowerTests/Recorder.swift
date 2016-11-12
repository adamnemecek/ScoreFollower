//
//  Recorder.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 5/1/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import ScoreFollower

open class Recorder {
	fileprivate var buffer: TPCircularBuffer = TPCircularBuffer(buffer: nil, length: Int32(Signal.windowSize), tail: 0, head: 0, fillCount: 0, atomic: true)
	fileprivate let controller = AEAudioController(audioDescription: AudioStreamBasicDescription(mSampleRate: Double(Signal.sampleRate), mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved, mBytesPerPacket: UInt32(MemoryLayout<Float>.size), mFramesPerPacket: 1, mBytesPerFrame: UInt32(MemoryLayout<Float>.size), mChannelsPerFrame: 1, mBitsPerChannel: UInt32(8 * MemoryLayout<Float>.size), mReserved: 0), inputEnabled: true)!
	fileprivate var queue = DispatchQueue(label: "Queue", attributes: [])
	fileprivate var samples = [Double](repeating: 0.0, count: Signal.windowSize)
	fileprivate var sampleCount = 0
	fileprivate let process: ([Double]) -> ()
	public init(process: @escaping ([Double]) -> ()) {
		self.process = process
		TPCircularBufferInit(&buffer, Int32(MemoryLayout<Float>.size * (Signal.windowSize + Signal.windowSize)))
		TPCircularBufferSetAtomic(&buffer, true)
		// Put setup code here. This method is called before the invocation of each test method in the class.
		// audioManager.inputFormat.mChannelsPerFrame = 1
		controller.addInputReceiver(AEBlockAudioReceiver() { source, time, frames, audio in
			self.sampleCount += Int(frames)
			TPCircularBufferProduceBytes(&self.buffer, audio!.pointee.mBuffers.mData, Int32(Int(frames) * MemoryLayout<Float>.size))
			var availableBytes: Int32 = 0
            let buffer = unsafeBitCast(TPCircularBufferTail(&self.buffer, &availableBytes), to: UnsafeMutablePointer<Float>.self)
			if self.sampleCount >= Signal.samplesPerFrame {
				for i in 0..<Signal.windowSize {
					self.samples[i] = Double(buffer[i])
				}
				TPCircularBufferConsume(&self.buffer, Int32(Signal.samplesPerFrame * MemoryLayout<Float>.size))
				self.queue.async(execute: self.processSamples)
				self.sampleCount = 0
			}
			return
		})
	}
	open func start(_ duration: UInt32) {
		do { try controller.start() }
		catch { print("ERROR") }
		sleep(duration)
	}
	open func processSamples() {
		process(samples)
	}
}
