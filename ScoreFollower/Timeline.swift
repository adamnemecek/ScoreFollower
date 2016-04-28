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
	public private(set) var count: Int
	private var start: Double
	private var end: Double
	public var range: HalfOpenInterval<Double> { return start..<end }
	private var events: [Int: [(position: Double, events: [(T, HalfOpenInterval<Double>)], change: Bool)]]
	public init(timestep: Double) {
		self.timestep = timestep
		self.count = 0
		start = Double.infinity
		end = -Double.infinity
		events = [Int: [(position: Double, events: [(T, HalfOpenInterval<Double>)], change: Bool)]]()
	}
	public init(timestep: Double, events: [(T, HalfOpenInterval<Double>)]) {
		self.timestep = timestep
		self.count = events.count
		self.events = [Int: [(position: Double, events: [(T, HalfOpenInterval<Double>)], change: Bool)]]()
		start = Double.infinity
		end = -Double.infinity
		for (event, interval) in events {
			start = min(start, interval.start)
			end = max(end, interval.end)
			for i in Int(floor(interval.start / timestep))...Int(floor(interval.end / timestep)) {
				if self.events[i] == nil {
					self.events[i] = []
				}
				Timeline<T>.insertEvent(&self.events[i]!, arrayInterval: Double(i) * timestep..<Double(i + 1) * timestep, event: event, eventInterval: interval)
			}
		}
	}
	public mutating func insert(event: T, _ interval: HalfOpenInterval<Double>) {
		start = min(start, interval.start)
		end = max(end, interval.end)
		for i in Int(floor(interval.start / timestep))...Int(floor(interval.end / timestep)) {
			if events[i] == nil {
				events[i] = []
			}
			Timeline<T>.insertEvent(&events[i]!, arrayInterval: Double(i) * timestep..<Double(i + 1) * timestep, event: event, eventInterval: interval)
		}
		count += 1
	}
	subscript(position: Double) -> [(T, HalfOpenInterval<Double>)] {
		if let closeEvents = events[Int(floor(position / timestep))] {
			for (position2, events, _) in closeEvents.reverse() {
				if position2 <= position {
					return events
				}
			}
			assert(false, "UNEXPECTED ERROR")
		} else {
			return []
		}
	}
	public func collapse<U>(transform: [T] -> U) -> Timeline<U> {
		if count == 0 {
			return Timeline<U>(timestep: timestep)
		}
		let sortedEvents = events.sort({$0.0 < $1.0})
		var newEvents = [(U, HalfOpenInterval<Double>)]()
		for (_, array) in sortedEvents {
			for (position, events, change) in array where change {
				newEvents.append((transform(events.reduce([T](), combine: {$0 + [$1.0]})), position..<Double.infinity))
			}
		}
		for i in 0..<newEvents.count {
			if i != newEvents.count - 1 {
				newEvents[i].1 = newEvents[i].1.start..<newEvents[i + 1].1.start
			} else {
				newEvents[i].1 = newEvents[i].1.start..<end
			}
		}
		return Timeline<U>(timestep: timestep, events: newEvents)
	}
	private static func insertEvent(inout array: [(position: Double, events: [(T, HalfOpenInterval<Double>)], change: Bool)], arrayInterval: HalfOpenInterval<Double>, event: T, eventInterval: HalfOpenInterval<Double>) {
		if eventInterval.isEmpty {
			return
		}
		var (i, events) = (0, [(event, eventInterval)])
		while i < array.count && array[i].position < eventInterval.start {
			events = array[i].events + [(event, eventInterval)]
			i += 1
		}
		if i >= array.count || array[i].position != eventInterval.start {
			array.insert((max(arrayInterval.start, eventInterval.start), events, arrayInterval.start <= eventInterval.start), atIndex: i)
			i += 1
		} else if array[i].position == eventInterval.start {
			array[i].change = true
		}
		events.removeLast()
		while i < array.count && array[i].position < eventInterval.end {
			events = array[i].events
			array[i].events.append((event, eventInterval))
			i += 1
		}
		if eventInterval.end <= arrayInterval.end && (i >= array.count || array[i].position != eventInterval.end) {
			array.insert((eventInterval.end, events, true), atIndex: i)
		}
	}
}