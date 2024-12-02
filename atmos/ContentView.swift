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
var TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3MzM5OTg0NzQsImlhdCI6MTczMzEzNDQ3NCwiaXNzIjoieW91ci1hcHAtbmFtZSJ9.zixGVfYfQ5TckItrklCWunR5IOCF793gkQ9ciFsdLJA"

enum ConnectionState {
    case disconnected
    case connected
}

enum RecordingState {
    case idle
    case paused
    case recording
}

struct ContentView: View {
//    @State private var isRecording = false
//    @State private var transcriberID = ""
    @State private var connectionStatus: ConnectionState = .disconnected
    @State private var recordingStatus: RecordingState = .idle
    @State private var messages: [String] = []
    @State private var coAuthEnabled = false // Tracks the CO_AUTH state
    private let webSocketManager = WebSocketManager()
    private let audioProcessor = AudioProcessor()


    private var connectionColor: Color {
        switch connectionStatus {
        case .disconnected:
            return .red
        case .connected:
            switch recordingStatus {
            case .idle:
                return .orange
            case .paused:
                return .green
            case .recording:
                return .green
            }
        }
    }

    private var connectionStatusMessage: String {
        switch connectionStatus {
        case .disconnected:
            return "Tap the microphone to start"
        case .connected:
            switch recordingStatus {
            case .idle:
                return "Connected, I'm getting ready to listen"
            case .paused:
                return "Continue the story after I've finished talking"
            case .recording:
                return "I'm ready, start telling me your story!"
            }
        }
    }
    
    private func handleButtonAction() {
        if connectionStatus != .disconnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    private var connectionButton: String {
        switch connectionStatus {
        case .disconnected:
            return "mic.slash.fill"
        case .connected:
            switch recordingStatus {
            case .idle:
                return "mic.slash.fill"
            case .paused:
                return "mic.slash.fill"
            case .recording:
                return "mic.fill"
            }
        }
    }

    private func setup() {
        UIApplication.shared.isIdleTimerDisabled = true
        // Additional setup code
    }

    private func cleanup() {
        UIApplication.shared.isIdleTimerDisabled = false
        disconnect()
    }

    private func connect() {
        audioProcessor.configureRecordingSession()
        audioProcessor.setupAudioEngine()

        if let url = URL(string: SERVER_URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                webSocketManager.connect(to: url, token: TOKEN, coAuth: coAuthEnabled)
            }
        }
    }

    private func disconnect() {
        webSocketManager.disconnect()
        audioProcessor.stopAllAudio()
        connectionStatus = .disconnected
    }
    
    var body: some View {
        ZStack {
            Color(.systemPurple) // Use a predefined purple
                .opacity(1.0)    // Adjust the opacity for a lighter shade
                .edgesIgnoringSafeArea(.all) // Extend the background to the edges
            
            VStack(spacing: 20) {
                VStack {
                    
                    Text("\(connectionStatusMessage)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    if connectionStatus != ConnectionState.disconnected {
                        DispatchQueue.global(qos: .userInitiated).async {
                            webSocketManager.stopAudioStream()
                            webSocketManager.disconnect()
                            self.audioProcessor.stopAllAudio()
                        }
                    } else {
                        audioProcessor.configureRecordingSession()
                        audioProcessor.setupAudioEngine()
                        if let url = URL(string: SERVER_URL) {
                            DispatchQueue.global(qos: .userInitiated).async {
                                webSocketManager.connect(to: url, token: TOKEN, coAuth: coAuthEnabled)
                            }
                        }
                    }
                }) {
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
                        Image(systemName: connectionButton)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180) // Adjust size as needed
                            .foregroundColor(connectionColor)
                    }
                }
                
