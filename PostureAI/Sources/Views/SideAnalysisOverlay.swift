import SwiftUI

// MARK: - Side Analysis Overlay
/// Draws plumb lines on side view images showing deviations from ideal posture
struct SideAnalysisOverlay: View {
    let metrics: SidePostureMetrics
    let imageSize: CGSize
    
    // Color scheme
    private let idealLineColor = Color.green.opacity(0.8)
    private let actualLineColor = Color.cyan.opacity(0.8)
    private let deviationLineColor = Color.orange.opacity(0.8)
    private let textBackground = Color.black.opacity(0.6)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Draw ideal vertical plumb line (always visible if we have valid data)
                drawIdealPlumbLine(in: geo.size)
                
                // Draw actual body alignment line
                drawBodyAlignmentLine(in: geo.size)
                
                // Draw deviation lines and measurements
                drawDeviationLines(in: geo.size)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }
    
    // MARK: - Ideal Plumb Line
    private func drawIdealPlumbLine(in size: CGSize) -> some View {
        // Get top and bottom Y positions
        let topY: CGFloat
        let bottomY: CGFloat
        
        if let ear = metrics.earPosition {
            topY = CGFloat(ear.y) * size.height
        } else if let nose = metrics.nosePosition {
            topY = CGFloat(nose.y) * size.height
        } else {
            topY = size.height * 0.15
        }
        
        if let ankle = metrics.anklePosition {
            bottomY = CGFloat(ankle.y) * size.height
        } else {
            bottomY = size.height * 0.9
        }
        
        // Calculate X position for ideal plumb line (at ankle position)
        let plumbX: CGFloat
        if let ankle = metrics.anklePosition {
            plumbX = CGFloat(ankle.x) * size.width
        } else {
            plumbX = CGFloat(metrics.verticalLineX) * size.width
        }
        
        return ZStack {
            // Main vertical dashed line (IDEAL PLUMB LINE)
            Path { path in
                path.move(to: CGPoint(x: plumbX, y: topY))
                path.addLine(to: CGPoint(x: plumbX, y: bottomY))
            }
            .stroke(
                idealLineColor,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    dash: [8, 6]
                )
            )
            
            // Top marker (head reference point)
            Circle()
                .stroke(idealLineColor, lineWidth: 2)
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .position(x: plumbX, y: topY)
            
            // Bottom marker (ankle reference point)
            Circle()
                .stroke(idealLineColor, lineWidth: 2)
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .position(x: plumbX, y: bottomY)
        }
    }
    
    // MARK: - Body Alignment Line
    private func drawBodyAlignmentLine(in size: CGSize) -> some View {
        let points = bodyPointsForDrawing()
        guard points.count >= 2 else { return AnyView(EmptyView()) }
        
        // Build the path through actual body points
        let path = Path { path in
            let first = screenPoint(points[0], in: size)
            path.move(to: first)
            
            for i in 1..<points.count {
                let pt = screenPoint(points[i], in: size)
                path.addLine(to: pt)
            }
        }
        
        return AnyView(
            path.stroke(
                actualLineColor,
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        )
    }
    
    // MARK: - Deviation Lines
    private func drawDeviationLines(in size: CGSize) -> some View {
        let plumbX = CGFloat(metrics.verticalLineX) * size.width
        
        return ZStack {
            // Head deviation line (horizontal line from ideal to actual)
            if let headPos = metrics.earPosition ?? metrics.nosePosition {
                drawDeviationLine(
                    actual: headPos,
                    idealX: plumbX,
                    value: metrics.headForwardCm,
                    in: size
                )
            }
            
            // Shoulder deviation
            if let shoulderPos = metrics.shoulderPosition {
                drawDeviationLine(
                    actual: shoulderPos,
                    idealX: plumbX,
                    value: metrics.shoulderForwardCm,
                    in: size
                )
            }
            
            // Hip deviation
            if let hipPos = metrics.hipPosition {
                drawDeviationLine(
                    actual: hipPos,
                    idealX: plumbX,
                    value: metrics.hipForwardCm,
                    in: size
                )
            }
            
            // Knee deviation
            if let kneePos = metrics.kneePosition {
                drawDeviationLine(
                    actual: kneePos,
                    idealX: plumbX,
                    value: metrics.kneeForwardCm,
                    in: size
                )
            }
        }
    }
    
    private func drawDeviationLine(actual: CGPoint, idealX: CGFloat, value: Double, in size: CGSize) -> some View {
        let actualX = CGFloat(actual.x) * size.width
        let actualY = CGFloat(actual.y) * size.height
        
        return ZStack {
            // Horizontal deviation line connecting ideal plumb to actual body point
            Path { path in
                path.move(to: CGPoint(x: idealX, y: actualY))
                path.addLine(to: CGPoint(x: actualX, y: actualY))
            }
            .stroke(deviationLineColor, lineWidth: 2)
            
            // Distance label for significant deviations (show if > 0.5cm)
            if value > 0.5 {
                Text(String(format: "%.1f cm", value))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(deviationLineColor)
                    )
                    .position(
                        x: (idealX + actualX) / 2,
                        y: actualY - 18
                    )
            }
        }
    }
    
    // MARK: - Labels
    private func drawLabels(in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Ideal line legend
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(idealLineColor)
                        .frame(width: 20, height: 3)
                    Text("Ideal Plumb")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Actual line legend
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(actualLineColor)
                        .frame(width: 20, height: 3)
                    Text("Your Posture")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(textBackground)
        )
        .position(x: size.width / 2, y: 30)
    }
    
    // MARK: - Helper Functions
    
    private func bodyPointsForDrawing() -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Build from bottom to top
        if let ankle = metrics.anklePosition { points.append(ankle) }
        if let knee = metrics.kneePosition { points.append(knee) }
        if let hip = metrics.hipPosition { points.append(hip) }
        if let shoulder = metrics.shoulderPosition { points.append(shoulder) }
        if let neck = metrics.neckPosition { points.append(neck) }
        if let ear = metrics.earPosition { points.append(ear) }
        else if let nose = metrics.nosePosition { points.append(nose) }
        
        return points
    }
    
    private func screenPoint(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        return CGPoint(
            x: CGFloat(normalized.x) * size.width,
            y: CGFloat(normalized.y) * size.height
        )
    }
}

