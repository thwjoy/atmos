//
//  MainView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI

class AppAudioStateViewModel: ObservableObject {
    @Published var appAudioState: AppAudioState = .disconnected
}

struct ProgressBar: View {
    let currentProgress: Int
    let colorForArcState: (Int) -> Color // Function to get the color for a specific arcState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7) { index in
                Rectangle()
                    .fill(index < currentProgress ? colorForArcState(index + 1) : Color.gray.opacity(0.4)) // Use the function to get the color
                    .frame(width: 30, height: 10)
                    .cornerRadius(2)
            }
        }
        .padding(.top)
    }
}

struct BackgroundImage: View {
    var body: some View {
        Image("Spark_background")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .opacity(0.5)
    }
}

struct MicrophoneButton: View {
    @Binding var appAudioState: AppAudioState
    let onGestureChange: () -> Void
    let onGestureEnd: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(1.0),
                            connectionColor.opacity(0.8)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
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
                .shadow(color: connectionColor.opacity(0.5), radius: 10, x: 5, y: 5)
                .shadow(color: connectionColor.opacity(0.8), radius: 10, x: -5, y: -5)
                .frame(width: 200, height: 200)

            Image(systemName: connectionButton)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundColor(connectionColor)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onGestureChange() }
                .onEnded { _ in onGestureEnd() }
        )
    }

    private var connectionColor: Color {
        switch appAudioState {
        case .disconnected: return .red
        case .connecting: return .orange
        case .idle: return .yellow
        case .listening, .recording: return .green
        case .thinking, .playing: return .yellow
        }
    }

    private var connectionButton: String {
        switch appAudioState {
        case .disconnected, .connecting, .idle, .listening, .thinking, .playing:
            return "mic.slash.fill"
        case .recording:
            return "mic.fill"
        }
    }
}



struct ControlButtons: View {
    let replayStoryAudio: () -> Void
    let disconnect: () -> Void
    @Binding var showDisconnectConfirmation: Bool

    var body: some View {
        HStack {
            // Replay Button
            Button(action: replayStoryAudio) {
                CircleButton(iconName: "gobackward", backgroundColor: .blue)
            }

            Spacer()

            // Disconnect Button with Confirmation
            Button(action: {
                showDisconnectConfirmation = true
            }) {
                CircleButton(iconName: "xmark", backgroundColor: .red)
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
    }
}


struct CircleButton: View {
    let iconName: String
    let backgroundColor: Color

    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 50, height: 50)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(radius: 5)
    }
}

struct StoryPicker: View {
    @EnvironmentObject var storiesStore: StoriesStore

    var body: some View {
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
    }
}


struct StartConnectionButton: View {
    var connect: () -> Void // Action to perform when the button is tapped

    var body: some View {
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
        .padding(.horizontal, 50) // Add horizontal padding
    }
}


struct MusicToggle: View {
    @Binding var isOn: Bool // Binding to control the toggle's state
    var disconnect: () -> Void // Action to perform when the toggle changes

    var body: some View {
        Toggle(isOn: $isOn) {
            Text("How about adding some music?")
                .font(.headline)
                .foregroundColor(.white)
        }
        .onChange(of: isOn) { newValue, _ in
            // Perform any cleanup if needed when the toggle changes
            if !newValue {
                disconnect()
            }
        }
        .padding(30) // Add padding
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10) // Round the corners
    }
}


struct MainView: View {
    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store
    @StateObject private var appAudioStateViewModel = AppAudioStateViewModel()

    @State private var isPressed = false
    @State private var isShaking = false // State to control blob shaking
    @State private var isSpinning = false
    @State private var arcState: Int = 0  // Will range from 0..7
    @State private var blobColor: Color = .gray // Blob color state
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


