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

    struct AnimatedBlob: View {
        // Dynamic parameters from parent
        var pointiness: CGFloat
        var speed: Double
        var radiusVariation: CGFloat
        var rotationSpeed: Double

        // Internal states (now recalculated dynamically)
        @State private var controlPoints: [CGFloat] = Array(repeating: 1.0, count: 8)
        @State private var rotationAngle: CGFloat = 0.0

        var body: some View {
            BlobShape(
                controlPoints: controlPoints,
                angleOffsets: randomAngleOffsets(count: controlPoints.count),
                distanceOffsets: randomDistanceOffsets(count: controlPoints.count),
                controlPointPhases: Array(repeating: 0.0, count: controlPoints.count),
                controlPointFrequencies: calculateFrequencies(),
                controlPointAmplitudes: calculateAmplitudes(),
                pointiness: pointiness,
                radiusVariation: radiusVariation,
                rotationAngle: rotationAngle
            )
            .fill(Color.purple)
            .frame(width: 300, height: 300)
            .onAppear {
                initializeControlPoints()
                startRotation()
            }
            .onChange(of: pointiness) { _, _ in initializeControlPoints() }
            .onChange(of: speed) { _, _ in initializeControlPoints() }
            .onChange(of: rotationSpeed) { _, _ in startRotation() }
        }

        private func initializeControlPoints() {
            // Recalculate control points dynamically based on `pointiness` and `speed`
            controlPoints = Array(repeating: 1.0, count: 8).enumerated().map { index, _ in
                1.0 + CGFloat.random(in: 0.6...1.5) * CGFloat(pointiness)
            }
        }

        private func calculateFrequencies() -> [CGFloat] {
            // Dynamically calculate control point frequencies based on `speed`
            return (0..<controlPoints.count).map { _ in CGFloat.random(in: 0.5...1.5) * CGFloat(speed) }
        }

        private func calculateAmplitudes() -> [CGFloat] {
            // Dynamically calculate control point amplitudes based on `radiusVariation`
            return (0..<controlPoints.count).map { _ in CGFloat.random(in: 0.1...0.5) * CGFloat(radiusVariation) }
        }

        private func startRotation() {
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                rotationAngle += CGFloat(0.02 * rotationSpeed)
            }
        }

        private func randomAngleOffsets(count: Int) -> [CGFloat] {
            (0..<count).map { _ in CGFloat.random(in: -(.pi / 8)...(.pi / 8)) }
        }

        private func randomDistanceOffsets(count: Int) -> [CGFloat] {
            (0..<count).map { _ in CGFloat.random(in: -40...40) }
        }
    }



    struct BlobShape: Shape {
        var controlPoints: [CGFloat]
        var angleOffsets: [CGFloat]
        var distanceOffsets: [CGFloat]
        var controlPointPhases: [CGFloat]
        var controlPointFrequencies: [CGFloat]
        var controlPointAmplitudes: [CGFloat]
        var pointiness: CGFloat
        var radiusVariation: CGFloat // NEW: Radius variation control
        var rotationAngle: CGFloat

        var animatableData: AnimatableVector {
            get { AnimatableVector(values: controlPoints) }
            set { controlPoints = newValue.values }
        }

        func path(in rect: CGRect) -> Path {
            let width = rect.width
            let height = rect.height
            let center = CGPoint(x: rect.midX, y: rect.midY)

            let count = controlPoints.count
            let angleStep = 2 * CGFloat.pi / CGFloat(count)
            let baseRadius = min(width, height) / 2

            var points: [CGPoint] = []
            for i in 0..<count {
                // Compute the angle for each point
                let angle = angleStep * CGFloat(i) + angleOffsets[i] + rotationAngle

                // Oscillate radius independently for each point
                let oscillation = sin(controlPointPhases[i]) * controlPointAmplitudes[i]
                let radius = baseRadius * controlPoints[i] + (distanceOffsets[i] * pointiness * oscillation * radiusVariation)

                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }

            return createSmoothClosedPath(points: points)
        }

        private func createSmoothClosedPath(points: [CGPoint]) -> Path {
            var path = Path()
            guard points.count > 1 else { return path }

            path.move(to: points[0])
            let count = points.count

            for i in 0..<count {
                let p0 = points[i]
                let p1 = points[(i + 1) % count]
                let pMinus1 = points[(i - 1 + count) % count]
                let pPlus1 = points[(i + 2) % count]

                let smoothness: CGFloat = 0.2

                let v1 = CGPoint(
                    x: (p1.x - pMinus1.x) * smoothness,
                    y: (p1.y - pMinus1.y) * smoothness
                )
                let c1 = CGPoint(x: p0.x + v1.x, y: p0.y + v1.y)

                let v2 = CGPoint(
                    x: (pPlus1.x - p0.x) * smoothness,
                    y: (pPlus1.y - p0.y) * smoothness
                )
                let c2 = CGPoint(x: p1.x - v2.x, y: p1.y - v2.y)

                path.addCurve(to: p1, control1: c1, control2: c2)
            }

            path.closeSubpath()
            return path
        }
    }

    // For animating arrays of CGFloat
    struct AnimatableVector: VectorArithmetic {
        var values: [CGFloat]

        static var zero: AnimatableVector {
            AnimatableVector(values: [])
        }

        static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
            AnimatableVector(values: zip(lhs.values, rhs.values).map(+))
        }

        static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
            AnimatableVector(values: zip(lhs.values, rhs.values).map(-))
        }

        mutating func scale(by rhs: Double) {
            values = values.map { $0 * CGFloat(rhs) }
        }

        var magnitudeSquared: Double {
            values.map { Double($0 * $0) }.reduce(0, +)
        }

        static func * (lhs: AnimatableVector, rhs: Double) -> AnimatableVector {
            AnimatableVector(values: lhs.values.map { $0 * CGFloat(rhs) })
        }

        static func *= (lhs: inout AnimatableVector, rhs: Double) {
            lhs = lhs * rhs
        }
    }

    // Properties for the AnimatedBlob
    @State private var pointiness: CGFloat = 1.0
    @State private var speed: Double = 0.5
    @State private var radiusVariation: CGFloat = 0.01
    @State private var rotationSpeed: Double = 0.0

    private func updateBlobParameters(for state: AppAudioState) {
        withAnimation(.easeInOut(duration: 0.5)) {
            print(state)
            switch state {
            case .playing:
                pointiness = 0.5
                speed = 2.0
                radiusVariation = 0.8
                rotationSpeed = 0.0
            case .listening, .recording:
                pointiness = 1.0
                speed = 0.5
                radiusVariation = 0.01
                rotationSpeed = 0.0
            case .thinking:
                pointiness = 1.0
                speed = 1.0
                radiusVariation = 0.02
                rotationSpeed = 1.0
            case .disconnected:
                pointiness = 0.0
                speed = 0.0
                radiusVariation = 0.0
                rotationSpeed = 0.0
            default:
                break
            }
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
                    AnimatedBlob(
                        pointiness: pointiness,
                        speed: speed,
                        radiusVariation: radiusVariation,
                        rotationSpeed: rotationSpeed
                    )
                    .frame(width: 300, height: 300)
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
                        print("New status: \(status)")
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
        .onChange(of: appAudioState) { newState, _ in
            print("Change state \(newState)")
            updateBlobParameters(for: newState)
        }
    }
}
