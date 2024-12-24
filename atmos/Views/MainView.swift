//
//  MainView.swift
//  Spark
//
//  Created by Tom Joy on 23/12/2024.
//

import Foundation
import Combine
import SwiftUI


//
//  UIBlob.swift
//  UIBlob
//
//  Created by Daniel Eke on 20/01/2020.
//  Copyright © 2020 Daniel Eke. All rights reserved.
//

import UIKit

open class UIBlob: UIView {

    private static var displayLink: CADisplayLink?
    private static var blobs: [UIBlob] = []

    private var points: [UIBlobPoint] = []
    private var numPoints = 32
    fileprivate var radius: CGFloat = 0

    @IBInspectable public var color: UIColor = .black {
        didSet { self.setNeedsDisplay() }
    }
    public var stopped = true
    private var isShakingContinuously = false // New property for continuous shaking
    private var shakeTimer: Timer? // Timer for continuous shaking

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        for i in 0...numPoints {
            let point = UIBlobPoint(azimuth: self.divisional() * CGFloat(i + 1), parent: self)
            points.append(point)
        }
        UIBlob.blobs.append(self)
    }

    deinit {
        destroy()
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        destroy()
    }

    private func destroy() {
        UIBlob.blobs.removeAll { $0 == self }
        UIBlob.blobStopped()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        radius = frame.size.width / 3
    }

    // MARK: Public interfaces

    public func shakeContinuously() {
        isShakingContinuously = true
        shake() // Start shaking immediately
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.shake() // Continue shaking periodically
        }
    }

    public func stopShakeContinuously() {
        isShakingContinuously = false
        shakeTimer?.invalidate()
        shakeTimer = nil
//        stopShake() // Stop shaking immediately
    }

    public func shake() {
        guard isShakingContinuously || shakeTimer == nil else { return }
        var randomIndices: [Int] = Array(0...numPoints)
        randomIndices.shuffle()
        randomIndices = Array(randomIndices.prefix(5))
        for index in randomIndices {
            points[index].acceleration = -0.3 + CGFloat(Float(arc4random()) / Float(UINT32_MAX)) * 0.6
        }
        stopped = false
        UIBlob.blobStarted()
    }

    public func stopShake() {
        for i in 0...numPoints {
            let point = points[i]
            point.acceleration = 0
            point.speed = 0
            point.radialEffect = 0
        }
        setNeedsDisplay()
    }

    // MARK: Rendering

    public override func draw(_ rect: CGRect) {
        UIGraphicsGetCurrentContext()?.flush()
        render(frame: rect)
    }

    private func render(frame: CGRect) {
        guard points.count >= numPoints else { return }

        // Create the bezier path
        let bezierPath = createBezierPath()

        // Draw gradient fill
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()

            // Clip to the bezier path
            context.addPath(bezierPath.cgPath)
            context.clip()

            // Create a gold gradient with opacity at the edges
            let gradientColors = [
                UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor,  // Bright gold (fully opaque)
                UIColor(red: 1.0, green: 0.72, blue: 0.0, alpha: 0.7).cgColor,  // Semi-transparent gold
                UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.4).cgColor, // More transparent gold
                UIColor.clear.cgColor // Fully transparent at the edges
            ]
            let locations: [CGFloat] = [0.0, 0.5, 0.8, 1.0]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: locations)!

            // Use a radial gradient to fade out the edges
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radius = max(frame.width, frame.height) / 2
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])

            context.restoreGState()
        }
    }

    private func createBezierPath() -> UIBezierPath {
        let p0 = points[numPoints - 1].getPosition()
        var p1 = points[0].getPosition()
        let _p2 = p1
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0))

        for i in 0..<numPoints {
            let p2 = points[i].getPosition()
            let xc = (p1.x + p2.x) / 2.0
            let yc = (p1.y + p2.y) / 2.0

            bezierPath.addQuadCurve(to: CGPoint(x: xc, y: yc), controlPoint: CGPoint(x: p1.x, y: p1.y))
            p1 = p2
        }

        let xc = (p1.x + _p2.x) / 2.0
        let yc = (p1.y + _p2.y) / 2.0
        bezierPath.addQuadCurve(to: CGPoint(x: xc, y: yc), controlPoint: CGPoint(x: p1.x, y: p1.y))
        bezierPath.close()

        return bezierPath
    }

    private func divisional() -> CGFloat {
        return .pi * 2.0 / CGFloat(numPoints)
    }

    fileprivate func center() -> CGPoint {
        return CGPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)
    }

    // MARK: Animation update logic

    static func blobStarted() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(updateDeltaTime))
        displayLink?.add(to: RunLoop.main, forMode: .common)
    }

    static func blobStopped() {
        guard blobs.filter({ ($0).stopped == false }).count == 0 else { return }
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private static func updateDeltaTime(link: CADisplayLink) {
        blobs.filter { $0.stopped == false }.forEach { $0.update() }
        usleep(10)
    }

    @objc private func update() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var allDone = true
            var stopped = self.points[0].solveWith(leftPoint: self.points[self.numPoints-1], rightPoint: self.points[1])
            if !stopped { allDone = false }
            for i in 1...self.numPoints {
                if i + 1 < self.numPoints {
                    stopped = self.points[i].solveWith(leftPoint: self.points[i-1], rightPoint: self.points[i+1])
                } else {
                    stopped = self.points[i].solveWith(leftPoint: self.points[i-1], rightPoint: self.points[0])
                }
                if !stopped { allDone = false }
            }

            DispatchQueue.main.async { [weak self] in
                if allDone {
                    self?.stopped = true
                    UIBlob.blobStopped()
                }
                self?.setNeedsDisplay()
            }
        }
    }
}