    private var connectionStatusMessage: String {
        switch appAudioStateViewModel.appAudioState {
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
    
    
    private func handleButtonAction() {
        if appAudioStateViewModel.appAudioState != .disconnected {
            disconnect()
        } else {
            connect()
        }
    }
    
    
    private func setup() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func cleanup() {
        UIApplication.shared.isIdleTimerDisabled = false
        disconnect()
    }

    private func connect() {
        DispatchQueue.main.async {
            appAudioStateViewModel.appAudioState = .connecting
            arcState = 0
        }
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
        if !isPressed && (appAudioStateViewModel.appAudioState == .listening || appAudioStateViewModel.appAudioState == .recording) {
            isPressed = true
            holdStartTime = Date()

            simulatedHoldTask?.cancel()
            simulatedHoldTask = nil

            webSocketManager.sendAudioStream()
            webSocketManager.sendTextMessage("START")
            DispatchQueue.main.async {
                appAudioStateViewModel.appAudioState = .recording
            }
        }
    }

    private func handleGestureEnd() {
        if isPressed {
            isPressed = false

            simulatedHoldTask = DispatchWorkItem {
                appAudioStateViewModel.appAudioState = .thinking
                self.isShaking = true
                self.isSpinning = true
                webSocketManager.stopAudioStream()
                webSocketManager.sendTextMessage("STOP")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: simulatedHoldTask!)
        }
    }
    
    private func blobColorForArcState(_ arcState: Int) -> Color {
        switch arcState {
        case 0:
            return .gray
        case 1:
            return .red
        case 2:
            return .orange
        case 3:
            return .yellow
        case 4:
            return .green
        case 5:
            return .blue
        case 6:
            return .indigo
        case 7:
            return .purple
        default:
            return .white
        }
    }

    private func updateBlobColor() {
        print("Updating blob color for state \(self.arcState)")
        blobColor = blobColorForArcState(self.arcState)
    }

//    private func handleArcStateChange(_ newState: Int) {
//        arcState = min(max(0, newState), 7)
//        updateBlobColor()
//    }
    
    @ViewBuilder
    private func renderConnectedUI() -> some View {
        VStack {
            ProgressBar(
                currentProgress: arcState,
                colorForArcState: blobColorForArcState // Pass the function
            )

            UIBlobWrapper(isShaking: $isShaking, isSpinning: $isSpinning, color: $blobColor)
                .frame(width: 200, height: 200)

            Spacer()
            MicrophoneButton(
                appAudioState: $appAudioStateViewModel.appAudioState,
                onGestureChange: handleGestureChange,
                onGestureEnd: handleGestureEnd
            )
            Spacer()
            ControlButtons(
                replayStoryAudio: audioProcessor.replayStoryAudio,
                disconnect: disconnect,
                showDisconnectConfirmation: $showDisconnectConfirmation
            )
        }
    }

    @ViewBuilder
    private func renderDisconnectedUI() -> some View {
        VStack(spacing: 20) {
            Text("Please select a story to get started or create a new one.")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            StoryPicker()
            StartConnectionButton(connect: connect)
            MusicToggle(isOn: $musicEnabled, disconnect: disconnect)
        }
    }

    var body: some View {
                
        ZStack {
            BackgroundImage()
            VStack(spacing: 20) {
                Spacer()
                Text(connectionStatusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                if appAudioStateViewModel.appAudioState != .disconnected {
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
                audioProcessor.onBufferStateChange = { state in
                    if !state {
                        if appAudioStateViewModel.appAudioState == .playing {
                            DispatchQueue.main.async {
                                appAudioStateViewModel.appAudioState = .listening
                                print("New buff status \(appAudioStateViewModel.appAudioState)")
                                self.isShaking = false
                                print("MainView: isShaking updated to \(self.isShaking)")
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            appAudioStateViewModel.appAudioState = .playing
                            self.isShaking = true
                        }
                    }
                }
                webSocketManager.onAppStateChange = { status in
                    DispatchQueue.main.async {
                        
                        if self.appAudioStateViewModel.appAudioState != status {
                            self.appAudioStateViewModel.appAudioState = status
                            print("New WS status: \(status)")
                            let shouldShake = (status == .playing)
                            self.isShaking = shouldShake
                            print("MainView: isShaking updated to \(self.isShaking)")
                            let shouldSpin = (status == .thinking)
                            self.isSpinning = shouldSpin
                            print("MainView: shouldSpin updated to \(self.isSpinning)")
                            if status == .disconnected {
                                self.audioProcessor.stopAllAudio()
                            } else if status == .idle {
                                self.audioProcessor.configureRecordingSession()
                                self.audioProcessor.setupAudioEngine()
                            }
                        }
                    }
                }
                webSocketManager.onAudioReceived = { data, indicator, sampleRate in
                    audioProcessor.playAudioChunk(audioData: data, indicator: indicator, sampleRate: sampleRate)
                }
                webSocketManager.onARCStateChange = { state in
                    DispatchQueue.main.async {
                        print("Setting new ARC section to \(state)")
                        self.arcState = min(max(self.arcState, state), 7)
                        updateBlobColor()
                    }
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
                disconnect()
                audioProcessor.stopAllAudio()
                webSocketManager.onAppStateChange = nil
                webSocketManager.onAudioReceived = nil
            }
        }
    }
}
