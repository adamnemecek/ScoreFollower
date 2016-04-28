//
//  Particle.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 1/29/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public protocol State: class {
	associatedtype Observation
	func predict(Δt: Double)
	func update(observation: Observation) -> Double
	func copy() -> Self
}

public class ScoreState: State {
	
	public typealias Observation = (spectrum: [Double], pOnset: Double)
	
	private static let onsetWidth = 0.05 //seconds
	private static let silenceTemplate = Utils.pinkNoise
	
	public private(set) var position: Double
	public private(set) var logTempo: Double
	
	private var score: Score
	private var notes: [NoteTracker]
	
	private var pOnset: Double
	private var spectra: [[Double]]
	private var weights: [Double]
	private var template: [Double]
	
	public required init(position: Double, logTempo: Double, score: Score, notes: [NoteTracker]) {
		
		self.position = position
		self.logTempo = logTempo
		self.notes = notes
		self.score = score
		self.notes = notes
		
		self.pOnset = 0
		self.spectra = [[Double]]()
		self.weights = [Double]()
		self.template = [Double]()
		template.reserveCapacity(Parameters.fftlength)
		
	}
	
	public func predict(Δt: Double) {
		
		position += exp(logTempo) * Δt
		
		position += Utils.randomGaussian(0, 0.01)
		logTempo += Utils.randomGaussian(0, 0.01)
		
		spectra.removeAll()
		weights.removeAll()
		for noteTracker in notes {
			for note in noteTracker.update(position) {
				spectra.append(note.spectrum)
				weights.append(note.weight)
			}
		}
		calculateTemplate()
		
		//Calculates the probability that a note onset occurs in this frame
		let onsets = score.getOnsets(position)
		let (sinceOnset, untilOnset) = (onsets.start, onsets.end)
		pOnset = exp(sinceOnset * sinceOnset / 2 / ScoreState.onsetWidth / ScoreState.onsetWidth) +
				 exp(untilOnset * untilOnset / 2 / ScoreState.onsetWidth / ScoreState.onsetWidth)
		
	}
	
	private func calculateTemplate() {
		
		if spectra.isEmpty {
			template = ScoreState.silenceTemplate
			return
		}
		
		//Normalizes weights
		Utils.normalize(weights)
		
		//Multiplies each spectrum by its weight
		//Each spectrum sums to 1 and the weights sum to 1, so the resulting weighted sum of the spectra will also sum to 1
		for (var spectrum, var weight) in zip(spectra, weights) {
			vDSP_vsmulD(spectrum, 1, &weight, &spectrum, 1, vDSP_Length(spectrum.count))
		}
		
		//Adds all spectra
		template = spectra[0]
		for i in 1..<notes.count {
			vDSP_vaddD(template, 1, spectra[i], 1, &template, 1, vDSP_Length(template.count))
		}
		
		//Takes square root of elements in order to compute bhattacharyya distance
		var length = Int32(template.count)
		vvsqrt(&template, template, &length)
		
	}
	
	public func update(observation: (spectrum: [Double], pOnset: Double)) -> Double {
		
		//Computes bhattacharyya distance between spectral template and observation
		//Both template and observation are assumed to have already been sqrt-ed elementwise beforehand
		var distance = 0.0
		vDSP_dotprD(observation.spectrum, 1, template, 1, &distance, vDSP_Length(template.count))
		
		//Multiplies bhattacharyya distance between spectrums by onset probability
		distance *= self.pOnset * observation.pOnset + (1 - self.pOnset) * (1 - observation.pOnset)
		
		return distance
		
	}
	
	public func copy() -> Self {
		return self.dynamicType.init(position: position, logTempo: logTempo, score: score, notes: notes.map({ $0.copy() }))
	}
}

