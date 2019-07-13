//
//  Analyser.swift
//  BeatVox
//
//  Created by Nahuel Proietto on 17/2/18.
//  Copyright © 2018 ADBAND. All rights reserved.
//

import Foundation

protocol AnalyserDelegate {
    func analyser(_ analyser: Analyser, didFinishTraning phoneme: String)
    func analyser(_ analyser: Analyser, isReadyToPredict: Bool)
    func analyser(_ analyser: Analyser, didPredict phoneme: String, certainty: Float)
}

//MARK: 
class Analyser : NSObject {
    
    var fft = FastTransform(withSize: 1024, sampleRate: 44100)
    var trainingSamples:[knn_curve_label_pair] = [knn_curve_label_pair]()
    let knn_dtw: KNNDTW = KNNDTW()
    var trainingCount = 0 // Just for testing
    var phonema = ""
    var listeningMode = false
    
    var delegate : AnalyserDelegate?
    
    public func process(timeStamp: Double, numberOfFrames: Int, numberOfBands: Int, samples: [Float]) {
        
        self.fft = FastTransform(withSize: numberOfFrames, sampleRate: 44100.0)
        self.fft.windowType = WindowType.hanning
        self.fft.fftForward(samples)
        
        // Interpoloate the FFT data so there's one band per pixel.
        self.fft.calculateLinearBands(minFrequency: 0, maxFrequency: fft.nyquistFrequency, numberOfBands: Int(numberOfBands))
        // self.fft.calculateLogarithmicBands(minFrequency: 0, maxFrequency: fft.nyquistFrequency, bandsPerOctave: Parameters.FFT_BANDS_PER_OCTAVE)
        
        // MFCC feature extraction.
        let sr = 44100
        let FFTlen = numberOfFrames
        let specLen = FFTlen / 2+1
        let numFilters = 48
        let numCoeffs = 12 // 20
        let fftBandMagnitudes = self.fft.bandMagnitudes.map({Double($0)}) // TODO update datatypes for performance
        
        let mfccs = MFCCepstrum(samplingRate: sr, numFilters: numFilters, binSize: specLen, numCoeffs: numCoeffs)
        var mfccData = [Double](repeating: 0.0, count: numCoeffs)
        mfccData = mfccs.getCoefficients(spectralData: fftBandMagnitudes, mfccs: mfccData)
        
        // DTW. Training Series Comparison.
        let mfccFloatData = mfccData.map({Float($0)})
        
        // Just for testing
        if !phonema.isEmpty {
            if self.trainingCount < Parameters.REQUIRED_TRAINING {
                print("mfcc data :: %i", mfccData)
                self.trainingSamples.append(knn_curve_label_pair(curve: mfccFloatData, label: phonema))
                DispatchQueue.main.async {
                    self.delegate?.analyser(self, didFinishTraning: self.phonema)
                }
            }
            else if self.trainingCount == Parameters.REQUIRED_TRAINING {
                self.knn_dtw.train(data_sets: self.trainingSamples)
                print("READY")
                DispatchQueue.main.async {
                    self.delegate?.analyser(self, isReadyToPredict:true)
                }
            }
            self.trainingCount += 1
        }
        else {
            if self.trainingCount > Parameters.REQUIRED_TRAINING {
                if self.listeningMode {
                    let prediction: knn_certainty_label_pair = self.knn_dtw.predict(curve_to_test: mfccFloatData)
                    DispatchQueue.main.async {
                        self.delegate?.analyser(self, didPredict: prediction.label, certainty: prediction.probability*100)
                    }
                    self.listeningMode = false
                }
            }
        }
    }
}
