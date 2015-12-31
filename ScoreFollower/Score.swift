//
//  Score.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 10/30/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public class Score {
	//private var states = [State]()
	//private var allNotes: [HashableArray<Int>: Notes] = [:]
	
	let length: Double
	let notes: [HashableArray<Int>: Int]
	public let noteSpectra: [[Double]]
	public let states: [(Int, Double, Double)]
	
	public init(_ allNotes: [([Int], Double)]) {
		
		var length = 0.0
		var notes: [HashableArray<Int>: Int] = [:]
		var noteSpectra = [[Double]]()
		var states = [(Int, Double, Double)]()
		
		notes[HashableArray(array: [])] = 0
		noteSpectra.append(Utils.pinkNoise)
		var i = 1
		for(n, l) in allNotes {
			if let n = notes[HashableArray(array: n)] {
				states.append((n, length, l))
			} else {
				noteSpectra.append(Utils.frequencyTemplate(n))
				notes[HashableArray(array: n)] = noteSpectra.count - 1
				states.append((i, length, l))
				i++
			}
			length += l
		}
		
		self.notes = notes
		self.noteSpectra = noteSpectra
		self.states = states
		self.length = length
		
	}
	
}

class HashableArray<T: Hashable>: Hashable {
	var array: [T]
	init(array: [T]) {
		self.array = array
	}
	var hashValue: Int {
		var hashCode = 1
		for i in array {
			hashCode = 31 &* hashCode &+ i.hashValue
		}
		return hashCode
	}
}

func ==<T: Hashable>(lhs: HashableArray<T>, rhs: HashableArray<T>) -> Bool {
	return lhs.array == rhs.array
}