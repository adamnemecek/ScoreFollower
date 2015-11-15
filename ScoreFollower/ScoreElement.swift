//
//  ScoreElement.swift
//  ScoreFollower
//
//  Created by Tristan Yang on 11/15/14.
//  Copyright (c) 2014 Tristan Yang. All rights reserved.
//

import Foundation
import Accelerate

public class ScoreElement {
	var pEmission = [Int: Double]()
	func pEmission(t: Int) -> Double! {
		return pEmission[t]
	}
	func update(observation: [Double], t: Int) {
		if pEmission[t] == nil {
			pEmission[t] = log(calculate(observation))
		}
	}
	func calculate(observation: [Double]) -> Double { return 0 }
}

public class Notes: ScoreElement {
    //public let notes: [Int]
    public let frequencies: [Double]
	init(frequencies: [Double]) {
		self.frequencies = frequencies
	}
    /*init(notes: [Int]) {
        self.notes = notes
        frequencies = Utils.frequencyTemplate(notes)
    }*/
    public override func calculate(observation: [Double]) -> Double {
		var dotp = 0.0
		vDSP_dotprD(observation, 1, frequencies, 1, &dotp, vDSP_Length(Parameters.fftlength))
		return dotp
    }
}