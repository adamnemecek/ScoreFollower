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
	public static let windowSize = 1 << log2size	//4096
	public static let fftlength = windowSize / 2	//2048
	public static let sampleRate = 44100
	public static let frameLength = 1.0 * Double(windowSize) / Double(sampleRate)
	public static let concertPitch = 441.0
}


/*public class Rest: ScoreElement {
	public override func calculate(observation: [Double]) -> Double {
		return Utils.pSilence(observation)
	}
}*/
public struct Utils {
	//public static let rest: ScoreElement = Rest()
	public static func normalize(array: [Double]) -> [Double] {
		var sum = 0.0
		vDSP_sveD(array, 1, &sum, vDSP_Length(array.count))
		var newArray = [Double](count: array.count, repeatedValue: 0.0)
		vDSP_vsdivD(array, 1, &sum, &newArray, 1, vDSP_Length(array.count))
		return newArray
	}
	private static var r2 = 0.0
	private static var needNewGaussian = true
	public static func randomGaussian() -> Double {
		if !needNewGaussian {
			needNewGaussian = true
			return r2
		}
		var x1, x2, w: Double
		repeat {
			x1 = 2.0 * drand48() - 1.0;
			x2 = 2.0 * drand48() - 1.0;
			w = x1 * x1 + x2 * x2;
		} while ( w >= 1.0 );
		
		w = sqrt((-2.0 * log(w)) / w);
		r2 = x2 * w;
		return x1 * w;
	}
	public static func randomGaussian(μ: Double, _ σ: Double) -> Double {
		return randomGaussian() * σ + μ
	}
	public static func gaussianDistribution(n: Int, μ: Double, σ: Double) -> [Double] {
		var array = [Double](count: n, repeatedValue: 0.0)
		for i in 0..<n {
			array[i] = randomGaussian() * σ + μ
		}
		return array
	}
	public static func logSumExp(values: [Double]) -> Double {
		
		if values.isEmpty {
			return -Double.infinity
		}
		
		var isZero = true
		for value in values {
			if value != -Double.infinity {
				isZero = false
				break
			}
		}
		if isZero {
			return -Double.infinity
		}
		
		var iMax = vDSP_Length(0)
		var max = 0.0
		vDSP_maxviD(values, 1, &max, &iMax, vDSP_Length(values.count))
		max = -max
		var subValues = [Double](count: values.count, repeatedValue: 0.0)
		vDSP_vsaddD(values, 1, &max, &subValues, 1, vDSP_Length(values.count))
		var expValues = [Double](count: values.count, repeatedValue: 0.0)
		var count = Int32(values.count)
		vvexp(&expValues, subValues, &count)
		var sum = 0.0
		vDSP_sveD(expValues, 1, &sum, vDSP_Length(expValues.count))
		return -max + log(sum)
		
	}
	public static func maxPair(values: [Double]) -> (Int, Double) {
		var iMax: vDSP_Length = 0
		var vMax = 0.0
		vDSP_maxviD(values, 1, &vMax, &iMax, vDSP_Length(values.count))
		return (Int(iMax), vMax)
	}
	public static var A0 = Parameters.concertPitch / pow(2, 4)
	public static func noteToFrequency(note: Double) -> Double {
		return A0 * pow(2, (note - 9) / 12);
	}
	public static func frequencyToNote(frequency: Double) -> Double {
		return 12 * log(frequency / A0) / log(2) + 9
	}
	public static func normalDistribution(x: Double, _ mean: Double, _ sd: Double) -> Double {
		return 1.0 / (sd * sqrt(2 * M_PI)) * exp(-(x - mean) * (x - mean) / (2 * sd * sd));
	}
	public static func poisson_pdf(n: Int, _ mu: Double) -> Double {
		if n >  0 {
			return exp(Double(n) * log(mu) - lgamma(Double(n+1)) - mu)
		}
		else  {
			//  when  n = 0 and mu = 0,  1 is returned
			if mu >= 0 {
				return exp(-mu)
			}
			// return a nan for mu < 0 since it does not make sense
			return log(mu);
		}
	}
	public static func poisson_cdf(n: Int, _ mu: Double) -> Double {
		let a = Double(n) + 1.0
		return gamma_cdf_c(mu, alpha: a, theta: 1.0)
	}
	public static func poisson_cdf_c(n: Int, _ mu: Double) -> Double {
		let a = Double(n) + 1.0
		return gamma_cdf(mu, alpha: a, theta: 1.0)
	}
	private static func gamma_cdf(x: Double, alpha: Double, theta: Double) -> Double {
		return igam(alpha, x / theta);
	}
	private static func gamma_cdf_c(x: Double, alpha: Double, theta: Double) -> Double {
		return igamc(alpha, x / theta);
	}
	
