//
//  Score.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 2/16/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public protocol Score {
	//var tempo: Double { get }
	var length: Double { get }
	var instrumentGroups: [NoteTracker.Type] { get }	//IsPedaled
	func getOnsets(position: Double) -> HalfOpenInterval<Double>
	func getNotes(instrumentGroup: Int, _ position: Double) -> [Int: NoteGroup]
}
public struct PianoScore: Score {
	//public let tempo: Double
	public let length: Double
	public let instrumentGroups: [NoteTracker.Type] = [PedaledNoteTracker.self]
	private let onsets: Timeline<Bool>
	private let timeline: Timeline<(Int, NoteGroup)>
	private let noteGroups: [NoteGroup]
	public init(sequence: MusicSequence) {
		
		var length = 0.0
		var noteGroups = [NoteGroup]()
		var timeline = Timeline<(Int, NoteGroup)>(timestep: 0.25)
		
		let templates = NSDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("SpectralTemplates", ofType: "plist")!)!["piano"] as! [[Double]]
		for i in 0..<templates.count {
			var sqrtSpectrum = [Double](count: templates[i].count, repeatedValue: 0.0)
			vvsqrt(&sqrtSpectrum, templates[i], [Int32(sqrtSpectrum.count)])
			noteGroups.append(PianoNote(pitch: i, spectrum: templates[i]))
		}
		
		var trackCount: UInt32 = 0
		MusicSequenceGetTrackCount(sequence, &trackCount)
		var track: MusicTrack = nil
		var iterator: MusicEventIterator = nil
		var index = 0
		for i in 0...trackCount {
			MusicSequenceGetIndTrack(sequence, i, &track)
			NewMusicEventIterator(track, &iterator)
			var hasNext: DarwinBoolean = false
			MusicEventIteratorHasNextEvent(iterator, &hasNext)
			var timeStamp: MusicTimeStamp = 0
			var eventType: MusicEventType = 0
			var eventData: UnsafePointer<Void> = nil
			var eventDataSize: UInt32 = 0
			while hasNext {
				MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
				if eventType == kMusicEventType_MIDINoteMessage {
					let noteData = UnsafePointer<MIDINoteMessage>(eventData)
					timeline.insert((index, noteGroups[Int(noteData.memory.note) - 12]), Double(timeStamp)..<Double(timeStamp) + Double(noteData.memory.duration))
					length = max(length, Double(timeStamp) + Double(noteData.memory.duration))
					index += 1
				}
				MusicEventIteratorNextEvent(iterator)
				MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
			}
		}
		
		onsets = timeline.collapse({$0.isEmpty})
		
		self.length = length
		self.noteGroups = noteGroups
		self.timeline = timeline
		
	}
	public func getNotes(instrumentGroup: Int, _ position: Double) -> [Int: NoteGroup] {
		return timeline[position].reduce([Int: NoteGroup]()) { dictionary, event in
			var newDict = dictionary
			newDict[event.0.0] = event.0.1
			return newDict
		}
	}
	public func getOnsets(position: Double) -> HalfOpenInterval<Double> {
		return onsets[position][0].1
	}
}