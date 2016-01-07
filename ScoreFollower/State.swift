//
//  State.swift
//  Score Follower
//
//  Created by Tristan Yang on 10/18/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public class State {
	public let scorePosition: Double
    public let notes: ScoreElement
	public let previous: State!
	public let length: Double
	private var startTime: Int!
	private var pViterbi = [Double]()
	private var pTransition = [Double]()
	private var tempo = [Double]()
	
	private var lastProduct = 0.0
	
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
	func transitionFunction(tempo: Double, _ t: Int) -> Double {
		lastProduct += notes.pEmission(t)
		//return lastProduct
		//return 0
		return t == 0 ? 0 : -Double.infinity
	}
	func viterbiFunction(tempo: Double, _ t: Int) -> Double {
		//self.kalman[t] = Kalman(v0: tempo)
		//return lastProduct
		return t == 0 ? 0 : -Double.infinity
		//return t == 0 ? 0 : self.pEmission(t) + self.pViterbi(t - 1)
	}
	public func pEmission(t: Int) -> Double {
		if let p = notes.pEmission(t) {
			return p
		} else {
			return -Double.infinity
		}
	}
	/*private func kalman(t: Int) -> Kalman {
		return kalman[t - startTime]
	}*/
	public func pTransition(t: Int) -> Double {
		return /*t == 0 && scorePosition == 0 ? 0 : */(startTime == nil || t < startTime || t >= pViterbi.count + startTime) ? -Double.infinity : pTransition[t - startTime]
	}
	public func pViterbi(t: Int) -> Double {
		return /*t == 0 ? 0 : */(startTime == nil || t < startTime || t >= pViterbi.count + startTime) ? -Double.infinity : pViterbi[t - startTime]
	}
	public func update(observation: [Double], _ tempo: Double, _ t: Int) -> Double {
		if startTime == nil { startTime = t }
        notes.update(observation, t)
		pTransition.append(transitionFunction(tempo, t))
		pViterbi.append(viterbiFunction(tempo, t))
        return pViterbi[pViterbi.count - 1]
	}
}

class MarkovState: State {
	init(scorePosition: Double, notes: ScoreElement, previous: State) {
		super.init(scorePosition: scorePosition, notes: notes, previous: previous, length: 0)
	}
	override func viterbiFunction(tempo: Double, _ t: Int) -> Double {
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
	enum survivalDistributionMode {
		case logistic
		case gaussian
		case cauchy
		//case poisson
		case exponential
		case exact
	}
	var mode = survivalDistributionMode.exact
	private var varianceFactor = 1.0
	private var observationTable = [Double]()
	init(scorePosition: Double, notes: ScoreElement, previous: State, length: Double) {
		super.init(scorePosition: scorePosition, notes: notes, previous: previous, length: length)
	}
	private func prepare(tempo: Double, _ t: Int) {
		//let uMax = max(min(Int(2.0 / tempo * length), t - self.startTime), 2)
		let uMax = max(t + 1, 2)//max(Int(2.0 / tempo * length), 2)
		observationTable = [Double](count: t + 1, repeatedValue: 0.0)
		var lastProduct = 0.0
		for u in 0...t {
			//lastProduct += pEmission(t - u + 1)
			observationTable[u] = lastProduct + previous.pTransition(t - u)
		}
	}
	override func transitionFunction(tempo: Double, _ t: Int) -> Double {
		var transitionTable = observationTable
		let variance = max(varianceFactor * length / tempo, 0.0001)
		for u in 0..<observationTable.count {
			//let a = 0.5 * (1 + erf((Double(u) - 0.5 - length / tempo) / sqrt(variance * 2)))
			//let b = 0.5 * (1 + erf((Double(u) + 0.5 - length / tempo) / sqrt(variance * 2)))
			
			/*let duration1 = Int(Double(u) - length / tempo)
			var duration2 = Int(Double(u + 1) - length / tempo)
			if duration1 != 0 || duration2 != 1 {
				transitionTable[u - 1] -= Double.infinity
			}*/
			
			/*print(tempo)
			if length <= 0.04 {
				print(variance)
			} else {
				print("ASDFASDF\(variance)")
			}*/
			//print("\(scorePosition) + \(length / tempo)")
			transitionTable[u] += log(Utils.poisson_pdf(u, length / tempo))
			//transitionTable[u - 1] += log(b - a)
		}
		
		/*var vMax = 0.0
		var iMax = vDSP_Length(0)
		vDSP_maxviD(transitionTable, 1, &vMax, &iMax, vDSP_Length(transitionTable.count))
		
		return vMax*/
		return Utils.logSumExp(transitionTable)
	}
	override func viterbiFunction(tempo: Double, _ t: Int) -> Double {
		var viterbiTable = observationTable
		let variance = max(varianceFactor * length / tempo, 0.0001)
		for u in 1..<observationTable.count + 1 {
			viterbiTable[u - 1] += log(Utils.poisson_cdf_c(u - 1, length / tempo))
			//viterbiTable[u - 1] += log(0.5 * (1 + erf((-Double(u) + length / tempo) / sqrt(variance * 2))))
		}
		/*var vMax = 0.0
		var iMax = vDSP_Length(0)
		vDSP_maxviD(viterbiTable, 1, &vMax, &iMax, vDSP_Length(viterbiTable.count))
		
		return vMax*/
		
		return Utils.logSumExp(viterbiTable)
		
		/*let uMax = max(min(Int(2.0 / tempo * length), t - self.startTime), 2)
		var v = [Double](count: uMax - 1, repeatedValue: 0.0)
		var lastProduct = 0.0//self.pEmission(t)
		//var tempo: Double
		for u in 1..<uMax {
			//tempo = previous.kalman(t - u).getTempo()
			lastProduct += 0//self.pEmission(t - u)
			v[u - 1] = lastProduct + previous.pViterbi(t - u)
			switch mode {
			case .logistic:
				v[u - 1] -= log(1.0 + exp(12.0 * (Double(u) / (length / tempo) - 1.0)))
			case .gaussian:
				v[u - 1] += log(0.5 * (1 + erf((-Double(u) + 1.5 * length / tempo) / sqrt(1 * length / tempo * 2))))
			case .cauchy:
				v[u - 1] += log(1.0 / M_PI * atan((-((Double(u) / (length / tempo)) - 1.0)) / (0.2 * tempo)) + 0.5)
			//case .poisson:
			//	v[u - 1] += 0
			case .exponential:
				v[u - 1] -= 0.5 * Double(u) / (length / tempo)
			case .exact:
				if Double(u) > max(length / tempo * 1.05, 1) {
					v[u - 1] -= Double.infinity
				}
			}
		}
		var vMax = -Double.infinity
		for i in 0..<v.count {
			if v[i] > vMax {
				vMax = v[i]
			}
		}
		//var pNormalized = vMax - Utils.logSumExp(v, max: vMax)
		//REMEMBER TO CHANGE STDEV for ACCELERATION
		//kalman[t] = previous.kalman(t - duration).update(duration, σa: 2.5, a: 0, z:scorePosition, σz: <#Double#>)
		
		return vMax*/
	}
	override func update(observation: [Double], _ tempo: Double, _ t: Int) -> Double {
		if startTime == nil { startTime = t }
		notes.update(observation, t)
		prepare(tempo, t)
		//varianceFactor = 0.2 * length / tempo
		pTransition.append(transitionFunction(tempo, t))
		pViterbi.append(viterbiFunction(tempo, t))
		return pViterbi[pViterbi.count - 1]
	}
}
