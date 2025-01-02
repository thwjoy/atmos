//
//  AudioProcessor.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import AVFoundation

class AudioProcessor: ObservableObject {
    private let audioEngine = AVAudioEngine()
    let playerNodes: [String: AVAudioPlayerNode] = [
        "MUSIC": AVAudioPlayerNode(),
        "SFX": AVAudioPlayerNode(),
        "STORY": AVAudioPlayerNode()
    ]
    var previousStoryAudio: [Data] = []  // Store STORY audio chunks
    private let audioQueue = DispatchQueue(label: "com.audioprocessor.queue")
//    var onAppStateChange: ((AppAudioState) -> Void)?
    var onBufferStateChange: ((Bool) -> Void)?
    
    /// Configure the recording session for playback and recording.
    func configureRecordingSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set category to PlayAndRecord to allow input and output
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            // Set the preferred input to the built-in microphone
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
                print("Preferred input set to: \(builtInMic.portName)")
            }
            // Activate the audio session
            try audioSession.setActive(true)
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
        // Debug: Log the current audio route
        print("Current audio route: \(audioSession.currentRoute)")
        for input in audioSession.currentRoute.inputs {
            print("Active input: \(input.portName), Type: \(input.portType)")
        }
        for output in audioSession.currentRoute.outputs {
            print("Active output: \(output.portName), Type: \(output.portType)")
        }
    }
    
    /// Sets up the audio engine
    func setupAudioEngine(sampleRate: Double = 44100) {
        audioQueue.async {

            // Define the desired audio format for the engine
            let mainMixerFormat = self.audioEngine.mainMixerNode.outputFormat(forBus: 0)
            let desiredFormat = AVAudioFormat(
                commonFormat: mainMixerFormat.commonFormat,
                sampleRate: sampleRate,
                channels: mainMixerFormat.channelCount,
                interleaved: mainMixerFormat.isInterleaved
            )

            // Disconnect nodes safely
            self.audioEngine.disconnectNodeOutput(self.audioEngine.mainMixerNode)

            // Loop through the player nodes and connect them to the mixer
            for (_, playerNode) in self.playerNodes {
                self.audioEngine.attach(playerNode)
                self.audioEngine.connect(playerNode, to: self.audioEngine.mainMixerNode, format: desiredFormat)
            }
            
            self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: desiredFormat)

            do {
                // Start the engine with the desired configuration
                try self.audioEngine.start()
                print("Audio engine started with sample rate: \(sampleRate)")
            } catch {
                print("Error starting audio engine: \(error.localizedDescription)")
            }
            self.startMonitoringStoryPlayback()
        }
    }
    
    /// Way to check if the Audio buffer is empty, used for monitoring the back and forth with AI and user
    private func isAudioBufferActive(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData else {
            return false
        }

        let channelSamples = channelData[0] // Access the first channel
        let frameCount = Int(buffer.frameLength)

        // Check if all samples are zero (silence)
        for i in 0..<frameCount {
            if channelSamples[i] != 0 {
                return true // Audio is playing
            }
        }
        return false // Buffer contains silence
    }
    
    /// AI is speaking, monitor the playback
    func startMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            print("STORY player node not found")
            return
        }

        storyNode.removeTap(onBus: 0)

        let tapFormat = storyNode.outputFormat(forBus: 0)
        storyNode.installTap(onBus: 0, bufferSize: 100 * 1024, format: tapFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }

            let isBufferActive = self.isAudioBufferActive(buffer)
            onBufferStateChange?(isBufferActive)
        }
        print("Tap installed on STORY player node")
    }

    /// User is speaking, no need to monitor
    func stopMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            print("STORY player node not found")
            return
        }

        if storyNode.engine != nil {
            storyNode.removeTap(onBus: 0)
        } else {
            print("Attempted to remove tap on a node that is not attached to an engine.")
        }
