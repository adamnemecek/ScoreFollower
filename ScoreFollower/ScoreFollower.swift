//
//  ScoreFollower.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 2/16/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public class ScoreFollower {
	
	public let score: Score
	private let particleFilter: ParticleFilter<ScoreState>
	
	//For Onset Detection (see https://pdfs.semanticscholar.org/9eca/e0bca8b066171fed7a20f90d82d9916b971d.pdf for algorithm)
	private let m = pow(0.000001, 25.6 * Double(Parameters.sampleRate))	//memory coefficient for POWER spectrum, decays by 60db in 25.6s
	private let r = 0.1	//r = 0.1, floor value
	private var lastWhitenedSpectrum = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
	private var filteredSpectrum = [Double](count: 125, repeatedValue: 0.0)	//125 = highest note under nyquist frequency
	private var lastFilteredSpectrum = [Double]()
	private var triangleWindows: [(function: [Double], range: Range<Int>, tempArray: [Double])]
	
	init(score: Score, positionDistribution: [Double], logTempoDistribution: [Double]) {
		self.score = score
		precondition(logTempoDistribution.count == positionDistribution.count)
		var states = [ScoreState]()
		for (position, logTempo) in zip(positionDistribution, logTempoDistribution) {
			var noteTrackers = [NoteTracker]()
			for (group, trackerType) in score.instrumentGroups.enumerate() {
				noteTrackers.append(trackerType.init(score: score, instrumentGroup: group, position: position))
			}
			states.append(ScoreState(position: position, logTempo: logTempo, score: score, notes: noteTrackers))
		}
		particleFilter = ParticleFilter(states, [Double](count: positionDistribution.count, repeatedValue: 1.0 / Double(positionDistribution.count)))
		
		//Onset detection "mel" filter windows
		triangleWindows = []
		var leftBin = 0
		var centerBin = Int(Parameters.concertPitch * pow(2, -58.0 / 12.0) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))
		var rightBin = Int(Parameters.concertPitch * pow(2, -57.0 / 12.0) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))
		for note in 0..<filteredSpectrum.count {
			var function = [Double](count: rightBin - leftBin + 1, repeatedValue: 0.0)
			let tempArray = function
			leftBin = centerBin
			centerBin = rightBin
			rightBin = Int(Parameters.concertPitch * pow(2, (Double(note + 1) - 57.0) / 12.0) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))
			for bin in leftBin + 1..<centerBin {
				function[bin] = Double(bin - leftBin) / Double(centerBin - leftBin)
			}
			for bin in centerBin + 1..<min(rightBin, Parameters.fftlength) {
				function[bin] = Double(rightBin - bin) / Double(rightBin - centerBin)
			}
			function[centerBin] = 1.0
			triangleWindows.append((function: function, range: leftBin...(min(rightBin, Parameters.fftlength - 1)), tempArray: tempArray))
		}
		
	}
	private func update(samples: [Double], _ Δt: Double) -> (position: Double, tempo: Double) {	//Magnitude Spectrum, NOT normalized
		let powerSpectrum = Utils.fft(samples)
		var sqrtSpectrum = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vvsqrt(&sqrtSpectrum, Utils.normalize(powerSpectrum), [Int32(sqrtSpectrum.count)])
		let particles = particleFilter.update((sqrtSpectrum, pOnset(powerSpectrum)), Δt)
		let sortedParticles = zip(particles.0, particles.1).sort({$0.1 < $1.1})
		let positions = sortedParticles.map({$0.0.position})
		let tempi = sortedParticles.map({exp($0.0.logTempo)})
		var meanPosition = 0.0
		var meanTempo = 0.0
		vDSP_meanvD(Array(positions[positions.count * 4 / 5..<positions.count]), 1, &meanPosition, vDSP_Length(positions.count - positions.count * 4 / 5))
		vDSP_meanvD(Array(tempi[tempi.count * 4 / 5..<tempi.count]), 1, &meanTempo, vDSP_Length(tempi.count - tempi.count * 4 / 5))
		return (meanPosition, meanTempo)
	}
	private func pOnset(spectrum: [Double]) -> Double {
		if lastFilteredSpectrum.isEmpty {
			return 0.5
		}
		//Applies adaptive whitening to spectrum and normalizes it
		var whitenedSpectrum = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_vsmulD(lastWhitenedSpectrum, 1, [m], &lastWhitenedSpectrum, 1, vDSP_Length(Parameters.fftlength))
		vDSP_vmaxD(lastWhitenedSpectrum, 1, spectrum, 1, &whitenedSpectrum, 1, vDSP_Length(Parameters.fftlength))
		vDSP_vthrD(whitenedSpectrum, 1, [r], &whitenedSpectrum, 1, vDSP_Length(Parameters.fftlength))
		var normalizedSpectrum = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_vdivD(whitenedSpectrum, 1, spectrum, 1, &normalizedSpectrum, 1, vDSP_Length(Parameters.fftlength))
		lastWhitenedSpectrum = whitenedSpectrum
		
		//Applies filter bank
		for (note, var window) in triangleWindows.enumerate() {
			var binValue = 0.0
			vDSP_vmulD(Array(normalizedSpectrum[window.range]), 1, window.function, 1, &window.tempArray, 1, vDSP_Length(window.range.count))
			vDSP_svemgD(window.tempArray, 1, &binValue, vDSP_Length(window.range.count))
			filteredSpectrum[note] = binValue
		}
		vDSP_vsmsaD(filteredSpectrum, 1, [20.0], [1.0], &filteredSpectrum, 1, vDSP_Length(triangleWindows.count))
		vvlog(&filteredSpectrum, filteredSpectrum, [Int32(triangleWindows.count)])
		var ds = [Double](count: triangleWindows.count, repeatedValue: 0.0)
		vDSP_vsubD(lastFilteredSpectrum, 1, filteredSpectrum, 1, &ds, 1, vDSP_Length(triangleWindows.count))
		
		//Calculates modified flux
		var pOnset = 0.0
		vDSP_svemgD(ds, 1, &pOnset, vDSP_Length(triangleWindows.count))	//Takes into account increases AND decreases
		lastFilteredSpectrum = filteredSpectrum
		return pOnset
		
	}
}