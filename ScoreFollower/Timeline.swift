//
//  Timeline.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 4/6/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation

public struct Timeline<T> {
	public let timestep: Double
	public fileprivate(set) var count: Int
	fileprivate var start: Double
	fileprivate var end: Double
	public var range: Range<Double> { return start..<end }
	fileprivate var events: [Int: [(position: Double, events: [(T, Range<Double>)], change: Bool)]]
	public init(timestep: Double) {
		self.timestep = timestep
		self.count = 0
		start = Double.infinity
		end = -Double.infinity
		events = [Int: [(position: Double, events: [(T, Range<Double>)], change: Bool)]]()
	}
	public init(timestep: Double, events: [(T, Range<Double>)]) {
		self.timestep = timestep
		self.count = events.count
		self.events = [Int: [(position: Double, events: [(T, Range<Double>)], change: Bool)]]()
		start = Double.infinity
		end = -Double.infinity
		for (event, interval) in events {
			start = min(start, interval.lowerBound)
			end = max(end, interval.upperBound)
			for i in Int(floor(interval.lowerBound / timestep))...Int(floor(interval.upperBound / timestep)) {
				if self.events[i] == nil {
					self.events[i] = []
				}
				Timeline<T>.insertEvent(&self.events[i]!, arrayInterval: Double(i) * timestep..<Double(i + 1) * timestep, event: event, eventInterval: interval)
			}
		}
	}
	public mutating func insert(_ event: T, _ interval: Range<Double>) {
		start = min(start, interval.lowerBound)
		end = max(end, interval.upperBound)
		for i in Int(floor(interval.lowerBound / timestep))...Int(floor(interval.upperBound / timestep)) {
			if events[i] == nil {
				events[i] = []
			}
			Timeline<T>.insertEvent(&events[i]!, arrayInterval: Double(i) * timestep..<Double(i + 1) * timestep, event: event, eventInterval: interval)
		}
		count += 1
	}
	subscript(position: Double) -> [(T, Range<Double>)] {
		if let closeEvents = events[Int(floor(position / timestep))] {
			if closeEvents.count == 1 {
				return closeEvents[0].events
			}
			for (position2, events, _) in closeEvents.reversed() {
				if position2 <= position {
					return events
				}
			}
			assert(false, "UNEXPECTED ERROR")
			return []
		} else {
			return []
		}
	}
	public func collapse<U>(_ transform: ([T]) -> U) -> Timeline<U> {
		if count == 0 {
			return Timeline<U>(timestep: timestep)
		}
		let sortedEvents = events.sorted(by: {$0.0 < $1.0})
		var newEvents = [(U, Range<Double>)]()
		for (_, array) in sortedEvents {
			for (position, events, change) in array where change {
				newEvents.append((transform(events.reduce([T](), {$0 + [$1.0]})), position..<Double.infinity))
			}
		}
		for i in 0..<newEvents.count {
			if i != newEvents.count - 1 {
				newEvents[i].1 = newEvents[i].1.lowerBound..<newEvents[i + 1].1.lowerBound
			} else {
				newEvents[i].1 = newEvents[i].1.lowerBound..<end
			}
		}
		return Timeline<U>(timestep: timestep, events: newEvents)
	}
	fileprivate static func insertEvent(_ array: inout [(position: Double, events: [(T, Range<Double>)], change: Bool)], arrayInterval: Range<Double>, event: T, eventInterval: Range<Double>) {
		if eventInterval.isEmpty {
			return
		}
		if eventInterval.upperBound == arrayInterval.lowerBound {
			if !array.isEmpty && array[0].position == arrayInterval.lowerBound{
				array[0].change = true
			} else {
				array.append((arrayInterval.lowerBound, [], true))
			}
			return
		}
		var (i, events) = (0, [(event, eventInterval)])
		while i < array.count && array[i].position < eventInterval.lowerBound {
			events = array[i].events + [(event, eventInterval)]
			i += 1
		}
		if i >= array.count || array[i].position != eventInterval.lowerBound && (array[0].position != arrayInterval.lowerBound || arrayInterval.lowerBound < eventInterval.lowerBound) {
			array.insert((max(arrayInterval.lowerBound, eventInterval.lowerBound), events, arrayInterval.lowerBound <= eventInterval.lowerBound), at: i)
			i += 1
		} else if array[i].position == eventInterval.lowerBound {
			array[i].change = true
		}
		events.removeLast()
		while i < array.count && array[i].position < eventInterval.upperBound {
			events = array[i].events
			array[i].events.append((event, eventInterval))
			i += 1
		}
		if eventInterval.upperBound < arrayInterval.upperBound && (i >= array.count || array[i].position != eventInterval.upperBound) {
			array.insert((eventInterval.upperBound, events, true), at: i)
		}
	}
}
