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

class ScoreFollowerTests: XCTestCase {
	func testLive() {
		var sequence: MusicSequence? = nil
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence!, URL(fileURLWithPath: "/Users/Tristan/Documents/Op68No3.mid") as CFURL, MusicSequenceFileTypeID.midiType, MusicSequenceLoadFlags())
		print("\nMIDI file loaded")
		let schubertScore = PianoScore(sequence: sequence!)
		print("score loaded")
		
		let numParticles = 100
		let scoreFollower = ScoreFollower(score: schubertScore, positionDistribution: Utils.gaussianDistribution(numParticles, μ: 0.0, σ: 3.0).map{abs($0)}, logTempoDistribution: Utils.gaussianDistribution(numParticles, μ: 0.5, σ: 0.6))
		
		var beatCount = 0
		var frameCount = 0
		let recorder = Recorder() {samples in
			scoreFollower.update(samples, Signal.frameLength)
			if frameCount % 8 == 0 {
				//print(scoreFollower.position)
			}
			if scoreFollower.position >= Double(beatCount) {
				//print("ASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDF")
				print(Signal.frameLength * Double(frameCount))
			}
			beatCount = Int(scoreFollower.position) + 1
			frameCount += 1

		}
		recorder.start(10000)
	}
	func testFromFile() {
		var sequence: MusicSequence? = nil
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence!, URL(fileURLWithPath: "/Users/Tristan/Documents/Op68No3.mid") as CFURL, MusicSequenceFileTypeID.midiType, MusicSequenceLoadFlags())
		print("\nMIDI file loaded")
		let chopinScore = PianoScore(sequence: sequence!)
		print("score loaded")
		
		let numParticles = 1000
		let scoreFollower = ScoreFollower(score: chopinScore, positionDistribution: Utils.gaussianDistribution(numParticles, μ: 0.0, σ: 0.1).map{abs($0)}, logTempoDistribution: Utils.gaussianDistribution(numParticles, μ: 0.92293527459, σ: 0.0000001))
		
		var beatCount = 0
		var frameCount = 0
		let fileReader = FileReader() { samples in
			scoreFollower.update(samples, Signal.frameLength)
			if frameCount % 8 == 0 {
				print("\(scoreFollower.position) \(scoreFollower.tempo * 60)")
			}
			if scoreFollower.position >= Double(beatCount) {
				//print("ASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDF")
				//print(Parameters.frameLength * Double(frameCount))
			}
			beatCount = Int(scoreFollower.position) + 1
			frameCount += 1
		}
		fileReader.readFile(URL(fileURLWithPath: "/Users/Tristan/Documents/Chopin Mazurka - Ashkenazy.wav"))
	}
	func testSimpleFromFile() {
		let pianoVariations: [(String, Range<Double>)] = [("E3", 3..<4), ("C3", 4..<7), ("D#3", 7..<8), ("C#4", 8..<11), ("C2", 9..<9.5), ("E2", 9..<9.5), ("E3", 9..<9.5), ("A3", 9..<9.5), ("E3", 13..<14), ("C3", 14..<15), ("E4", 15..<16), ("D#3", 16..<18), ("C#4", 18..<22), ("D#4", 20..<20.5)]		//let pianoVariations = [("C#4", 0..<20.5), ("C2", 0..<20.5), ("E2", 0..<20.5), ("E3", 0..<20.5), ("A3", 0..<20.5)]
		let coplandScore = PianoScore(notes: pianoVariations.map {
			(["E3": 52, "C3": 48, "D#3": 51, "C#4": 61, "C2": 36, "E2": 40, "A3": 57, "E4": 64, "D#4": 63][$0.0]! - 12, $0.1)
			})
		
		let numParticles = 500
		let scoreFollower = ScoreFollower(score: coplandScore, positionDistribution: Utils.gaussianDistribution(numParticles, μ: 2.0, σ: 3.0).map{abs($0)}, logTempoDistribution: Utils.gaussianDistribution(numParticles, μ: 0.5, σ: 0.3))
		//let scoreFollower = ScoreFollower(score: coplandScore, positionDistribution: Utils.gaussianDistribution(numParticles, μ: 3.0, σ: 0.1).map{abs($0)}, logTempoDistribution: Utils.gaussianDistribution(numParticles, μ: 0.0, σ: 0.05))
		
		var beatCount = 0
		var frameCount = 0
		let fileReader = FileReader() { samples in
			scoreFollower.update(samples, Signal.frameLength)
			if frameCount % 2 == 0 {
				let note: Int
				if scoreFollower.position > 22 {
					note = -1
				}
				else {
					note = [0, 0, 0, 1, 2, 2, 2, 3, 4, 5, 6, 6, 6, 7, 8, 9, 10, 10, 11, 11, 12, 13, 13, 14, 15][Int(scoreFollower.position)]
				}
				let tempo = scoreFollower.tempo * 60
				//print(note)
			}
			if scoreFollower.position >= Double(beatCount) {
				//print("ASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDFASDF")
				//print(Parameters.frameLength * Double(frameCount))
			}
			beatCount = Int(scoreFollower.position) + 1
			frameCount += 1
		}
		fileReader.readFile(URL(fileURLWithPath: "/Users/Tristan/Documents/Piano Variations.wav"))
	}

}