	public static func gaussian_pdf(x: Int, _ mu: Double, _ sd: Double) -> Double {
		let a = 0.5 * (1 + erf((Double(x) - 0.5 - mu) / (sd * sqrt(mu * 2))))
		let b = 0.5 * (1 + erf((Double(x) + 0.5 - mu) / (sd * sqrt(mu * 2))))
		return b - a
	}
	public static func gaussian_cdf(x: Int, _ mu: Double, _ sd: Double) -> Double {
		return 0.5 * (1 + erf((Double(x) - mu) / (sd * sqrt(mu * 2))))
	}
	public static func gaussian_cdf_c(x: Int, _ mu: Double, _ sd: Double) -> Double {
		return 0.5 * (1 + erf((-Double(x) + mu) / (sd * sqrt(mu * 2))))
	}
	
	public static let fftsetup = vDSP_create_fftsetupD(vDSP_Length(Parameters.log2size), FFTRadix(kFFTRadix2))
	public static func fft(samples: [Double]) -> [Double] {
		
		/*var observation = observation
		
		var windowFunction = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_blkman_windowD(&windowFunction, vDSP_Length(Parameters.fftlength), 0)
		vDSP_vmulD(observation, 1, windowFunction, 1, &observation, 1, vDSP_Length(Parameters.fftlength))*/
		
		var realp = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		var imagp = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		var splitComplex = DSPDoubleSplitComplex(realp: &realp, imagp: &imagp)
		vDSP_ctozD(UnsafeMutablePointer(samples), 2, &splitComplex, 1, vDSP_Length(Parameters.fftlength))
		vDSP_fft_zripD(fftsetup, &splitComplex, 1, vDSP_Length(Parameters.log2size), FFTDirection(kFFTDirection_Forward))
		splitComplex.realp[0] = 0
		
		var fft = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		vDSP_zvmagsD(&splitComplex, 1, &fft, 1, vDSP_Length(Parameters.fftlength))
		
		return fft
	}
	public static func frequencyTemplate(notes: [Int]) -> [Double] {
		var frequencies = [Double](count: Parameters.fftlength, repeatedValue: 0.0)
		for (_, note) in notes.enumerate() {
			addFrequency(&frequencies, Double(note), 1)
			var octave: Int = 0
			for i in 2...Parameters.harmonics {
				if (i & (i - 1)) == 0 {
					octave += 1
					//addFrequency(&frequencies, note: Double(note + 12 * octave), power: 1.0 / Double(i))
                    addFrequency(&frequencies, Double(note + 12 * octave), 1.0 / pow(2.0, Double(i - 1)))
				}
				else {
					addFrequency(&frequencies, frequencyToNote(Double(i) * noteToFrequency(Double(note))), 1.0 / pow(2.0, Double(i - 1)))
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
	private static func addFrequency(inout frequencies: [Double], _ note: Double, _ power: Double) {
        //print("Test ")
        //println(round(noteToFrequency(note - 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate)))
		let minFrequency = max(Int(round(noteToFrequency(note - 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))), 0)
		let maxFrequency = min(Int(round(noteToFrequency(note + 4 * Parameters.sd) * Double(Parameters.windowSize) / Double(Parameters.sampleRate))), Parameters.fftlength - 1)
		//println(minFrequency)
		//println(maxFrequency)
		//println(normalDistribution(frequencyToNote(Double((minFrequency + maxFrequency)) / 2.0 * Double(Parameters.sampleRate) / Double(Parameters.windowSize)), mean: note, sd: Parameters.sd))
		if minFrequency < maxFrequency {
			for i in minFrequency...maxFrequency {
				frequencies[i] += power * normalDistribution(frequencyToNote(Double(i) * Double(Parameters.sampleRate) / Double(Parameters.windowSize)), note, Parameters.sd)
			}
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
	public static func parseMIDI(URL: NSURL) -> [([Int], Double)] {
		
		var notes = [[(Double, Int, Bool)]]()
		
		var sequence: MusicSequence = nil
		NewMusicSequence(&sequence)
		MusicSequenceFileLoad(sequence, URL, MusicSequenceFileTypeID.MIDIType, MusicSequenceLoadFlags.SMF_PreserveTracks)
		
		
		var trackCount: UInt32 = 0
		MusicSequenceGetTrackCount(sequence, &trackCount)
		var track: MusicTrack = nil
		var iterator: MusicEventIterator = nil
		for i in 0...trackCount {
			MusicSequenceGetIndTrack(sequence, i, &track)
			NewMusicEventIterator(track, &iterator)
			notes += parseTrack(track, iterator: iterator)
		}
		
		return midiNotesToScore(merge(notes, { $0.0 < $1.0 }))
		
	}
	
	private static func parseTrack(track: MusicTrack, iterator: MusicEventIterator) -> [[(Double, Int, Bool)]] {
		
		var notes = [[(Double, Int, Bool)](), [(Double, Int, Bool)]()]
		
		var hasNext: DarwinBoolean = false
		MusicEventIteratorHasNextEvent(iterator, &hasNext)
		var timeStamp: MusicTimeStamp = 0
		var eventType: MusicEventType = 0
		var eventData: UnsafePointer<Void> = nil
		var eventDataSize: UInt32 = 0
		while hasNext {
			MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)
			if eventType == kMusicEventType_MIDINoteMessage {
				let noteData = UnsafePointer<MIDINoteMessage>(eventData)
				notes[0].append((timeStamp, Int(noteData.memory.note), true))
				if (noteData.memory.duration == 0.0500000007450581) {
					notes[1].append((timeStamp + Double(0.5), Int(noteData.memory.note), false))
				} else {
					notes[1].append((timeStamp + Double(noteData.memory.duration), Int(noteData.memory.note), false))
				}
			}
			MusicEventIteratorNextEvent(iterator)
			MusicEventIteratorHasCurrentEvent(iterator, &hasNext)
		}
		
		return notes
		
	}
	
	private static func midiNotesToScore(midiNotes: [(Double, Int, Bool)]) -> [([Int], Double)] {
		var scoreNotes = [([Int], Double)]()
		var currentNotes = [Int]()
		var lastTimeStamp = 0.0
		for note in midiNotes {
			if note.0 - lastTimeStamp > 0.05 {
				scoreNotes.append((currentNotes, note.0 - lastTimeStamp))
				lastTimeStamp = note.0
			}
			if note.2 {
				currentNotes.append(note.1 - 12)
			} else {
				currentNotes.removeAtIndex(currentNotes.indexOf(note.1 - 12)!)
			}
		}
		return scoreNotes
	}
	
	public static func merge<T>(arrays: [[T]], _ lessThan: (T, T) -> Bool) -> [T] {
		var arrayCapacity = 0
		for array in arrays {
			arrayCapacity += array.count
		}
		var mergedArray = [T]()
		mergedArray.reserveCapacity(arrayCapacity)
		var value: (Int, T)!
		var startPositions = [Int](count: arrays.count, repeatedValue: 0)
		var done = false
		while !done {
			for (i, array) in arrays.enumerate() {
				if startPositions[i] < array.count && (value == nil || lessThan(arrays[i][startPositions[i]], value.1)) {
					value = (i, arrays[i][startPositions[i]])
				}
			}
			if value == nil {
				done = true
			} else {
				startPositions[value.0] += 1
				mergedArray.append(value.1)
				value = nil
			}
		}
		return mergedArray
	}
	
	public static func noteName(pitch: Int) -> String {
		let note = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"][pitch % 12]
		let octave = String(pitch / 12)
		return note + octave
	}
	
}