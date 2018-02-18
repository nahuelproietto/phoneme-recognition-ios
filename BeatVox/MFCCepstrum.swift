//
//  MelFrequencyCepstrum.swift
//  BeatVox
//
//  Created by Nahuel Proietto on 16/2/18.
//  Copyright © 2018 ADBAND. All rights reserved.
//

import Foundation

// MFCC feature extraction

class MFCCepstrum : NSObject {
    
    var samplingRate = 0
    var numFilters = 0
    var binSize = 0
    var numCoeffs = 0
    var filterParams = [[Double]]()
    var normFactors = [Double]()
    var innerSum = [Double]()
    
    init(samplingRate: Int, numFilters: Int, binSize: Int, numCoeffs: Int) {
        
        super.init()
        
        self.samplingRate = samplingRate
        self.numFilters = numFilters
        self.binSize = binSize
        self.numCoeffs = numCoeffs
        
        self.filterParams = [[Double]](repeating: [Double](repeating: 0, count: binSize), count: numFilters)
        
        self.normFactors = [Double](repeating: 0.0, count: numCoeffs)
        self.innerSum = [Double](repeating: 0.0, count: numFilters)
        
        if self.numCoeffs >= self.numFilters {
            self.numCoeffs = self.numFilters - 1
        }
        
        for i in 0 ... numCoeffs - 1{
            self.normFactors[i] = self.normalizationFactor(m: i)
        }
        
        for i in 0 ... numFilters-1 {
            for k in 0 ... binSize-1 {
                self.filterParams[i][k] = self.getFilterParameter(frequencyBand: k,filterBand: i+1)
            }
        }
    }
    
    func clearTransient() {
        if self.filterParams.count != 0 {
            for i in 0 ... self.numFilters {
                self.filterParams.remove(at: i)
            }
            self.filterParams.removeAll()
        }
        if self.normFactors.count != 0 {
            self.normFactors.removeAll()
        }
        if self.innerSum.count != 0 {
            self.innerSum.removeAll()
        }
    }
    
    func getCoefficients(spectralData: [Double], mfccs: [Double]) -> [Double] {
        var retValue = [Double]()
        if var newMfccs = mfccs as [Double]? {
            for l in 0 ... self.numFilters-1 {
                self.innerSum [l] = 0.0
                for k in 0 ... self.binSize-1 {
                    self.innerSum[l] += fabs(spectralData[k]) * self.filterParams[l][k]
                }
                for m in 0 ... self.numCoeffs-1 {
                    newMfccs[m] += self.innerSum[l] * cos(((Double(m) * Double.pi) / Double(self.numFilters)) * Double((Double(l+1)-0.5)))
                }
            }
            for m in 0 ... self.numCoeffs-1 {
                newMfccs[m] *= self.normFactors[m]
            }
            retValue = newMfccs
        }
        return retValue
    }
    
    func normalizationFactor(m: Int) -> Double {
        var normalizationFactor:Double = 0.0
        if m == 0 {
            normalizationFactor = sqrt(1.0 / Double(self.numFilters))
        }
        else {
            normalizationFactor = sqrt(2.0 / Double(self.numFilters))
        }
        return normalizationFactor
    }
    
    func getFilterParameter(frequencyBand: Int, filterBand: Int) -> Double {
        
        var filterParameter:Double = 0.0
        let boundary = Double((frequencyBand * self.samplingRate) / self.binSize)
        let prevCenterFrequency = self.getCenterFrequency(filterBand: filterBand - 1)
        let thisCenterFrequency = self.getCenterFrequency(filterBand: filterBand)
        let nextCenterFrequency = self.getCenterFrequency(filterBand: filterBand + 1)
        
        if boundary >= 0 && (boundary < prevCenterFrequency) {
            filterParameter = 0.0
        }
        else if (boundary >= prevCenterFrequency && boundary < thisCenterFrequency) {
            filterParameter = (boundary - prevCenterFrequency) / (thisCenterFrequency - prevCenterFrequency)
            filterParameter *= self.getMagnitudeFactor(filterBand: filterBand)
        }
        else if (boundary >= thisCenterFrequency) && (boundary < nextCenterFrequency) {
            filterParameter = (boundary - nextCenterFrequency) / (thisCenterFrequency - prevCenterFrequency)
            filterParameter *= self.getMagnitudeFactor(filterBand: filterBand)
        }
        else if (boundary >= nextCenterFrequency) && (boundary < Double(self.samplingRate)) {
            filterParameter = 0.0
        }
            
        return filterParameter
    }
    
    func getMagnitudeFactor(filterBand: Int) -> Double {
        var magnitudeFactor = 0.0
        if filterBand >= 1 && filterBand <= 14 {
            magnitudeFactor = 0.015
        }
        else if filterBand >= 15 && filterBand <= 48 {
            magnitudeFactor = 2.0 / (self.getCenterFrequency(filterBand: filterBand + 1) - self.getCenterFrequency(filterBand: filterBand - 1))
        }
        return magnitudeFactor
    }
    func getCenterFrequency(filterBand: Int) -> Double {
        
        var centerFrequency:Double = 0.0
        var exponent:Double = 0.0
        
        if filterBand == 0 {
            centerFrequency = 0
        }
        else if filterBand >= 1 && filterBand <= 14 {
            centerFrequency = (200.0 * Double(filterBand)) / 3.0
        }
        else {
            exponent = Double(filterBand) - 14
            centerFrequency = pow(1.0711703, exponent)
            centerFrequency *= 1073.4
        }
        return centerFrequency
    }
}
