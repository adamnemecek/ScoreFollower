//
//  State.swift
//  Score Follower
//
//  Created by Tristan Yang on 10/18/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import Foundation

public class State {
	public let scorePosition: Double
    public let notes: ScoreElement
	public let previous: State!
	public let length: Double
	private var startTime: Int!
	private var pViterbi = [Double]()
	//private var kalman = [Kalman]()
    //private var viterbiFunction: (Double, Int) -> Double = { (tempo, t) in return 0.0 }
	private init(scorePosition: Double, notes: ScoreElement, previous: State!, length: Double) {
		self.scorePosition = scorePosition
		self.length = length
		self.notes = notes
		self.previous = previous
	}
	convenience init(silence: ScoreElement) {
		self.init(scorePosition: 0, notes: silence, previous: nil, length: 0)
	}
	func viterbiFunction(tempo: Double, t: Int) -> Double {
		//self.kalman[t] = Kalman(v0: tempo)
		return t == 0 ? 0 : self.pEmission(t) + self.pViterbi(t - 1)
	}
		public func pEmission(t: Int) -> Double {
		if let p = notes.pEmission(t) {
			return p
		} else {
			return 0
		}
	}
	/*private func kalman(t: Int) -> Kalman {
		return kalman[t - startTime]
	}*/
	public func pViterbi(t: Int) -> Double {
		return t == 0 ? 0 : (startTime == nil || t < startTime || t >= pViterbi.count + startTime) ? -Double.infinity : pViterbi[t - startTime]
	}
	public func update(observation: [Double], tempo: Double, t: Int) -> Double {
		if startTime == nil { startTime = t }
        notes.update(observation, t: t)
		let p = viterbiFunction(tempo, t: t)
		pViterbi.append(p)
        return p
	}
}

class MarkovState: State {
	init(scorePosition: Double, notes: ScoreElement, previous: State) {
		super.init(scorePosition: scorePosition, notes: notes, previous: previous, length: 0)
	}
	override func viterbiFunction(tempo: Double, t: Int) -> Double {
		let pPrevious = log(0.5) + previous.pViterbi(t - 1)
		let pSelf = log(0.5) + self.pViterbi(t - 1)
		if pPrevious > pSelf {
			//self.kalman[t] = previous.kalman(t - 1)
			return self.pEmission(t) + pPrevious
		} else {
			//self.kalman[t] = self.kalman(t - 1)
			return self.pEmission(t) + pSelf
		}
		//return self.pEmission(t) + max(log(tempo / length) + previous.pViterbi(t - 1), log(1.0 - tempo / length) + self.pViterbi(t - 1))
	}
}

class SemiMarkovState: State {
	init(scorePosition: Double, notes: ScoreElement, previous: State, length: Double) {
		super.init(scorePosition: scorePosition, notes: notes, previous: previous, length: length)
	}
	override func viterbiFunction(tempo: Double, t: Int) -> Double {
		let uMax = max(min(Int(2.0 / tempo * length), t - self.startTime), 1)
		var v = [Double](count: uMax - 1, repeatedValue: 0.0)
		var lastProduct = self.pEmission(t)
		//var tempo: Double
		for u in 1..<uMax {
			//tempo = previous.kalman(t - u).getTempo()
			lastProduct += self.pEmission(t - u)
			v[u - 1] = lastProduct + previous.pViterbi(t - u)
			v[u - 1] -= log(1.0 + exp(12.0 * (Double(u) / (length / tempo) - 1.0)))
			//v *= Utils.function({1.0 / (1.0 + exp(12.0 * ($0 - 1.0)))}, x: Double(-u) / (length / tempo))
		}
		
		var duration: Int
		var vMax = -Double.infinity
		for i in 0..<v.count {
			if v[i] > vMax {
				vMax = v[i]
				duration = i
			}
		}
		//var pNormalized = vMax - Utils.logSumExp(v, max: vMax)
		//REMEMBER TO CHANGE STDEV for ACCELERATION
		//kalman[t] = previous.kalman(t - duration).update(duration, σa: 2.5, a: 0, z:scorePosition, σz: <#Double#>)
		
		return vMax
	}
}
