//
//  Kalman.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 2/3/15.
//  Copyright (c) 2015 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public struct Kalman {
	
	private static let H = Matrix(matrix: [1, 0], rows: 1, columns: 2)
	private static let I = Matrix(matrix: [1, 0, 0, 1], rows: 2, columns: 2)
	
	private let x: Matrix
	private let P: Matrix
	
	public init(v0: Double) {
		x = Matrix(matrix: [0.0, v0], rows: 2, columns: 1)
		P = Matrix(matrix: [1, 0, 0, 1], rows: 2, columns: 2)
	}
	
	public init(x: Matrix, P: Matrix) {
		self.x = x;
		self.P = P
	}
	
	public func update(Δt Δt: Double, σa: Double, a: Double, z: Double, σz: Double) -> Kalman {
		
		let z = Matrix(matrix: [z], rows: 1, columns: 1)
		let F = Matrix(matrix: [1, Δt, 0, 1], rows: 2, columns: 2)
		let B = Matrix(matrix: [pow(Δt, 2) / 2.0, Δt], rows: 2, columns: 1)
		let u = Matrix(matrix: [a], rows: 1, columns: 1)
		let Q = Matrix(matrix: [pow(Δt, 4) / 4.0, pow(Δt, 3) / 2.0, pow(Δt, 3) / 2.0, pow(Δt, 2)], rows: 2, columns: 2) * (σa * σa)
		
		let x = F * self.x + B * u
		let P = F * self.P * F.transpose() + Q
		
		let R = Matrix(matrix: [σz * σz], rows: 1, columns: 1)
		let K = P * Kalman.H.transpose() * (Kalman.H * P * Kalman.H.transpose() + R).invert()!
		
		return Kalman(x: x + K * (z - Kalman.H * x), P: (Kalman.I - K * Kalman.H) * P)
	}
	
	public func getPosition() -> Double { return x.matrix[0] }
	public func getTempo() -> Double { return x.matrix[1] }
	
}