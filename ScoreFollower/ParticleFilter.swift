//
//  ParticleFilter.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 1/29/16.
//  Copyright © 2016 Tristan Yang. All rights reserved.
//

import Foundation

public class ParticleFilter<S: State> {
	private var t: Int
	private var particles: [S]
	private var weights: [Double]
	public init(_ initialParticles: [S], _ initialWeights: [Double]) {
		precondition(initialParticles.count == initialWeights.count)
		t = 0
		particles = initialParticles
		weights = initialWeights
	}
	public func update(observation: S.Observation, _ Δt: Double) -> ([S], [Double]) {
		if resamplingNeeded() {
			resample()
		}
		for i in 0..<particles.count {
			particles[i].predict(Δt)
			weights[i] *= particles[i].update(observation)
		}
		Utils.normalize(weights)
		t += 1
		return (particles, weights)
	}
	private func resamplingNeeded() -> Bool {
		return true
	}
	//Systematic Resampling
	private func resample() {
		let u0 = drand48()
		var u = [Double](count: particles.count, repeatedValue: 0.0)
		for k in 0..<u.count {
			u[k] = (Double(k) + u0) / Double(u.count)
		}
		var weightSum = weights[0]
		var weightIndex = 0
		var newParticles = [S]()
		newParticles.reserveCapacity(particles.count)
		for (k, u_k) in u.enumerate() {
			while u_k > weightSum {
				weightIndex += 1
				weightSum += weights[weightIndex]
			}
			newParticles[k] = particles[weightIndex].copy()
		}
		particles = newParticles
		weights = [Double](count: particles.count, repeatedValue: 1.0 / Double(particles.count))
	}
	
}