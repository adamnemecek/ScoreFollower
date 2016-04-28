//
//  ScoreFollowerTests.swift
//  ScoreFollowerTests
//
//  Created by Tristan Yang on 10/22/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import UIKit
import XCTest
import ScoreFollower
import Accelerate

struct ts {
	var x = 3
	init(x: Int) {
		self.x = x
	}
}

class ScoreFollowerTests: XCTestCase {
	var buffer: TPCircularBuffer = TPCircularBuffer(buffer: nil, length: Int32(Parameters.windowSize), tail: 0, head: 0, fillCount: 0, atomic: true)
    var samples = [Double](count: Parameters.windowSize, repeatedValue: 0.0)
	var samples2 = [Double](count: Parameters.windowSize, repeatedValue: 0.0)
    //var controller = AEAudioController(audioDescription: AEAudioController.floatMonoAudioDescription(Double(Parameters.sampleRate)), inputEnabled: true)
	var controller = AEAudioController(audioDescription: AudioStreamBasicDescription(mSampleRate: Double(Parameters.sampleRate), mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved, mBytesPerPacket: UInt32(sizeof(Float)), mFramesPerPacket: 1, mBytesPerFrame: UInt32(sizeof(Float)), mChannelsPerFrame: 1, mBitsPerChannel: UInt32(8 * sizeof(Float)), mReserved: 0), inputEnabled: true)
	var templates = [[Double]]()
    var newnote: Int = 0
    var oldnote: Int = 0
	var x: Int = 0
	var y: Int = 0
	var z: Int = 0
	var test = [ts(x: 0), ts(x: 1), ts(x: 2), ts(x: 3), ts(x: 4)]
	var time = [Double](count: 8, repeatedValue: 0.0)
	var frames = [Int](count: 8, repeatedValue: 0)
	var extra = [Double](count: 8, repeatedValue: 0.0)
	func tf(i: Int) -> ts {
		return test[i]
	}
	var queue = dispatch_queue_create("Queue", nil)
	var oldsamples: [Float] = [Float]()
	var newsamples: [Float] = [Float](count: 100, repeatedValue: 0.0)
	var duplicate = false
	//var score = ScoreFollower(score: Score(ScoreFollowerTests.initializeSchubert()), tempo: 280) // = Score(startTempo: 160)
	//var score = ScoreFollower(score: Score(Utils.parseMIDI(NSURL(fileURLWithPath: "/Users/Tristan/Downloads/sy_ss104.mid"))), tempo: 140)
	//var score = ScoreFollower(score: Score(Utils.parseMIDI(NSURL(fileURLWithPath: "/Users/Tristan/Downloads/sacrintr.mid"))), tempo: 54)
	/*var schubert = [
	
		[33, 49],
		[40, 49],
		[45, 49, 52],
		[40, 49, 52],
		[37, 49, 52],
		[40, 49, 52],
		[45, 49, 52, 57],
		[40, 49, 52, 57],
		[35, 50, 52, 57],
		[40, 50, 52, 57],
		[44, 50, 52, 56],
		[40, 50, 52, 56],
		[37, 49, 52, 57],
		[40, 49, 52, 57],
		[45, 49, 52, 57],
		[40, 49, 52, 57],
		[38, 54, 57, 59],
		[42, 54, 57, 59],
		[47, 54, 57, 59],
	
	]*/
	/*var schubert = initializeSchubert()
	func initializeSchubert() -> [[(String, Int)]] {
		var schubert = [[("A", 2), ("C#", 4)]]
		schubert.append([("A", 2), ("C#", 4)])
		schubert.append([("A", 2), ("E", 3)])
		schubert.append([("A", 2), ("A", 3), ("C#", 4), ("E", 4)])
		schubert.append([("A", 2), ("E", 3), ("C#", 4), ("E", 4)])
		schubert.append([("C#", 3), ("C#", 4), ("E", 4)])
		schubert.append([("C#", 3), ("E", 3), ("C#", 4), ("E", 4)])
		schubert.append([("C#", 3), ("A", 3), ("C#", 4), ("E", 4), ("A", 4)])
		schubert.append([("C#", 3), ("E", 3), ("C#", 4), ("E", 4), ("A", 4)])
		schubert.append([("B", 2), ("D", 4), ("E", 4), ("A", 4)])
		schubert.append([("B", 2), ("E", 3), ("D", 4), ("E", 4), ("A", 4)])
		schubert.append([("B", 2), ("G#", 3), ("D", 4), ("E", 4), ("G#", 4)])
		schubert.append([("B", 2), ("E", 3)])
		schubert.append([("C#", 3), ("C#", 4), ("E", 4), ("A", 4)])
		schubert.append([("C#", 3), ("E", 3), ("C#", 4), ("E", 4), ("A", 4)])
		return schubert
	}*/
	static func initializeSchubert() -> [([Int], Double)] {
		
		var notes = [([Int], Double)]()
		
		notes.append(([43, 55], 7));
		notes.append(([62], 1))//
		notes.append(([43, 60], 1))
		notes.append(([55, 59], 1))
		notes.append(([50, 53, 59], 1))
		notes.append(([55, 59], 1))//
		notes.append(([42, 59], 1))
		notes.append(([55, 60], 1))
		notes.append(([48, 51], 1))
		notes.append(([55, 63], 1))//
		notes.append(([43, 60], 1))
		notes.append(([55, 59], 1))
		notes.append(([50, 53, 59], 1))
		notes.append(([55, 59], 1))//
		notes.append(([42, 59], 1))
		notes.append(([55, 60], 1))
		notes.append(([42, 48, 51], 1))
		notes.append(([54, 63], 1))//
		notes.append(([41, 60], 1))
		notes.append(([53, 58], 1))
		notes.append(([50, 58], 1))//
		notes.append(([53, 58], 1))
		notes.append(([43, 60], 1))
		notes.append(([52, 58], 1))
		notes.append(([48, 58], 1))//
		notes.append(([52, 58], 1))
		notes.append(([41, 50, 60], 0.5))
		notes.append(([41, 50, 58], 0.5))
		notes.append(([53, 57], 0.5))
		notes.append(([53, 58], 0.5))
		notes.append(([41, 51, 60], 1))//
		notes.append(([53, 62], 1))
		notes.append(([46, 50, 58], 2))
		notes.append(([43, 55], 8))
		
		return notes
		
	}
	func getNote(note: String, octave: Int) -> Int {
		var i = 0
		switch note {
			case "Cb": i = -1
			case "C": i = 0
			case "C#", "Db": i = 1
			case "D": i = 2
			case "D#", "Eb": i = 3
			case "E", "Fb": i = 4
			case "E#", "F": i = 5
			case "F#", "Gb": i = 6
			case "G": i = 7
			case "G#", "Ab": i = 8
			case "A": i = 9
			case "A#", "Bb": i = 10
			case "B": i = 11
			case "B#": i = 12
			default: i = 0
		}
		return octave * 12 + i
	}

