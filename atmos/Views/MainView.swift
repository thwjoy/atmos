//
//  MainView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

struct MainView: View {
    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store

    @State private var appAudioState: AppAudioState = .disconnected
    @State private var isPressed = false
    @State private var holdStartTime: Date?
    @State private var simulatedHoldTask: DispatchWorkItem? // Task for the simulated hold
//    @State private var messages: [String] = []
    @State private var coAuthEnabled = true // Tracks the CO_AUTH state
    @State private var SFXEnabled = true // Tracks the CO_AUTH state
    @State private var musicEnabled = true // Tracks the CO_AUTH state
    @StateObject private var webSocketManager: WebSocketManager
    @StateObject private var audioProcessor: AudioProcessor

    init() {
        // Create the required instances
        let sharedAudioProcessor = AudioProcessor()
        let sharedWebSocketManager = WebSocketManager(audioProcessor: sharedAudioProcessor)
        
        // Assign them to @StateObject
        _audioProcessor = StateObject(wrappedValue: sharedAudioProcessor)
        _webSocketManager = StateObject(wrappedValue: sharedWebSocketManager)
    }

    private var connectionColor: Color {
        switch appAudioState {
        case .disconnected:
            return .red
        case .connecting:
            return .orange
        case .idle:
            return .yellow
        case .listening:
            return .green
        case .recording:
            return .green
        case .thinking:
            return .yellow
        case .playing:
            return .yellow
        }
    }
    
    private var connectionStatusMessage: String {
        switch appAudioState {
        case .disconnected:
            return "Click start"
        case .connecting:
            return "We're starting, please wait..."
        case .idle:
            return "Nearly there, hold tight..."
        case .listening:
            return "Press the mic to answer"
        case .recording:
            return "Now you can start talking"
        case .thinking:
            return "I like it, let me think..."
        case .playing:
            return "Once I finish talking, it's your turn"
        }
    }
    
    private var connectionButton: String {
        switch appAudioState {
        case .disconnected:
            return "mic.slash.fill"
        case .connecting:
            return "mic.slash.fill"
        case .idle:
            return "mic.slash.fill"
        case .listening:
            return "mic.slash.fill"
        case .recording:
            return "mic.fill"
        case .thinking:
            return "mic.slash.fill"
        case .playing:
            return "mic.slash.fill"
        }
    }
    
