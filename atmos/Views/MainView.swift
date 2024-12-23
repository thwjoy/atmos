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
    @State private var showDisconnectConfirmation = false
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
    
    private func fetchStories() {
        storiesStore.fetchDocuments { error in
            if let error = error {
                print("Failed to fetch stories: \(error.localizedDescription)")
            } else {
                print("Stories fetched successfully.")
            }
        }
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
    
    private func handleGestureChange() {
        if !isPressed && (appAudioState == .listening || appAudioState == .recording) {
            isPressed = true
            holdStartTime = Date()

            simulatedHoldTask?.cancel()
            simulatedHoldTask = nil

            webSocketManager.sendAudioStream()
            webSocketManager.sendTextMessage("START")
            appAudioState = .recording
        }
    }

    private func handleGestureEnd() {
        if isPressed {
            isPressed = false

            simulatedHoldTask = DispatchWorkItem {
                appAudioState = .thinking
                webSocketManager.stopAudioStream()
                webSocketManager.sendTextMessage("STOP")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: simulatedHoldTask!)
        }
    }
    
    @ViewBuilder
    private func renderConnectedUI() -> some View {
        VStack {
            Spacer()

            // Microphone Button - Positioned higher
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(1.0), // Lighter center
                                connectionColor.opacity(0.8)  // Light outer edge
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
                                    gradient: Gradient(colors: [
                                        connectionColor.opacity(0.8),
                                        connectionColor,
                                        connectionColor.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )
                    )
                    .shadow(color: connectionColor.opacity(0.5), radius: 10, x: 5, y: 5) // Outer shadow matches button color
                    .shadow(color: connectionColor.opacity(0.8), radius: 10, x: -5, y: -5) // Inner highlight matches button color
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
                            let remainingTime = 1
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
//            .padding(.bottom, 50) // Position the microphone button higher
//
//            Spacer()

            // Replay and Disconnect Buttons at the bottom
            HStack {
                // Replay Button
                Button(action: {
                    audioProcessor.replayStoryAudio()
                }) {
                    Image(systemName: "gobackward")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }

                Spacer()

                // Disconnect Button with Confirmation
                Button(action: {
                    showDisconnectConfirmation = true // Show confirmation dialog
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .alert(isPresented: $showDisconnectConfirmation) {
                    Alert(
                        title: Text("Disconnect?"),
                        message: Text("Are you sure you want to disconnect? This will stop the current session."),
                        primaryButton: .destructive(Text("Disconnect")) {
                            disconnect() // Perform the disconnect action
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding(.horizontal, 50)
//            .padding(.bottom, 30) // Keeps the buttons at the bottom
        }
    }


    @ViewBuilder
    private func renderDisconnectedUI() -> some View {
        VStack(spacing: 20) {
            // Informational text
            Text("Please select a story to get started or create a new one.")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Story Picker
            Picker("Select Story", selection: $storiesStore.selectedStoryTitle) {
                Text("Make a New Story").tag(nil as String?)

                ForEach(storiesStore.stories, id: \.story_name) { story in
                    Text(story.story_name).tag(story.story_name as String?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .foregroundColor(.black)
            .shadow(radius: 5)

            // Start Button
            Button(action: {
                connect()
            }) {
                Text("Start Connection")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .padding(.horizontal, 50)

            // Music toggle
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
                
            
                // Main rendering logic
                Spacer()

                // Connection status message
                Text(connectionStatusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                
                // Render UI based on connection state
                if appAudioState != .disconnected {
                    renderConnectedUI()
                } else {
                    renderDisconnectedUI()
                }

                Spacer()
            }
            .padding()
            .onAppear {
                fetchStories() // Fetch stories when the view appears
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
