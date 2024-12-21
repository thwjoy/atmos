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

var SERVER_URL = "wss://myatmos.pro/test"
var TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiVG9tLmpveTk0QGdtYWlsLmNvbSIsImV4cCI6MTczNzI4Njk4NywiaWF0IjoxNzM0Njk0OTg3LCJpc3MiOiJ5b3VyLWFwcC1uYW1lIn0.Nt_fXevalnaAjmizI1a1cz32WEzjSaKNT_r4pMCsMfM"

enum AppAudioState {
    case disconnected   // when not connected to server
    case connecting     // when connecting to server
    case idle           // connected to ws, but transcriber not ready
    case listening      // AI finished talking, waiting for user input
    case recording  // user is currently holding button and speaking
    case thinking     // AI is processing user input
    case playing      // AI is sending audio back
}

struct ContentView: View {
    @State private var isUserNameSet = UserDefaults.standard.string(forKey: "userName") != nil
    @StateObject var storiesStore = StoriesStore()

//    init() {
//        UserDefaults.standard.removeObject(forKey: "userName")
//        print("Username has been cleared for debugging.")
//    }
    
    var body: some View {
        Group {
            if isUserNameSet {
                // Main content of the app, injecting environment object
                AppTabView()
                    .environmentObject(storiesStore)
            } else {
                // Show text entry screen
                TextEntryView(isUserNameSet: $isUserNameSet)
            }
        }
    }
}


// Email validation function
func isValidEmail(_ email: String) -> Bool {
    let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
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
                
                TextField("Enter a valid email address", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    // Usage in your logic
                    if !inputText.isEmpty && isValidEmail(inputText) {
                        // Save the username (email) to UserDefaults
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

struct AppTabView: View {
    @State private var selectedTab: Tab = .spark

    enum Tab {
        case spark, stories
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Label("Spark", systemImage: "house")
                }
                .tag(Tab.spark)

            DocumentsView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Stories", systemImage: "doc.text")
                }
                .tag(Tab.stories)
        }
    }
}

