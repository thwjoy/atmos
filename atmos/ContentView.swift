//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation
import Foundation

var SERVER_URL = "wss://myatmos.pro/ws"
var TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3MzMwNjg5NzksImlhdCI6MTczMjIwNDk3OSwiaXNzIjoieW91ci1hcHAtbmFtZSJ9.irNjsFJSjdxWqfRZqHclf4Pb78-hNIYTr9PRuZJYtQ8"

struct ContentView: View {
    @State private var isRecording = false
    @State private var transcriberID = ""
    @State private var connectionStatus = "Disconnected"
    @State private var messages: [String] = []
    private let webSocketManager = WebSocketManager()
    private let audioProcessor = AudioProcessor()

    private var recordingStatus: String {
        if connectionStatus == "Connected" {
            return isRecording ? "Recording" : "Connecting..."
        }
        return "Idle"
    }

    private var connectionColor: Color {
        connectionStatus == "Connected" ? (isRecording ? .green : .orange) : .red
    }
    
    private var messageStatus: String {
        if connectionStatus == "Disconnected" {
            return "Tap the microphone to start"
        } else if !isRecording {
            return "Hold tight, we're connecting..."
        } else if connectionStatus == "Connected" {
            return "Connected, start telling me your story!"
        } else {
            return ""
        }
    }
    
    
    var body: some View {
        ZStack {
            Color(.systemPurple) // Use a predefined purple
                .opacity(1.0)    // Adjust the opacity for a lighter shade
                .edgesIgnoringSafeArea(.all) // Extend the background to the edges
            
            VStack(spacing: 20) {
                VStack {
                    //                Text("Recording Status: \(recordingStatus)")
                    //                    .font(.headline)
                    //                    .foregroundColor(connectionStatus == "Connected" ? (isRecording ? .green : .orange) : .red)
                    //
                    //                Text("Connection Status: \(connectionStatus)")
                    //                    .font(.headline)
                    //                    .foregroundColor(connectionColor)
                    
                    Text("\(messageStatus)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    if connectionStatus == "Connected" {
                        DispatchQueue.global(qos: .userInitiated).async {
                            webSocketManager.stopAudioStream()
                            webSocketManager.disconnect()
                            self.audioProcessor.stopAllAudio()
                        }
                    } else {
                        if let url = URL(string: SERVER_URL) {
                            DispatchQueue.global(qos: .userInitiated).async {
                                webSocketManager.connect(to: url, token: TOKEN)
                            }
                        }
                    }
                }) {
                    //                Text(connectionStatus == "Connected" ? "Disconnect" : "Connect")
                    //                    .font(.title)
                    //                    .foregroundColor(.white)
                    //                    .padding()
                    //                    .background(connectionStatus == "Connected" ? Color.red : Color.green)
                    //                    .cornerRadius(10)
                    ZStack {
                        // Grey transparent disk with blurred edges
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(1.0), // Transparent grey at center
                                        Color.white.opacity(0.3) // Fades to almost transparent
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 250 // Adjust for desired size
                                )
                            )
                            .frame(width: 250, height: 250) // Adjust disk size
                            .blur(radius: 25) // Adds a soft blur effect

                        // Microphone icon
                        Image(systemName: connectionStatus == "Connected" ? "mic.fill" : "mic.slash.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180) // Adjust size as needed
                            .foregroundColor(connectionColor)
                    }
                }
                
                //            VStack(alignment: .leading) {
                //                Text("Messages Log")
                //                    .font(.headline)
                //                    .padding(.bottom, 5)
                //
                //                ScrollView {
                //                    ForEach(messages.indices, id: \.self) { index in
                //                        let message = messages[index]
                //                        Text(message)
                //                            .padding(.vertical, 5)
                //                            .frame(maxWidth: .infinity, alignment: .leading)
                //                            .background(Color.gray.opacity(0.2))
                //                            .cornerRadius(5)
                //                    }
                //                }
                //            }
            }
            .padding()
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from turning off
                audioProcessor.configureRecordingSession()
                audioProcessor.setupAudioEngine()
                audioProcessor.logMessage = { message in
                    DispatchQueue.global(qos: .userInitiated).async {
                        logMessage(message)
                    }
                }
                webSocketManager.onConnectionChange = { status in
                    DispatchQueue.main.async {
                        connectionStatus = status ? "Connected" : "Disconnected"
                    }
                }
                webSocketManager.onStreamingChange = { streaming in
                    DispatchQueue.main.async {
                        isRecording = streaming
                    }
                }
                webSocketManager.onAudioReceived = { data, isSFX in
                    audioProcessor.playAudioChunk(audioData: data, isSFX: isSFX)
                }
                webSocketManager.logMessage = { message in
                    logMessage(message)
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
                webSocketManager.disconnect()
                connectionStatus = "Disconnected"
                webSocketManager.onConnectionChange = nil
                webSocketManager.onStreamingChange = nil
                webSocketManager.onAudioReceived = nil
                webSocketManager.logMessage = nil
            }
        }
    }
    
    private func logMessage(_ message: String) {
        DispatchQueue.main.async {
            print(message)
            messages.append(message)
        }
    }
}