                // Toggle button for CO_AUTH
                Toggle(isOn: $coAuthEnabled) {
                    Text("Make a story together")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .cornerRadius(10)
                
            }
            .padding()
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from turning off
                audioProcessor.logMessage = { message in
                    DispatchQueue.global(qos: .userInitiated).async {
                        logMessage(message)
                    }
                }
                audioProcessor.onStoryStateChange = { isPlaying in
                    if isPlaying {
                        logMessage("Stopping Recording for User")
                        webSocketManager.stopAudioStream() // Stop recording
                    } else {
                        webSocketManager.sendAudioStream() // Resume recording
                        logMessage("Starting Recording for User")
                    }
                }
                webSocketManager.onConnectionChange = { status in
                    DispatchQueue.main.async {
                        connectionStatus = status
                    }
                }
                webSocketManager.onStreamingChange = { streaming in
                    DispatchQueue.main.async {
                        recordingStatus = streaming
                    }
                }
                webSocketManager.onAudioReceived = { data, indicator, sampleRate in
                    audioProcessor.playAudioChunk(audioData: data, indicator: indicator, sampleRate: sampleRate)
                }
                webSocketManager.logMessage = { message in
                    logMessage(message)
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
                webSocketManager.stopAudioStream()
                webSocketManager.disconnect()
                audioProcessor.stopAllAudio()
                connectionStatus = ConnectionState.disconnected
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
//    private let musicPlayerNode = AVAudioPlayerNode()
//    private let sfxPlayerNode = AVAudioPlayerNode()
//    private let storyPlayerNode = AVAudioPlayer()
    let playerNodes: [String: AVAudioPlayerNode] = [
        "MUSIC": AVAudioPlayerNode(),
        "SFX": AVAudioPlayerNode(),
        "STORY": AVAudioPlayerNode()
    ]
    private let audioQueue = DispatchQueue(label: "com.audioprocessor.queue")
    private var playbackTimer: Timer?
    private(set) var isStoryPlaying = false {
        didSet {
            onStoryStateChange?(isStoryPlaying)
        }
    }
    var onStoryStateChange: ((Bool) -> Void)? // Callback for STORY state changes


    
    var logMessage: ((String) -> Void)?

    /// Configure the recording session for playback and recording.
    func configureRecordingSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            self.logMessage?("Audio session configured for playback")
        } catch {
            self.logMessage?("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
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
    
    func startMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            logMessage?("STORY player node not found")
            return
        }

        let tapFormat = storyNode.outputFormat(forBus: 0)
        storyNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }

