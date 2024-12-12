//
//  ContentView.swift
//  atmos
//
//  Created by Tom Joy on 17/10/2024.
//

import SwiftUI
import AVFoundation
import Foundation
import Combine

var SERVER_URL = "wss://myatmos.pro/ws"
var TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE3MzY0MjUwOTcsImlhdCI6MTczMzgzMzA5NywiaXNzIjoieW91ci1hcHAtbmFtZSJ9.eYiFnpSF0YHbjvstR0VfFCZpauF5wKhZvrOW613SPuM"

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

enum RecordingState {
    case idle
    case paused
    case recording
}

struct ContentView: View {
    @State private var isUserNameSet = UserDefaults.standard.string(forKey: "userName") != nil

//    init() {
//        UserDefaults.standard.removeObject(forKey: "userName")
//        print("Username has been cleared for debugging.")
//    }
    
    var body: some View {
        Group {
            if isUserNameSet {
                // Main content of the app
                MainView()
            } else {
                // Show text entry screen
                TextEntryView(isUserNameSet: $isUserNameSet)
            }
        }
    }
}

struct TextEntryView: View {
    @State private var inputText: String = ""
    @Binding var isUserNameSet: Bool

    var body: some View {
        ZStack {
            // Set the background image
            Image("Spark_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea() // Ensures the image fills the screen
                .opacity(0.5) // Adjust the opacity level here
            
            VStack(spacing: 20) {
                Text("Enter your email to proceed")
                    .font(.headline)
                
                TextField("Enter your email...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    if !inputText.isEmpty {
                        // Save the username to UserDefaults
                        UserDefaults.standard.set(inputText, forKey: "userName")
                        // Update state to show main content
                        isUserNameSet = true
                    }
                }) {
                    Text("Save and Continue")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(inputText.isEmpty) // Disable button if text is empty
                .padding(.horizontal)
            }
            .padding()
            
        }
    }
}

struct MainView: View {
    @State private var connectionStatus: ConnectionState = .disconnected
    @State private var recordingStatus: RecordingState = .idle
    @State private var messages: [String] = []
    @State private var coAuthEnabled = true // Tracks the CO_AUTH state
    @State private var SFXEnabled = true // Tracks the CO_AUTH state
    @State private var musicEnabled = true // Tracks the CO_AUTH state
    @StateObject private var audioProcessor = AudioProcessor()
    @StateObject private var webSocketManager: WebSocketManager

    init() {
        // Initialize webSocketManager with audioProcessor
        _webSocketManager = StateObject(wrappedValue: WebSocketManager(audioProcessor: AudioProcessor()))
    }


