import SwiftUI

struct SilhouetteGuideView: View {
    let scanStatus: ScanStatus
    
    var body: some View {
        GeometryReader { geometry in
            // Width matches the bottom panel mode selector (screen width - 40pt padding)
            let frameWidth = geometry.size.width - 40 // 20pt each side
            // Height is proportional to width for portrait body ratio
            let frameHeight = min(geometry.size.height * 0.92, frameWidth / 0.55) // Max 92% height
            
            ZStack {
                // Outer glow background
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.clear)
                    .frame(width: frameWidth + 12, height: frameHeight + 12)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(statusColor.opacity(0.15))
                            .blur(radius: 20)
                    )
                
                // White border frame
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    .frame(width: frameWidth, height: frameHeight)
                    .shadow(color: statusColor.opacity(0.6), radius: 10, x: 0, y: 0)
                
                // Corner accents - REMOVED, keeping only rounded corners
                // CornerAccents(width: frameWidth, height: frameHeight)
                
                // Wireframe body - REMOVED as per user request
                // WireframeBody()
                //     .stroke(
                //         statusColor.opacity(isBodyDetected ? 0.9 : 0.4),
                //         style: StrokeStyle(lineWidth: isBodyDetected ? 2.5 : 2, lineCap: .round, lineJoin: .round)
                //     )
                //     .frame(width: frameWidth * 0.75, height: frameHeight * 0.82)
                //     .glow(color: statusColor, radius: isBodyDetected ? 8 : 0)
                //     .animation(.easeInOut(duration: 0.3), value: isBodyDetected)
                    
                // Status text at top - moved higher (was 0.14)
                StatusText(status: scanStatus)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var isBodyDetected: Bool {
        scanStatus == .detectedHoldStill || scanStatus == .captured
    }
    
    private var statusColor: Color {
        switch scanStatus {
        case .detectedHoldStill, .sideViewGood:
            return .green
        case .captured:
            return .blue
        case .moveCloser, .moveBack:
            return .orange
        case .turnToSide, .turnMoreToSide:
            return .orange
        case .noDetection:
            return .white
        }
    }
}

// MARK: - Wireframe Body Shape

struct WireframeBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        
        // Head - oval
        let headW = w * 0.22
        let headH = h * 0.11
        let headY = h * 0.05
        
        // Draw head outline
        path.addEllipse(in: CGRect(
            x: cx - headW/2,
            y: headY,
            width: headW,
            height: headH
        ))
        
        // Vertical center line for head
        path.move(to: CGPoint(x: cx, y: headY + headH * 0.2))
        path.addLine(to: CGPoint(x: cx, y: headY + headH * 0.8))
        
        // Horizontal line for eyes
        path.move(to: CGPoint(x: cx - headW/3, y: headY + headH * 0.35))
        path.addLine(to: CGPoint(x: cx + headW/3, y: headY + headH * 0.35))
        
        // Neck
        let neckY = headY + headH
        let neckW = w * 0.08
        path.move(to: CGPoint(x: cx - neckW/2, y: neckY))
        path.addLine(to: CGPoint(x: cx - neckW/2, y: neckY + h * 0.05))
        path.addLine(to: CGPoint(x: cx + neckW/2, y: neckY + h * 0.05))
        path.addLine(to: CGPoint(x: cx + neckW/2, y: neckY))
        
        // Shoulders
        let shoulderY = neckY + h * 0.06
        let shoulderW = w * 0.85
        
        // Torso - natural body shape
        let chestY = shoulderY + h * 0.12
        let chestW = w * 0.82
        let waistY = chestY + h * 0.18
        let waistW = w * 0.55
        let hipY = waistY + h * 0.12
        let hipW = w * 0.62
        
        // Left side of body (smooth curves)
        path.move(to: CGPoint(x: cx - shoulderW/2, y: shoulderY))
        path.addCurve(
            to: CGPoint(x: cx - chestW/2, y: chestY),
            control1: CGPoint(x: cx - shoulderW/2, y: shoulderY + (chestY-shoulderY)*0.3),
            control2: CGPoint(x: cx - chestW/2, y: chestY - (chestY-shoulderY)*0.2)
        )
        path.addCurve(
            to: CGPoint(x: cx - waistW/2, y: waistY),
            control1: CGPoint(x: cx - chestW/2, y: chestY + (waistY-chestY)*0.4),
            control2: CGPoint(x: cx - waistW/2, y: waistY - (waistY-chestY)*0.2)
        )
        path.addCurve(
            to: CGPoint(x: cx - hipW/2, y: hipY),
            control1: CGPoint(x: cx - waistW/2, y: waistY + (hipY-waistY)*0.3),
            control2: CGPoint(x: cx - hipW/2, y: hipY - (hipY-waistY)*0.2)
        )
        
        // Left leg - thigh
        let thighY = hipY + h * 0.12
        let thighW = w * 0.18
        path.addLine(to: CGPoint(x: cx - thighW/2, y: thighY))
        
        // Left knee
        let kneeY = thighY + h * 0.15
        path.addLine(to: CGPoint(x: cx - thighW/2, y: kneeY))
        
        // Left calf
        let ankleW = w * 0.14
        let ankleY = kneeY + h * 0.20
        path.addLine(to: CGPoint(x: cx - ankleW/2, y: ankleY))
        
        // Left foot
        let footY = ankleY + h * 0.02
        path.addLine(to: CGPoint(x: cx - ankleW/2 - w*0.02, y: footY))
        path.addLine(to: CGPoint(x: cx - ankleW/2 + w*0.03, y: footY))
        
