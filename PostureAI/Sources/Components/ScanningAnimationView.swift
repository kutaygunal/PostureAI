import SwiftUI
import AVFoundation

// MARK: - Simplified Scanning Animation View (No Up/Down Motion)

struct ScanningAnimationView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var borderWidth: CGFloat = 3
    
    let isActive: Bool
    let status: ScanStatus
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static glow that only pulses (no vertical movement)
                statusColor
                    .opacity(isActive ? glowOpacity : 0)
                    .blur(radius: 30)
                    .scaleEffect(pulseScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Static border pulse
                RoundedRectangle(cornerRadius: 24)
                    .stroke(statusColor, lineWidth: isActive ? borderWidth : 0)
                    .opacity(isActive ? 1 : 0)
                    .frame(
                        width: geometry.size.width - 40,
                        height: geometry.size.height * 0.85
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: isActive) { _, new in
            if new { startAnimation() } else { stopAnimation() }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .detectedHoldStill, .sideViewGood:
            return .green
        case .moveCloser, .moveBack, .turnToSide, .turnMoreToSide:
            return .orange
        case .captured:
            return .blue
        default:
            return .cyan
        }
    }
    
    private func startAnimation() {
        // Very subtle pulse - no vertical movement
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.02
            glowOpacity = 0.4
            borderWidth = 4
        }
    }
    
    private func stopAnimation() {
        pulseScale = 1.0
        glowOpacity = 0.3
        borderWidth = 3
    }
}

// MARK: - Enhanced Skeleton Overlay (No movement)

struct EnhancedSkeletonOverlayView: View {
    let pose: PoseData
    
    var body: some View {
        Canvas { context, size in
            // Draw connections with glow
            for connection in PoseEstimator.jointConnections {
                guard let startJoint = pose.joint(connection.0),
                      let endJoint = pose.joint(connection.1) else {
                    continue
                }
                
                let startPoint = CGPoint(
                    x: startJoint.position.x * size.width,
                    y: startJoint.position.y * size.height
                )
                let endPoint = CGPoint(
                    x: endJoint.position.x * size.width,
                    y: endJoint.position.y * size.height
                )
                
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                
                let avgConfidence = (startJoint.confidence + endJoint.confidence) / 2
                let color = confidenceColor(avgConfidence)
                
                // Static glow effect (no animation)
                context.stroke(path, with: .color(color.opacity(0.3)), lineWidth: 12)
                context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 8)
                context.stroke(path, with: .color(color), lineWidth: 4)
            }
            
            // Draw joints with glow
            for (_, joint) in pose.joints {
                let point = CGPoint(
                    x: joint.position.x * size.width,
                    y: joint.position.y * size.height
                )
                
                let circle = Path(ellipseIn: CGRect(
                    x: point.x - 8,
                    y: point.y - 8,
                    width: 16,
                    height: 16
                ))
                
                let color = confidenceColor(joint.confidence)
                
                context.fill(circle, with: .color(color.opacity(0.4)))
                context.fill(Path(ellipseIn: CGRect(
                    x: point.x - 6,
                    y: point.y - 6,
                    width: 12,
                    height: 12
                )), with: .color(color))
                context.stroke(circle, with: .color(.white), lineWidth: 2)
            }
        }
        .ignoresSafeArea()
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.7 {
            return .cyan
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Static Glow Effect

struct StatusGlow: View {
    let status: ScanStatus
    let isActive: Bool
    
    var statusColor: Color {
        switch status {
        case .detectedHoldStill, .sideViewGood:
            return .green
        case .moveCloser, .moveBack, .turnToSide, .turnMoreToSide:
            return .orange
        case .captured:
            return .blue
        default:
            return .cyan
        }
    }
    
    var body: some View {
        statusColor
            .opacity(isActive ? 0.3 : 0)
            .blur(radius: 60)
    }
}

// MARK: - Static Particles (No movement)

struct StaticParticles: View {
    let status: ScanStatus
    let isActive: Bool
    
    var body: some View {
        EmptyView() // Remove particle animation
    }
}

// MARK: - Pulse Ring Animation

struct PulseRingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.cyan.opacity(0.3 - Double(index) * 0.08), lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.5 + CGFloat(index) * 0.3 : 1)
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Success Celebration Animation

struct SuccessCelebrationView: View {
    @State private var showConfetti = false
    @State private var ringScale: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 200, height: 200)
                
                Circle()
                    .stroke(Color.green, lineWidth: 4)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ringScale)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(checkmarkScale)
            }
            
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            performAnimation()
        }
    }
    
    private func performAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            ringScale = 1
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
            checkmarkScale = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showConfetti = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle, containerSize: geometry.size)
                }
            }
        }
        .onAppear {
            generateConfetti()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.green, .cyan, .blue, .yellow, .white]
        
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                id: UUID(),
                color: colors.randomElement()!,
                x: CGFloat.random(in: 0.2...0.8),
                delay: Double.random(in: 0...0.4),
                rotation: Double.random(in: 0...360),
                size: CGFloat.random(in: 6...12)
            )
            particles.append(particle)
        }
    }
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let containerSize: CGSize
    @State private var isAnimating = false
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .position(
                x: particle.x * containerSize.width,
                y: containerSize.height / 2 + yOffset
            )
            .rotationEffect(.degrees(rotation))
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(particle.delay)) {
                    isAnimating = true
                    yOffset = CGFloat.random(in: -150...150)
                    rotation = particle.rotation + Double.random(in: -180...180)
                }
            }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    let color: Color
    let x: CGFloat
    let delay: Double
    let rotation: Double
    let size: CGFloat
}

#Preview {
    ZStack {
        Color.black
        ScanningAnimationView(isActive: true, status: .detectedHoldStill)
    }
}
