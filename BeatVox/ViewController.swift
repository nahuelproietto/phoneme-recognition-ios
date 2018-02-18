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

class ViewController: UIViewController {
    
    var spectralView: SpectralView!
    var audioInput: Audio!
    
    @IBOutlet weak var phonemaTextField: UITextField?
    
    @IBAction func listenMode(sender: AnyObject) {
        Analyser.sharedInstance.listeningMode = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        self.phonemaTextField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        self.spectralView = SpectralView(frame: self.view.bounds)
        self.spectralView.frame = CGRect(x: self.spectralView.frame.origin.x,
                                         y: self.spectralView.frame.origin.y + 90,
                                         width: self.spectralView.frame.size.width,
                                         height: self.spectralView.frame.size.height - 90)
        
        self.spectralView.backgroundColor = UIColor.white
        self.view.addSubview(self.spectralView)
        
        let audioInputCallback: AudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            let numberOfBands = UIScreen.main.bounds.size.width * UIScreen.main.scale
            Analyser.sharedInstance.analyse(timeStamp: Double(timeStamp),
                                            numberOfFrames: Int(numberOfFrames),
                                            numberOfBands: Int(numberOfBands),
                                            samples: samples)
            // UI rendering
            tempi_dispatch_main { () -> () in
                self.refreshViews()
            }
        }
        self.audioInput = Audio(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        self.audioInput.startRecording()
    }
    
    func refreshViews() {
        self.spectralView.fft = Analyser.sharedInstance.fft
        self.spectralView.setNeedsDisplay()
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        Analyser.sharedInstance.phonema = textField.text!
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
