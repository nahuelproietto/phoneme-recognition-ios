//
//  ViewController.swift
//  BeatVox
//
//  Created by Nahuel Proietto on 14/2/18.
//  Copyright © 2018 ADBAND. All rights reserved.
//

import UIKit

struct Parameters {
    static let REQUIRED_TRAINING = 500
    static let PROBABILITY_THRESHOLD:Float = 55.0
    static let FFT_BANDS_PER_OCTAVE = 45
}

//MARK:
class ViewController: UIViewController {
    
    var spectralView: SpectralView!
    var analyser : Analyser?
    var audioInput: Audio!
    
    @IBOutlet weak var predictButton: UIButton?
    @IBOutlet weak var textField: UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupAnalyser()
        self.setupCallbacks()
    }
    
    func setupAnalyser() {
        self.analyser = Analyser()
        self.analyser?.delegate = self
    }
    
    func setupCallbacks() {
        
        self.textField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        self.spectralView = SpectralView(frame: self.view.bounds)
        self.spectralView.frame = CGRect(x: self.spectralView.frame.origin.x,
                                         y: self.spectralView.frame.origin.y + 90,
                                         width: self.spectralView.frame.size.width,
                                         height: self.spectralView.frame.size.height - 90)
        
        self.spectralView.backgroundColor = UIColor.white
        self.view.insertSubview(self.spectralView, at: 0)
        
        let audioInputCallback: AudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            let numberOfBands = UIScreen.main.bounds.size.width * UIScreen.main.scale
            self.analyser?.process(timeStamp: Double(timeStamp),
                                   numberOfFrames: Int(numberOfFrames),
                                   numberOfBands: Int(numberOfBands),
                                   samples: samples)
            // UI rendering
            DispatchQueue.main.async {
                self.refreshViews()
            }
        }
        
        self.audioInput = Audio(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        self.audioInput.startRecording()
        
    }
    
    func refreshViews() {
        guard self.analyser != nil else { return }
        self.spectralView.fft = analyser?.fft
        self.spectralView.setNeedsDisplay()
        
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        self.analyser?.phonema = textField.text!
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func listenMode(sender: AnyObject) {
        self.analyser?.phonema = ""
        self.textField?.text = ""
        self.analyser?.listeningMode = true
    }
}

//MARK:
extension ViewController : AnalyserDelegate {
    
    func analyser(_ analyser: Analyser, didFinishTraning phoneme: String) {}
    
    func analyser(_ analyser: Analyser, isReadyToPredict:Bool) {
        self.predictButton?.isEnabled = true
        self.analyser?.phonema = ""
        self.textField?.text = ""
    }
    
    func analyser(_ analyser: Analyser, didPredict phoneme: String, certainty: Float) {
        
        if certainty > Parameters.PROBABILITY_THRESHOLD {
            textField?.text = "PREDICTED: " + "\"\(phoneme)\"" + " " + "\(certainty)" + "% certainty"
        }
        else {
            textField?.text = "NOT SURE.."
        }
    }
    
}
