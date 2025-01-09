////
////  MainView.swift
////  Spark
////
////  Created by Tom Joy on 23/12/2024.
////
//
//import Foundation
//import Combine
//import SwiftUI
//
//class AppAudioStateViewModel: ObservableObject {
//    @Published var appAudioState: AppAudioState = .disconnected
//}
//
//class MainViewModel: ObservableObject {
//    @Published var points: Int?
//    @Published var isFetchingStreak: Bool = false
//    @Published var isLoggedIn: Bool = false
//    
//    private let networkingManager = NetworkingManager() // Directly use NetworkingManager
//    
//    // Fetch the streak value from the server and update state
//    func fetchStreak() {
//        isFetchingStreak = true
//        networkingManager.fetchStreak { [weak self] result in
//            DispatchQueue.main.async {
//                self?.isFetchingStreak = false
//                switch result {
//                case .success(let streakValue):
//                    self?.points = streakValue
//                case .failure(let error):
//                    print("Error fetching streak: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//    
//    // Authenticate the user and update state
//    func authenticateUser(email: String) {
//        networkingManager.performLoginRequest(email: email) { [weak self] result in
//            DispatchQueue.main.async {
//                switch result {
//                case .success:
//                    UserDefaults.standard.set(email, forKey: "userName")
//                    self?.isLoggedIn = true
//                case .failure(let error):
//                    print("Authentication failed: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//}
//
//struct MainView: View {
//    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store
//    @StateObject private var appAudioStateViewModel = AppAudioStateViewModel()
//    @StateObject private var mainViewModel = MainViewModel()
//
//    
//
//    @State private var isPressed = false
//    @State private var isShaking = false // State to control blob shaking
//    @State private var isSpinning = false
//    @State private var sessionStreak: Int = 0
////    @State private var points: Int? = nil
//    @State private var isFetchingStreak: Bool = false
////    @State private var isLoggedIn: Bool = false
//    @State private var arcState: Int = 0  // Will range from 0..7
//    @State private var blobColor: Color = .gray // Blob color state
//    @State private var showDisconnectConfirmation = false
//    @State private var holdStartTime: Date?
//    @State private var simulatedHoldTask: DispatchWorkItem? // Task for the simulated hold
////    @State private var messages: [String] = []
//    @State private var coAuthEnabled = true // Tracks the CO_AUTH state
//    @State private var SFXEnabled = true // Tracks the CO_AUTH state
//    @State private var musicEnabled = true // Tracks the CO_AUTH state
//    @StateObject private var webSocketManager: WebSocketManager
//    @StateObject private var audioProcessor: AudioProcessor
////    private let networkingManager = NetworkingManager() // Instance of NetworkingManager
//
//    init() {
//        // Create the required instances
//        let sharedAudioProcessor = AudioProcessor()
//        let sharedWebSocketManager = WebSocketManager(audioProcessor: sharedAudioProcessor)
//        
//        // Assign them to @StateObject
//        _audioProcessor = StateObject(wrappedValue: sharedAudioProcessor)
//        _webSocketManager = StateObject(wrappedValue: sharedWebSocketManager)
//    }
//
//    private var connectionStatusMessage: String {
//        switch appAudioStateViewModel.appAudioState {
//        case .disconnected:
//            return ""
//        case .connecting:
//            return "We're starting, please wait..."
//        case .idle:
//            return "Nearly there, hold tight..."
//        case .listening:
//            return "Press the mic to answer"
//        case .recording:
//            return "Now you can start talking"
//        case .thinking:
//            return "I like it, let me think..."
//        case .playing:
//            return "Once I finish talking, it's your turn"
//        }
//    }
//    
//    
//    private func handleButtonAction() {
//        if appAudioStateViewModel.appAudioState != .disconnected {
//            disconnect()
//        } else {
//            connect()
//        }
//    }
//    
//    
//    private func setup() {
//        UIApplication.shared.isIdleTimerDisabled = true
//    }
//
//    private func cleanup() {
//        UIApplication.shared.isIdleTimerDisabled = false
//        disconnect()
//    }
//
//    private func connect() {
//        DispatchQueue.main.async {
//            appAudioStateViewModel.appAudioState = .connecting
//            arcState = 0
//        }
//        if let url = URL(string: SERVER_URL) {
//            DispatchQueue.global(qos: .userInitiated).async {
//                // Get the full document based on the selected title
//                let storyID = storiesStore.selectedStory?.id ?? ""
//                print("Story ID \(storyID)")
//                webSocketManager.connect(
//                    to: url,
//                    token: TOKEN,
//                    coAuthEnabled: coAuthEnabled,
//                    musicEnabled: musicEnabled,
//                    SFXEnabled: SFXEnabled,
//                    story_id: storyID
//                )
//            }
//        }
//    }
//
//    private func disconnect() {
//        DispatchQueue.global(qos: .userInitiated).async {
//            webSocketManager.disconnect()
//        }
//    }
//    
//    private func handleGestureChange() {
//        if !isPressed && (appAudioStateViewModel.appAudioState == .listening || appAudioStateViewModel.appAudioState == .recording) {
//            isPressed = true
//            holdStartTime = Date()
//
//            simulatedHoldTask?.cancel()
//            simulatedHoldTask = nil
//
//            webSocketManager.sendAudioStream()
//            webSocketManager.sendTextMessage("START")
//            DispatchQueue.main.async {
//                appAudioStateViewModel.appAudioState = .recording
//            }
//        }
//    }
//
//    private func handleGestureEnd() {
//        if isPressed {
//            isPressed = false
//
//            simulatedHoldTask = DispatchWorkItem {
//                appAudioStateViewModel.appAudioState = .thinking
//                self.isShaking = true
//                self.isSpinning = true
//                webSocketManager.stopAudioStream()
//                webSocketManager.sendTextMessage("STOP")
//            }
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: simulatedHoldTask!)
//        }
//    }
//    
//    private func updateBlobColor() {
//        print("Updating blob color for state \(self.arcState)")
//        blobColor = blobColorForArcState(self.arcState)
//    }
//    
//    @ViewBuilder
//    private func renderConnectedUI() -> some View {
//        VStack {
//            Text("Collected 🟡 \(String(describing: sessionStreak))")
//                .font(.headline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            
//            ProgressBar(
//                currentProgress: arcState,
//                colorForArcState: blobColorForArcState // Pass the function
//            )
//
//            UIBlobWrapper(isShaking: $isShaking, isSpinning: $isSpinning, color: $blobColor)
//                .frame(width: 250, height: 250)
//
//            Spacer()
//            MicrophoneButton(
//                appAudioState: $appAudioStateViewModel.appAudioState,
//                onGestureChange: handleGestureChange,
//                onGestureEnd: handleGestureEnd
//            )
//            Spacer()
//            ControlButtons(
//                replayStoryAudio: audioProcessor.replayStoryAudio,
//                disconnect: disconnect,
//                showDisconnectConfirmation: $showDisconnectConfirmation
//            )
//        }
//        .onAppear{
//            updateBlobColor()
//        }
//    }
//
//    @ViewBuilder
//    private func renderDisconnectedUI() -> some View {
//        VStack(spacing: 20) {
//            Text("Continue a story or create a new one")
//                .font(.headline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//
//            StoryPicker()
//            StartConnectionButton(connect: connect)
////            MusicToggle(isOn: $musicEnabled, disconnect: disconnect)
//        }
//    }
//
//    var body: some View {
//                
//        ZStack {
//            BackgroundImage()
//            
//            VStack {
//                // Use a consistent layout for points
//                HStack {
//                    Spacer() // Push the box to the right
//                    // Fix the width of the text elements to avoid UI shifting
//                    Group {
//                        if let points = mainViewModel.points {
//                            Text("Total 🟡 \(points)")
//                        } else {
//                            Text("Total 🟡 --")
//                        }
//                    }
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .multilineTextAlignment(.trailing) // Align text to the right
//                    .padding(10)
//                    .background(Color.black.opacity(0.5))
//                    .cornerRadius(8)
//                }
//                .padding(.horizontal, 20) // Ensure consistent horizontal padding
//                .frame(maxWidth: .infinity) // Ensure alignment and avoid shifts
//                
//                Spacer()
//                
//                Text(connectionStatusMessage)
//                    .font(.headline)
//                    .foregroundColor(.gray)
//                    .padding()
//                if appAudioStateViewModel.appAudioState != .disconnected {
//                    renderConnectedUI()
//                } else {
//                    renderDisconnectedUI()
//                }
//                Spacer()
//                
//            }
//            .padding()
//            .onAppear {
//                print(SERVER_URL)
//                if !mainViewModel.isLoggedIn {
//                    let username = UserDefaults.standard.string(forKey: "userName")
//                    if username != nil {
//                        mainViewModel.authenticateUser(email: username!)
//                    }
//                }
//                mainViewModel.fetchStreak() // Fetch the streak when the view appears
//                storiesStore.fetchDocuments() // Fetch stories when the view appears
//                UIApplication.shared.isIdleTimerDisabled = true // Prevent screen from turning off
//                audioProcessor.onBufferStateChange = { state in
//                    if !state {
//                        if appAudioStateViewModel.appAudioState == .playing {
//                            DispatchQueue.main.async {
//                                appAudioStateViewModel.appAudioState = .listening
//                                //                                    print("New buff status \(appAudioStateViewModel.appAudioState)")
//                                self.isShaking = false
//                                print("MainView: isShaking updated to \(self.isShaking)")
//                            }
//                        }
//                    } else {
//                        if appAudioStateViewModel.appAudioState != .disconnected {
//                            DispatchQueue.main.async {
//                                appAudioStateViewModel.appAudioState = .playing
//                                //                                    print("New buff status \(appAudioStateViewModel.appAudioState)")
//                                self.isShaking = true
//                            }
//                        }
//                    }
//                }
//                webSocketManager.onAppStateChange = { status in
//                    DispatchQueue.main.async {
//                        if self.appAudioStateViewModel.appAudioState != status {
//                            self.appAudioStateViewModel.appAudioState = status
//                            print("New WS status: \(self.appAudioStateViewModel.appAudioState)")
//                            let shouldShake = (status == .playing)
//                            self.isShaking = shouldShake
//                            print("MainView: isShaking updated to \(self.isShaking)")
//                            let shouldSpin = (status == .thinking)
//                            self.isSpinning = shouldSpin
//                            print("MainView: shouldSpin updated to \(self.isSpinning)")
//                            if status == .disconnected {
//                                self.audioProcessor.stopAllAudio()
//                                self.mainViewModel.points! += self.sessionStreak // temp until fetches from db
//                                self.sessionStreak = 0
//                            } else if status == .idle {
//                                self.audioProcessor.configureRecordingSession()
//                                self.audioProcessor.setupAudioEngine()
//                            }
//                        }
//                    }
//                }
//                webSocketManager.onAudioReceived = { data, indicator, sampleRate in
//                    audioProcessor.playAudioChunk(audioData: data, indicator: indicator, sampleRate: sampleRate)
//                }
//                webSocketManager.onARCStateChange = { state in
//                    DispatchQueue.main.async {
//                        print("Setting new ARC section to \(state)")
//                        self.arcState = min(max(self.arcState, state), 7)
//                        updateBlobColor()
//                    }
//                }
//                webSocketManager.onStreakChange = { streak in // TODO do we want to do this on the server of here?
//                    DispatchQueue.main.async {
//                        print("Setting new Streak \(streak)")
//                        sessionStreak = streak
//                    }
//                }
//            }
//            .onDisappear {
//                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
//                disconnect()
//                audioProcessor.stopAllAudio()
//                webSocketManager.onAppStateChange = nil
//                webSocketManager.onAudioReceived = nil
//            }
//        }
//    }
//}
//
//


