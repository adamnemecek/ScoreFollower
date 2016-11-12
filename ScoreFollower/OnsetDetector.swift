//
//  OnsetDetector.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 5/29/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public protocol OnsetDetector {
	func pOnset(_ spectrum: [Double]) -> Double
}

//Uses a modified version of the algorithm described at http://phenicx.upf.edu/system/files/publications/Boeck_DAFx-13.pdf
open class SuperFluxDetector: OnsetDetector {

	fileprivate let m = pow(10, -6.0 / (1.0 * Signal.framesPerSecond))	//memory coefficient for POWER spectrum, decays by 60db in 1s
	fileprivate let r = 5.0	//r = 5.0, floor value
	fileprivate var spectrumPeaks = [Double](repeating: 0.0, count: Signal.fftlength)
	
	fileprivate let µ = 2		//Number of frames previous to calculate difference
	fileprivate var pastSpectra: [[Double]] = []
	fileprivate var meanWindow = [Double](repeating: 0.0, count: 17)
	
	fileprivate var frames = 0
	
	public init() {
		pastSpectra = [[Double]](repeating: [Double](repeating: 0.0, count: Signal.cqtlength), count: µ)
	}
	open func pOnset(_ spectrum: [Double]) -> Double {
		
		frames += 256
		if frames % 44100 < 256 {
		//	print("-1")
		}
		
		//Smooths spectrum by past peaks
		vDSP_vsmulD(spectrumPeaks, 1, [m], &spectrumPeaks, 1, vDSP_Length(Signal.fftlength))		//Decay of past peak levels
		vDSP_vthrD(spectrumPeaks, 1, [r], &spectrumPeaks, 1, vDSP_Length(Signal.fftlength))			//Floor value
		vDSP_vmaxD(spectrumPeaks, 1, spectrum, 1, &spectrumPeaks, 1, vDSP_Length(Signal.fftlength))	//Current spectrum
		
		let whitenedSpectrum = spectrumPeaks
		//vDSP_vdivD(spectrumPeaks, 1, spectrum, 1, &whitenedSpectrum, 1, vDSP_Length(Parameters.fftlength))
		
		//Triangular filters
		var filteredSpectrum = Signal.cqt(whitenedSpectrum)
		if filteredSpectrum[0].isNaN {
			print(0.0)
		}
		vvlog1p(&filteredSpectrum, filteredSpectrum, [Int32(filteredSpectrum.count)])	//log spectrum
		
		//Maximum filter for vibrato suppression
		var maxSpectrum = [Double](repeating: 0.0, count: filteredSpectrum.count - 2)
		vDSP_vswmaxD(filteredSpectrum, 1, &maxSpectrum, 1, vDSP_Length(maxSpectrum.count), 3)
		
		//var average = [Double](count: maxSpectrum.count, repeatedValue: 0.0)
		//vDSP_vaddD(pastSpectra[0], 1, pastSpectra[1], 1, &average, 1, vDSP_Length(average.count))
		//vDSP_vsdivD(average, 1, [2.0], &average, 1, vDSP_Length(average.count))
		
		//Calculates modified flux
		var difference = [Double](repeating: 0.0, count: maxSpectrum.count)
		vDSP_vsubD(pastSpectra[0], 1, maxSpectrum, 1, &difference, 1, vDSP_Length(difference.count))
		vDSP_vthrD(difference, 1, [0.0], &difference, 1, vDSP_Length(difference.count))	//increases only
		var ODF = 0.0	//flux
		vDSP_svemgD(difference, 1, &ODF, vDSP_Length(difference.count))
		var totalPower = 0.0	//Power of n-µ frame
		vDSP_svemgD(pastSpectra[0], 1, &totalPower, vDSP_Length(maxSpectrum.count))
		ODF /= totalPower	//ODF relative to power
		pastSpectra.removeFirst()
		pastSpectra.append(maxSpectrum)
		
		print(ODF)
		
		let pOnset = 1.0 / (1 + pow(100.0 * ODF, -3.0))	//Maps ODF to probability in 0..<1 range
		
		return pOnset
		
	}
}