    override func setUp() {
        super.setUp()
		//controller.preferredBufferDuration = 4096.0 / Double(Parameters.sampleRate)
        for i in 48...59 {
            templates.append(Utils.frequencyTemplate([i]))//, harmonics: [[128, 64, 32, 16, 8, 4, 2, 1]]))
        }
		var a = Utils.frequencyTemplate([49])
		var ab = Utils.frequencyTemplate([48])
		//var a = Utils.frequencyTemplate([57], harmonics: [[128, 64, 32, 16, 8, 4, 2, 1]])
		//var a2 = Utils.frequencyTemplate([57], harmonics: [[1, 0.891251, 0.213796, 0.089125, 0.033113, 0.016982, 0.036308, 0.00912, 0.003631, 0.003311]])
		//var ab = Utils.frequencyTemplate([56], harmonics: [128, 64, 32, 16, 8, 4, 2, 1])
        TPCircularBufferInit(&buffer, Int32(sizeof(Float) * (Parameters.windowSize + Parameters.windowSize)))
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // audioManager.inputFormat.mChannelsPerFrame = 1
		controller.addInputReceiver(AEBlockAudioReceiver() {source, time, frames, audio in
			self.oldsamples = self.newsamples
			self.newsamples = [Float](count: Int(frames), repeatedValue: 0.0)
			for i in 0..<Int(frames) {
				self.newsamples[i] = Float(UnsafeMutablePointer<Float>(audio.memory.mBuffers.mData)[i])
			}
			if self.newsamples[11] == self.oldsamples[11] {
				self.duplicate = true
				//println("\(self.z) ????")
				return
			} else {
				self.duplicate = false
				//println("\(self.z) ----")
			}
			self.z++
			TPCircularBufferProduceBytes(&self.buffer, audio.memory.mBuffers.mData, Int32(Int(frames) * sizeof(Float)))
			//return
			var availableBytes: Int32 = 0
			var buffer = UnsafeMutablePointer<Float>(TPCircularBufferTail(&self.buffer, &availableBytes))
			//println(Int(availableBytes) / sizeof(Float))
			if Int(availableBytes) / sizeof(Float) >= Parameters.windowSize {
				//println((UnsafeMutablePointer<Float>(audio.memory.mBuffers.mData))[511])
				//println((UnsafeMutablePointer<Float>(audio.memory.mBuffers.mData))[1023])
				var temp = 0.0
				for i in 0..<Parameters.windowSize {
					self.samples[i] = Double(buffer[i])
				}
				TPCircularBufferConsumeNoBarrier(&self.buffer, Int32(Parameters.windowSize * sizeof(Float)))
				//println("ASDF")
				dispatch_async(self.queue, self.process)
				
			}
			return
		})
	}
	func process() {
		//println("ASDFASDF")
		//println(Double(audio.memory.mBuffers.mDataByteSize) / Double(sizeof(Float)))
		/*var newsamples = UnsafeMutablePointer<Float>(audio.memory.mBuffers.mData)
		for i in 512 * self.y..<512 * (self.y + 1) {
			self.samples[i] = Double(newsamples[i % 512])
		}
		self.time[self.y] = time.memory.mSampleTime
		self.frames[self.y] = Int(frames)
		self.extra[self.y] = Double(newsamples[511])
		self.y++
		if self.y == 8 {
			self.y = 0
		} else {
			return
		}*/
		//return
		/*
		
		for i in 0..<4096 {
			print(self.samples[i])
			print(" ")
			println(self.samples2[i])
		}*/
		
		/*for i in 0..<self.samples.count {
			var d = Double(i)
			self.samples[i] = d / 159.42 - floor(d / 159.42)
		}*/
		/*if self.duplicate {
			for d in self.samples {
				println(d * 100)
			}
			self.duplicate = false
			exit(1)
		}*/
		//var fft = Utils.fft(samples)
		//Utils.normalize(&fft)
		/*for i in fft{
			println(i)
		}
		exit(0)*/
		//print(score.update(fft))
		return
		//var floor = fft.reduce(Double(Int.max), min)
		//var floor = Utils.sum(2000, end: 2048) { return fft[$0] } / 48.0
		//var energy = Utils.normalize(&fft) / 2048.0
		//var x = floor / energy
		//println(log10(x))
		//var noise = Utils.bhattacharyya(fft, frequencies: pinkNoise)
		//println(noise)
		//var silencePb = 1.0 / (1.0 + exp(-2 * log10(x) - 8))
		//var silencePb = noise
		//println(energy)
		//println(volume)
		/*if self.x % 10 == 0 {
			for i in self.samples {
				for j in 0...Int((i + 3) * 10) {
					print("*")
				}
				println()
			}
		}*/
		/*var displacement = [Int]()
		for i in 1..<4096 {
			if self.samples[i - 1] > 0 && self.samples[i] < 0 {
				displacement.append(i)
			}
		}*/
		//x++
		//return
		/*if Utils.bhattacharyya(fft, frequencies: ab) < Utils.bhattacharyya(fft, frequencies: a) {
			//println(fft.count)
			for d in self.extra {
				println(d)
			}
			for i in self.frames {
				println(i)
			}
			for d in self.time {
				println(d)
			}
			println()
			for i in 1..<displacement.count {
				println(displacement[i] - displacement[i - 1])
			}
			println(displacement.count)
			/*for (index, i) in enumerate(self.samples) {
				/*for j in 0...Int((i + 3) * 10) {
					print("*")
				}*/
				println(i)
				var d = Double(index - displacement)
				println(0.223 * (d / 159.42 - floor(d / 159.42)) - 0.1)
				println()
			}*/
			for i in self.samples {
				println(i * 100)
			}
			for i in 0..<100 {
				print(Int(round(Double(i) / Double(fft.count) * Double(Parameters.sampleRate))))
				print(": ")
				//print(fft[i])
				for j in 0...Int(fft[i] * 100) {
					print("*")
				}
				println()
			}
			println()
			for i in 0..<100 {
				print(Int(round(Double(i) / Double(fft.count) * Double(Parameters.sampleRate))))
				print(": ")
				if let j = a[i] {
					for k in 0...Int(j * 100) {
						print("*")
					}
				}
				else {
					print("*")
				}
				println()
			}
			for i in 0..<100 {
				print(Int(round(Double(i) / Double(fft.count) * Double(Parameters.sampleRate))))
				print(": ")
				if let j = ab[i] {
					for k in 0...Int(j * 100) {
						print("*")
					}
				}
				else {
					print("*")
				}
				println()
			}
			println()
			//exit(0)
		}*/
		
		//*
		//println(Utils.bhattacharyya(fft, frequencies: a))
		//println(Utils.bhattacharyya(fft, frequencies: a2))
		//println()
		/*if self.x == 100 {
			for i in 0..<1024 {
				println(fft[i])
			}
			exit(1)
		}*/
		//oldnote = newnote
		/*var m = Utils.maxPair(0, end: 12, function: { Utils.bhattacharyya(fft, frequencies: self.templates[$0]) })
		if m.1 > silencePb {
			newnote = m.0
		} else {
			newnote = -1
			m.1 = silencePb
			/*for d in fft {
				println(d)
			}
			exit(0)*/
		}
		if newnote != oldnote {
			switch newnote {
			case 0: print("C")
			case 1: print("C#")
			case 2: print("D")
			case 3: print("Eb")
			case 4: print("E")
			case 5: print("F")
			case 6: print("F#")
			case 7: print("G")
			case 8: print("Ab")
			case 9: print("A")
			case 10: print("Bb")
			case 11: print("B")
			default: print("Silence")
			}
			//println(silencePb)
			
		}
		println("   \(m.1)")*/
			//*/
            //println(Utils.bhattacharyya(Utils.fft(self.samples), frequencies: Utils.frequencyTemplate([57], harmonics: [128, 64, 32, 16, 8, 4, 2, 1])))
      /*audioManager.inputBlock = {newAudio, numSamples, numChannels in
            for j in 0..<numSamples {
                for k in 0..<numChannels {
                    self.samples[Int(j)] += newAudio[Int(numChannels * j + k)]
                }
                //print(i)
                //print(" ")
                //println(newAudio[i])
            }
            println(numSamples)
            println(numChannels)
        }
        audioManager.play()*/
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
        /*var t = Utils.frequencyTemplate([57], harmonics: [128, 64, 32, 16, 8, 4, 2, 1])
        for d in t {
            for i in 0...Int(d * 10000) {
                print("*")
            }
            println()
        }*/
		/*var a = [1,3,6,7,9,15,400,461,462]
		var b = [1,2,4,5,300,1000]
		var c = [30,40,50,51,52,420]
		var d = a
		d[2] -= 10*/
		var score = Utils.parseMIDI(NSURL(fileURLWithPath: "/Users/Tristan/Downloads/sy_ss104.mid"))
		var time = 0.0
		for (i, array) in score.enumerate() {
			time += array.1
			print(time)
			//print(i, array)
		}/*
		print("a\(a)")
		print(Utils.merge([a,b,c],<))
		print("ASDFASDFASDFASDFASDFASDFASDFA")
		print(Utils.logSumExp([-Double.infinity, -Double.infinity, -Double.infinity]))
		print(Utils.logSumExp([1000, 1001, 1000]))
		var length = 5.0
		var tempo = 1.0
		var variance = 1.0
		for u in 1..<10 {
			print(0.5 * (1 + erf((-Double(u) + length / tempo) / sqrt(variance * 2))))
		}
		print("Poisson:")
		for x in 0...20 {
			print("pdf: \(x): \(Utils.poisson_pdf(x, 10))")
		}
		for x in 0...20 {
			print("cdf: \(x): \(Utils.poisson_cdf(x, 10))")
		}
		for x in 0...20 {
			print("cdf_c: \(x): \(Utils.poisson_cdf_c(x, 10))")
		}*/
		//testKalman()
		var length = 64
		var d1 = [Double]()
		var l1 = 3.5 / (140.0 / 60.0 / Double(Parameters.sampleRate) * Double(Parameters.windowSize)) 
		for x in 0...length - 1 {
			//d1.append(log(Utils.poisson_pdf(x, l1)))
			d1.append(normal_pdf(x, l1, 2))
		}
		var d2 = [Double]()
		var l2 = 0.5 / (140.0 / 60.0 / Double(Parameters.sampleRate) * Double(Parameters.windowSize))
		for x in 0...length - 1 {
			//d2.append(log(Utils.poisson_pdf(x, l2)))
			d2.append(normal_pdf(x, l2, 2))
		}
		var d3 = [Double](count: length, repeatedValue: 0.0)
		vDSP_convD(d1, 1, d2, 1, &d3, 1, vDSP_Length(length), vDSP_Length(length))
		d3 = logConvolve(d1, d2, length)
		var d4 = [Double]()
		var l3 = l1 + l2
		for x in 0...length - 1 {
			//d4.append(log(Utils.poisson_pdf(x, l3)))
			d4.append(normal_pdf(x, l3, 2))
		}
		for x in 0...length - 1 {
			print("\(exp(d3[x]))")
		}
		print("   ")
		for x in 0...length - 1 {
			print("\(exp(d4[x]))")
		}
		//print("windowsize \(Parameters.windowSize)")
		do {
			try print(self.controller.start())
		}
		catch is NSError {
			
		}
        sleep(10000)
    }
	
	func normal_pdf(x: Int, _ mu: Double, _ factor: Double) -> Double {
		let d = 0.01
		let a = 0.5 * (1 + erf((Double(x) - d - mu) / sqrt(factor * mu * 2))) / (2.0 * d)
		let b = 0.5 * (1 + erf((Double(x) + d - mu) / sqrt(factor * mu * 2))) / (2.0 * d)
		return log(b - a)
	}
	
	func logConvolve(d1: [Double], _ d2: [Double], _ length: Int) -> [Double] {
		var d3 = [Double](count: length, repeatedValue: 0.0)
		for t in 0..<length {
			var tmp = [Double](count: t + 1, repeatedValue: 0.0)
			for u in 0...t {
				tmp[u] = d1[u] + d2[t - u]
			}
			d3[t] = Utils.logSumExp(tmp)
		}
		return d3
	}

	
	func convolve(d1: [Double], _ d2: [Double], _ length: Int) -> [Double] {
		var d3 = [Double](count: length, repeatedValue: 0.0)
		for t in 0..<length {
			for u in 0...t {
				d3[t] += d1[u] * d2[t - u]
			}
		}
		return d3
	}
	
	/*func testKalman() {
		var m1 = Matrix(matrix: [1,2,3,4,7,5,0,8,1], rows: 3, columns: 3)
		var m2 = Matrix(matrix: [1,2,3,4,7,5,0,8,1], rows: 3, columns: 3)
		println((m1 - m2).transpose().matrix)
		var k = Kalman(v0: 1.0)
		var sd = 1.0
		for i in 1...100 {
			var z = Double(i) + randomGaussian() * sd
			println(z)
			k = k.update(1.0, σa: 0.02, a: 0.0, z: z, σz: sd)
			println("     \(k.getPosition())")
		}
	}*/
	func randomGaussian() -> Double {
		var x1, x2, w, y1, y2: Double
		repeat {
			x1 = 2.0 * (Double(arc4random()) / Double(0x100000000)) - 1.0
			x2 = 2.0 * (Double(arc4random()) / Double(0x100000000)) - 1.0
			w = x1 * x1 + x2 * x2
		} while w >= 1.0
		w = sqrt((-2.0 * log(w)) / w)
		y1 = x1 * w
		y2 = x2 * w
		return y1
	}
	
	/*func testPoisson() {
		self.measureBlock() {
			for i in 0..<100000 {
				for j in 0..<50 {
					Utils.poisson_cdf_c(j, Double(j) / 2.0)
				}
			}
		}
	}
	
	func testGaussian() {
		self.measureBlock() {
			for i in 0..<100000 {
				for j in 0..<50 {
					0.5 * (1 + erf((Double(j) - 0.5 - Double(j) / 2.0) / sqrt(Double(j))))
					0.5 * (1 + erf((Double(j) + 0.5 - Double(j) / 2.0) / sqrt(Double(j))))
				}
			}
		}
	}*/
	
    /*func testPerformanceExample() {
		// This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
			for i in 0..<1 {
				var x = log(Double(i) / 9000000.0)
			}
        }
    }*/
	
}
