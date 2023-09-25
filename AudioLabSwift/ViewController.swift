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
        
        //Build the graph
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

        
      
    }
    // just start up the audio model here
    //Play Button
    @IBAction func play(_ sender: UIButton) {
        audio.startProcesingAudioFileForPlayback(withFps: 20)
        audio.togglePlaying()
        audio.playing = true //Set boolean to know when to pause
        //Schedule timer to update graph
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
    
    //To pause when leaving screen
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        if(audio.playing==true){
            audio.pause();
            
        }
        //audio.pause();
        
    }
    //To pause when leaving screen
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated);
        
        if(audio.playing==true){
            audio.pause();
            
        }
       
        
    }
    
    //Setup to start place when audio.playing = true
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
    
            audio.play(withFps: 20)
            audio.playing = true
        // run the loop for updating the graph peridocially
            Timer.scheduledTimer(timeInterval: 0.05, target: self,
                                 selector: #selector(self.updateGraph),
                                 userInfo: nil,
                                 repeats: true)

    }
    
    @IBOutlet weak var volumeLabel: UILabel!
    
    
    
    var displaySongName = "Satisfaction"
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
              
           //Use accelerate to get the max from the fftData2 that is of size buffersize/2, and broken down into 20 windows,
            //where each window is a fifth of the halfed buffersize. We do not need the second part of the fft as it is
            //only a mirror of the first half
            vDSP_vswmax(self.audio.fftData2, 1, &audio.fftData2, 1, vDSP_Length(AudioConstants.AUDIO_BUFFER_SIZE/20), vDSP_Length(AudioConstants.AUDIO_BUFFER_SIZE/100))
                
            //Setup fft2 graph 
            graph.updateGraph(
                data: self.audio.fftData2,
                forKey: "fft2"
             
            )
        }
        
    }
}