//struct StoryEditorView: View {
//    @Binding var story: Document
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 20) {
//            Text("Editing: \(story.story_name)")
//                .font(.headline)
//
//            TextEditor(text: $story.story)
//                .font(.body)
//                .padding()
//                .border(Color.gray, width: 1)
//                .cornerRadius(5)
//                .frame(maxHeight: .infinity)
//
//            Spacer()
//
//            Button(action: {
//                saveStory()
//            }) {
//                Text("Save Changes")
//                    .font(.headline)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//            }
//        }
//        .padding()
//        .navigationTitle("Edit Story")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func saveStory() {
//        guard let url = URL(string: "https://myatmos.pro/stories/\(story.id)") else {
//            print("Invalid URL")
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "PUT"
//        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        // Prepare the request body
//        let storyData: [String: Any] = [
//            "story_name": story.story_name,
//            "story": story.story,
//            "visible": story.visible
//        ]
//        guard let body = try? JSONSerialization.data(withJSONObject: storyData) else {
//            print("Failed to encode story data")
//            return
//        }
//        request.httpBody = body
//
//        // Perform the network request
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            // Handle network errors
//            if let error = error {
//                print("Failed to save story: \(error.localizedDescription)")
//                return
//            }
//
//            // Check HTTP response status
//            if let httpResponse = response as? HTTPURLResponse {
//                if httpResponse.statusCode == 200 {
//                    print("Story updated successfully!")
//                } else {
//                    print("Failed to update story: HTTP \(httpResponse.statusCode)")
//                    if let data = data,
//                       let errorResponse = try? JSONSerialization.jsonObject(with: data, options: []) {
//                        print("Error response: \(errorResponse)")
//                    }
//                }
//            }
//        }.resume()
//    }
//}

struct StoryEditorView: View {
    @Binding var story: Document
    @Environment(\.dismiss) var dismiss // To close the sheet

    @State private var updatedStoryName: String
    @State private var updatedStoryContent: String
    @State private var isSaving = false // Loading indicator for saving
    @State private var errorMessage: String? // Error message, if any

    init(story: Binding<Document>) {
        _story = story
        _updatedStoryName = State(initialValue: story.wrappedValue.story_name)
        _updatedStoryContent = State(initialValue: story.wrappedValue.story)
    }

    var body: some View {
        VStack {
            TextField("Story Title", text: $updatedStoryName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextEditor(text: $updatedStoryContent)
                .padding()
                .border(Color.gray, width: 1)
                .cornerRadius(8)
                .frame(maxHeight: .infinity)

            if isSaving {
                ProgressView("Saving...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: saveChanges) {
                Text("Save Changes")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Edit Story")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveChanges() {
        guard !updatedStoryName.isEmpty else {
            errorMessage = "Story title cannot be empty."
            return
        }
        guard !updatedStoryContent.isEmpty else {
            errorMessage = "Story content cannot be empty."
            return
        }

        isSaving = true
        errorMessage = nil

        // Update the local story object
        story.story_name = updatedStoryName
        story.story = updatedStoryContent

        // Send the updated story to the server
        updateStoryOnServer(
            storyID: story.id,
            updatedName: updatedStoryName,
            updatedContent: updatedStoryContent,
            isVisible: story.visible
        ) { success, error in
            DispatchQueue.main.async {
                isSaving = false

                if success {
                    dismiss() // Close the editor on success
                } else {
                    errorMessage = error ?? "Failed to save story. Please try again."
                }
            }
        }
    }

    private func updateStoryOnServer(
        storyID: String,
        updatedName: String,
        updatedContent: String,
        isVisible: Bool,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let url = URL(string: "https://myatmos.pro/stories/\(storyID)") else {
            completion(false, "Invalid URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "story_name": updatedName,
            "story": updatedContent,
            "visible": isVisible
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "Failed to encode story data.")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(false, "Server error: Failed to update story.")
                return
            }

            completion(true, nil) // Success
        }.resume()
    }
}




struct DocumentPayload: Decodable {
    let stories: [Document]
}

struct Document: Identifiable, Decodable {
    let id: String
    var story: String
    var story_name: String
    let user: String
    let visible: Bool
}

class StoriesStore: ObservableObject {
    @Published var stories: [Document] = []
    @Published var selectedStoryTitle: String? = nil

    // Helper to get the full Document based on the selected story title
    var selectedStory: Document? {
        stories.first(where: { $0.story_name == selectedStoryTitle })
    }
}



struct DocumentsView: View {
    @EnvironmentObject var storiesStore: StoriesStore
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedStory: Document? // Holds the currently selected story for editing
    
    @Binding var selectedTab: AppTabView.Tab

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Fetching documents...")
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                        Button("Retry") {
                            fetchDocuments()
                        }
                        .padding()
                    }
                } else {
                    List {
                        ForEach(storiesStore.stories, id: \.id) { document in
                            HStack {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(document.story_name)
                                        .font(.headline)
                                    Text(document.story)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Menu {
                                    Button(action: {
                                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let rootViewController = scene.windows.first?.rootViewController {
                                            shareStory(
                                                from: rootViewController,
                                                storyName: document.story_name,
                                                storyContent: document.story
                                            )
                                        }
                                    }) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }

                                    Button(action: {
                                        selectedStory = document // Set the selected story
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Button(action: {
                                        playAndConnect(document: document)
                                    }) {
                                        Label("Play", systemImage: "play.circle")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            .navigationTitle("Documents")
            .sheet(item: $selectedStory) { story in
                StoryEditorView(story: Binding(
                    get: { story },
                    set: { newStory in
                        // Update the story in the store
                        if let index = storiesStore.stories.firstIndex(where: { $0.id == newStory.id }) {
                            storiesStore.stories[index] = newStory
                        }
                    }
                ))
            }
            .onAppear {
                fetchDocuments()
            }
        }
    }

    // Function to handle play and WebSocket connection
    private func playAndConnect(document: Document) {
        selectedTab = .spark
        storiesStore.selectedStoryTitle = document.story_name
    }

    func shareStory(from viewController: UIViewController,
                    storyName: String,
                    storyContent: String) {
        let storyText = """
        Check out this I made with Spark!:

        Title: \(storyName)

        \(storyContent)

        Made with Spark
        https://www.sparkmeapp.com
        """
        let activityViewController = UIActivityViewController(activityItems: [storyText], applicationActivities: nil)
        activityViewController.excludedActivityTypes = [
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .assignToContact,
            .print,
            .saveToCameraRoll
        ]
        viewController.present(activityViewController, animated: true, completion: nil)
    }

    private func fetchDocuments() {
        guard let url = URL(string: "https://myatmos.pro/stories/get_stories") else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(TOKEN)", forHTTPHeaderField: "Authorization")

        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    errorMessage = "Failed to fetch documents"
                    return
                }
                do {
                    let decodedPayload = try JSONDecoder().decode(DocumentPayload.self, from: data)
                    storiesStore.stories = decodedPayload.stories
                } catch {
                    errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}


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


class AudioProcessor: ObservableObject {
    private let audioEngine = AVAudioEngine()
    let playerNodes: [String: AVAudioPlayerNode] = [
        "MUSIC": AVAudioPlayerNode(),
        "SFX": AVAudioPlayerNode(),
        "STORY": AVAudioPlayerNode()
    ]
    var previousStoryAudio: [Data] = []  // Store STORY audio chunks
    private let audioQueue = DispatchQueue(label: "com.audioprocessor.queue")
    var onAppStateChange: ((AppAudioState) -> Void)?
    var onBufferStateChange: ((Bool) -> Void)?
    
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
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
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
                print("Audio engine started with sample rate: \(sampleRate)")
            } catch {
                print("Error starting audio engine: \(error.localizedDescription)")
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
            print("STORY player node not found")
            return
        }

        let tapFormat = storyNode.outputFormat(forBus: 0)
        storyNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }

            let isBufferActive = self.isAudioBufferActive(buffer)
            onBufferStateChange?(isBufferActive)
        }
        print("Tap installed on STORY player node")
    }

    /// User is speaking, no need to monitor
    func stopMonitoringStoryPlayback() {
        guard let storyNode = playerNodes["STORY"] else {
            print("STORY player node not found")
            return
        }

        if storyNode.engine != nil {
            storyNode.removeTap(onBus: 0)
        } else {
            print("Attempted to remove tap on a node that is not attached to an engine.")
        }
        onAppStateChange?(.listening) // Ensure state is reset
        print("Tap removed from STORY player node")
    }

    /// Configure a tap on the input node to capture audio buffers.
    func configureInputTap(bufferSize: AVAudioFrameCount = 1024, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        let inputNode = audioEngine.inputNode
        let format = audioEngine.inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0) // Remove existing tap if any
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            onBuffer(buffer)
        }
        print("Input tap installed with bufferSize: \(bufferSize)")
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
            print("Unsupported audio format")
            return nil
        }
    }
    
    /// Start the audio engine.
    func startAudioEngine() {
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("Audio engine started")
            } catch {
                print("Failed to start audio engine: \(error.localizedDescription)")
            }
        }
    }

    /// Stop the audio engine and remove taps.
    func stopAudioEngine() {
        removeTap()
        if audioEngine.isRunning {
            audioEngine.stop()
            print("Audio engine stopped")
        }
    }
    
    func removeTap() {
        audioEngine.inputNode.removeTap(onBus: 0)
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
            print("All audio stopped")
        }
    }
    
    // Add a method to replay the stored STORY audio
    func replayStoryAudio() {
        audioQueue.async {
            guard !self.previousStoryAudio.isEmpty else {
                print("No STORY audio to replay.")
                return
            }
            print("Replay called")
            // Re-play all previously received STORY chunks
            for chunk in self.previousStoryAudio {
                self.playAudioChunk(audioData: chunk, indicator: "STORY", sampleRate: 24000, saveStory: false)
            }
        }
    }

    /// Play a chunk of audio data.
    func playAudioChunk(audioData: Data, indicator: String, volume: Float = 1.0, sampleRate: Double = 44100, saveStory: Bool = true) {
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
        
        if indicator == "STORY" && saveStory {
            // Store the chunk for later playback
            audioQueue.async {
                self.previousStoryAudio.append(audioData)
            }
        }
        
        if let playerNode = playerNodes[indicator] {
            audioQueue.async {
                if !self.audioEngine.isRunning {
                    self.setupAudioEngine()
                }
                
                let bytesPerSample = MemoryLayout<Int16>.size
                let frameCount = audioData.count / (bytesPerSample * Int(audioFormat.channelCount))
                
                // Create the source buffer
                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                    print("Failed to create AVAudioPCMBuffer")
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
                            print("Failed to get left channel data")
                            return
                        }
                        
                        // Mono: Duplicate the data into both left and right channels
                        for i in 0..<frameCount {
                            let sample = int16Samples[i]
                            leftChannel[i] = Float(sample) / Float(Int16.max) * volume * 2.3
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
//                            print("Error: Insufficient channels or nil floatChannelData.")
                            return
                        }
                    }

                    // Initialize the converter
                    guard let converter = AVAudioConverter(from: audioFormat, to: destinationFormat) else {
                        print("Failed to create AVAudioConverter")
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
                        print("Failed to create destination buffer")
                        return
                    }

                    // Perform the conversion
                    var error: NSError?
                    converter.convert(to: destinationBuffer, error: &error) { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return audioBuffer
                    }

                    if let error = error {
                        print("Error during conversion: \(error)")
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
                            print("Failed to get channel data")
                            return
                        }
                        for i in 0..<frameCount {
                            let left = int16Samples[i * 2]
                            let right = int16Samples[i * 2 + 1]
                            leftChannel[i] = Float(left) / Float(Int16.max) * 0.2
                            rightChannel[i] = Float(right) / Float(Int16.max) * 0.2
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
//    private var isStreaming = false
//    private var isConnected = false // Track connection state
    private let recieveQueue = DispatchQueue(label: "com.websocket.recieveQueue")
    struct AudioSequence {
        var indicator: String       // Indicator (e.g., "MUSIC" or "SFX")
        var accumulatedData: Data  // Accumulated audio data
        var packetsReceived: Int    // Number of packets received
        var sampleRate: Double
    }
    private var accumulatedAudio: [UUID: AudioSequence] = [:]
//    private var expectedAudioSize = 0     // Expected total size of the audio
    private let HEADER_SIZE = 37
    private var sessionID: String? = nil
//    private let maxAudioSize = 50 * 1024 * 1024 // 50MB in bytes

    var onAppStateChange: ((AppAudioState) -> Void)?
    var onMessageReceived: ((String) -> Void)? // Called for received text messages
    var onAudioReceived: ((Data, String, Double) -> Void)? // Called for received audio
//    var stopRecordingCallback: (() -> Void)?
    
    init(audioProcessor: AudioProcessor) {
        self.audioProcessor = audioProcessor
    }

    func connect(to url: URL, token: String, coAuthEnabled: Bool, musicEnabled: Bool, SFXEnabled: Bool, story_id: String) {
        stopAudioStream()
        disconnect() // Ensure any existing connection is closed

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(coAuthEnabled ? "True" : "False", forHTTPHeaderField: "CO-AUTH")
        request.setValue(musicEnabled ? "True" : "False", forHTTPHeaderField: "MUSIC")
        request.setValue(SFXEnabled ? "True" : "False", forHTTPHeaderField: "SFX")
        let username = UserDefaults.standard.string(forKey: "userName")
        request.setValue(username, forHTTPHeaderField: "userName")
        request.setValue(story_id, forHTTPHeaderField: "storyId")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessages()
    }


    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: "Client closing connection".data(using: .utf8))
        webSocketTask = nil
        sessionID = ""
        // Clear the accumulatedAudio buffer
        self.recieveQueue.async {
            self.accumulatedAudio = [:]
            print("Accumulated audio buffer cleared")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        DispatchQueue.main.async { [weak self] in
            self?.onAppStateChange?(.idle)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected with code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("Reason: \(reasonString)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.onAppStateChange?(.disconnected)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("WebSocket connection failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.disconnected)
            }
        }
    }

    func sendAudioStream() {
//        guard !isStreaming else { return } TODO
        onAppStateChange?(.recording)
        print("Streaming Audio")

        audioProcessor.configureInputTap(bufferSize: 1024) { [weak self] buffer in
            guard let self = self else { return }
            if let audioData = self.audioProcessor.convertPCMBufferToData(buffer: buffer) {
                self.sendData(audioData)
            } else {
                print("Failed to convert audio buffer to data")
            }
        }
        audioProcessor.startAudioEngine()
    }

    func stopAudioStream() {
        audioProcessor.removeTap()
    }
        
    func processSessionUpdate(sessionID: String?) {
        if let uuidString = sessionID, UUID(uuidString: uuidString) != nil {
            // sessionID is a valid UUID
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.listening)
            }
        } else {
            // sessionID is not valid
            DispatchQueue.main.async { [weak self] in
                self?.onAppStateChange?(.idle)
            }
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
    
    func sendTextMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Failed to send text message: \(error.localizedDescription)")
            } else {
                print("Text message sent: \(text)")
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
                    print("Unknown WebSocket message type")
                }

                // Continue listening for messages
                self.receiveMessages()

            case .failure(let error):
                print("Failed to receive message: \(error.localizedDescription)")

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
            }
            // TODO process other messages from the server
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
                print("Error: Incomplete header")
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
            
            print("Indicator: \(indicator), Sequence ID: \(sequenceID), Packet: \(packetCount)/\(totalPackets), Sample Rate: \(sampleRate), Packet Size: \(packetSize)")
            
            // If this is a new STORY sequence, clear the previously stored story audio.
            if indicator == "STORY" && self.accumulatedAudio[sequenceID] == nil {
                DispatchQueue.main.async {
                    self.audioProcessor.previousStoryAudio.removeAll()
                    print("Cleared previous story")
                }
            }
            
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
                print("Updated Sequence \(sequenceID): Packets Received = \(sequence.packetsReceived)")
                let chunkSize = 2048 // Adjust as needed
                while sequence.accumulatedData.count >= chunkSize {
                    let chunk = sequence.accumulatedData.prefix(chunkSize)
                    sequence.accumulatedData.removeFirst(chunkSize)
                    // Reassign the modified value back to the dictionary
                    self.accumulatedAudio[sequenceID] = sequence
                    if sequence.indicator == "STORY"{
                        DispatchQueue.main.async {
                            self.onAppStateChange?(.playing)
                        }
                    }
                    if sequence.indicator == "FILL" {
                        DispatchQueue.main.async {
                            self.onAppStateChange?(.thinking)
                            self.onAudioReceived?(chunk, "STORY", sequence.sampleRate)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.onAudioReceived?(chunk, sequence.indicator, sequence.sampleRate)
                        }
                    }
                    
                }
                if sequence.packetsReceived == totalPackets  {
                    print("Received complete sequence for \(sequence.indicator) with ID \(sequenceID)")
                    self.accumulatedAudio.removeValue(forKey: sequenceID)
                }
            }
            
        }
    }
}



#Preview {
    ContentView()
}
