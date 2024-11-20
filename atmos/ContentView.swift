//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation
import Foundation

var SERVER_URL = "ws://192.168.1.197:8765"

struct ContentView: View {
    @State private var isRecording = false
    @State private var connectionStatus = "Disconnected"
    @State private var messages: [(String, Data?)] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayers: [AVAudioPlayer] = []
    private let audioProcessingQueue = DispatchQueue(label: "AudioProcessingQueue")
    private var webSocketManager = WebSocketManager()
    private var audioBufferQueue = DispatchQueue(label: "com.audio.buffer.queue")
    @State private var bufferPool: [Data] = [] // To store incoming audio chunks
    private let audioEngine = AVAudioEngine()
    private let musicPlayerNode = AVAudioPlayerNode()
    private let sfxPlayerNode = AVAudioPlayerNode() // Separate node for SFX
    private let audioQueue = DispatchQueue(label: "audio.queue")


    var body: some View {
        VStack(spacing: 20) {
            // Recording and Connection Status Indicators
            VStack {
                Text("Recording Status: \(connectionStatus == "Connected" ? (isRecording ? "Recording" : "Connecting") : "Idle")")
                    .font(.headline)
                    .foregroundColor(connectionStatus == "Connected" ? (isRecording ? .green : .orange) : .red)

                Text("Connection Status: \(connectionStatus)")
                    .font(.headline)
                    .foregroundColor(connectionStatus == "Connected" ? .green : .red)
            }

//            // Start/Stop Recording Button
//            Button(action: {
//                if connectionStatus == "Connected" {
//                    isRecording.toggle()
//                    if isRecording {
//                        webSocketManager.sendAudioStream()
//                    } else {
//                        webSocketManager.stopAudioStream()
//                    }
//                }
//            }) {
//                Text(isRecording ? "Stop Recording" : "Start Recording")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(isRecording ? Color.red : Color.green)
//                    .cornerRadius(10)
//            }
//
//            // Connect/Disconnect Button
//            Button(action: {
//                if connectionStatus == "Connected" {
//                    webSocketManager.disconnect()
//                    DispatchQueue.main.async {
//                        stopAllAudio()      // Stop all audio
//                    }
//                } else {
//                    if let url = URL(string: SERVER_URL) {
//                        webSocketManager.connect(to: url)
//                    }
//                }
//            }) {
//                Text(connectionStatus == "Connected" ? "Disconnect" : "Connect")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(connectionStatus == "Connected" ? Color.red : Color.green)
//                    .cornerRadius(10)
//            }
            
            Button(action: {
                if connectionStatus == "Connected" {
                    if isRecording {
                        // Stop recording
                        isRecording = false
                        webSocketManager.stopAudioStream()
                    }
                    // Disconnect
                    webSocketManager.disconnect()
                    DispatchQueue.main.async {
                        stopAllAudio() // Stop all audio
                    }
                } else {
                    if let url = URL(string: SERVER_URL) {
                        webSocketManager.connect(to: url)
                        // Start streaming after connection is established
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if connectionStatus == "Connected" {
                                webSocketManager.sendAudioStream()
                                isRecording = true
                            }
                        }
                    }
                }
            }) {
                Text(
                    connectionStatus == "Connected"
                        ? "Disconnect"
                        : "Connect"
                )
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(
                    connectionStatus == "Connected"
                        ? Color.red
                        : Color.green
                )
                .cornerRadius(10)
            }

            // Messages Log
//            VStack(alignment: .leading) {
//                Text("Messages Log")
//                    .font(.headline)
//                    .padding(.bottom, 5)
//
//                ScrollView {
//                    ForEach(messages.indices, id: \.self) { index in
//                        let message = messages[index].0
//                        let audioData = messages[index].1
//
//                        HStack {
//                            Text(message)
//                                .padding(.vertical, 5)
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .background(
//                                    message.hasPrefix("Sent:") ? Color.gray.opacity(0.2) :
//                                        message.hasPrefix("Received:") ? Color.blue.opacity(0.2) : Color.clear
//                                )
//                                .cornerRadius(5)
//
//                            // Play Button for Received Audio
//                            if let audioData = audioData {
//                                Button(action: {
////                                    playReceivedAudio(audioData: audioData)
//                                }) {
//                                    Image(systemName: "play.circle")
//                                        .foregroundColor(.blue)
//                                        .font(.title2)
//                                }
//                                .padding(.leading, 10)
//                            }
//                        }
//                    }
//                }
//                .frame(height: 200)
//                .border(Color.gray, width: 1)
//            }
            
        }
        .padding()
        .onAppear {
            configureRecordingSession()
            // WebSocket Connection Status Handling
            webSocketManager.onConnectionChange = { status in
                DispatchQueue.main.async {
                    self.connectionStatus = status ? "Connected" : "Disconnected"
                }
            }

            // Handle Received Messages
            webSocketManager.onMessageReceived = { message in
                DispatchQueue.main.async {
                    self.messages.append(("Received: \(message)", nil))
                }
            }
            
            webSocketManager.stopRecordingCallback = {
                DispatchQueue.main.async {
                    isRecording = false
                }
            }
            
            setupAudioEngine()
            webSocketManager.onAudioReceived = { audioData, isSFX in
                self.playAudioChunk(audioData: audioData, isSFX: isSFX)
            }
        }
        .onDisappear {
            // Disconnect WebSocket
            webSocketManager.disconnect()
            connectionStatus = "Disconnected"
        }
    }
    
    private func configureRecordingSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
            
    private func stopAllAudio() {
        audioQueue.async {
            // Stop the player node
            if self.musicPlayerNode.isPlaying {
                self.musicPlayerNode.stop()
            }
            self.musicPlayerNode.reset()
            
            if self.sfxPlayerNode.isPlaying {
                self.sfxPlayerNode.stop()
            }
            self.sfxPlayerNode.reset()

            // Optionally, stop the audio engine if it's no longer needed
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }

            print("All audio stopped")
        }
    }
    
    // Initialize and connect these nodes to the audio engine
    private func setupAudioEngine() {
        audioEngine.attach(musicPlayerNode)
        audioEngine.attach(sfxPlayerNode)

        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)

        // Connect the nodes to the mixer
        audioEngine.connect(musicPlayerNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.connect(sfxPlayerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
        
    private func playAudioChunk(audioData: Data, isSFX: Bool = false, volume: Float = 1.0) {
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false  // The mainMixerNode expects deinterleaved audio
        )!

        if !audioEngine.isRunning {
            setupAudioEngine()
        }

        let playerNode = isSFX ? sfxPlayerNode : musicPlayerNode

        let bytesPerSample = MemoryLayout<Int16>.size
        let frameCount = audioData.count / (bytesPerSample * Int(audioFormat.channelCount))

        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("Failed to create AVAudioPCMBuffer")
            return
        }
        audioBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Convert Int16 interleaved data to Float32 deinterleaved
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
                leftChannel[i] = Float(left) / Float(Int16.max) * volume
                rightChannel[i] = Float(right) / Float(Int16.max) * volume
            }
        }

        // Schedule the buffer for playback
        audioQueue.async {
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
            }
            if !playerNode.isPlaying {
                print("Starting playback")
                playerNode.play()
            }
        }
    }

}


#Preview {
    ContentView()
}
