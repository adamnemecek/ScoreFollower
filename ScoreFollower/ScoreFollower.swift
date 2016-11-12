//
//  ScoreFollower.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 2/16/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

open class ScoreFollower {
	
	//Parameters
	open static let constantQ = false
	open static let spectrumLength = constantQ ? Signal.cqtlength : Signal.fftlength
	
	open let score: Score
	fileprivate let particleFilter: ParticleFilter<ScoreState>
	fileprivate let onsetDetector: OnsetDetector
	
	//The onset detector runs at a different framerate than the particle filter
	fileprivate let frameMultiplier = 8	//Onset detection frames per score following frame
	fileprivate var frameCounter = 0
	fileprivate var onsetProbabilities: [Double]
	
	open fileprivate(set) var position: Double	//beats
	open fileprivate(set) var tempo: Double		//beats per second

	fileprivate var hannWindow = [Double](repeating: 0.0, count: Signal.windowSize)
	
	public init(score: Score, positionDistribution: [Double], logTempoDistribution: [Double]) {
		srand48(time(nil))
		self.score = score
		precondition(logTempoDistribution.count == positionDistribution.count)
		var states = [ScoreState]()
		for (position, logTempo) in zip(positionDistribution, logTempoDistribution) {
			var noteTrackers = [NoteTracker]()
			for (group, trackerType) in score.instrumentGroups.enumerated() {
				noteTrackers.append(trackerType.init(score: score, instrumentGroup: group, position: position))
			}
			states.append(ScoreState(position: position, logTempo: logTempo, score: score, notes: noteTrackers))
		}
		particleFilter = ParticleFilter(states, [Double](repeating: 1.0 / Double(positionDistribution.count), count: positionDistribution.count))
		onsetDetector = SuperFluxDetector()
		onsetProbabilities = [Double](repeating: 0.0, count: frameMultiplier)
		vDSP_hann_windowD(&hannWindow, vDSP_Length(Signal.windowSize), Int32(vDSP_HANN_NORM))
		var (meanPosition, meanTempo) = (0.0, 0.0)
		vDSP_meanvD(positionDistribution[positionDistribution.count * 4 / 5..<positionDistribution.count].withUnsafeBufferPointer{ $0.baseAddress }!, 1, &meanPosition, vDSP_Length(positionDistribution.count - positionDistribution.count * 4 / 5))
		vDSP_meanvD(logTempoDistribution[logTempoDistribution.count * 4 / 5..<logTempoDistribution.count].withUnsafeBufferPointer{ $0.baseAddress }!, 1, &meanTempo, vDSP_Length(logTempoDistribution.count - logTempoDistribution.count * 4 / 5))
		(position, tempo) = (meanPosition, exp(meanTempo))
	}
	open func update(_ samples: [Double], _ Δt: Double) {
		var windowedSamples = [Double](repeating: 0.0, count: Signal.windowSize)
		vDSP_vmulD(samples, 1, hannWindow, 1, &windowedSamples, 1, vDSP_Length(Signal.windowSize))
		let powerSpectrum = Signal.fft(windowedSamples)
		
		onsetProbabilities[frameCounter] = onsetDetector.pOnset(powerSpectrum)
		frameCounter += 1
		if frameCounter % frameMultiplier != 0 {
			return
		}
		frameCounter = 0
		
		let spectrum = ScoreFollower.constantQ ? Utils.normalize(Signal.cqSpectrum(powerSpectrum)) : Utils.normalize(powerSpectrum)
		
		let particles = particleFilter.update((spectrum, onsetProbabilities.max()!, tempo), Δt * Double(frameMultiplier))
		let sortedParticles = zip(particles.0, particles.1).sorted(by: {$0.1 < $1.1})
		let (weightedPositions, weightedLogTempi) = (sortedParticles.map({$0.0.position * $0.1}), sortedParticles.map({$0.0.logTempo * $0.1}))
		var logTempo = 0.0
		vDSP_sveD(weightedPositions, 1, &position, vDSP_Length(weightedPositions.count))
		vDSP_sveD(weightedLogTempi, 1, &logTempo, vDSP_Length(weightedLogTempi.count))
		var maxWeight = 0.0
		var maxIndex: UInt = 0
		vDSP_maxviD(particles.1, 1, &maxWeight, &maxIndex, vDSP_Length(particles.1.count))
		//position = particles.0[Int(maxIndex)].position
		//logTempo = particles.0[Int(maxIndex)].logTempo
		/*vDSP_sveD(positions[positions.count * 4 / 5..<positions.count].withUnsafeBufferPointer{ $0.baseAddress }, 1, &position, vDSP_Length(positions.count - positions.count * 4 / 5))
		vDSP_sveD(logTempi[logTempi.count * 4 / 5..<logTempi.count].withUnsafeBufferPointer{ $0.baseAddress }, 1, &logTempo, vDSP_Length(logTempi.count - logTempi.count * 4 / 5))*/
		tempo = exp(logTempo)
	}
}
