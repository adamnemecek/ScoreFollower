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
	func getSpectrum(duration: Double) -> (spectrum: [Double], weight: Double)
}

public struct SustainNoteGroup: NoteGroup {
	public let pitches: [Int]
	public let spectrum: [Double]
	public init(pitches: [Int], spectrum: [Double]) {
		self.pitches = pitches
		self.spectrum = spectrum
	}
	public func getSpectrum(duration: Double) -> (spectrum: [Double], weight: Double) {
		return (spectrum, 1)
	}
}

public struct PianoNote: NoteGroup {	//Basic exponential decay model
	private let pitch: Int
	public var pitches: [Int] { get { return [pitch] } }
	public let spectrum: [Double]
	public init(pitch: Int, spectrum: [Double]) {
		self.pitch = pitch
		self.spectrum = spectrum
	}
	public func getSpectrum(duration: Double) -> (spectrum: [Double], weight: Double) {
		return (spectrum, pow(decayRate(pitch), duration))
	}
	private func decayRate(pitch: Int) -> Double {	//Power per second; Around 2 db/s for lowest notes to 10 db/s for highest; linear fit for log rate vs pitch
		return 0.7 * exp(-Double(pitch) / 50.0)
	}
}