    private func handleButtonAction() {
        if appAudioState != .disconnected {
            disconnect()
        } else {
            connect()
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
        appAudioState = .connecting
        if let url = URL(string: SERVER_URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                // Get the full document based on the selected title
                let storyID = storiesStore.selectedStory?.id ?? ""
                
                webSocketManager.connect(
                    to: url,
                    token: TOKEN,
                    coAuthEnabled: coAuthEnabled,
                    musicEnabled: musicEnabled,
                    SFXEnabled: SFXEnabled,
                    story_id: storyID
                )
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
            // Set the background image
            Image("Spark_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea() // Ensures the image fills the screen
                .opacity(0.5) // Adjust the opacity level here
            
            // Internal view with opacity
            VStack(spacing: 20) {
                // Toggle buttons at the top
//                Toggle(isOn: $SFXEnabled) {
//                    Text("Read aloud, and I'll add sounds")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                }
//                .onChange(of: SFXEnabled) { _, _ in
//                    if connectionStatus == .connected {
//                        disconnect()
//                    }
//                }
//                .padding(30)
//                .cornerRadius(10)
//
//
//                Toggle(isOn: $coAuthEnabled) {
//                    Text("Shall we make a story together?")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                }
//                .onChange(of: coAuthEnabled) { _, _ in
//                    if connectionStatus == .connected {
//                        disconnect()
//                    }
//                }
//                .padding(30)
//                .cornerRadius(10)
                
                

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
                    if appAudioState != AppAudioState.disconnected {
                        disconnect()
                    } else {
                        connect()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15) // Rounded rectangle for the bar
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: appAudioState == .disconnected
                                        ? [Color.orange.opacity(0.8), Color.yellow.opacity(1.0)] // Default gradient
                                        : [Color.gray.opacity(0.8), Color.gray.opacity(1.0)] // Silver gradient
                                    ),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 50) // Set height for the bar
                            .shadow(color: appAudioState == .disconnected
                                ? Color.orange.opacity(0.3)
                                : Color.gray.opacity(0.3), // Adjust shadow color
                                radius: 5, x: 2, y: 2
                            )
                            .shadow(color: appAudioState == .disconnected
                                ? Color.yellow.opacity(0.5)
                                : Color.gray.opacity(0.5), // Adjust highlight shadow
                                radius: 5, x: -2, y: -2
                            )

                        Text(appAudioState == .disconnected ? "Start" : "Stop") // Button label
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 50) // Add padding to make the bar wider
                }
                if appAudioState != .disconnected {
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
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                // Handle initial press or re-press
                                if !isPressed {
                                    if appAudioState == .listening || appAudioState == .recording {
                                        isPressed = true
                                        holdStartTime = Date() // Record the start time of the press
                                        
                                        // Cancel any existing simulated hold
                                        simulatedHoldTask?.cancel()
                                        simulatedHoldTask = nil
                                        
                                        webSocketManager.sendAudioStream() // Start streaming
                                        webSocketManager.sendTextMessage("START")
                                        appAudioState = .recording
                                    }
                                }
                            }
                            .onEnded { _ in
                                if isPressed {
                                    //let elapsedTime = holdStartTime.map { Date().timeIntervalSince($0) } ?? 0
                                    let remainingTime = 1 // max(0, 1 - elapsedTime)
                                    isPressed = false
                                    
                                    // Create a new simulated hold task
                                    simulatedHoldTask = DispatchWorkItem {
                                        appAudioState = .thinking
                                        webSocketManager.stopAudioStream() // Stop streaming
                                        webSocketManager.sendTextMessage("STOP")
                                    }
                                    
                                    // Schedule the task for the remaining time
                                    if let task = simulatedHoldTask {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(remainingTime), execute: task)
                                    }
                                }
                            }
                    )
                    
                    Button(action: {
                        audioProcessor.replayStoryAudio()
                    }) {
                        Text("Replay Story Audio")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                } else {
                    
                    // Show Picker and other controls when disconnected
                    if !storiesStore.stories.isEmpty {
                        Picker("Select Story", selection: $storiesStore.selectedStoryTitle) {
                            Text("Make a New Story").tag(nil as String?)
                            
                            ForEach(storiesStore.stories, id: \.story_name) { story in
                                Text(story.story_name).tag(story.story_name as String?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                    
                    Toggle(isOn: $musicEnabled) {
                        Text("How about adding some music?")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .onChange(of: musicEnabled) { _, _ in
                        if appAudioState != .disconnected {
                            disconnect()
                        }
                    }
                    .padding(30)
                    .cornerRadius(10)
                    
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from turning off
                audioProcessor.onAppStateChange = { storyState in
                    if storyState != .listening || storyState != .recording {
                        webSocketManager.stopAudioStream()
                    }
                }
                audioProcessor.onBufferStateChange = { state in
                    switch state {
                    case true:
                        if appAudioState == .listening {
                            appAudioState = .playing
                        }
                    case false:
                        if appAudioState == .playing {
                            appAudioState = .listening
                        }
                    }
                }
                webSocketManager.onAppStateChange = { status in
                    DispatchQueue.main.async {
                        appAudioState = status
                        if status == .disconnected {
                            self.audioProcessor.stopAllAudio()
                        } else if status == .idle {
                            self.audioProcessor.configureRecordingSession()
                            self.audioProcessor.setupAudioEngine()
                        }
                    }
                }
                webSocketManager.onAudioReceived = { data, indicator, sampleRate in
                    audioProcessor.playAudioChunk(audioData: data, indicator: indicator, sampleRate: sampleRate)
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
                disconnect()
                audioProcessor.stopAllAudio()
                audioProcessor.onAppStateChange = nil
                webSocketManager.onAppStateChange = nil
                webSocketManager.onAudioReceived = nil
            }
        }
    }
    
}
