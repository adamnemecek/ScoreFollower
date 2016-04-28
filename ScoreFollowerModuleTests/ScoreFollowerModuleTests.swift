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
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		
		var sequence: MusicSequence = nil
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence, NSURL(fileURLWithPath: "/Users/Tristan/Downloads/sy_ss104.mid"), MusicSequenceFileTypeID.MIDIType, MusicSequenceLoadFlags.SMF_PreserveTracks)
		print("\nFile Loaded")
		let schubertScore = PianoScore(sequence: sequence)
		print("Score Loaded")
		for i in 0..<20 {
			let notes = schubertScore.getNotes(0, Double(i) / 2.0)
			for noteGroup in notes.values {
				for note in noteGroup.pitches {
					print(Utils.noteName(note), terminator: " ")
				}
			}
			print(schubertScore.getOnsets(Double(i) / 2.0))
			print("\n")
		}
		print("\n")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
