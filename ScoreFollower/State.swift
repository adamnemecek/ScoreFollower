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
	func predict(_ Δt: Double)
	func update(_ observation: Observation) -> Double
	func copy() -> Self
}

open class ScoreState: State {
	
	public typealias Observation = (spectrum: [Double], pOnset: Double, logTempo: Double)
	
	fileprivate static let onsetWidth = 0.05 //seconds
	fileprivate static let silenceTemplate = Signal.pinkNoise
	
	open fileprivate(set) var position: Double
	open fileprivate(set) var logTempo: Double
	
	fileprivate var score: Score
	fileprivate var notes: [NoteTracker]
	
	fileprivate var pOnset: Double
	fileprivate var spectra: [[Double]]
	fileprivate var weights: [Double]
	fileprivate var template: [Double]
	
	fileprivate var spectrum = [Double](repeating: 0.0, count: ScoreFollower.spectrumLength)
	
	public required init(position: Double, logTempo: Double, score: Score, notes: [NoteTracker]) {
		
		self.position = position
		self.logTempo = logTempo
		self.notes = notes
		self.score = score
		self.notes = notes
		
		self.pOnset = 0
		self.spectra = []
		self.weights = []
		self.template = [Double](repeating: 0.0, count: ScoreFollower.spectrumLength)
		//template.reserveCapacity(Parameters.fftlength)
		
	}
	
	open func predict(_ Δt: Double) {
		
		position += exp(logTempo) * Δt
		
		position += Utils.randomGaussian(0, 0.02)
		logTempo += Utils.randomGaussian(0, 0.02)//0.01
		
		spectra.removeAll()
		weights.removeAll()
		for noteTracker in notes {
			for note in noteTracker.update(position, Δt) {
				spectra.append(note.spectrum)
				weights.append(note.weight)
			}
		}
		calculateTemplate()
		
		//Calculates the probability that a note onset occurs in this frame
		let onsets = score.getOnsets(position)
		let (sinceOnset, untilOnset) = (onsets.lowerBound, onsets.upperBound)
		pOnset = exp(sinceOnset * sinceOnset / 2 / ScoreState.onsetWidth / ScoreState.onsetWidth) +
				 exp(untilOnset * untilOnset / 2 / ScoreState.onsetWidth / ScoreState.onsetWidth)
		
	}
	
	fileprivate func calculateTemplate() {
		
		if spectra.isEmpty {
			template = ScoreState.silenceTemplate
			return
		}
		
		//Normalizes weights
		weights = Utils.normalize(weights)
		
		//Weighs each spectrum and adds
		//Each spectrum sums to 1 and the weights sum to 1, so the resulting weighted sum of the spectra will also sum to 1
		memcpy(&template, spectra[0], template.count * MemoryLayout<Double>.size)
		vDSP_vsmulD(template, 1, &weights[0], &template, 1, vDSP_Length(template.count))
		for i in 1..<spectra.count {
			vDSP_vsmaD(spectra[i], 1, &weights[i], template, 1, &template, 1, vDSP_Length(template.count))
		}
		
		var sum = 0.0
		vDSP_sveD(template, 1, &sum, vDSP_Length(template.count))
		//print(sum)
		
		//Takes square root of elements in order to compute bhattacharyya distance
		//var length = Int32(template.count)
		//vvsqrt(&template, template, &length)
		
		
	}
	
	open func update(_ observation: (spectrum: [Double], pOnset: Double, logTempo: Double)) -> Double {
		
		//Computes bhattacharyya distance between spectral template and observation
		//Both template and observation are assumed to have already been sqrt-ed elementwise beforehand
		var distance = exp(-0.5 * Signal.KLDivergence(template, observation.spectrum))
		//distance = Signal.HellingerDistance(template, observation.spectrum)
		/*if distance.isNaN || Utils.randomGaussian() > 3 {
			print()
			for x in template {
				print(x)
			}
			for _ in 0..<100 {
				print()
			}
			for x in observation.spectrum {
				print(x)
			}
			let y = score.getNotes(0, position)
			print(distance)
			print()
		}
		for _ in 0..<4 {
			print(distance)
		}*/
		//Multiplies bhattacharyya distance between spectrums by onset probability
		//distance *= self.pOnset * observation.pOnset + (1 - self.pOnset) * (1 - observation.pOnset)
		//print("distance \(distance)")
		//print(distance)
		return distance
		
	}
	
	open func copy() -> Self {
		return type(of: self).init(position: position, logTempo: logTempo, score: score, notes: notes.map({ $0.copy() }))
	}
}

