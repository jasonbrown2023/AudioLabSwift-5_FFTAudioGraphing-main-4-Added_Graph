//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal





class ViewController: UIViewController {

    @IBOutlet weak var userView: UIView!
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // becasue the fft is returned in dB which has very large negative values and some large positive values
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "time",
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            graph.addGraph(withName: "fft2",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.makeGrids() // add grids to graph
        }
        
        
        
        // start up the audio model here, querying microphone
        //audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
        

        //audio.play()
        /*
        run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
                             selector: #selector(self.updateGraph),
                             userInfo: nil,
                             repeats: true)
       */
    }
    
    
    @IBAction func play(_ sender: UIButton) {
        audio.startProcesingAudioFileForPlayback(withFps: 20)
        audio.togglePlaying()
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
                             selector: #selector(self.updateGraph),
                             userInfo: nil,
                             repeats: true)
    }
    @IBAction func volumeChanged(_ sender: UISlider) {
        // set the volumen using the audio model, this controls the output block
        audio.setVolume(val: sender.value)
        // let the user know what the volume is!
        volumeLabel.text = String(format: "Volume: %.1f", sender.value )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        [super.viewWillDisappear(animated)];
        [audio.pause];
    }
    
    @IBOutlet weak var volumeLabel: UILabel!
    override func viewWillAppear(_ animated: Bool) {
        [super.viewWillAppear(animated)];
        [audio.play];
    }
    var displayImageName = "psuedo"
    // periodically, update the graph with refreshed FFT Data
    @objc func updateGraph(){
        
        if let graph = self.graph{
            
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
                
            )
              
           
            vDSP_vswmax(self.audio.fftData2, 1, &audio.fftData2, 1, vDSP_Length(AudioConstants.AUDIO_BUFFER_SIZE/20), vDSP_Length(AudioConstants.AUDIO_BUFFER_SIZE/100))
                
            
            graph.updateGraph(
                data: self.audio.fftData2,
                forKey: "fft2"
             
            )
        }
        
    }
}