    private var connectionColor: Color {
        switch connectionStatus {
        case .disconnected:
            return .red
        case .connecting:
            return .orange // Use yellow or any color to represent connecting state
        case .connected:
            switch recordingStatus {
            case .idle:
                return .yellow
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
        case .connecting:
            return "Connecting, please wait..."
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
        case .connecting:
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
        connectionStatus = .connecting
        if let url = URL(string: SERVER_URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                webSocketManager.connect(to: url, token: TOKEN,
                                         coAuthEnabled: coAuthEnabled,
                                         musicEnabled: musicEnabled,
                                         SFXEnabled: SFXEnabled)
            }
        }
    }

    private func disconnect() {
        DispatchQueue.global(qos: .userInitiated).async {
            webSocketManager.disconnect()
        }
    }
    
    var body: some View {
        ZStack {
//            Color(.systemPurple) // Use a predefined purple
//                .opacity(1.0)    // Adjust the opacity for a lighter shade
//                .edgesIgnoringSafeArea(.all) // Extend the background to the edges
            
            // Set the background image
            Image("Spark_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea() // Ensures the image fills the screen
                .opacity(0.5) // Adjust the opacity level here
            
            // Internal view with opacity
            VStack(spacing: 20) {
                // Toggle buttons at the top
                Toggle(isOn: $SFXEnabled) {
                    Text("Read aloud, and I'll add sounds")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .onChange(of: SFXEnabled) { _, _ in
                    if connectionStatus == .connected {
                        disconnect()
                    }
                }
                .padding(30)
                .cornerRadius(10)

                Toggle(isOn: $musicEnabled) {
                    Text("How about some music?")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .onChange(of: musicEnabled) { _, _ in
                    if connectionStatus == .connected {
                        disconnect()
                    }
                }
                .padding(30)
                .cornerRadius(10)

                Toggle(isOn: $coAuthEnabled) {
                    Text("Shall we make a story together?")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .onChange(of: coAuthEnabled) { _, _ in
                    if connectionStatus == .connected {
                        disconnect()
                    }
                }
                .padding(30)
                .cornerRadius(10)
                
                

                // Spacer to push content down
                Spacer()

                // Connection status message at the bottom
                VStack {
                    Text("\(connectionStatusMessage)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Button vertically centered
                Button(action: {
                    if connectionStatus != ConnectionState.disconnected {
                        disconnect()
                    } else {
                        connect()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(1.0), // Lighter center
                                        Color.orange.opacity(0.8)  // Light gray outer edge
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 250 // Adjust for desired size
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.yellow.opacity(0.8), Color.orange, Color.yellow]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 5
                                    )
                            )
                            .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 5, y: 5) // Outer shadow
                            .shadow(color: Color.yellow.opacity(0.9), radius: 10, x: -5, y: -5) // Inner highlight
                            .frame(width: 200, height: 200) // Adjust disk size

                        Image(systemName: connectionButton)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120) // Adjust size as needed
                            .foregroundColor(connectionColor)
                    }
                }

                // Spacer to push content up
                Spacer()
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
                        DispatchQueue.main.async {
                            recordingStatus = .paused
                        }
                    } else if connectionStatus == .connected {
                        webSocketManager.sendAudioStream() // Resume recording
                        logMessage("Starting Recording for User")
                    }
                }
                webSocketManager.onConnectionChange = { status in
                    DispatchQueue.main.async {
                        connectionStatus = status
                        switch status {
                        case .connected:
                            self.audioProcessor.configureRecordingSession()
                            self.audioProcessor.setupAudioEngine()
                        case .connecting:
                            break
                        case .disconnected:
                            self.audioProcessor.stopAllAudio()
                        }
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
                disconnect()
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


class AudioProcessor: ObservableObject {
    private let audioEngine = AVAudioEngine()
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
            // Set category to PlayAndRecord to allow input and output
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            // Set the preferred input to the built-in microphone
            if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try audioSession.setPreferredInput(builtInMic)
                print("Preferred input set to: \(builtInMic.portName)")
            }
            // Activate the audio session
            try audioSession.setActive(true)
            self.logMessage?("Audio session configured for playback")
        } catch {
            self.logMessage?("Failed to configure audio session: \(error.localizedDescription)")
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
                self.logMessage?("Audio engine started with sample rate: \(sampleRate)")
            } catch {
                self.logMessage?("Error starting audio engine: \(error.localizedDescription)")
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

    /// User is speaking, no need to monitor
    func stopMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            logMessage?("STORY player node not found")
            return
        }

        if storyNode.engine != nil {
            storyNode.removeTap(onBus: 0)
        } else {
            logMessage?("Attempted to remove tap on a node that is not attached to an engine.")
        }
        isStoryPlaying = false // Ensure state is reset
        DispatchQueue.main.async {
            self.onStoryStateChange?(false) // Notify that playback has stopped
        }

        logMessage?("Tap removed from STORY player node")
    }

    /// Configure a tap on the input node to capture audio buffers.
    func configureInputTap(bufferSize: AVAudioFrameCount = 1024, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        let inputNode = audioEngine.inputNode
        let format = audioEngine.inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0) // Remove existing tap if any
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            onBuffer(buffer)
        }
        logMessage?("Input tap installed with bufferSize: \(bufferSize)")
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
            self.logMessage?("Unsupported audio format")
            return nil
        }
    }
    
    /// Start the audio engine.
    func startAudioEngine() {
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                logMessage?("Audio engine started")
            } catch {
                logMessage?("Failed to start audio engine: \(error.localizedDescription)")
            }
        }
    }

    /// Stop the audio engine and remove taps.
    func stopAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
            logMessage?("Audio engine stopped")
        }
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
            self.logMessage?("All audio stopped")
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
            audioQueue.async {
                if !self.audioEngine.isRunning {
                    self.setupAudioEngine()
                }
                
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
                        // Ensure audioBuffer has valid floatChannelData and enough channels
                        if let channelData = audioBuffer.floatChannelData,
                           audioBuffer.format.channelCount > 1 {
                            
                            let leftChannel = channelData[0]  // Access the left channel
                            let rightChannel = channelData[1]  // Access the right channel

                            // Copy left channel data to right channel
                            memcpy(rightChannel, leftChannel, Int(audioBuffer.frameLength) * MemoryLayout<Float>.size)
                        } else {
                            // Handle invalid data gracefully
                            print("Error: Insufficient channels or nil floatChannelData.")
                            return
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
                    playerNode.play()
                }
            }
        }
    }
}


