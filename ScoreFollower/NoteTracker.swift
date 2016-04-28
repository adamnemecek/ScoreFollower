//
//  NoteTracker.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 3/25/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation

public class NoteTracker {
	private var score: Score
	private var instrumentGroup: Int
	private var position: Double
	private var notes: [Int: (noteGroup: NoteGroup, duration: Double)]
	public convenience required init(score: Score, instrumentGroup: Int, position: Double) {
		var notes = [Int: (noteGroup: NoteGroup, duration: Double)]()
		for (index, noteGroup) in score.getNotes(instrumentGroup, position) {
			notes[index] = (noteGroup, 0)
		}
		self.init(score: score, instrumentGroup: instrumentGroup, position: position, notes: notes)
	}
	public required init(score: Score, instrumentGroup: Int, position: Double, notes: [Int: (noteGroup: NoteGroup, duration: Double)]) {
		self.score = score
		self.instrumentGroup = instrumentGroup
		self.position = position
		self.notes = notes
	}
	public func update(newPosition: Double) -> [(spectrum: [Double], weight: Double)] {
		position = newPosition
		var newNotes = score.getNotes(instrumentGroup, position)
		for (index, noteGroup) in newNotes where notes[index] == nil {
			notes[index] = (noteGroup, 0)
		}
		for index in notes.keys where newNotes[index] == nil {
			notes[index] = nil
		}
		for var noteGroup in notes.values {
			noteGroup.duration += Parameters.frameLength
		}
		return notes.values.map { $0.noteGroup.getSpectrum($0.duration) }
	}
	public func copy() -> Self {
		return self.dynamicType.init(score: score, instrumentGroup: instrumentGroup, position: position, notes: notes)
	}
}

public class PedaledNoteTracker: NoteTracker {
	private var pedalOn: Bool
	private var pedalPoint: Double
	public required init(score: Score, instrumentGroup: Int, position: Double, notes: [Int : (noteGroup: NoteGroup, duration: Double)]) {
		pedalOn = false
		pedalPoint = position
		super.init(score: score, instrumentGroup: instrumentGroup, position: position, notes: notes)
	}
	public required init(score: Score, instrumentGroup: Int, position: Double, notes: [Int : (noteGroup: NoteGroup, duration: Double)], pedalOn: Bool, pedalPoint: Double) {
		self.pedalOn = pedalOn
		self.pedalPoint = pedalPoint
		super.init(score: score, instrumentGroup: instrumentGroup, position: position, notes: notes)
	}
	public override func update(newPosition: Double) -> [(spectrum: [Double], weight: Double)] {
		position = newPosition
		changePedal()
		var newNotes = score.getNotes(instrumentGroup, position)
		for (index, noteGroup) in newNotes where notes[index] == nil {
			notes[index] = (noteGroup, 0)
		}
		if !pedalOn {
			for index in notes.keys where newNotes[index] == nil {
				notes[index] = nil
			}
			pedalPoint = position
		}
		for var noteGroup in notes.values {
			noteGroup.duration += Parameters.frameLength
		}
		return notes.values.map { $0.noteGroup.getSpectrum($0.duration) }
	}
	private func changePedal() {
		
	}
	public override func copy() -> Self {
		return self.dynamicType.init(score: score, instrumentGroup: instrumentGroup, position: position, notes: notes, pedalOn: pedalOn, pedalPoint: pedalPoint)
	}
}