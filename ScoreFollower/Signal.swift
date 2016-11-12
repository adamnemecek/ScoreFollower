//
//  Signal.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 6/21/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

//Static utility methods for manipulating signals
public struct Signal {
	
	public static let sampleRate = 44100
	public static let log2size = 12
	public static let windowSize = 1 << log2size	//4096
	public static let fftlength = windowSize / 2	//2048
	public static let samplesPerFrame = 256
	public static let frameLength = Double(samplesPerFrame) / Double(sampleRate)
	public static let framesPerSecond = Double(sampleRate) / Double(samplesPerFrame)
	
	fileprivate static let fftsetup = vDSP_create_fftsetupD(vDSP_Length(log2size), FFTRadix(kFFTRadix2))
	public static func fft(_ samples: [Double]) -> [Double] {		//Returns the POWER spectrum of a signal
		
		//formatting imput vector
		//var samples = samples
		var realp = [Double](repeating: 0.0, count: fftlength)
		var imagp = [Double](repeating: 0.0, count: fftlength)
		var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
		vDSP_ctozD(unsafeBitCast(samples, to: UnsafePointer<DSPDoubleComplex>.self), 2, &splitComplex, 1, vDSP_Length(fftlength))
		/*withUnsafePointer(to: &samples) {
			$0.withMemoryRebound(to: DSPDoubleComplex.self, capacity: fftlength) {
				vDSP_ctozD($0, 2, &splitComplex, 1, vDSP_Length(fftlength))
			}
		}*/
		
		//fft
		vDSP_fft_zripD(fftsetup!, &splitComplex, 1, vDSP_Length(log2size), FFTDirection(kFFTDirection_Forward))
		splitComplex.realp[0] = 0	//DC component discarded
		
		//power spectrum conversion
		var fft = [Double](repeating: 0.0, count: fftlength)
		vDSP_zvmagsD(&splitComplex, 1, &fft, 1, vDSP_Length(fftlength))
		
		return fft
	}
	
	public static let concertPitch = 441.0
	public static let cqtLowFrequency = concertPitch / 16.0
	public static let cqtResolution = 24 //divisions per octave
	public static let cqtFactor = pow(2, 1.0 / Double(cqtResolution))	//Frequency
	public static let cqtlength = Int(log(Double(sampleRate) / 2.0 / cqtLowFrequency) / log(cqtFactor)) + 1
	
