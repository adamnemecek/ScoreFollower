//
//  main.swift
//  SpectralTemplateCreator
//
//  Created by Tristan Yang on 3/6/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation

import AudioToolbox
import Accelerate

let log2size = 12
let windowSize = 4096
let fftlength = 2048
let sampleRate = 44100

let fftsetup = vDSP_create_fftsetupD(vDSP_Length(log2size), FFTRadix(kFFTRadix2))
func fft(observation: [Double]) -> [Double] {
	
	var realp = [Double](count: fftlength, repeatedValue: 0.0)
	var imagp = [Double](count: fftlength, repeatedValue: 0.0)
	var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
	vDSP_ctozD(UnsafeMutablePointer(observation), 2, &splitComplex, 1, vDSP_Length(fftlength))
	vDSP_fft_zripD(fftsetup, &splitComplex, 1, vDSP_Length(log2size), FFTDirection(kFFTDirection_Forward))
	splitComplex.realp[0] = 0
	
	var fft = [Double](count: fftlength, repeatedValue: 0.0)
	vDSP_zvmagsD(&splitComplex, 1, &fft, 1, vDSP_Length(fftlength))
	
	return fft
}

func normalize(array: [Double]) -> [Double] {
	var sum = 0.0
	vDSP_sveD(array, 1, &sum, vDSP_Length(array.count))
	var newArray = [Double](count: array.count, repeatedValue: 0.0)
	vDSP_vsdivD(array, 1, &sum, &newArray, 1, vDSP_Length(array.count))
	return newArray
}

var file = ExtAudioFileRef()
//print(NSBundle.mainBundle().bundlePath)
//ExtAudioFileOpenURL(NSBundle.mainBundle().URLForResource("Templates", withExtension: "wav")!, &file)
//let path = self.bundle.pathForResource("Templates", ofType: "wav")
let path = "/Users/Tristan/Documents/ScoreFollower/SpectralTemplateCreator/Templates.wav"
ExtAudioFileOpenURL(NSURL(fileURLWithPath: path), &file)
print("file opened")

var audioDescription = AudioStreamBasicDescription()
audioDescription.mSampleRate = 44100.0;
audioDescription.mFormatID = kAudioFormatLinearPCM;
audioDescription.mFramesPerPacket = 1; //For uncompressed audio, the value is 1. For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC
audioDescription.mChannelsPerFrame = 2;
audioDescription.mBytesPerFrame = audioDescription.mChannelsPerFrame * 2;
audioDescription.mBytesPerPacket = audioDescription.mFramesPerPacket * audioDescription.mBytesPerFrame;
audioDescription.mBitsPerChannel = 16;
audioDescription.mReserved = 0;
audioDescription.mFormatFlags =  kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kLinearPCMFormatFlagIsPacked;

var frames: UInt32 = 0
var propertySize = UInt32(sizeof(Int))
ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &propertySize, &frames)
print("frames: \(frames)")

var bufferList = AudioBufferList()
bufferList.mNumberBuffers = 1
bufferList.mBuffers.mNumberChannels = 2
bufferList.mBuffers.mDataByteSize = audioDescription.mBytesPerFrame * frames
bufferList.mBuffers.mData = malloc(Int(audioDescription.mBytesPerFrame * frames))

ExtAudioFileRead(file, &frames, &bufferList)
print("file read")

let buffers = UnsafeBufferPointer<AudioBuffer>(start: &bufferList.mBuffers, count: Int(bufferList.mNumberBuffers))

var data = [[[Double]]]()

