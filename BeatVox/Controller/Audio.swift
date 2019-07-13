//
//  Audio.swift
//  BeatVox
//
//  Created by Nahuel Proietto on 14/2/18.
//  Copyright © 2018 ADBAND. All rights reserved.
//

import Foundation
import AVFoundation
import AudioUnit

typealias AudioInputCallback = (
    _ timeStamp: Double,
    _ numberOfFrames: Int,
    _ samples: [Float]
    ) -> Void

final class Audio : NSObject {

    var audioUnit: AudioUnit? = nil
    
    var micPermission = false
    var sessionActive = false
    var isRecording = false
    
    var sampleRate:Double = 44100.0
    var audioLevel: Float = 0
    
    private var hwsRate = 48000.0
    private var micPermissionDispatchToken = 0
    private var interrupted = false
    
    private var audioInputCallback: AudioInputCallback!
    
    func startRecording() {
        if self.isRecording {
            return
        }
        self.startAudioSession()
        if self.sessionActive {
            self.startAudioUnit()
        }
    }
    
    var numberOfChannels: Int = 2
    private let outputBus: UInt32 = 0
    private let inputBus: UInt32 = 1
    
    init(audioInputCallback callback: @escaping AudioInputCallback, sampleRate: Float = 44100.0, numberOfChannels: Int = 2) {
        self.audioInputCallback = callback
    }
    
    func startAudioUnit() {
        var err: OSStatus = noErr
        
        if self.audioUnit == nil {
            self.setupAudioUnit()
        }
        guard let au = self.audioUnit
            else {
                return
        }
        err = AudioUnitInitialize(au)
        self.gTmp0 = Int(err)
        
        if err != noErr {
            return
        }
        err = AudioOutputUnitStart(au)
        
        self.gTmp0 = Int(err)
        if err == noErr {
            self.isRecording = true
        }
    }
    func startAudioSession() {
        if sessionActive == false {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                if self.micPermission == false {
                    if self.micPermissionDispatchToken == 0 {
                        self.micPermissionDispatchToken = 1
                        
                        audioSession.requestRecordPermission({(granted: Bool) -> Void in
                            if granted {
                                self.micPermission = true
                                return
                            } else {
                                //dispatch in main thread an alert
                                self.self.gTmp0 += 1
                            }
                        })
                    }
                }
                
                if self.micPermission == false {
                    return
                }
                
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
                var preferredIOBufferDuration = 0.0058
                self.hwsRate = audioSession.sampleRate
                
                if self.hwsRate == 48000.0 { self.sampleRate = 48000.0 }
                if self.hwsRate == 48000.0 { preferredIOBufferDuration = 0.0053 }
                let desiredSampleRate = self.sampleRate
                
                try audioSession.setPreferredSampleRate(desiredSampleRate)
                try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
                
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name.AVAudioSessionInterruption,
                    object: nil,
                    queue: nil,
                    using: myAudioSessionInterruptionHandler)
                
                try audioSession.setActive(true)
                self.sessionActive = true
                
            } catch {
                // handle error here
            }
        }
    }
    func stopRecording() {
        AudioUnitUninitialize(self.audioUnit!)
        self.isRecording = false
    }
    func setupAudioUnit() {
        var componentDesc = AudioComponentDescription(componentType: OSType(kAudioUnitType_Output),
                                                      componentSubType: OSType(kAudioUnitSubType_RemoteIO),
                                                      componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                                                      componentFlags: UInt32(0),
                                                      componentFlagsMask: UInt32(0))
        var osErr: OSStatus = noErr
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        guard let au = self.audioUnit
            else { return }
        
        // Enable I/O for input
        var one_ui32: UInt32 = 1
        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     self.inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        
        let nc = 1
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: Double(self.sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: (kAudioFormatFlagsNativeFloatPacked),
            mBytesPerPacket: UInt32(nc * MemoryLayout<UInt32>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(nc * MemoryLayout<UInt32>.size),
            mChannelsPerFrame: UInt32(nc),
            mBitsPerChannel: UInt32(8 * (MemoryLayout<UInt32>.size)),
            mReserved: UInt32(0))
        
        osErr = AudioUnitSetProperty(au,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, self.outputBus,
                                    &streamFormatDesc,
                                    UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     self.inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: self.recordingCallback,
                                     inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers on render.
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     self.inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        self.gTmp0 = Int(osErr)
    }
    
    var windowBuffer = [Float]()
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: Audio.self)
        var err: OSStatus = noErr
        
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer (mNumberChannels: UInt32(2), mDataByteSize: 16, mData: nil))
        
        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }
        
        audioObject.processMicrophoneBuffer(inputDataList: &bufferList,
                                            frameCount: UInt32(frameCount))
        
        // Triggers FFT Action + UI Rendering
        let threashold:Float = 55.0
        if audioObject.audioLevel > threashold {
            let ptr = bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self)
            audioObject.windowBuffer.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(frameCount)))
            let windowFrameCount = 1024
            if audioObject.windowBuffer.count == windowFrameCount {
                audioObject.audioInputCallback(inTimeStamp.pointee.mSampleTime / Double(audioObject.sampleRate),
                                               Int(windowFrameCount),
                                               audioObject.windowBuffer)
                audioObject.windowBuffer.removeAll()
                audioObject.windowBuffer.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(frameCount)))
            }
        }
        
        return 0
    }
    func processMicrophoneBuffer(   // process RemoteIO Buffer from mic input
        inputDataList : UnsafeMutablePointer<AudioBufferList>,
        frameCount : UInt32 )
    {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            var sum : Float = 0.0
            for i in 0..<(count/2) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
                sum += x * x + y * y
            }
            if sum > 0.0 && count > 0 {
                let tmp = 5.0 * (logf(sum / Float(count)) + 20.0)
                let r : Float = 0.2
                self.audioLevel = r * tmp + (1.0 - r) * self.audioLevel
                // print("Level :: \(self.audioLevel)")
            }
        }
    }
    //MARK: Interruption Handler
    func myAudioSessionInterruptionHandler(notification: Notification) -> Void {
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let interuptionVal = AVAudioSessionInterruptionType(
                rawValue: (interuptionType as AnyObject).uintValue )
            if (interuptionVal == AVAudioSessionInterruptionType.began) {
                if (self.isRecording) {
                    stopRecording()
                    self.isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        self.sessionActive = false
                    } catch {
                    }
                    interrupted = true
                }
            } else if (interuptionVal == AVAudioSessionInterruptionType.ended) {
                if (self.interrupted) {
                    // potentially restart here
                }
            }
        }
    }
    
    var gTmp0 = 0 //  temporary variable for debugger viewing

}
