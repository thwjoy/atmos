

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
        // Declare isDownloading as a shared property in the class
        var isDownloading = false

        audioProcessor.onBufferStateChange = { [weak self] isBufferFull in
            guard let self = self else { return }
            
            // Assign the closure to update the shared isDownloading variable
            self.webSocketManager.audioDownloading = { downloading in
                DispatchQueue.main.async {
                    isDownloading = downloading // Update shared state
                    print("Audio downloading state updated: \(isDownloading)")
                }
            }

            DispatchQueue.main.async {
                if !isBufferFull {
                    // Buffer emptied → typically from .playing → .listening
                    if self.appAudioState == .playing && !isDownloading {
                        self.appAudioState = .listening
                        self.isShaking = false
                        print("Buffer empty → switching to .listening")
                    }
                } else {
                    // Buffer filled → typically from .listening → .playing
                    if self.appAudioState != .disconnected {
                        self.appAudioState = .playing
                        self.isShaking = true
                        print("Buffer filled → switching to .playing")
                    }
                }
            }
        }
    }

}




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



