//
//  ScoreFollowerModuleTests.swift
//  ScoreFollowerModuleTests
//
//  Created by Tristan Yang on 4/6/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import XCTest
import ScoreFollower

class ScoreFollowerModuleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testMisc() {
		print("\n")
		var x = [[0.0, 1.0], [0.0, 1.0]]
		for i in 0..<2 {
			f(&x[i])
		}
		print(x)
		print("\n")
	}
	func f(_ x: inout [Double]) {
		x[0] = 5.0
	}
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		
		var sequence: MusicSequence? = nil
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence!, URL(fileURLWithPath: "/Users/Tristan/Downloads/sy_ss104.mid") as CFURL, MusicSequenceFileTypeID.midiType, MusicSequenceLoadFlags())
		print("\nFile Loaded")
		let schubertScore = PianoScore(sequence: sequence!)
		print("Score Loaded")
		let noteTracker = NoteTracker(score: schubertScore, instrumentGroup: 0, position: 14.7)
		
		print(Signal.frameLength)
		let pianoNote = PianoNote(pitch: 57, spectrum: [])
		for i in 0..<40 {
			let duration = Double(i) * Signal.frameLength
			print("\(duration): \(pianoNote.getSpectrum(duration).weight)")
		}
		
		for i in 18*4..<150 {
			for (spectrum, weight) in noteTracker.update(Double(i) / 2.0, 0.5) {
				print("\(Utils.noteName(spectrum)) \(weight)")
			}
			print("\n")
		}
		print("\n")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
