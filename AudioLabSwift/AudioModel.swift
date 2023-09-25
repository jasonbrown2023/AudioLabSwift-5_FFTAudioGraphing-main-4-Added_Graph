//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    var fftData2:[Float]
    var playing:Bool
    //var max:[Float]
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        fftData2 = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        playing = false
        
    }
    
    // public function for starting processing of audio file data
    func startProcesingAudioFileForPlayback(withFps:Double){
        // set the output block to read from and play the audio file
        if let manager = self.audioManager,
           let fileReader = self.fileReader{
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            fileReader.play() // tell file Reader to start filling its buffer
            manager.inputBlock = self.handleMicrophone
            //manager.outputBlock = self.printMax
            
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval()
                
            }
            
        }
        
    }
    

    // You must call this when you want the audio to start being handled by our model
    func play(withFps:Double){
        if let manager = self.audioManager{
            playing = true
            manager.play()
            manager.inputBlock = self.handleMicrophone
            
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval()
                
            }
        }
    }
    
    //We need a pause function to stop audio when leaving view
    func pause(){
        if let manager = self.audioManager{
            manager.pause()
            
        }
    }
    
    //For the button to start playing and reset
    func togglePlaying(){
        if let manager = self.audioManager, let reader=self.fileReader{
            if manager.playing{
                manager.pause() // pause audio processing
                reader.pause() // stop buffering the song file
            }else{
                manager.play() // start both again!
                reader.play()
            }
        }
    }
    
    //For the volume slider
    func setVolume(val:Float){
        self.volume = val
    }

    
    //==========================================
    // MARK: Private Properties
    
    private var volume:Float = 1.0 // internal storage for volume
    
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var fftHelper2:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    

    //==========================================
    // MARK: Private Methods
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData,
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            fftHelper2!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData2)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    
   
    
    //MARK: File Reader object has three functions that we will use:
    //      init(), find the audio file and make sure we can see it
    //      play(), go to the file and start decoding samples
    //      retrieveFreshAudio(...), load new samples buffer by buffer into an array
    
    private lazy var fileReader:AudioFileReader? = {
        // find song in the main Bundle
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            // if we could find the url for the song in main bundle, setup file reader
            // the file reader is doing a lot here becasue its a decoder
            // so when it decodes the compressed mp3, it needs to know how many samples
            // the speaker is expecting and how many output channels the speaker has (mono, left/right, surround, etc.)
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0 // start from time zero!
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    
    
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>,
                                                 numFrames:UInt32,
                                                 numChannels: UInt32){
        if let file = self.fileReader{
            
            // read from file, loading into data (a float pointer)
            if let arrayData = data{
                // get samples from audio file, pass array by reference
                file.retrieveFreshAudio(arrayData,
                                        numFrames: numFrames,
                                        numChannels: numChannels)
                // that is it! The file was just loaded into the data array
                
                // adjust volume of audio file output
                vDSP_vsmul(arrayData, 1, &(self.volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
                
            }
            
            
            
        }
    }
    
    //==========================================
        // MARK: Audiocard Callbacks
        // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
        // and in swift this translates to:
        // public function for starting processing of microphone data
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        //printMax(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannel
        
    }
}