import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    @Published var isLoggedIn: Bool = false
    @Published var points: Int?
    @Published var isFetchingStreak: Bool = false
    @Published var arcState: Int = 0  // Will range from 0..7
    @Published var blobColor: Color = .gray
    @Published var isPressed = false
    @Published var isShaking = false
    @Published var isSpinning = false
    @Published var sessionStreak: Int = 0
    @Published var showDisconnectConfirmation = false
    
    // MARK: - Networking & Audio
    private let networkingManager = NetworkingManager() // Directly use NetworkingManager
    let audioProcessor = AudioProcessor()
    let webSocketManager: WebSocketManager
    
    // MARK: - App Audio State
    @Published var appAudioState: AppAudioState = .disconnected
    
    init() {
        // Initialize WebSocketManager with AudioProcessor
        webSocketManager = WebSocketManager(audioProcessor: audioProcessor)
        
        // Bind the web socket callbacks
        bindWebSocketCallbacks()
        
        // Bind the audio processor callback
        bindAudioProcessorCallback()
    }
    
    // MARK: - Networking Methods
    
    /// Authenticates the user by email and updates `isLoggedIn`.
    func authenticateUser(email: String) {
        networkingManager.performLoginRequest(email: email) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    UserDefaults.standard.set(email, forKey: "userName")
                    self?.isLoggedIn = true
                case .failure(let error):
                    print("Authentication failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Fetches the current streak from the server and updates `points`.
    func fetchStreak() {
        isFetchingStreak = true
        networkingManager.fetchStreak { [weak self] result in
            DispatchQueue.main.async {
                self?.isFetchingStreak = false
                switch result {
                case .success(let streakValue):
                    self?.points = streakValue
                case .failure(let error):
                    print("Error fetching streak: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - WebSocket Connection Methods
    
    /// Connects to the WebSocket server, setting the state to `.connecting`.
    func connect(
        serverURL: String,
        token: String,
        storyID: String,
        coAuthEnabled: Bool,
        musicEnabled: Bool,
        SFXEnabled: Bool
    ) {
        DispatchQueue.main.async {
            self.appAudioState = .connecting
            self.arcState = 0
        }
        
        guard let url = URL(string: serverURL) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.webSocketManager.connect(
                to: url,
                token: token,
                coAuthEnabled: coAuthEnabled,
                musicEnabled: musicEnabled,
                SFXEnabled: SFXEnabled,
                story_id: storyID
            )
        }
    }
    
    /// Disconnects from the WebSocket server.
    func disconnect() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.webSocketManager.disconnect()
        }
    }
    
    // MARK: - Gesture Handling
    
    /// Starts the "press and hold" recording gesture.
    func handleGestureChange() {
        if !isPressed && (appAudioState == .listening || appAudioState == .recording) {
            isPressed = true
            webSocketManager.sendAudioStream()
            webSocketManager.sendTextMessage("START")
            DispatchQueue.main.async {
                self.appAudioState = .recording
            }
        }
    }
    
    /// Ends the "press and hold" recording gesture.
    func handleGestureEnd() {
        if isPressed {
            isPressed = false
            
            // Simulate a short delay before stopping audio
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.appAudioState = .thinking
                self.isShaking = true
                self.isSpinning = true
                self.webSocketManager.stopAudioStream()
                self.webSocketManager.sendTextMessage("STOP")
            }
        }
    }
    
    // MARK: - Color Updates
    
    /// Updates the blob color based on the current `arcState`.
    func updateBlobColor() {
        blobColor = blobColorForArcState(arcState)
    }
    
    // MARK: - Connection Status
    
    /// Returns a string describing the current connection status.
    var connectionStatusMessage: String {
        switch appAudioState {
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
    
    // MARK: - Private Helpers
    
    /// Binds the callbacks from `WebSocketManager` to update this model's state.
    private func bindWebSocketCallbacks() {
        webSocketManager.onAppStateChange = { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.appAudioState != status {
                    self.appAudioState = status
                    print("New WS status: \(status)")
                    
                    let shouldShake = (status == .playing)
                    self.isShaking = shouldShake
                    let shouldSpin = (status == .thinking)
                    self.isSpinning = shouldSpin
                    
                    if status == .disconnected {
                        self.audioProcessor.stopAllAudio()
                        // Add session streak to points
                        if let currentPoints = self.points {
                            self.points = currentPoints + self.sessionStreak
                        } else {
                            self.points = self.sessionStreak
                        }
                        self.sessionStreak = 0
                    } else if status == .idle {
                        self.audioProcessor.configureRecordingSession()
                        self.audioProcessor.setupAudioEngine()
                    }
                }
            }
        }
        
        webSocketManager.onAudioReceived = { [weak self] data, indicator, sampleRate in
            self?.audioProcessor.playAudioChunk(audioData: data, indicator: indicator, sampleRate: sampleRate)
        }
        
        webSocketManager.onARCStateChange = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("Setting new ARC section to \(state)")
                self.arcState = min(max(self.arcState, state), 7)
                self.updateBlobColor()
            }
        }
        
        // If the server sends updated streak data:
        webSocketManager.onStreakChange = { [weak self] streak in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("Setting new Streak \(streak)")
                self.sessionStreak = streak
            }
        }
    }
    
    /// Binds the audio processor state changes to update `appAudioState`.
    private func bindAudioProcessorCallback() {
        audioProcessor.onBufferStateChange = { [weak self] isBufferFull in
            guard let self = self else { return }
            if !isBufferFull {
                // Buffer emptied → typically from .playing → .listening
                if self.appAudioState == .playing {
                    DispatchQueue.main.async {
                        self.appAudioState = .listening
                        self.isShaking = false
                        print("Buffer empty → switching to .listening")
                    }
                }
            } else {
                // Buffer filled → typically from .listening → .playing
                if self.appAudioState != .disconnected {
                    DispatchQueue.main.async {
                        self.appAudioState = .playing
                        self.isShaking = true
                        print("Buffer filled → switching to .playing")
                    }
                }
            }
        }
    }
}


