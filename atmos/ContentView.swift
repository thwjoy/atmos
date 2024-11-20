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

class WebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var isStreaming = false
    private let audioProcessingQueue = DispatchQueue(label: "AudioProcessingQueue")
    private var accumulatedAudio = Data() // Accumulate audio chunks
    private var expectedAudioSize = 0     // Expected total size of the audio
    private var sampleRate = 44100        // Default sample rate, updated by header
    private let HEADER_SIZE = 13
    var onConnectionChange: ((Bool) -> Void)? // Called when connection status changes
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data) -> Void)? // Called for received audio
    var stopRecordingCallback: (() -> Void)?

    // Connect to the WebSocket server
    func connect(to url: URL) {
        disconnect() // Ensure any existing connection is closed
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        stopAudioStream()
        onConnectionChange?(false)
        stopRecordingCallback?()
    }

    // Start streaming audio
    func sendAudioStream() {
        guard !isStreaming else { return }
        isStreaming = true

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.audioProcessingQueue.async {
                if let audioData = self.convertPCMBufferToData(buffer: buffer) {
                    self.sendData(audioData)
                } else {
                    print("Failed to convert audio buffer to data")
                }
            }
        }
        
        do {
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // Stop streaming audio
    func stopAudioStream() {
        isStreaming = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    // Convert PCM buffer to data
    private func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        if let int16ChannelData = buffer.int16ChannelData {
            // Use Int16 data directly
            let channelData = int16ChannelData[0]
            let frameLength = Int(buffer.frameLength)
            return Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
        } else if let floatChannelData = buffer.floatChannelData {
            // Convert Float32 to Int16
            let channelData = Array(UnsafeBufferPointer(start: floatChannelData[0], count: Int(buffer.frameLength)))
            let int16Data = channelData.map { Int16($0 * Float(Int16.max)) }
            return Data(bytes: int16Data, count: int16Data.count * MemoryLayout<Int16>.size)
        } else {
            print("Unsupported audio format")
            return nil
        }
    }

    // Send binary data via WebSocket
    private func sendData(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
            }
        }
    }

    // Handle received messages
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.processReceivedData(data)
                case .string(let text):
                    self.onMessageReceived?(text)
                @unknown default:
                    print("Unknown WebSocket message type")
                }
            case .failure(let error):
                print("Failed to receive message: \(error.localizedDescription)")
            }

            // Continue listening for messages
            self.receiveMessages()
        }
    }
    
    private func extractUInt32(from data: Data, at range: Range<Data.Index>) -> UInt32 {
        let subdata = data.subdata(in: range) // Extract the range
        return subdata.withUnsafeBytes { $0.load(as: UInt32.self) } // Safely load UInt32
    }
    
    private let processingQueue = DispatchQueue(label: "com.websocket.audioProcessingQueue")
    
    private func parseWAVHeader(data: Data) -> (sampleRate: Int, channels: Int, bitsPerSample: Int)? {
        guard data.count >= 44 else {
            print("Invalid WAV file: Header too short")
            return nil
        }

        // Verify the "RIFF" chunk ID
        let chunkID = String(bytes: data[0..<4], encoding: .ascii)
        guard chunkID == "RIFF" else {
            print("Invalid WAV file: Missing RIFF header")
            return nil
        }

        // Verify the "WAVE" format
        let format = String(bytes: data[8..<12], encoding: .ascii)
        guard format == "WAVE" else {
            print("Invalid WAV file: Missing WAVE format")
            return nil
        }

        // Parse sample rate
        let sampleRate = data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

        // Parse number of channels
        let channels = data.subdata(in: 22..<24).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian

        // Parse bits per sample
        let bitsPerSample = data.subdata(in: 34..<36).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian

        return (sampleRate: Int(sampleRate), channels: Int(channels), bitsPerSample: Int(bitsPerSample))
    }

    private func processReceivedData(_ data: Data) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            if self.accumulatedAudio.isEmpty {
                // First chunk, parse the header
                if data.count >= self.HEADER_SIZE {
                    let headerData = data.prefix(self.HEADER_SIZE)
                    let indicator = String(bytes: headerData[0..<5], encoding: .utf8) ?? "UNKNOWN"
                    if indicator != "UNKNOWN" {
                        self.expectedAudioSize = Int(self.extractUInt32(from: headerData, at: 5..<9).bigEndian)
                        self.sampleRate = Int(self.extractUInt32(from: headerData, at: 9..<13).bigEndian)
                        print("Indicator: \(indicator), Expected Size: \(self.expectedAudioSize), Sample Rate: \(self.sampleRate)")

                        // Start accumulating audio data
                        
                        let wavHeaderData = data.subdata(in: self.HEADER_SIZE..<(44 + self.HEADER_SIZE))
                        if let wavInfo = self.parseWAVHeader(data: wavHeaderData) {
                            let sampleRate = Int(wavInfo.sampleRate)
                            let channels = wavInfo.channels
                            let bitsPerSample = wavInfo.bitsPerSample
                            
                            print("Parsed WAV Info: Sample Rate = \(sampleRate), Channels = \(channels), Bits Per Sample = \(bitsPerSample)")
                            
                            // Start accumulating data after the WAV header
                            self.accumulatedAudio.append(data.suffix(from: 44 + self.HEADER_SIZE))
                        }
                    } else {
                        print("Error: Invalid header")
                    }
                } else {
                    print("Error: Incomplete header")
                }
            } else {
                // Subsequent chunks
                self.accumulatedAudio.append(data)
                print("Accumulated \(self.accumulatedAudio.count) / \(self.expectedAudioSize) bytes")
            }

            let chunkSize = 2048 // Adjust as needed
            while self.accumulatedAudio.count >= chunkSize {
                let chunk = self.accumulatedAudio.prefix(chunkSize)
                self.accumulatedAudio.removeFirst(chunkSize)
                DispatchQueue.main.async {
                    self.onAudioReceived?(chunk)
                }
            }
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        onConnectionChange?(true) // Confirm the connection
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("Reason: \(reasonString)")
        }
        onConnectionChange?(false) // Confirm the disconnection
    }
}


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
    private let audioPlayerNode = AVAudioPlayerNode()
    private let audioQueue = DispatchQueue(label: "audio.queue")


    var body: some View {
        VStack(spacing: 20) {
            // Recording and Connection Status Indicators
            VStack {
                Text("Recording Status: \(isRecording ? "Recording" : "Idle")")
                    .font(.headline)
                    .foregroundColor(isRecording ? .green : .red)

                Text("Connection Status: \(connectionStatus)")
                    .font(.headline)
                    .foregroundColor(connectionStatus == "Connected" ? .green : .red)
            }

            // Start/Stop Recording Button
            Button(action: {
                if connectionStatus == "Connected" {
                    isRecording.toggle()
                    if isRecording {
                        webSocketManager.sendAudioStream()
                    } else {
                        webSocketManager.stopAudioStream()
                    }
                }
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
            }

            // Connect/Disconnect Button
            Button(action: {
                if connectionStatus == "Connected" {
                    webSocketManager.disconnect()
                    DispatchQueue.main.async {
                        stopAllAudio()      // Stop all audio
                    }
                } else {
                    if let url = URL(string: SERVER_URL) {
                        webSocketManager.connect(to: url)
                    }
                }
            }) {
                Text(connectionStatus == "Connected" ? "Disconnect" : "Connect")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(connectionStatus == "Connected" ? Color.red : Color.green)
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
            configureAudioSession()
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

            // Handle Received Audio
//            webSocketManager.onAudioReceived = { audioData in
//                DispatchQueue.main.async {
//                    self.playReceivedAudio(audioData: audioData)
//                }
//            }
            
            webSocketManager.stopRecordingCallback = {
                DispatchQueue.main.async {
                    isRecording = false
                }
            }
            
            setupAudioEngine()
            webSocketManager.onAudioReceived = { audioData in
                self.playAudioChunk(audioData: audioData)
            }
        }
        .onDisappear {
            // Disconnect WebSocket
            webSocketManager.disconnect()
            connectionStatus = "Disconnected"
        }
    }
    
    private func validateWAVFile(audioData: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.wav")
        do {
            try audioData.write(to: tempURL)

            var audioFile: AudioFileID?
            let status = AudioFileOpenURL(tempURL as CFURL, .readPermission, 0, &audioFile)
            guard status == noErr, let audioFile = audioFile else {
                print("Failed to open audio file: \(status)")
                return
            }

            var audioFormat = AudioStreamBasicDescription()
            var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            let result = AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propertySize, &audioFormat)
            if result == noErr {
                print("Audio format: \(audioFormat)")
                print("Sample rate: \(audioFormat.mSampleRate), Channels: \(audioFormat.mChannelsPerFrame)")
            } else {
                print("Failed to get audio format: \(result)")
            }

            AudioFileClose(audioFile)
        } catch {
            print("Error writing temp file: \(error.localizedDescription)")
        }
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
        
    private func playReceivedAudio(audioData: Data) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newPlayer = try AVAudioPlayer(data: audioData)
                newPlayer.prepareToPlay()

                // Add the player to the array to keep a reference
                DispatchQueue.main.async {
                    self.audioPlayers.append(newPlayer)
                    newPlayer.play()
                    print("Playing audio...")
                    
                    // Remove finished players
                    self.cleanupAudioPlayers()
                }
            } catch {
                print("Error playing audio: \(error.localizedDescription)")
            }
        }
    }

    // Clean up finished players
    private func cleanupAudioPlayers() {
        audioPlayers = audioPlayers.filter { $0.isPlaying }
    }
    
    private func stopAllAudio() {
        audioQueue.async {
            // Stop the player node
            if self.audioPlayerNode.isPlaying {
                self.audioPlayerNode.stop()
            }

            // Reset the node to clear any scheduled buffers
            self.audioPlayerNode.reset()

            // Optionally, stop the audio engine if it's no longer needed
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }

            print("All audio stopped")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: nil)

        do {
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func enqueueAudioChunk(_ audioData: Data) {
        audioBufferQueue.async {
            self.bufferPool.append(audioData)

            // Ensure we have enough data to play
            if self.bufferPool.count > 2 { // Example threshold
                let chunkToPlay = self.bufferPool.removeFirst()
                self.playAudioChunk(audioData: chunkToPlay)
            }
        }
    }
    
    private func playAudioChunk(audioData: Data, volume: Float = 1.0) {
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,  // The format required by mainMixerNode
            sampleRate: 44100,
            channels: 2,
            interleaved: false  // The mainMixerNode expects deinterleaved audio
        )!

        if !audioEngine.isRunning {
            setupAudioEngine()
        }

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
            self.audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
                print("Buffer finished playing")
            }
            if !self.audioPlayerNode.isPlaying {
                self.audioPlayerNode.play()
            }
        }
    }
}


#Preview {
    ContentView()
}
