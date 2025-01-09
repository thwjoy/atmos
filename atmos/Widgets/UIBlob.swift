//
//  UIBlob.swift
//  Spark
//
//  Created by Tom Joy on 03/01/2025.
//

import Foundation
import SwiftUI
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
    
    var globalSpinAngle: CGFloat = 0.0

    // Properties/timers for continuous shaking
    private var isShakingContinuously = false
    private var shakeTimer: Timer?

    // ─────────────────────────────────────────────────────────────────────────
    // NEW: Spin properties
    private var isSpinningContinuously = false
    private var spinTimer: Timer?
    // ─────────────────────────────────────────────────────────────────────────

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

        // Build the "points" that define the blob
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

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Shaking Interfaces
    // ─────────────────────────────────────────────────────────────────────────

    /// Begin shaking in a continuous manner
    public func shakeContinuously() {
        isShakingContinuously = true
        shake()  // Start shaking immediately
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.5,
                                          repeats: true) { [weak self] _ in
            self?.shake() // Apply random shake periodically
        }
    }

    /// Stop continuous shaking
    public func stopShakeContinuously() {
        isShakingContinuously = false
        shakeTimer?.invalidate()
        shakeTimer = nil
    }

    /// Apply one instance of random shake
    public func shake() {
        // Only apply shake if continuously set or if there's no timer
        guard isShakingContinuously || shakeTimer != nil else { return }

        var randomIndices: [Int] = Array(0...numPoints)
        randomIndices.shuffle()
        randomIndices = Array(randomIndices.prefix(5))
        for index in randomIndices {
            points[index].acceleration = -0.3 + CGFloat(Float(arc4random()) / Float(UINT32_MAX)) * 0.6
        }

        stopped = false
        UIBlob.blobStarted()
    }

    /// Completely reset blob points
    public func stopShake() {
        for i in 0...numPoints {
            let point = points[i]
            point.acceleration = 0
            point.speed = 0
            point.radialEffect = 0
        }
        setNeedsDisplay()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - SPIN Interfaces (NEW)
    // ─────────────────────────────────────────────────────────────────────────

    /// Begin spinning in a continuous manner
    public func spinContinuously() {
        guard !isSpinningContinuously else { return }
        isSpinningContinuously = true

        spinTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0/60.0,
            repeats: true
        ) { [weak self] _ in
            self?.applySpin()
        }
    }

    /// Stop spinning continuously
    public func stopSpinContinuously() {
        isSpinningContinuously = false
        spinTimer?.invalidate()
        spinTimer = nil
    }

    /// Increment the global angle by a small amount
    private func applySpin() {
        // E.g. rotate by 0.02 radians (~1.15 degrees) each frame
        globalSpinAngle += 0.02
        // Trigger a redraw to reflect the new angle
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Drawing
    // ─────────────────────────────────────────────────────────────────────────

    public override func draw(_ rect: CGRect) {
        UIGraphicsGetCurrentContext()?.flush()
        render(frame: rect)
    }

    private func render(frame: CGRect) {
        guard points.count >= numPoints else { return }

        // Create the bezier path
        let bezierPath = createBezierPath()

        // Draw gradient fill or solid fill using the `color` property
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()

            // Clip to the bezier path
            context.addPath(bezierPath.cgPath)
            context.clip()

            // Use the `color` property to fill the blob
            let blobColor = color.cgColor

            // Optional: Apply a gradient using the blob's color
            let gradientColors = [
                blobColor,                                  // Fully opaque center
                blobColor.copy(alpha: 0.5) ?? blobColor,    // Semi-transparent
                blobColor.copy(alpha: 0.0) ?? blobColor     // Fully transparent at edges
            ]
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: gradientColors as CFArray,
                locations: locations
            )!

            // Draw a radial gradient for the blob
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radius = max(frame.width, frame.height) / 2
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )

            context.restoreGState()
        }
    }

    private func createBezierPath() -> UIBezierPath {
        let p0 = points[numPoints - 1].getPosition()
        var p1 = points[0].getPosition()
        let _p2 = p1
        let bezierPath = UIBezierPath()
        bezierPath.move(
            to: CGPoint(
                x: (p0.x + p1.x) / 2.0,
                y: (p0.y + p1.y) / 2.0
            )
        )

        for i in 0..<numPoints {
            let p2 = points[i].getPosition()
            let xc = (p1.x + p2.x) / 2.0
            let yc = (p1.y + p2.y) / 2.0

            bezierPath.addQuadCurve(
                to: CGPoint(x: xc, y: yc),
                controlPoint: CGPoint(x: p1.x, y: p1.y)
            )
            p1 = p2
        }

        let xc = (p1.x + _p2.x) / 2.0
        let yc = (p1.y + _p2.y) / 2.0
        bezierPath.addQuadCurve(
            to: CGPoint(x: xc, y: yc),
            controlPoint: CGPoint(x: p1.x, y: p1.y)
        )
        bezierPath.close()

        return bezierPath
    }

    private func divisional() -> CGFloat {
        return .pi * 2.0 / CGFloat(numPoints)
    }

    fileprivate func center() -> CGPoint {
        CGPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)
    }

    // MARK: - Animation update logic

    static func blobStarted() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(updateDeltaTime))
        displayLink?.add(to: RunLoop.main, forMode: .common)
    }

    static func blobStopped() {
        guard blobs.filter({ $0.stopped == false }).count == 0 else { return }
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
            var stopped = self.points[0].solveWith(
                leftPoint: self.points[self.numPoints - 1],
                rightPoint: self.points[1]
            )
            if !stopped { allDone = false }

            for i in 1...self.numPoints {
                let left = self.points[i - 1]
                let right = (i + 1 <= self.numPoints) ? self.points[i + 1] : self.points[0]
                stopped = self.points[i].solveWith(leftPoint: left, rightPoint: right)
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

        // The radial effect, speed, and acceleration remain the same
        // We just ask the parent for the global spin offset
        let finalAngle = (azimuth) + parent.globalSpinAngle
        let x = cos(finalAngle)
        let y = sin(finalAngle)

        return CGPoint(
            x: parent.center().x + x * (parent.radius + self.radialEffect),
            y: parent.center().y + y * (parent.radius + self.radialEffect)
        )
    }
    
}

struct UIBlobWrapper: UIViewRepresentable {
    @Binding var isShaking: Bool
    @Binding var isSpinning: Bool
    @Binding var color: Color

    func makeUIView(context: Context) -> UIBlob {
        let uiBlob = UIBlob()
        uiBlob.color = UIColor(color)
        context.coordinator.uiBlob = uiBlob
        return uiBlob
    }

    func updateUIView(_ uiView: UIBlob, context: Context) {
        print("UIBlobWrapper: updateUIView called — isShaking = \(isShaking), isSpinning = \(isSpinning)")
        uiView.color = UIColor(color) // Update blob color
        context.coordinator.updateShakingState(isShaking: isShaking)
        context.coordinator.updateSpinningState(isSpinning: isSpinning)
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
            print("Coordinator: updateShakingState — isShaking = \(isShaking)")

            if isShaking {
                uiBlob.shakeContinuously()
            } else {
                uiBlob.stopShakeContinuously()
            }
        }

        func updateSpinningState(isSpinning: Bool) {
            guard let uiBlob = uiBlob else { return }
            print("Coordinator: updateSpinningState — isSpinning = \(isSpinning)")

            if isSpinning {
                uiBlob.spinContinuously()
            } else {
                uiBlob.stopSpinContinuously()
            }
        }
    }
}