//
//  MainView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        ZStack {
            BackgroundImage()
            VStack {
                renderHeader()
                Spacer()
                
                // Display the connection status
                Text(viewModel.connectionStatusMessage)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
                
                // Conditional UI based on WebSocket state
                if viewModel.appAudioState != .disconnected {
                    renderConnectedUI()
                } else {
                    renderDisconnectedUI()
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                // View lifecycle & data fetching
                setupView()
            }
            .onDisappear {
                cleanupView()
            }
        }
    }
    
    // MARK: - Setup and Cleanup
    
    private func setupView() {
        // Prevent the screen from turning off
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Try to authenticate user from UserDefaults
        if !viewModel.isLoggedIn {
            if let username = UserDefaults.standard.string(forKey: "userName") {
                viewModel.authenticateUser(email: username)
            }
        }
        
        // Fetch stories & streak
        storiesStore.fetchDocuments()
        viewModel.fetchStreak()
    }
    
    private func cleanupView() {
        UIApplication.shared.isIdleTimerDisabled = false
        viewModel.disconnect()
        viewModel.audioProcessor.stopAllAudio()
        
        // Clear out callbacks if desired
        viewModel.webSocketManager.onAppStateChange = nil
        viewModel.webSocketManager.onAudioReceived = nil
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func renderHeader() -> some View {
        HStack {
            Spacer()
            Group {
                if let points = viewModel.points {
                    Text("Total 🟡 \(points)")
                } else {
                    Text("Total 🟡 --")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .multilineTextAlignment(.trailing)
            .padding(10)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Connected UI
    
    @ViewBuilder
    private func renderConnectedUI() -> some View {
        VStack {
            Text("Collected 🟡 \(viewModel.sessionStreak)")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ProgressBar(
                currentProgress: viewModel.arcState,
                colorForArcState: blobColorForArcState
            )
            
            UIBlobWrapper(
                isShaking: $viewModel.isShaking,
                isSpinning: $viewModel.isSpinning,
                color: $viewModel.blobColor
            )
            .frame(width: 250, height: 250)
            
            Spacer()
            
            // Microphone interaction
            MicrophoneButton(
                appAudioState: $viewModel.appAudioState,
                onGestureChange: viewModel.handleGestureChange,
                onGestureEnd: viewModel.handleGestureEnd
            )
            
            Spacer()
            
            ControlButtons(
                replayStoryAudio: viewModel.audioProcessor.replayStoryAudio,
                disconnect: viewModel.disconnect,
                showDisconnectConfirmation: $viewModel.showDisconnectConfirmation
            )
        }
        .onAppear {
            viewModel.updateBlobColor()
        }
    }
    
    // MARK: - Disconnected UI
    
    @ViewBuilder
    private func renderDisconnectedUI() -> some View {
        VStack(spacing: 20) {
            Text("Continue a story or create a new one")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            StoryPicker()
            StartConnectionButton {
                let storyID = storiesStore.selectedStory?.id ?? ""
                viewModel.connect(
                    serverURL: SERVER_URL,
                    token: TOKEN,
                    storyID: storyID,
                    coAuthEnabled: true,
                    musicEnabled: true,
                    SFXEnabled: true
                )
            }
        }
    }
}