//        onAppStateChange?(.listening) // Ensure state is reset
        print("Tap removed from STORY player node")
    }

    /// Configure a tap on the input node to capture audio buffers.
    func configureInputTap(bufferSize: AVAudioFrameCount = 1024, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        let inputNode = audioEngine.inputNode
        let format = audioEngine.inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0) // Remove existing tap if any
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            onBuffer(buffer)
        }
        print("Input tap installed with bufferSize: \(bufferSize)")
    }
    
    /// Helper to convert to PCM, ued in streaming
    func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        if let int16ChannelData = buffer.int16ChannelData {
            // Use Int16 data directly
            let channelData = int16ChannelData[0]
            let frameLength = Int(buffer.frameLength)
            return Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
        } else if let floatChannelData = buffer.floatChannelData {
            // Convert Float32 to Int16
            let channelData = Array(UnsafeBufferPointer(start: floatChannelData[0], count: Int(buffer.frameLength)))
            let int16Data = channelData.map { sample in
                let scaledSample = sample * Float(Int16.max)
                return Int16(max(Float(Int16.min), min(Float(Int16.max), scaledSample)))
            }
            return Data(bytes: int16Data, count: int16Data.count * MemoryLayout<Int16>.size)
        } else {
            print("Unsupported audio format")
            return nil
        }
    }
    
    /// Start the audio engine.
    func startAudioEngine() {
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("Audio engine started")
            } catch {
                print("Failed to start audio engine: \(error.localizedDescription)")
            }
        }
    }

    /// Stop the audio engine and remove taps.
    func stopAudioEngine() {
        removeTap()
        if audioEngine.isRunning {
            audioEngine.stop()
            print("Audio engine stopped")
        }
    }
    
    func removeTap() {
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    /// Stop all audio playback.
    func stopAllAudio() {
        audioQueue.async {
            // Loop through the player nodes
            for (_, playerNode) in self.playerNodes {
                if playerNode.isPlaying {
                    playerNode.stop()
                }
                playerNode.reset()
            }

            self.stopAudioEngine()
            self.stopMonitoringStoryPlayback()
            print("All audio stopped")
        }
    }
    
    // Add a method to replay the stored STORY audio
    func replayStoryAudio() {
        audioQueue.async {
            guard !self.previousStoryAudio.isEmpty else {
                print("No STORY audio to replay.")
                return
            }
            print("Replay called")
            // Re-play all previously received STORY chunks
            for chunk in self.previousStoryAudio {
                self.playAudioChunk(audioData: chunk, indicator: "STORY", sampleRate: 24000, saveStory: false)
            }
        }
    }

    /// Play a chunk of audio data.
    func playAudioChunk(audioData: Data, indicator: String, volume: Float = 1.0, sampleRate: Double = 44100, saveStory: Bool = true) {
        // Create a destination format with the engine's sample rate
        let destinationFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false
        )!
        
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: indicator == "STORY" ? 1 : 2,
            interleaved: false
        )!
        
        if indicator == "STORY" && saveStory {
            // Store the chunk for later playback
            audioQueue.async {
                self.previousStoryAudio.append(audioData)
            }
        }
        
        if let playerNode = playerNodes[indicator] {
            audioQueue.async {
                if !self.audioEngine.isRunning {
                    self.setupAudioEngine()
                }
                
                let bytesPerSample = MemoryLayout<Int16>.size
                let frameCount = audioData.count / (bytesPerSample * Int(audioFormat.channelCount))
                
                // Create the source buffer
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                    print("Failed to create AVAudioPCMBuffer")
                    return
                }
                audioBuffer.frameLength = AVAudioFrameCount(frameCount)
                
                // Check if the indicator requires conversion
                if indicator == "STORY" {
                    // Handle conversion for STORY
                    // Convert Int16 interleaved data to Float32
                    audioData.withUnsafeBytes { bufferPointer in
                        let int16Samples = bufferPointer.bindMemory(to: Int16.self)

                        guard let leftChannel = audioBuffer.floatChannelData?[0] else {
                            print("Failed to get left channel data")
                            return
                        }
                        
                        // Mono: Duplicate the data into both left and right channels
                        for i in 0..<frameCount {
                            let sample = int16Samples[i]
                            leftChannel[i] = Float(sample) / Float(Int16.max) * volume * 2.3
                        }
                        // Ensure audioBuffer has valid floatChannelData and enough channels
                        if let channelData = audioBuffer.floatChannelData,
                           audioBuffer.format.channelCount > 1 {
                            
                            let leftChannel = channelData[0]  // Access the left channel
                            let rightChannel = channelData[1]  // Access the right channel

                            // Copy left channel data to right channel
                            memcpy(rightChannel, leftChannel, Int(audioBuffer.frameLength) * MemoryLayout<Float>.size)
                        } else {
                            // Handle invalid data gracefully
//                            print("Error: Insufficient channels or nil floatChannelData.")
                            return
                        }
                    }

                    // Initialize the converter
                    guard let converter = AVAudioConverter(from: audioFormat, to: destinationFormat) else {
                        print("Failed to create AVAudioConverter")
                        return
                    }

                    // Calculate frame capacity for the destination buffer
                    let ratio = destinationFormat.sampleRate / audioFormat.sampleRate
                    let destinationFrameCapacity = AVAudioFrameCount(Double(audioBuffer.frameLength) * ratio)

                    // Create the destination buffer
                    guard let destinationBuffer = AVAudioPCMBuffer(
                        pcmFormat: destinationFormat,
                        frameCapacity: destinationFrameCapacity
                    ) else {
                        print("Failed to create destination buffer")
                        return
                    }

                    // Perform the conversion
                    var error: NSError?
                    converter.convert(to: destinationBuffer, error: &error) { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return audioBuffer
                    }

                    if let error = error {
                        print("Error during conversion: \(error)")
                        return
                    }
                    
                    // Schedule the buffer for playback
                    playerNode.scheduleBuffer(destinationBuffer, at: nil, options: []) {
                    }
                    
                    // Schedule the buffer with explicit timing
                    let startTime = AVAudioTime(sampleTime: 0, atRate: destinationFormat.sampleRate)
                    playerNode.scheduleBuffer(destinationBuffer, at: startTime, options: []) {
                    }
                                        
                } else {
                    // Handle non-STORY indicators (no conversion required)
                    audioData.withUnsafeBytes { bufferPointer in
                        let int16Samples = bufferPointer.bindMemory(to: Int16.self)
                        guard let leftChannel = audioBuffer.floatChannelData?[0],
                              let rightChannel = audioBuffer.floatChannelData?[1] else {
                            print("Failed to get channel data")
                            return
                        }
                        for i in 0..<frameCount {
                            let left = int16Samples[i * 2]
                            let right = int16Samples[i * 2 + 1]
                            leftChannel[i] = Float(left) / Float(Int16.max) * 0.2
                            rightChannel[i] = Float(right) / Float(Int16.max) * 0.2
                        }
                    }
                    
                    // Schedule the buffer for playback
                    playerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {}
                }
                
                
                // Start playback if the player is not already playing
                if !playerNode.isPlaying {
                    playerNode.play()
                }
            }
        }
    }
}
