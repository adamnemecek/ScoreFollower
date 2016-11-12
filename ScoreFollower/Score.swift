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
	func getOnsets(_ position: Double) -> Range<Double>
	func getNotes(_ instrumentGroup: Int, _ position: Double) -> [Int: NoteGroup]
}
public struct PianoScore: Score {
	//public let tempo: Double
	public let length: Double
	public let instrumentGroups: [NoteTracker.Type] = [PedaledNoteTracker.self]
	fileprivate let onsets: Timeline<Bool>
	fileprivate let timeline: Timeline<[Int: NoteGroup]>
	fileprivate let noteGroups: [NoteGroup?]
	public init(sequence: MusicSequence) {
		
		var length = 0.0
		var noteGroups = [NoteGroup!]()
		var timeline = Timeline<(Int, NoteGroup)>(timestep: 0.25)
		
		let templates = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "SpectralTemplates", ofType: "plist")!)!["piano"] as! [[Double]]
		for i in 0..<templates.count where !templates[i].isEmpty {
			if templates[i].isEmpty {
				noteGroups.append(nil)
			} else {
				noteGroups.append(PianoNote(pitch: i, spectrum: Utils.normalize(ScoreFollower.constantQ ? Signal.cqSpectrum(templates[i]) : templates[i])))
			}
		}
		
		var trackCount: UInt32 = 0
		MusicSequenceGetTrackCount(sequence, &trackCount)
		var track: MusicTrack? = nil
		var iterator: MusicEventIterator? = nil
		var index = 0
		for i in 0...trackCount {
			MusicSequenceGetIndTrack(sequence, i, &track)
			NewMusicEventIterator(track!, &iterator)
			var hasNext: DarwinBoolean = false
			MusicEventIteratorHasNextEvent(iterator!, &hasNext)
			var timeStamp: MusicTimeStamp = 0
			var eventType: MusicEventType = 0
			var eventData: UnsafeRawPointer? = nil
			var eventDataSize: UInt32 = 0
			while hasNext.boolValue {
				MusicEventIteratorGetEventInfo(iterator!, &timeStamp, &eventType, &eventData, &eventDataSize)
				if eventType == kMusicEventType_MIDINoteMessage {
					let noteData = eventData?.assumingMemoryBound(to: MIDINoteMessage.self)
					timeline.insert((index, noteGroups[Int(noteData!.pointee.note) - 12]), Double(timeStamp)..<Double(timeStamp) + Double(noteData!.pointee.duration))
					length = max(length, Double(timeStamp) + Double(noteData!.pointee.duration))
					index += 1
				}
				MusicEventIteratorNextEvent(iterator!)
				MusicEventIteratorHasCurrentEvent(iterator!, &hasNext)
			}
		}
		
		onsets = timeline.collapse({$0.isEmpty})
		
		self.length = length
		self.noteGroups = noteGroups
		self.timeline = timeline.collapse({$0.reduce([Int: NoteGroup]()) { dictionary, event in
			var newDict = dictionary
			newDict[event.0] = event.1
			return newDict
		}})
		
	}
	public init(notes: [(Int, Range<Double>)]) {
		var length = 0.0
		var noteGroups = [NoteGroup!]()
		var timeline = Timeline<(Int, NoteGroup)>(timestep: 0.25)
		
		let templates = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "SpectralTemplates", ofType: "plist")!)!["piano"] as! [[Double]]
		for i in 0..<templates.count {
			if templates[i].isEmpty {
				noteGroups.append(nil)
			} else {
				noteGroups.append(PianoNote(pitch: i, spectrum: Utils.normalize(ScoreFollower.constantQ ? Signal.cqSpectrum(templates[i]) : templates[i])))
			}
		}
		
		/*var spectrum = Utils.normalize(templates[36])
		for x in spectrum {
			print(x)
		}
		print()*/
		
		onsets = timeline.collapse({$0.isEmpty})
		
		var index = 0
		for (pitch, range) in notes {
			print("pitch: \(pitch) range: \(range)")
			timeline.insert((index, noteGroups[pitch]), range)
			length = max(length, range.upperBound)
			index += 1
		}
		
		self.length = length
		self.noteGroups = noteGroups
		self.timeline = timeline.collapse({$0.reduce([Int: NoteGroup]()) { dictionary, event in
			var newDict = dictionary
			newDict[event.0] = event.1
			return newDict
		}})
	}
	public func getNotes(_ instrumentGroup: Int, _ position: Double) -> [Int: NoteGroup] {
		if timeline[position].isEmpty {
			return [:]
		}
		else {
			return timeline[position][0].0
		}
		/*return timeline[position].reduce([Int: NoteGroup]()) { dictionary, event in
			var newDict = dictionary
			newDict[event.0.0] = event.0.1
			return newDict
		}*/
	}
	public func getOnsets(_ position: Double) -> Range<Double> {
		if onsets[position].isEmpty {
			return 0..<0
		}
		return onsets[position][0].1
	}
}