class AudioProcessor {
    private let audioEngine = AVAudioEngine()
    private let musicPlayerNode = AVAudioPlayerNode()
    private let sfxPlayerNode = AVAudioPlayerNode()
    private let audioQueue = DispatchQueue(label: "com.audioprocessor.queue")
    
    var logMessage: ((String) -> Void)?

    /// Configure the recording session for playback and recording.
    func configureRecordingSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            self.logMessage?("Audio session configured for playback")
        } catch {
            self.logMessage?("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    /// Stop all audio playback.
    func stopAllAudio() {
        audioQueue.async {
            if self.musicPlayerNode.isPlaying {
                self.musicPlayerNode.stop()
            }
            self.musicPlayerNode.reset()

            if self.sfxPlayerNode.isPlaying {
                self.sfxPlayerNode.stop()
            }
            self.sfxPlayerNode.reset()

            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }

            self.logMessage?("All audio stopped")
        }
    }

    /// Set up the audio engine and attach player nodes.
    func setupAudioEngine() {
        audioQueue.async { // Use sync to ensure proper initialization before proceeding
            self.audioEngine.attach(self.musicPlayerNode)
            self.audioEngine.attach(self.sfxPlayerNode)

            let format = self.audioEngine.mainMixerNode.outputFormat(forBus: 0)
            self.audioEngine.connect(self.musicPlayerNode, to: self.audioEngine.mainMixerNode, format: format)
            self.audioEngine.connect(self.sfxPlayerNode, to: self.audioEngine.mainMixerNode, format: format)

            do {
                try self.audioEngine.start()
                self.logMessage?("Audio engine started")
            } catch {
                self.logMessage?("Error starting audio engine: \(error)")
            }
        }
    }


    /// Play a chunk of audio data.
    func playAudioChunk(audioData: Data, isSFX: Bool = false, volume: Float = 1.0) {
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 2,
            interleaved: false
        )!
        
        let playerNode = isSFX ? sfxPlayerNode : musicPlayerNode
        
        if !audioEngine.isRunning {
            setupAudioEngine()
        }
        
        audioQueue.async {
            let bytesPerSample = MemoryLayout<Int16>.size
            let frameCount = audioData.count / (bytesPerSample * Int(audioFormat.channelCount))

            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                self.logMessage?("Failed to create AVAudioPCMBuffer")
                return
            }
            audioBuffer.frameLength = AVAudioFrameCount(frameCount)

            // Convert Int16 interleaved data to Float32 deinterleaved
            audioData.withUnsafeBytes { bufferPointer in
                let int16Samples = bufferPointer.bindMemory(to: Int16.self)
                guard let leftChannel = audioBuffer.floatChannelData?[0],
                      let rightChannel = audioBuffer.floatChannelData?[1] else {
                    self.logMessage?("Failed to get channel data")
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
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {}
            if !playerNode.isPlaying {
                self.logMessage?("Starting playback")
                playerNode.play()
            }
        }
    }
}