	fileprivate static let spectralKernels = { () -> sparse_matrix_double in
		
		let Q = 1 / (cqtFactor - 1)
		
		var spectralKernels = sparse_matrix_create_double(UInt64(cqtlength), UInt64(fftlength))
		let floor = 0.0054 * 0.0054
		var frequency = cqtLowFrequency
		for row in 0..<cqtlength {
			var window = [Double](repeating: 0.0, count: windowSize)
			var temporalKernel = [Double](repeating: 0.0, count: windowSize)
			let N = min(window.count, Int(Double(Signal.sampleRate) / frequency * Q))
			vDSP_hamm_windowD(&window, vDSP_Length(N), 0)
			//vDSP_hann_windowD(&window, vDSP_Length(N), Int32(vDSP_HANN_NORM))
			for i in 0..<temporalKernel.count {
				temporalKernel[i] = cos(2.0 * frequency * M_PI / Double(Signal.sampleRate) * Double(i - N / 2))
			}
			vDSP_vmulD(window, 1, temporalKernel, 1, &temporalKernel, 1, vDSP_Length(windowSize))
			temporalKernel = Signal.fft(temporalKernel)
			var amplitude = 0.0
			var sum = 0.0
			vDSP_maxvD(temporalKernel, 1, &amplitude, vDSP_Length(temporalKernel.count))
			vDSP_sveD(temporalKernel, 1, &sum, vDSP_Length(temporalKernel.count))
			//vDSP_vsdivD(temporalKernel, 1, [44100*44100/Double(frequency * frequency)], &temporalKernel, 1, vDSP_Length(temporalKernel.count))
			//vDSP_maxvD(temporalKernel, 1, &amplitude, vDSP_Length(temporalKernel.count))
			//print(amplitude)
			if row == cqtlength - 3 {
				for x in temporalKernel {
					print(x)
				}
				print()
			}
			for (col, value) in temporalKernel.enumerated() {
				if value > floor {
					sparse_insert_entry_double(spectralKernels, value, Int64(row), Int64(col))
				}
			}
			frequency *= cqtFactor
		}
		
		print("cqtlength: \(cqtlength)")
		print("fftlength: \(fftlength)")
		
		var identity = [[Double]](repeating: [Double](repeating: 0.0, count: cqtlength), count: cqtlength)
		for i in 0..<cqtlength {
			identity[i][i] = 1.0
		}
		var vector = [Double](repeating: 0.0, count: fftlength)
		for i in 100...100 {
			sparse_matrix_vector_product_dense_double(CblasTrans, 1.0, spectralKernels, identity[i], 1, &vector, 1)
			for x in vector {
				print(x)
			}
			print(-1.0)
		}
		
		//sparse_commit(&spectralKernels)
		return spectralKernels!
		
	}()
	public static func cqt(_ samples: [Double]) -> [Double] {		//Takes the Constant-Q Transform of a signal
		var cqSpectrum = [Double](repeating: 0.0, count: cqtlength)
		sparse_matrix_vector_product_dense_double(CblasNoTrans, 1.0, spectralKernels, fft(samples), 1, &cqSpectrum, 1)
		return cqSpectrum
	}
	public static func cqSpectrum(_ fourierSpectrum: [Double]) -> [Double] {	//Returns the Constant-Q Transform of a signal given its Fourier Transform
		var cqSpectrum = [Double](repeating: 0.0, count: cqtlength)
		sparse_matrix_vector_product_dense_double(CblasNoTrans, 1.0, spectralKernels, fourierSpectrum, 1, &cqSpectrum, 1)
		return cqSpectrum
	}
	
	public static let pinkNoise = { () -> [Double] in
		var noise = [Double](repeating: 0.0, count: fftlength)
		for i in 0..<noise.count {
			noise[i] = 1.0 / (Double(i * fftlength) / Double(fftlength) + 1.0)
		}
		var sum = 0.0
		vDSP_sveD(noise, 1, &sum, vDSP_Length(fftlength))
		vDSP_vsdivD(noise, 1, &sum, &noise, 1, vDSP_Length(fftlength))
		return ScoreFollower.constantQ ? Signal.cqSpectrum(noise) : noise
	}()
	
	public static func KLDivergence(_ P: [Double], _ Q: [Double]) -> Double {
		var tempArray = [Double](repeating: 0.0, count: P.count)
		vDSP_vdivD(Q, 1, P, 1, &tempArray, 1, vDSP_Length(P.count))
		vvlog(&tempArray, tempArray, [Int32(tempArray.count)])
		vDSP_vmulD(P, 1, tempArray, 1, &tempArray, 1, vDSP_Length(P.count))
		var KLDivergence = 0.0
		vDSP_sveD(tempArray, 1, &KLDivergence, vDSP_Length(P.count))
		return KLDivergence
	}
	public static func EuclidianDistance(_ A: [Double], _ B: [Double]) -> Double {
		var distance = 0.0
		vDSP_distancesqD(A, 1, B, 1, &distance, vDSP_Length(A.count))
		return sqrt(distance)
	}
	public static func BhattacharyyaCoefficient(_ P: [Double], _ Q: [Double]) -> Double {
		var tempArrayP = [Double](repeating: 0.0, count: P.count)
		var tempArrayQ = [Double](repeating: 0.0, count: Q.count)
		vvsqrt(&tempArrayP, P, [Int32(P.count)])
		vvsqrt(&tempArrayQ, Q, [Int32(Q.count)])
		var bc = 0.0
		vDSP_dotprD(tempArrayP, 1, tempArrayQ, 1, &bc, vDSP_Length(P.count))
		return bc
	}
	public static func HellingerDistance(_ P: [Double], _ Q: [Double]) -> Double {
		return sqrt(1 - BhattacharyyaCoefficient(P, Q))
	}
	
}
