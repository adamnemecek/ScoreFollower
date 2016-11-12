//
//  NoteGroup.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 3/25/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation

public protocol NoteGroup {
	var pitches: [Int] { get }
	func getSpectrum(_ duration: Double) -> (spectrum: [Double], weight: Double)
}

public struct SustainNoteGroup: NoteGroup {
	public let pitches: [Int]
	public let spectrum: [Double]
	public init(pitches: [Int], spectrum: [Double]) {
		self.pitches = pitches
		self.spectrum = spectrum
	}
	public func getSpectrum(_ duration: Double) -> (spectrum: [Double], weight: Double) {
		return (spectrum, 1)
	}
}

public struct PianoNote: NoteGroup {	//Basic exponential decay model
	
	fileprivate static let highRate = 60.0	// db/s
	fileprivate static let lowRate = 3.0	// db/s
	
	fileprivate let pitch: Int
	fileprivate let decayRate: Double	// db/s
	public var pitches: [Int] { get { return [pitch] } }
	public let spectrum: [Double]
	public init(pitch: Int, spectrum: [Double]) {
		self.pitch = pitch
		self.spectrum = spectrum
		self.decayRate = (PianoNote.highRate - PianoNote.lowRate) * Double(pitch) / 87.0 + (32 * PianoNote.lowRate - 3 * PianoNote.highRate) / 29.0
	}
	public func getSpectrum(_ duration: Double) -> (spectrum: [Double], weight: Double) {
		let decay = decayRate * duration
		return (spectrum, 1)
		return (spectrum, pow(10, -decay / 10.0))
	}
}