class WebSocketManager: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private var isStreaming = false
    private let playQueue = DispatchQueue(label: "com.websocket.playQueue")
    private let recieveQueue = DispatchQueue(label: "com.websocket.recieveQueue")
    private var accumulatedAudio = Data() // Accumulate audio chunks
    private var expectedAudioSize = 0     // Expected total size of the audio
    private var sampleRate = 44100        // Default sample rate, updated by header
    private let HEADER_SIZE = 13
    private var sessionID: String? = nil
    private let maxAudioSize = 50 * 1024 * 1024 // 50MB in bytes

    var onConnectionChange: ((Bool) -> Void)? // Called when connection status changes
    var onStreamingChange: ((Bool) -> Void)? // Called when streaming status changes
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data, Bool) -> Void)? // Called for received audio
    var stopRecordingCallback: (() -> Void)?
    var logMessage: ((String) -> Void)?

    // Connect to the WebSocket server
    func connect(to url: URL, token: String) {
        disconnect() // Ensure any existing connection is closed

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: "Client closing connection".data(using: .utf8))
        webSocketTask = nil
        stopAudioStream()
        stopRecordingCallback?()
        // Clear the accumulatedAudio buffer
        self.recieveQueue.async {
            self.accumulatedAudio = Data()
            self.logMessage?("Accumulated audio buffer cleared")
        }
    }

    // Start streaming audio
    func sendAudioStream() {
        guard !isStreaming else { return }
        isStreaming = true
        DispatchQueue.main.async { [weak self] in
            self?.onStreamingChange?(true)
        }
        self.logMessage?("Streaming Audio")
        
        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.playQueue.async {
                if let audioData = self.convertPCMBufferToData(buffer: buffer) {
                    self.sendData(audioData)
                } else {
                    self.logMessage?("Failed to convert audio buffer to data")
                }
            }
        }
        
        do {
            try audioEngine.start()
            self.logMessage?("Audio engine started")
        } catch {
            self.logMessage?("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // Stop streaming audio
    func stopAudioStream() {
        isStreaming = false
        sessionID = nil
        DispatchQueue.main.async { [weak self] in
            self?.onStreamingChange?(false)
        }
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
            self.logMessage?("Unsupported audio format")
            return nil
        }
    }

    // Send binary data via WebSocket
    private func sendData(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                self.logMessage?("Failed to send data: \(error.localizedDescription)")
            }
        }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.processReceivedData(data)
                case .string(let text):
                    self.processRecievedMessage(text: text)
                @unknown default:
                    self.logMessage?("Unknown WebSocket message type")
                }

                // Continue listening for messages
                self.receiveMessages()

            case .failure(let error):
                self.logMessage?("Failed to receive message: \(error.localizedDescription)")

                // Stop recursion and handle disconnect
                self.disconnect()
            }
        }
    }
    
    private func processRecievedMessage(text: String) {
        DispatchQueue.main.async {
            // here we need to check that streaming is enabled
            if UUID(uuidString: text) != nil {
                self.sessionID = text
                self.sendAudioStream()
            }
            self.logMessage?(text)
        }
    }
    
    private func extractUInt32(from data: Data, at range: Range<Data.Index>) -> UInt32 {
        let subdata = data.subdata(in: range) // Extract the range
        return subdata.withUnsafeBytes { $0.load(as: UInt32.self) } // Safely load UInt32
    }
    
    private func parseWAVHeader(data: Data) -> (sampleRate: Int, channels: Int, bitsPerSample: Int)? {
        guard data.count >= 44 else {
            self.logMessage?("Invalid WAV file: Header too short")
            return nil
        }

        // Verify the "RIFF" chunk ID
        let chunkID = String(bytes: data[0..<4], encoding: .ascii)
        guard chunkID == "RIFF" else {
            self.logMessage?("Invalid WAV file: Missing RIFF header")
            return nil
        }

        // Verify the "WAVE" format
        let format = String(bytes: data[8..<12], encoding: .ascii)
        guard format == "WAVE" else {
            self.logMessage?("Invalid WAV file: Missing WAVE format")
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
        recieveQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if this chunk is SFX (always check first)
            if data.count >= self.HEADER_SIZE {
                let headerData = data.prefix(self.HEADER_SIZE)
                let indicator = String(bytes: headerData[0..<5], encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? "UNKNOWN"
                if indicator == "SFX" {
                    // Sound effect (SFX), play immediately
                    self.logMessage?("Recieved SFX")
                    let sfxData = data.suffix(from: self.HEADER_SIZE + 44)
                    DispatchQueue.main.async {
                        self.onAudioReceived?(sfxData, true)
                    }
                    return // Stop further processing for this chunk
                }
            }

            // Handle background music
            if self.accumulatedAudio.isEmpty {
                // First chunk of background music
                if data.count >= self.HEADER_SIZE {
                    let headerData = data.prefix(self.HEADER_SIZE)
                    let indicator = String(bytes: headerData[0..<5], encoding: .utf8) ?? "UNKNOWN"

                    if indicator == "MUSIC" {
                        // Parse header and start accumulating audio
                        self.expectedAudioSize = Int(self.extractUInt32(from: headerData, at: 5..<9).bigEndian)
                        self.sampleRate = Int(self.extractUInt32(from: headerData, at: 9..<13).bigEndian)
                        self.logMessage?("Indicator: \(indicator), Expected Size: \(self.expectedAudioSize), Sample Rate: \(self.sampleRate)")

                        // Parse WAV header
                        let wavHeaderData = data.subdata(in: self.HEADER_SIZE..<(44 + self.HEADER_SIZE))
                        if let wavInfo = self.parseWAVHeader(data: wavHeaderData) {
                            let sampleRate = Int(wavInfo.sampleRate)
                            let channels = wavInfo.channels
                            let bitsPerSample = wavInfo.bitsPerSample

                            self.logMessage?("Parsed WAV Info: Sample Rate = \(sampleRate), Channels = \(channels), Bits Per Sample = \(bitsPerSample)")

                            // Start accumulating data after the WAV header
                            self.accumulatedAudio.append(data.suffix(from: 44 + self.HEADER_SIZE))
                        }
                    } else {
                        self.logMessage?("Error: Unknown audio type in header")
                    }
                } else {
                    self.logMessage?("Error: Incomplete header")
                }
            } else {
                // Subsequent chunks for background music
                self.accumulatedAudio.append(data)
                if self.accumulatedAudio.count > maxAudioSize {
                    print("Warning: Accumulated audio exceeds 50MB!")
                    // Retain only the last 50MB of data
                    let excessSize = self.accumulatedAudio.count - maxAudioSize
                    self.accumulatedAudio.removeFirst(excessSize)
                    self.logMessage?("Removed \(excessSize) bytes of accumulated audio to manage memory.")
                }
                
                // Process accumulated audio in chunks
                let chunkSize = 2048 // Adjust as needed
                while self.accumulatedAudio.count >= chunkSize {
                    let chunk = self.accumulatedAudio.prefix(chunkSize)
                    self.accumulatedAudio.removeFirst(chunkSize)
                    DispatchQueue.main.async {
                        self.onAudioReceived?(chunk, false)
                    }
                }
            }
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.logMessage?("WebSocket connected")
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(true)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.logMessage?("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            self.logMessage?("Reason: \(reasonString)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(false)
        }
        
    }
}



#Preview {
    ContentView()
}