for buffer in buffers {
	print("buffer opened")
	let samples = UnsafeMutableBufferPointer<Int16>(start: UnsafeMutablePointer<Int16>(buffer.mData), count: Int(buffer.mDataByteSize) / sizeof(Int16))
	print("samples read")
	for i in 0..<samples.count {
		if samples[i] != 0 {
			print("\(i) \(samples[i])")
			break
		}
	}
	for instrument in 0..<38 {
		data.append([[Double]]())
		for note in 0..<12 * 9 {	//MIDI value + 12
			//frame, not index, which is 2 * frame because of interleaving
			let startFrame = sampleRate * 2 * (instrument * 12 * 9 + note)
			let endFrame = sampleRate * 2 * (instrument * 12 * 9 + note + 1)
			
			//checks for zeroes (only using one channel)
			var empty = true
			for i in startFrame..<endFrame {
				if samples[2 * i] != 0 {
					empty = false
					break
				}
			}
			
			if !empty {
				var averageSpectrum = [Double](count: fftlength, repeatedValue: 0.0)
				for windowIndex in 0..<sampleRate * 2 / windowSize {
					var window = [Double](count: windowSize, repeatedValue: 0.0)
					let startIndex = startFrame * 2 + windowIndex * windowSize * Int(bufferList.mBuffers.mNumberChannels)
					let endIndex = startFrame * 2 + (windowIndex + 1) * windowSize * Int(bufferList.mBuffers.mNumberChannels)
					for (i, j) in zip(0..<windowSize, startIndex.stride(to: endIndex, by: 2)) {
						window[i] = Double(samples[j] + samples[j + 1])
					}
					window = fft(window)
					vDSP_vaddD(averageSpectrum, 1, window, 1, &averageSpectrum, 1, vDSP_Length(fftlength))
				}
				data[data.count - 1].append(normalize(averageSpectrum))
				print("finished instrument \(instrument) note \(note)")
			} else {
				data[data.count - 1].append([])
				print("finished instrument \(instrument) note \(note) (empty)")
			}
		}
	}
	/*for i in 32..<41 {
		for j in i * 44100..<(i + 1) * 44100 {
			if samples[2 * i] == 0 && samples[2 * i + 1] == 0 {
				break
			}
			print(samples[2 * i] + samples[2 * i + 1])
		}
	}*/
	
	/*
	var data = [Double](count: windowSize, repeatedValue: 0.0)
	var spectrumAverage: [Double]
	for instrument in 0..<38 {
	for note in 0..<(12 * 9) {
	spectrumAverage = [Double](count: windowSize, repeatedValue: 0.0)
	let startIndex = (instrument * 12 * 9 + note) * 44100 * 2 * 2
	for window in 0..<10 {
	let sampleRange = startIndex + 2 * (1570 + windowSize * window)..<startIndex + 1570 + windowSize * (window + 1)
	for i in 0..<windowSize {
	data[i] = Double(samples[startIndex + 2 * (1570 + windowSize * window + i)] + samples[startIndex + 2 * (1570 + windowSize * window + i) + 1])
	}
	if !data.filter({$0 != 0}).isEmpty {
	let spectrum = normalize(fft(data))
	for (i, value) in spectrum.enumerate() {
	spectrumAverage[i] += value
	}
	}
	}
	spectrumAverage = normalize(spectrumAverage)
	}
	}*/
}

let instruments = [
	"basses",
	"cellos",
	"violas",
	"violins",
	"bass",
	"cello",
	"viola",
	"violin",
	"organ",
	"harpsichord",
	"celesta",
	"piano",
	"harp",
	"guitar",
	"chimes",
	"marimba",
	"vibraphone",
	"xylophone",
	"glockenspiel",
	"timpani",
	"tuba",
	"trombone",
	"trumpet",
	"horn",
	"contrabassoon",
	"bassoon",
	"baritone saxaphone",
	"tenor saxaphone",
	"alto saxaphone",
	"soprano saxaphone",
	"bass clarinet",
	"b-flat clarinet",
	"e-flat clarinet",
	"english horn",
	"oboe",
	"alto flute",
	"flute",
	"piccolo"
]

let fileManager = NSFileManager.defaultManager()
var dictionary = [String: [[Double]]]()
for i in 0..<instruments.count {
	dictionary[instruments[i]] = data[i]
}

(dictionary as NSDictionary).writeToFile("/Users/Tristan/Documents/ScoreFollower/ScoreFollower/SpectralTemplates.plist", atomically: false)

for x in data[instruments.indexOf("b-flat clarinet")!][57] {
	print(x)
}