            let isBufferActive = self.isAudioBufferActive(buffer)
            if isBufferActive != self.isStoryPlaying {
                self.isStoryPlaying = isBufferActive
                DispatchQueue.main.async {
                    self.onStoryStateChange?(isBufferActive)
                }
            }
        }

        logMessage?("Tap installed on STORY player node")
    }

    
    func stopMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            logMessage?("STORY player node not found")
            return
        }

        storyNode.removeTap(onBus: 0)
        isStoryPlaying = false // Ensure state is reset
        DispatchQueue.main.async {
            self.onStoryStateChange?(false) // Notify that playback has stopped
        }

        logMessage?("Tap removed from STORY player node")
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

            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }
            self.stopMonitoringStoryPlayback()
            self.logMessage?("All audio stopped")
        }
    }

    /// Set up the audio engine and attach player nodes.
    func setupAudioEngine(sampleRate: Double = 44100) {
        audioQueue.async { // Ensure proper initialization
            // Define the desired audio format for the engine
            let mainMixerFormat = self.audioEngine.mainMixerNode.outputFormat(forBus: 0)
            let desiredFormat = AVAudioFormat(
                commonFormat: mainMixerFormat.commonFormat,
                sampleRate: sampleRate,
                channels: mainMixerFormat.channelCount,
                interleaved: mainMixerFormat.isInterleaved
            )

            // Loop through the player nodes and connect them to the mixer
            for (_, playerNode) in self.playerNodes {
                self.audioEngine.attach(playerNode)
                self.audioEngine.connect(playerNode, to: self.audioEngine.mainMixerNode, format: desiredFormat)
            }

            // Connect the main mixer to the output node
            self.audioEngine.disconnectNodeOutput(self.audioEngine.mainMixerNode)
            self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: desiredFormat)

            do {
                // Start the engine with the desired configuration
                try self.audioEngine.start()
                self.logMessage?("Audio engine started with sample rate: \(sampleRate)")
            } catch {
                self.logMessage?("Error starting audio engine: \(error.localizedDescription)")
            }
            self.startMonitoringStoryPlayback()
        }
    }


    /// Play a chunk of audio data.
    func playAudioChunk(audioData: Data, indicator: String, volume: Float = 1.0, sampleRate: Double = 44100) {
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
        
        if let playerNode = playerNodes[indicator] {
            if !audioEngine.isRunning {
                setupAudioEngine()
            }
            
            audioQueue.async {
                let bytesPerSample = MemoryLayout<Int16>.size
                let frameCount = audioData.count / (bytesPerSample * Int(audioFormat.channelCount))
                
                // Create the source buffer
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                    self.logMessage?("Failed to create AVAudioPCMBuffer")
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
                            self.logMessage?("Failed to get left channel data")
                            return
                        }
                        
                        // Mono: Duplicate the data into both left and right channels
                        for i in 0..<frameCount {
                            let sample = int16Samples[i]
                            leftChannel[i] = Float(sample) / Float(Int16.max) * volume * 2
                        }
                        if let rightChannel = audioBuffer.floatChannelData?[1] {
                            memcpy(rightChannel, leftChannel, frameCount * MemoryLayout<Float>.size)
                        }
                    }

                    // Initialize the converter
                    guard let converter = AVAudioConverter(from: audioFormat, to: destinationFormat) else {
                        self.logMessage?("Failed to create AVAudioConverter")
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
                        self.logMessage?("Failed to create destination buffer")
                        return
                    }

                    // Perform the conversion
                    var error: NSError?
                    converter.convert(to: destinationBuffer, error: &error) { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return audioBuffer
                    }

                    if let error = error {
                        self.logMessage?("Error during conversion: \(error)")
                        return
                    }
                    
//                    self.logMessage?("Source sample rate: \(audioFormat.sampleRate)")
//                    self.logMessage?("Destination sample rate: \(destinationFormat.sampleRate)")
//                    let sourceDuration = Double(audioBuffer.frameLength) / audioFormat.sampleRate
//                    let destinationDuration = Double(destinationBuffer.frameLength) / destinationFormat.sampleRate
//                    self.logMessage?("Source buffer duration: \(sourceDuration)s")
//                    self.logMessage?("Destination buffer duration: \(destinationDuration)s")

                    // Verify buffer lengths
//                    self.logMessage?("Source buffer frame length: \(audioBuffer.frameLength)")
//                    self.logMessage?("Destination buffer frame length: \(destinationBuffer.frameLength)")

                    // Schedule the buffer for playback
                    playerNode.scheduleBuffer(destinationBuffer, at: nil, options: []) {
//                        self.logMessage?("Playback completed")
                    }
                    
                    // Schedule the buffer with explicit timing
                    let startTime = AVAudioTime(sampleTime: 0, atRate: destinationFormat.sampleRate)
                    playerNode.scheduleBuffer(destinationBuffer, at: startTime, options: []) {
                    }
                    
//                    // Pause recording
//                    if indicator == "STORY" {
//                        let isActive = self.isAudioBufferActive(destinationBuffer)
//                        if isActive != self.isStoryPlaying {
//                            self.isStoryPlaying = isActive
//                            DispatchQueue.main.async {
//                                self.onStoryStateChange?(isActive) // Notify state change
//                            }
//                        }
//                    }
                    
                } else {
                    // Handle non-STORY indicators (no conversion required)
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
                }
                
                // Start playback if the player is not already playing
                if !playerNode.isPlaying {
//                    self.logMessage?("Starting playback")
                    playerNode.play()
                }
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
    struct AudioSequence {
        var indicator: String       // Indicator (e.g., "MUSIC" or "SFX")
        var accumulatedData: Data  // Accumulated audio data
        var packetsReceived: Int    // Number of packets received
        var sampleRate: Double
    }
    private var accumulatedAudio: [UUID: AudioSequence] = [:]
    private var expectedAudioSize = 0     // Expected total size of the audio