class WebSocketManager: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private let audioProcessor: AudioProcessor // Use dependency injection
    private var isStreaming = false
    private var isConnected = false // Track connection state
    private let recieveQueue = DispatchQueue(label: "com.websocket.recieveQueue")
    struct AudioSequence {
        var indicator: String       // Indicator (e.g., "MUSIC" or "SFX")
        var accumulatedData: Data  // Accumulated audio data
        var packetsReceived: Int    // Number of packets received
        var sampleRate: Double
    }
    private var accumulatedAudio: [UUID: AudioSequence] = [:]
    private var expectedAudioSize = 0     // Expected total size of the audio
    private let HEADER_SIZE = 37
    private var sessionID: String? = nil
    private let maxAudioSize = 50 * 1024 * 1024 // 50MB in bytes

    var onConnectionChange: ((ConnectionState) -> Void)? // Called when connection status changes
    var onStreamingChange: ((RecordingState) -> Void)? // Called when streaming status changes
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data, String, Double) -> Void)? // Called for received audio
    var stopRecordingCallback: (() -> Void)?
    var logMessage: ((String) -> Void)?
    
    init(audioProcessor: AudioProcessor) {
        self.audioProcessor = audioProcessor
    }

    // Connect to the WebSocket server
    func connect(to url: URL, token: String, coAuthEnabled: Bool, musicEnabled: Bool, SFXEnabled: Bool) {
        stopAudioStream()
        disconnect() // Ensure any existing connection is closed

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(coAuthEnabled ? "True" : "False", forHTTPHeaderField: "CO-AUTH")
        request.setValue(musicEnabled ? "True" : "False", forHTTPHeaderField: "MUSIC")
        request.setValue(SFXEnabled ? "True" : "False", forHTTPHeaderField: "SFX")
        let username = UserDefaults.standard.string(forKey: "userName")
        request.setValue(username, forHTTPHeaderField: "userName")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessages()
    }

    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: "Client closing connection".data(using: .utf8))
        webSocketTask = nil
//        stopAudioStream()
        stopRecordingCallback?()
        sessionID = ""
        // Clear the accumulatedAudio buffer
        self.recieveQueue.async {
            self.accumulatedAudio = [:]
            self.logMessage?("Accumulated audio buffer cleared")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        logMessage?("WebSocket connected")
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(.connected)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        logMessage?("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            logMessage?("Reason: \(reasonString)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChange?(.disconnected)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logMessage?("WebSocket connection failed with error: \(error.localizedDescription)")
            onConnectionChange?(.disconnected)
        }
    }

    func isConnectionActive() -> Bool {
        return isConnected
    }

    func sendAudioStream() {
        guard !isStreaming else { return }
        isStreaming = true
        onStreamingChange?(.recording)
        logMessage?("Streaming Audio")

        audioProcessor.configureInputTap(bufferSize: 1024) { [weak self] buffer in
            guard let self = self else { return }
            if let audioData = self.audioProcessor.convertPCMBufferToData(buffer: buffer) {
                self.sendData(audioData)
            } else {
                self.logMessage?("Failed to convert audio buffer to data")
            }
        }
        audioProcessor.startAudioEngine()
    }

    func stopAudioStream() {
        isStreaming = false
        audioProcessor.stopAudioEngine()
        onStreamingChange?(.idle)
        logMessage?("Audio streaming stopped")
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



#Preview {
    ContentView()
}
