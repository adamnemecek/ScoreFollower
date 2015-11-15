//
//  Matrix.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 2/3/15.
//  Copyright (c) 2015 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public struct Matrix {
	public let matrix: [Double]
	private let r: vDSP_Length
	private let c: vDSP_Length
	public let rows: Int
	public let columns: Int
	public init(matrix: [Double], rows: Int, columns: Int) {
		self.matrix = matrix
		self.r = vDSP_Length(rows)
		self.c = vDSP_Length(columns)
		self.rows = rows
		self.columns = columns
	}
	public func transpose() -> Matrix {
		var result = [Double](count: rows * columns, repeatedValue: 0.0)
		vDSP_mtransD(matrix, 1, &result, 1, c, r)
		return Matrix(matrix: result, rows: columns, columns: rows)
	}
	public func invert() -> Matrix? {
		if rows != columns { return nil }
		var m = matrix
		var pivot = [__CLPK_integer](count: rows, repeatedValue: 0)
		var workspace = [Double](count: rows, repeatedValue: 0.0)
		var error : __CLPK_integer = 0
		var N = __CLPK_integer(rows)
		dgetrf_(&N, &N, &m, &N, &pivot, &error)
		if error != 0 { return nil }
		dgetri_(&N, &m, &N, &pivot, &workspace, &N, &error)
		return Matrix(matrix: m, rows: rows, columns: columns)
	}
}
public func +(m1: Matrix, m2: Matrix) -> Matrix {
	assert(m1.rows == m2.rows && m1.columns == m2.columns, "Adding matrices of different sizes")
	var result = [Double](count: m1.matrix.count, repeatedValue: 0.0)
	vDSP_vaddD(m1.matrix, 1, m2.matrix, 1, &result, 1, vDSP_Length(result.count))
	return Matrix(matrix: result, rows: m1.rows, columns: m2.columns)
}
public func -(m1: Matrix, m2: Matrix) -> Matrix {
	assert(m1.rows == m2.rows && m1.columns == m2.columns, "Subtracting matrices of different sizes")
	var result = [Double](count: m1.matrix.count, repeatedValue: 0.0)
	vDSP_vsubD(m2.matrix, 1, m1.matrix, 1, &result, 1, vDSP_Length(result.count))
	return Matrix(matrix: result, rows: m1.rows, columns: m2.columns)
}
public func *(m1: Matrix, m2: Matrix) -> Matrix {
	assert(m1.columns == m2.rows, "Invalid dimensions for matrix multiplication")
	var result = [Double](count: m1.rows * m2.columns, repeatedValue: 0.0)
	vDSP_mmulD(m1.matrix, 1, m2.matrix, 1, &result, 1, m1.r, m2.c, m1.c)
	return Matrix(matrix: result, rows: m1.rows, columns: m2.columns)
}
public func *(m: Matrix, d: Double) -> Matrix {
	var result = [Double](count: m.matrix.count, repeatedValue: 0.0)
	var k = d
	vDSP_vsmulD(m.matrix, 1, &k, &result, 1, vDSP_Length(result.count))
	return Matrix(matrix: result, rows: m.rows, columns: m.columns)
}
public func *(d: Double, m: Matrix) -> Matrix {
	var result = [Double](count: m.matrix.count, repeatedValue: 0.0)
	var k = d
	vDSP_vsmulD(m.matrix, 1, &k, &result, 1, vDSP_Length(result.count))
	return Matrix(matrix: result, rows: m.rows, columns: m.columns)
}