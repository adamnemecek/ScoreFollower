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
	private var currentState = 0
	private var currentRange = 0...0
	private var t = 0
	private var window = 2.0 * Double(Parameters.sampleRate) / Double(Parameters.windowSize)
	
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
		for s in score.states {
			print("ASDF  \(s.0)")
		}
		self.tempo = tempo / 60.0 / Double(Parameters.sampleRate) * Double(Parameters.windowSize)
	}
	
	/*public init(startTempo: Double) {
		//tempo = startTempo / 60.0 / Double(Parameters.sampleRate) * Double(Parameters.windowSize)
		states.append(State())
	}
	public func addState(notes: [Int], length: Double) {
		states.append(State(scorePosition: self.length, notes: notes.isEmpty ? Utils.rest : addNotes(notes), previous: states[states.count - 1], length: length, markovian: length == 0))
		self.length += length
	}
	/*public func reset(start: Int) {
	currentState = start
	t = 0
	}*/
	private func addNotes(notes: [Int]) -> Notes {
		if let n = allNotes[HashableArray(array: notes)] {
			return n
		} else {
			let n = Notes(notes: notes)
			allNotes[HashableArray(array: notes)] = n
			return n
		}
	}*/
	public func update(observation: [Double]) -> Int {
		currentRange = getWindow()
		//println(currentRange)
		var pViterbi = [Double](count: currentRange.endIndex - currentRange.startIndex, repeatedValue: 0.0)
		for (i, s) in states[currentRange].enumerate() {
			pViterbi[i] = s.update(observation, tempo: tempo, t: t)
			//println("    \(i + currentRange.startIndex) \(pViterbi[i])")
		}
		//Utils.normalize(&pViterbi)
		/*for (i, s) in enumerate(states[currentRange]) {
		s.update(pViterbi[i])
		}*/
		t++
		//print("\(t) ")
		var vMax = 0.0
		var iMax = vDSP_Length(0)
		vDSP_maxviD(pViterbi, 1, &vMax, &iMax, vDSP_Length(pViterbi.count))
		currentState = currentRange.startIndex + Int(iMax)
		//currentState = Utils.maxPair(0, end: pViterbi.count) { return pViterbi[$0] }.0 + currentRange.startIndex
		return currentState
	}
	public func getWindow() -> Range<Int> {
		var i1 = currentState
		var t = 0.0
		while ((t < window && i1 > currentRange.startIndex) || i1 > currentRange.startIndex + 1) && i1 > 0 {
			i1--
			t += states[i1].length / tempo
		}
		var i2 = currentState
		t = 0.0
		while (t < window || i2 < currentRange.endIndex - 1) && i2 < currentRange.endIndex && i2 < states.count - 1 {
			i2++
			t += states[i2].length / tempo
		}
		//return 0...34
		//println("\(i1) \(i2)")
		return i1...i2
	}
	
}