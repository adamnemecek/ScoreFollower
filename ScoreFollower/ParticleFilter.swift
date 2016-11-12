//
//  ParticleFilter.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 1/29/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

open class ParticleFilter<S: State> {
	fileprivate var t: Int
	fileprivate var particles: [S]
	fileprivate var weights: [Double]
	public init(_ initialParticles: [S], _ initialWeights: [Double]) {
		precondition(initialParticles.count == initialWeights.count)
		t = 0
		particles = initialParticles
		weights = initialWeights
	}
	open func update(_ observation: S.Observation, _ Δt: Double) -> ([S], [Double]) {
		if (particles.isEmpty) { return ([], []) }
		if resamplingNeeded() {
			resample()
		}
		for i in 0..<particles.count {
			particles[i].predict(Δt)
			weights[i] *= particles[i].update(observation)
		}
		weights = Utils.normalize(weights)
		t += 1
		return (particles, weights)
	}
	fileprivate func resamplingNeeded() -> Bool {
		//return true
		var effectiveSampleSize = 0.0
		vDSP_svesqD(weights, 1, &effectiveSampleSize, vDSP_Length(particles.count))
		effectiveSampleSize = 1.0 / effectiveSampleSize
		//print(effectiveSampleSize < Double(particles.count) / 4.0)
		return effectiveSampleSize < Double(particles.count) / 4.0
	}
	//Systematic Resampling
	fileprivate func resample() {
		let u0 = drand48()
		var u = [Double](repeating: 0.0, count: particles.count)
		for k in 0..<u.count {
			u[k] = (Double(k) + u0) / Double(u.count)
		}
		var weightSum = weights[0]
		var weightIndex = 0
		var newParticles = [S]()
		newParticles.reserveCapacity(particles.count)
		for u_k in u {
			while weightSum < u_k {
				weightIndex += 1
				weightSum += weights[weightIndex]
			}
			newParticles.append(particles[weightIndex].copy())
		}
		particles = newParticles
		weights = [Double](repeating: 1.0 / Double(particles.count), count: particles.count)
	}
	
}