        // Bottom line between feet
        path.addLine(to: CGPoint(x: cx + ankleW/2 - w*0.03, y: footY))
        path.addLine(to: CGPoint(x: cx + ankleW/2 + w*0.02, y: footY))
        
        // Right foot
        path.addLine(to: CGPoint(x: cx + ankleW/2, y: ankleY))
        
        // Right leg
        path.addLine(to: CGPoint(x: cx + thighW/2, y: kneeY))
        path.addLine(to: CGPoint(x: cx + thighW/2, y: thighY))
        path.addLine(to: CGPoint(x: cx + hipW/2, y: hipY))
        
        // Right side up (mirror of left)
        path.addCurve(
            to: CGPoint(x: cx + waistW/2, y: waistY),
            control1: CGPoint(x: cx + hipW/2, y: hipY - (hipY-waistY)*0.2),
            control2: CGPoint(x: cx + waistW/2, y: waistY + (waistY-hipY)*0.3)
        )
        path.addCurve(
            to: CGPoint(x: cx + chestW/2, y: chestY),
            control1: CGPoint(x: cx + waistW/2, y: waistY - (waistY-chestY)*0.2),
            control2: CGPoint(x: cx + chestW/2, y: chestY + (chestY-waistY)*0.4)
        )
        path.addCurve(
            to: CGPoint(x: cx + shoulderW/2, y: shoulderY),
            control1: CGPoint(x: cx + chestW/2, y: chestY - (chestY-shoulderY)*0.2),
            control2: CGPoint(x: cx + shoulderW/2, y: shoulderY + (chestY-shoulderY)*0.3)
        )
        
        // Neck connection
        path.addLine(to: CGPoint(x: cx + neckW/2, y: neckY + h * 0.05))
        path.addLine(to: CGPoint(x: cx + neckW/2, y: neckY))
        
        // Head connection
        path.addLine(to: CGPoint(x: cx + headW/2, y: neckY))
        
        // Grid lines on torso for wireframe effect
        // Vertical center
        path.move(to: CGPoint(x: cx, y: neckY))
        path.addLine(to: CGPoint(x: cx, y: hipY))
        
        // Horizontal lines
        for i in 1...4 {
            let y = neckY + (hipY - neckY) * CGFloat(i) / 5
            let widthAtY = w * 0.3 * (1.0 - abs(CGFloat(i) - 2.5) / 3)
            path.move(to: CGPoint(x: cx - widthAtY, y: y))
            path.addLine(to: CGPoint(x: cx + widthAtY, y: y))
        }
        
        // Arms
        let armY = shoulderY + h * 0.05
        let armLength = w * 0.35
        let elbowY = armY + h * 0.15
        let wristY = elbowY + h * 0.12
        
        // Left arm
        path.move(to: CGPoint(x: cx - shoulderW/2, y: shoulderY + h * 0.02))
        path.addLine(to: CGPoint(x: cx - shoulderW/2 - armLength * 0.3, y: elbowY))
        path.addLine(to: CGPoint(x: cx - shoulderW/2 - armLength, y: wristY))
        
        // Right arm
        path.move(to: CGPoint(x: cx + shoulderW/2, y: shoulderY + h * 0.02))
        path.addLine(to: CGPoint(x: cx + shoulderW/2 + armLength * 0.3, y: elbowY))
        path.addLine(to: CGPoint(x: cx + shoulderW/2 + armLength, y: wristY))
        
        return path
    }
}

// MARK: - Corner Accents

struct CornerAccents: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            // Top left
            CornerAccentShape()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .frame(width: 24, height: 24)
                .position(x: 12, y: 12)
            
            // Top right
            CornerAccentShape()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .rotationEffect(.degrees(90))
                .frame(width: 24, height: 24)
                .position(x: width - 12, y: 12)
            
            // Bottom right
            CornerAccentShape()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .rotationEffect(.degrees(180))
                .frame(width: 24, height: 24)
                .position(x: width - 12, y: height - 12)
            
            // Bottom left
            CornerAccentShape()
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
                .rotationEffect(.degrees(270))
                .frame(width: 24, height: 24)
                .position(x: 12, y: height - 12)
        }
        .frame(width: width, height: height)
    }
}

struct CornerAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size: CGFloat = 20
        path.move(to: CGPoint(x: 0, y: size))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size, y: 0))
        return path
    }
}

// MARK: - Status Text

struct StatusText: View {
    let status: ScanStatus
    
    var body: some View {
        Text(statusMessage)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
    
    private var statusMessage: String {
        switch status {
        case .noDetection:
            return "Bring person in frame"
        case .moveCloser:
            return "Move closer"
        case .moveBack:
            return "Move back"
        case .detectedHoldStill:
            return "Hold still"
        case .captured:
            return "Captured!"
        case .turnToSide:
            return "Turn to side"
        case .turnMoreToSide:
            return "Turn more to side"
        case .sideViewGood:
            return "Hold still"
        }
    }
}

// MARK: - Glow Effect

extension View {
    func glow(color: Color, radius: CGFloat) -> some View {
        self
            .shadow(color: color, radius: radius / 2)
            .shadow(color: color, radius: radius)
            .shadow(color: color, radius: radius * 1.5)
    }
}

#Preview {
    ZStack {
        Color.black
        SilhouetteGuideView(scanStatus: .noDetection)
    }
}