// MARK: - Front Analysis Overlay
struct FrontAnalysisOverlay: View {
    let metrics: FrontPostureMetrics
    
    private let levelColor = Color.green.opacity(0.6)
    private let actualColor = Color.cyan.opacity(0.8)
    private let centerColor = Color.orange.opacity(0.6)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Shoulder level analysis
                if let left = metrics.leftShoulder, let right = metrics.rightShoulder {
                    drawHorizontalAnalysis(
                        left: screenPoint(left, in: geo.size),
                        right: screenPoint(right, in: geo.size),
                        angle: metrics.shoulderTiltAngle,
                        label: "Shoulders"
                    )
                }
                
                // Hip level analysis
                if let left = metrics.leftHip, let right = metrics.rightHip {
                    drawHorizontalAnalysis(
                        left: screenPoint(left, in: geo.size),
                        right: screenPoint(right, in: geo.size),
                        angle: metrics.hipTiltAngle,
                        label: "Hips"
                    )
                }
                
                // Vertical center reference line
                drawCenterLine(in: geo.size)
            }
        }
    }
    
    private func drawHorizontalAnalysis(left: CGPoint, right: CGPoint, angle: Double, label: String) -> some View {
        let midY = (left.y + right.y) / 2
        let length: CGFloat = 100
        
        return ZStack {
            // Actual body line
            Path { path in
                path.move(to: left)
                path.addLine(to: right)
            }
            .stroke(actualColor, lineWidth: 3)
            
            // Horizontal reference line (ideal level)
            Path { path in
                let midX = (left.x + right.x) / 2
                path.move(to: CGPoint(x: midX - length/2, y: midY))
                path.addLine(to: CGPoint(x: midX + length/2, y: midY))
            }
            .stroke(levelColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
        }
    }
    
    private func drawCenterLine(in size: CGSize) -> some View {
        let centerX: CGFloat
        
        if let ls = metrics.leftShoulder, let rs = metrics.rightShoulder,
           let lh = metrics.leftHip, let rh = metrics.rightHip {
            let shoulderMid = (CGFloat(ls.x) + CGFloat(rs.x)) / 2 * size.width
            let hipMid = (CGFloat(lh.x) + CGFloat(rh.x)) / 2 * size.width
            centerX = (shoulderMid + hipMid) / 2
        } else {
            centerX = size.width / 2
        }
        
        return Path { path in
            path.move(to: CGPoint(x: centerX, y: size.height * 0.15))
            path.addLine(to: CGPoint(x: centerX, y: size.height * 0.9))
        }
        .stroke(centerColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
    }
    
    private func screenPoint(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        return CGPoint(
            x: CGFloat(normalized.x) * size.width,
            y: CGFloat(normalized.y) * size.height
        )
    }
}

// MARK: - Preview Helpers
struct SideAnalysisOverlay_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMetrics = SidePostureMetrics(
            headForwardCm: 4.2,
            shoulderForwardCm: 2.8,
            hipForwardCm: 1.5,
            kneeForwardCm: 0.9,
            headTiltAngle: 15.0,
            shoulderTiltAngle: 8.0,
            hipTiltAngle: 3.0,
            kneeAngle: 175.0,
            headStatus: .mild,
            shoulderStatus: .mild,
            hipStatus: .good,
            kneeStatus: .good,
            anklePosition: CGPoint(x: 0.48, y: 0.88),
            kneePosition: CGPoint(x: 0.52, y: 0.65),
            hipPosition: CGPoint(x: 0.51, y: 0.48),
            shoulderPosition: CGPoint(x: 0.58, y: 0.32),
            neckPosition: CGPoint(x: 0.56, y: 0.28),
            earPosition: CGPoint(x: 0.60, y: 0.22),
            nosePosition: CGPoint(x: 0.62, y: 0.25),
            verticalLineX: 0.48
        )
        
        ZStack {
            Color.gray
            SideAnalysisOverlay(
                metrics: sampleMetrics,
                imageSize: CGSize(width: 300, height: 400)
            )
        }
        .frame(width: 300, height: 400)
    }
}
