//
//  MathUtils.swift
//  Score Follower
//
//  Created by Tristan Yang on 10/18/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public struct Parameters {
	public static let harmonics = 10
	public static let sd = 0.25
	public static let log2size = 12
	public static let windowSize = 1 << log2size
	public static let fftlength = windowSize / 2
	public static var sampleRate = 48000
}


/*public class Rest: ScoreElement {
	public override func calculate(observation: [Double]) -> Double {
		return Utils.pSilence(observation)
	}
}*/
public struct Utils {
	//public static let rest: ScoreElement = Rest()
	public static func logSumExp(values: [Double], max: Double) -> Double {
		var expValues = [Double](count: values.count, repeatedValue: 0.0)
		var max = max
		vDSP_vsaddD(values, 1, &max, &expValues, 1, vDSP_Length(values.count))
		var sum = 0.0
		vDSP_sveD(expValues, 1, &sum, vDSP_Length(expValues.count))
		return max + log(sum)
	}
	public static var A0 = 440.0 / pow(2, 4)
	public static func noteToFrequency(note: Double) -> Double {
		return A0 * pow(2, (note - 9) / 12);
	}
	public static func frequencyToNote(frequency: Double) -> Double {
		return 12 * log(frequency / A0) / log(2) + 9
	}
	public static func normalDistribution(x: Double, mean: Double, sd: Double) -> Double {
		return 1.0 / (sd * sqrt(2 * M_PI)) * exp(-(x - mean) * (x - mean) / (2 * sd * sd));
	}
	public static let fftsetup = vDSP_create_fftsetupD(vDSP_Length(Parameters.log2size), FFTRadix(kFFTRadix2))
	public static func fft(observation: [Double]) -> [Double] {
		
		/*var observation = observation
		
		var windowFunction = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_blkman_windowD(&windowFunction, vDSP_Length(Parameters.fftlength), 0)
		vDSP_vmulD(observation, 1, windowFunction, 1, &observation, 1, vDSP_Length(Parameters.fftlength))*/
		
		var realp = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		var imagp = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
		vDSP_ctozD(UnsafeMutablePointer(observation), 2, &splitComplex, 1, vDSP_Length(Parameters.fftlength))
		vDSP_fft_zripD(fftsetup, &splitComplex, 1, vDSP_Length(Parameters.log2size), FFTDirection(kFFTDirection_Forward))
		splitComplex.realp[0] = 0
		
		var sum = 0.0
		vDSP_svesqD(splitComplex.realp, 1, &sum, vDSP_Length(Parameters.fftlength))
		var sum1 = 0.0
		vDSP_svesqD(splitComplex.imagp, 1, &sum1, vDSP_Length(Parameters.fftlength))
		sum = sqrt(sum + sum1)
		
		var fft = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_zvabsD(&splitComplex, 1, &fft, 1, vDSP_Length(Parameters.fftlength))
		
		vDSP_vsdivD(fft, 1, &sum, &fft, 1, vDSP_Length(Parameters.fftlength))
		
		return fft
	}
	public static func frequencyTemplate(notes: [Int]) -> [Double] {
		var frequencies = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		for (_, note) in notes.enumerate() {
			addFrequency(&frequencies, note: Double(note), power: 1)
			var octave: Int = 0
			for i in 2...Parameters.harmonics {
				if (i & (i - 1)) == 0 {
					octave++
					//addFrequency(&frequencies, note: Double(note + 12 * octave), power: 1.0 / Double(i))
                    addFrequency(&frequencies, note: Double(note + 12 * octave), power: 1.0 / pow(2.0, Double(i - 1)))
				}
				else {
					addFrequency(&frequencies, note: frequencyToNote(Double(i) * noteToFrequency(Double(note))), power: 1.0 / pow(2.0, Double(i - 1)))
				}
			}
		}
		
		var sum = 0.0
		vDSP_sveD(frequencies, 1, &sum, vDSP_Length(Parameters.fftlength))
		vDSP_vsdivD(frequencies, 1, &sum, &frequencies, 1, vDSP_Length(Parameters.fftlength))
		for i in 0..<Parameters.fftlength {
			frequencies[i] = sqrt(frequencies[i])
		}
		return frequencies
	}
	private static func addFrequency(inout frequencies: [Double], note: Double, power: Double) {
        //print("Test ")
        //println(round(noteToFrequency(note - 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate)))
		let minFrequency = max(Int(round(noteToFrequency(note - 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))), 0)
		let maxFrequency = min(Int(round(noteToFrequency(note + 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))), Parameters.windowSize - 1)
		//println(minFrequency)
		//println(maxFrequency)
		//println(normalDistribution(frequencyToNote(Double((minFrequency + maxFrequency)) / 2.0 * Double(Parameters.sampleRate) / Double(Parameters.windowSize)), mean: note, sd: Parameters.sd))
		for i in minFrequency...maxFrequency {
			frequencies[i] += power * normalDistribution(frequencyToNote(Double(i) * Double(Parameters.sampleRate) / Double(Parameters.windowSize)), mean: note, sd: Parameters.sd)
		}
	}
	/*public static func bhattacharyya(observation: [Double], frequencies: [Int: Double]) -> Double {
		return sum(frequencies.keys.array, { sqrt(observation[$0] * frequencies[$0]!) })
	}
    public static func bhattacharyya(observation: [Double], frequencies: [Double]) -> Double {
        return sum(0, end: observation.count, { sqrt(observation[$0] * frequencies[$0]) })
    }*/
	public static let pinkNoise = { () -> [Double] in
		var noise = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		for i in 0..<Parameters.fftlength {
			noise[i] = sqrt(1.0 / (Double(i * Parameters.sampleRate) / Double(Parameters.fftlength) + 1.0))
		}
		var sum = 0.0
		vDSP_svesqD(noise, 1, &sum, vDSP_Length(Parameters.fftlength))
		vDSP_vsdivD(noise, 1, &sum, &noise, 1, vDSP_Length(Parameters.fftlength))
		return noise
		}()
	/*public static func pSilence(observation: [Double]) -> Double {
		var dotp = 0.0
		vDSP_dotprD(observation, 1, pinkNoise, 1, &dotp, vDSP_Length(Parameters.fftlength))
		return dotp
	}*/
	/*public static func parseMIDI(URL: NSURL) -> Score {
		var sequence = MusicSequence()
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence, URL, MusicSequenceFileTypeID.MIDIType, MusicSequenceLoadFlags.SMF_PreserveTracks)
	}*/
}