fileprivate class UIBlobPoint {
    
    private weak var parent: UIBlob?
    private let azimuth: CGFloat
    fileprivate var speed: CGFloat = 0 {
        didSet {
            radialEffect += speed * 3
        }
    }
    fileprivate var acceleration: CGFloat = 0 {
        didSet {
            speed += acceleration * 2
        }
    }
    fileprivate var radialEffect: CGFloat = 0
    private var elasticity: CGFloat = 0.001
    private var friction: CGFloat = 0.0085
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    
    init(azimuth: CGFloat, parent: UIBlob) {
        self.parent = parent
        self.azimuth = .pi - azimuth
        let randomZeroToOne = CGFloat(Float(arc4random()) / Float(UINT32_MAX))
        self.acceleration = -0.3 + randomZeroToOne * 0.6
        self.x = cos(self.azimuth)
        self.y = sin(self.azimuth)
    }
    
    func solveWith(leftPoint: UIBlobPoint, rightPoint: UIBlobPoint) -> Bool {
        self.acceleration = (-0.3 * self.radialEffect
            + ( leftPoint.radialEffect - self.radialEffect )
            + ( rightPoint.radialEffect - self.radialEffect ))
            * self.elasticity - self.speed * self.friction;
        
        // Consider the point stopped if the acceleration is below the treshold
        let isStill = abs(acceleration) < 0.0001
        return isStill
    }
    
    func getPosition() -> CGPoint {
        guard let parent = self.parent else { return .zero }
        return CGPoint(
            x: parent.center().x + self.x * (parent.radius + self.radialEffect),
            y: parent.center().y + self.y * (parent.radius + self.radialEffect)
        )
    }
    
}

struct UIBlobWrapper: UIViewRepresentable {
    @Binding var isShaking: Bool

    func makeUIView(context: Context) -> UIBlob {
        let uiBlob = UIBlob()
        context.coordinator.uiBlob = uiBlob
        return uiBlob
    }

    func updateUIView(_ uiView: UIBlob, context: Context) {
        print("UIBlobWrapper: updateUIView called with isShaking = \(isShaking)")
        context.coordinator.updateShakingState(isShaking: isShaking)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: UIBlobWrapper
        weak var uiBlob: UIBlob?

        init(_ parent: UIBlobWrapper) {
            self.parent = parent
        }

        func updateShakingState(isShaking: Bool) {
            guard let uiBlob = uiBlob else { return }
            print("Coordinator: updateShakingState called with isShaking = \(isShaking)")

            if isShaking {
                print("Coordinator: Starting Continuous Shake")
                uiBlob.shakeContinuously()
            } else {
                print("Coordinator: Stopping Continuous Shake")
                uiBlob.stopShakeContinuously()
            }
        }
    }
}



class AppAudioStateViewModel: ObservableObject {
    @Published var appAudioState: AppAudioState = .disconnected
}

struct MainView: View {
    @EnvironmentObject var storiesStore: StoriesStore   // <— Use the store
    @StateObject private var appAudioStateViewModel = AppAudioStateViewModel()

