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

struct MainView: View {
    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store
    @StateObject private var appAudioStateViewModel = AppAudioStateViewModel()

    @State private var isPressed = false
    @State private var isShaking = false // State to control blob shaking
    @State private var isSpinning = false
    @State private var sessionStreak: Int = 0
    @State private var points: Int? = nil
    @State private var isFetchingStreak: Bool = false
    @State private var isLoggedIn: Bool = false
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
    private let networkingManager = NetworkingManager() // Instance of NetworkingManager

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
        
    func authenticateUser(email: String) {
        networkingManager.performLoginRequest(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Save email to UserDefaults and update state
                    UserDefaults.standard.set(email, forKey: "userName")
                    isLoggedIn = true
                case .failure(let error):
                    // Use the error's localized description for the message
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    private func fetchStreak() {
        isFetchingStreak = true

        networkingManager.fetchStreak { result in
            DispatchQueue.main.async {
                self.isFetchingStreak = false
                switch result {
                case .success(let streakValue):
                    self.points = streakValue
                case .failure(let error):
                    print("Error fetching streak: \(error.localizedDescription)")
                }
            }
        }
    }

    private var connectionStatusMessage: String {
        switch appAudioStateViewModel.appAudioState {
        case .disconnected:
            return ""
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
                print("Story ID \(storyID)")
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
    
    private func updateBlobColor() {
        print("Updating blob color for state \(self.arcState)")
        blobColor = blobColorForArcState(self.arcState)
    }
    
    @ViewBuilder
    private func renderConnectedUI() -> some View {
        VStack {
            Text("Collected 🟡 \(String(describing: sessionStreak))")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ProgressBar(
                currentProgress: arcState,
                colorForArcState: blobColorForArcState // Pass the function
            )

            UIBlobWrapper(isShaking: $isShaking, isSpinning: $isSpinning, color: $blobColor)
                .frame(width: 250, height: 250)

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
        .onAppear{
            updateBlobColor()
        }
    }

    @ViewBuilder
    private func renderDisconnectedUI() -> some View {
        VStack(spacing: 20) {
            Text("Continue a story or create a new one")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            StoryPicker()
            StartConnectionButton(connect: connect)
//            MusicToggle(isOn: $musicEnabled, disconnect: disconnect)
        }
    }

    var body: some View {
                
        ZStack {
            BackgroundImage()
            
            VStack {
                // Use a consistent layout for points
                HStack {
                    Spacer() // Push the box to the right
                    // Fix the width of the text elements to avoid UI shifting
                    Group {
                        if let points = points {
                            Text("Total 🟡 \(points)")
                        } else {
                            Text("Total 🟡 --")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing) // Align text to the right
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20) // Ensure consistent horizontal padding
                .frame(maxWidth: .infinity) // Ensure alignment and avoid shifts
                
                Spacer()
                
                Text(connectionStatusMessage)
                    .font(.headline)
                    .foregroundColor(.gray)
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
                print(SERVER_URL)
                if !isLoggedIn {
                    let username = UserDefaults.standard.string(forKey: "userName")
                    if username != nil {
                        authenticateUser(email: username!)
                    }
                }
                fetchStreak() // Fetch the streak when the view appears
                fetchStories() // Fetch stories when the view appears
                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from turning off
                audioProcessor.onBufferStateChange = { state in
                    if !state {
                        if appAudioStateViewModel.appAudioState == .playing {
                            DispatchQueue.main.async {
                                appAudioStateViewModel.appAudioState = .listening
                                //                                    print("New buff status \(appAudioStateViewModel.appAudioState)")
                                self.isShaking = false
                                print("MainView: isShaking updated to \(self.isShaking)")
                            }
                        }
                    } else {
                        if appAudioStateViewModel.appAudioState != .disconnected {
                            DispatchQueue.main.async {
                                appAudioStateViewModel.appAudioState = .playing
                                //                                    print("New buff status \(appAudioStateViewModel.appAudioState)")
                                self.isShaking = true
                            }
                        }
                    }
                }
                webSocketManager.onAppStateChange = { status in
                    DispatchQueue.main.async {
                        if self.appAudioStateViewModel.appAudioState != status {
                            self.appAudioStateViewModel.appAudioState = status
                            print("New WS status: \(self.appAudioStateViewModel.appAudioState)")
                            let shouldShake = (status == .playing)
                            self.isShaking = shouldShake
                            print("MainView: isShaking updated to \(self.isShaking)")
                            let shouldSpin = (status == .thinking)
                            self.isSpinning = shouldSpin
                            print("MainView: shouldSpin updated to \(self.isSpinning)")
                            if status == .disconnected {
                                self.audioProcessor.stopAllAudio()
                                self.points! += self.sessionStreak // temp until fetches from db
                                self.sessionStreak = 0
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
                webSocketManager.onStreakChange = { streak in // TODO do we want to do this on the server of here?
                    DispatchQueue.main.async {
                        print("Setting new Streak \(streak)")
                        sessionStreak = streak
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