//    private var sampleRate = 44100        // Default sample rate, updated by header
    private let HEADER_SIZE = 37
    private var sessionID: String? = nil
    private let maxAudioSize = 50 * 1024 * 1024 // 50MB in bytes

    var onConnectionChange: ((ConnectionState) -> Void)? // Called when connection status changes
    var onStreamingChange: ((RecordingState) -> Void)? // Called when streaming status changes
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data, String, Double) -> Void)? // Called for received audio
    var stopRecordingCallback: (() -> Void)?
    var logMessage: ((String) -> Void)?

    // Connect to the WebSocket server
    func connect(to url: URL, token: String, coAuth: Bool) {
        disconnect() // Ensure any existing connection is closed

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(coAuth ? "True" : "False", forHTTPHeaderField: "CO-AUTH")

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
            self.accumulatedAudio = [:]
            self.logMessage?("Accumulated audio buffer cleared")
        }
    }

    // Start streaming audio
    func sendAudioStream() {
        guard !isStreaming else { return }
        isStreaming = true
        DispatchQueue.main.async { [weak self] in
            self?.onStreamingChange?(RecordingState.recording)
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
    
    func processSessionUpdate(sessionID: String?) {
        if let uuidString = sessionID, UUID(uuidString: uuidString) != nil {
            // sessionID is a valid UUID
            DispatchQueue.main.async { [weak self] in
                self?.onStreamingChange?(.paused)
            }
        } else {
            // sessionID is not valid
            DispatchQueue.main.async { [weak self] in
                self?.onStreamingChange?(.idle)
            }
        }
    }

    // Stop streaming audio
    func stopAudioStream() {
        isStreaming = false
        DispatchQueue.main.async { [weak self] in
            self?.processSessionUpdate(sessionID: self?.sessionID)
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
            let int16Data = channelData.map { sample in
                let scaledSample = sample * Float(Int16.max)
                return Int16(max(Float(Int16.min), min(Float(Int16.max), scaledSample)))
            }
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
            
            // Ensure we have enough data for the header
            guard data.count >= self.HEADER_SIZE else {
                self.logMessage?("Error: Incomplete header")
                return
            }
            
            // Parse the header
            let headerData = data.prefix(self.HEADER_SIZE)
            let indicator = String(bytes: headerData[0..<5], encoding: .utf8)?.trimmingCharacters(in: .whitespaces) ?? "UNKNOWN"
            let packetSize = Int(self.extractUInt32(from: headerData, at: 5..<9).bigEndian)
            let sequenceID = UUID(uuid: (headerData[9..<25] as NSData).bytes.assumingMemoryBound(to: uuid_t.self).pointee)
            let packetCount = Int(self.extractUInt32(from: headerData, at: 25..<29).bigEndian)
            let totalPackets = Int(self.extractUInt32(from: headerData, at: 29..<33).bigEndian)
            let sampleRate = Double(self.extractUInt32(from: headerData, at: 33..<37).bigEndian)
            
            self.logMessage?("Indicator: \(indicator), Sequence ID: \(sequenceID), Packet: \(packetCount)/\(totalPackets), Sample Rate: \(sampleRate), Packet Size: \(packetSize)")
            
            // Process based on the indicator
            if self.accumulatedAudio[sequenceID] == nil {
                // First packet for this sequence
                self.accumulatedAudio[sequenceID] = AudioSequence(
                    indicator: indicator,
                    accumulatedData: Data(),
                    packetsReceived: 0,
                    sampleRate: sampleRate
                )
            }
            
            // Update the existing entry
            if var sequence = self.accumulatedAudio[sequenceID] {
                sequence.accumulatedData.append(data.suffix(from: self.HEADER_SIZE))
                sequence.packetsReceived += 1
                self.accumulatedAudio[sequenceID] = sequence
                self.logMessage?("Updated Sequence \(sequenceID): Packets Received = \(sequence.packetsReceived)")
                let chunkSize = 2048 // Adjust as needed
                while sequence.accumulatedData.count >= chunkSize {
                    let chunk = sequence.accumulatedData.prefix(chunkSize)
                    sequence.accumulatedData.removeFirst(chunkSize)
                    // Reassign the modified value back to the dictionary
                    self.accumulatedAudio[sequenceID] = sequence
                    DispatchQueue.main.async {
                        self.onAudioReceived?(chunk, sequence.indicator, sequence.sampleRate)
                    }
                }
                if sequence.packetsReceived == totalPackets  {
                    self.logMessage?("Received complete sequence for \(sequence.indicator) with ID \(sequenceID)")
                    self.accumulatedAudio.removeValue(forKey: sequenceID)
                }
            }
            
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.logMessage?("WebSocket connected")
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(ConnectionState.connected)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.logMessage?("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            self.logMessage?("Reason: \(reasonString)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(ConnectionState.disconnected)
        }
        
    }
}



#Preview {
    ContentView()
}