    @State private var isPressed = false
    @State private var isShaking = false // State to control blob shaking
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
        switch appAudioStateViewModel.appAudioState {
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
    
    private var connectionButton: String {
        switch appAudioStateViewModel.appAudioState {
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
        if appAudioStateViewModel.appAudioState != .disconnected {
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
        DispatchQueue.main.async {
            appAudioStateViewModel.appAudioState = .connecting
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
                            if appAudioStateViewModel.appAudioState == .listening || appAudioStateViewModel.appAudioState == .recording {
                                isPressed = true
                                holdStartTime = Date() // Record the start time of the press

                                // Cancel any existing simulated hold
                                simulatedHoldTask?.cancel()
                                simulatedHoldTask = nil

                                webSocketManager.sendAudioStream() // Start streaming
                                webSocketManager.sendTextMessage("START")
                                DispatchQueue.main.async {
                                    appAudioStateViewModel.appAudioState = .recording
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            let remainingTime = 1
                            isPressed = false

                            // Create a new simulated hold task
                            simulatedHoldTask = DispatchWorkItem {
                                appAudioStateViewModel.appAudioState = .thinking
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
                if appAudioStateViewModel.appAudioState != .disconnected {
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

        // Internal states
        @State private var controlPoints: [CGFloat] = Array(repeating: 1.0, count: 12)
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
            .frame(width: 200, height: 200)
            .onAppear {
                initializeControlPoints()
                startRotation()
            }
            .onChange(of: pointiness) { _, _ in initializeControlPoints() }
            .onChange(of: radiusVariation) { _, _ in initializeControlPoints() }
            .onChange(of: rotationSpeed) { _, _ in startRotation() }
        }

        private func initializeControlPoints() {
            // Recalculate control points dynamically based on `pointiness` and `radiusVariation`
            controlPoints = Array(repeating: 1.0, count: controlPoints.count).enumerated().map { index, _ in
                // Ensure control points create a circle when pointiness is 0
                1.0 + CGFloat.random(in: 0.0...1.0) * pointiness * radiusVariation
            }
        }

        private func calculateFrequencies() -> [CGFloat] {
            // Dynamically calculate control point frequencies based on `speed`
            return (0..<controlPoints.count).map { _ in CGFloat.random(in: 0.5...1.5) * CGFloat(speed) }
        }

        private func calculateAmplitudes() -> [CGFloat] {
            // Dynamically calculate control point amplitudes based on `radiusVariation`
            return (0..<controlPoints.count).map { _ in CGFloat.random(in: 0.1...0.5) * radiusVariation }
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
        var radiusVariation: CGFloat
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

                // Use a fixed base radius when pointiness and radiusVariation are 0
                let finalRadius = radiusVariation > 0 || pointiness > 0 ? radius : baseRadius
                let x = center.x + finalRadius * cos(angle)
                let y = center.y + finalRadius * sin(angle)
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

//    // Properties for the AnimatedBlob
//    @State private var pointiness: CGFloat = 1.0
//    @State private var speed: Double = 0.5
//    @State private var radiusVariation: CGFloat = 0.01
//    @State private var rotationSpeed: Double = 0.0

//    private func getBlob() -> AnimatedBlob {
//        switch appAudioStateViewModel.appAudioState {
//        case .playing:
//            return AnimatedBlob(
//                pointiness: 0.5,
//                speed: 2.0,
//                radiusVariation: 0.8,
//                rotationSpeed: 0.0
//            )
//        case .listening, .recording:
//            return AnimatedBlob(
//                pointiness: 1.0,
//                speed: 0.5,
//                radiusVariation: 0.01,
//                rotationSpeed: 0.0
//            )
//        case .thinking:
//            return AnimatedBlob(
//                pointiness: 1.0,
//                speed: 1.0,
//                radiusVariation: 0.02,
//                rotationSpeed: 0.05
//            )
//        default:
//            // Return a default AnimatedBlob configuration if the state doesn't match
//            return AnimatedBlob(
//                pointiness: 0.0,
//                speed: 0.0,
//                radiusVariation: 0.0,
//                rotationSpeed: 0.0
//            )
//        }
//    }

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
                if appAudioStateViewModel.appAudioState != .disconnected {
                    UIBlobWrapper(isShaking: $isShaking)
                        .frame(width: 200, height: 200)
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
//                audioProcessor.onAppStateChange = { storyState in
//                    DispatchQueue.main.async {
//                        print("New AP Status: \(storyState)")
//                    }
//                    if storyState != .listening || storyState != .recording {
//                        webSocketManager.stopAudioStream()
//                    }
//                }
                audioProcessor.onBufferStateChange = { state in
                    if !state {
                        if appAudioStateViewModel.appAudioState == .playing {
                            DispatchQueue.main.async {
                                appAudioStateViewModel.appAudioState = .listening
                                print("New buff status \(appAudioStateViewModel.appAudioState)")
                            }
                        }
                    }
                }
                webSocketManager.onAppStateChange = { status in
                    DispatchQueue.main.async {
                        if self.appAudioStateViewModel.appAudioState != status {
                            self.appAudioStateViewModel.appAudioState = status
                            print("New WS status: \(status)")
                            let shouldShake = (status == .playing)
                            if self.isShaking != shouldShake {
                                self.isShaking = shouldShake
                                print("MainView: isShaking updated to \(self.isShaking)")
                            }
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
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false // Re-enable screen auto-lock
                disconnect()
                audioProcessor.stopAllAudio()
//                audioProcessor.onAppStateChange = nil
                webSocketManager.onAppStateChange = nil
                webSocketManager.onAudioReceived = nil
            }
        }
    }
}
