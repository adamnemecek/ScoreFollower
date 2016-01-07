//
//  ScoreFollower.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 11/7/15.
//  Copyright © 2015 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public class ScoreFollower {
	
	private var states = [State]()
	private var notes = [ScoreElement]()
	
	private var tempo: Double
	private var detectedStates = [0]
	private var currentRange = 0...0
	private var t = 0
	private var window = 4.0 * Double(Parameters.sampleRate) / Double(Parameters.windowSize)
	
	var x = 0
	
	public init(score: Score, tempo: Double) {
		for spectrum in score.noteSpectra {
			self.notes.append(Notes(frequencies: spectrum))
		}
		states.append(State(silence: notes[0]))
		for state in score.states {
			if (state.2 == 0) {
				states.append(MarkovState(scorePosition: state.1, notes: self.notes[state.0], previous: states[states.count - 1]))
			} else {
				states.append(SemiMarkovState(scorePosition: state.1, notes: self.notes[state.0], previous: states[states.count - 1], length: state.2))
			}
		}
		self.tempo = tempo / 60.0 / Double(Parameters.sampleRate) * Double(Parameters.windowSize)
		detectedStates.reserveCapacity(states.count * 5)
	}
	
	public func update(observation: [Double]) -> Int {
		
		currentRange = 0...35//getWindow()
		var pViterbi = [Double](count: currentRange.endIndex - currentRange.startIndex, repeatedValue: 0.0)
		for (i, s) in states[currentRange].enumerate() {
			pViterbi[i] = s.update(observation, tempo, t)
		}
		t++
		var vMax = 0.0
		var iMax = vDSP_Length(0)
		vDSP_maxviD(pViterbi, 1, &vMax, &iMax, vDSP_Length(pViterbi.count))
		detectedStates.append(currentRange.startIndex + Int(iMax))
		if states[detectedStates[detectedStates.count - 1]].scorePosition % 2 == 0 {
			var measure = states[detectedStates[detectedStates.count - 1]].scorePosition / 2
			print("DOWNBEATBEATBEATBEATBEATBEATBEATBEATBEAT \(measure)")
		}
		x++
		if detectedStates[detectedStates.count - 1] == 35 {
			x++
			if x > 20 {
				x = 0
			}
		}
		return detectedStates[detectedStates.count - 1]
	}
	
	public func getWindow() -> Range<Int> {
		var i1 = detectedStates[detectedStates.count - 1]
		var t = 0.0
		while ((t < window && i1 > currentRange.startIndex) || i1 > currentRange.startIndex + 1) && i1 > 0 {
			i1--
			t += states[i1].length / tempo
		}
		var i2 = detectedStates[detectedStates.count - 1]
		t = 0.0
		while (t < window || i2 < currentRange.endIndex - 1) && i2 < currentRange.endIndex && i2 < states.count - 1 {
			i2++
			t += states[i2].length / tempo
		}
		return i1...i2
	}
	
}