import SwiftUI

enum EnhancedViewMode {
    case side
    case front
}

// MARK: - Enhanced Report View with Modern UI

struct EnhancedReportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedViewMode: EnhancedViewMode = .side
    @State private var selectedCard: Int? = nil
    @State private var headerOffset: CGFloat = -50
    @State private var headerOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 50
    @State private var cardsOpacity: Double = 0
    @State private var overallScore: Int = 0

    // Analysis metrics
    @State private var sideMetrics: SidePostureMetrics?
    @State private var frontMetrics: FrontPostureMetrics?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                ReportHeader(
                    dateText: dateFormatter.string(from: Date()),
                    offset: headerOffset,
                    opacity: headerOpacity
                )
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        headerOffset = 0
                        headerOpacity = 1
                    }
                }

                // Overall Score Card
                OverallScoreCard(score: overallScore)
                    .id(overallScore) // Force recreation when score changes so onAppear runs with new value
                    .offset(y: cardsOffset)
                    .opacity(cardsOpacity)

                // View Mode Picker - moved outside animation modifiers
                Picker("View Mode", selection: $selectedViewMode) {
                    Text("Side View").tag(EnhancedViewMode.side)
                    Text("Front View").tag(EnhancedViewMode.front)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)

                // Comparison Section based on selected mode
                viewModeSection
                    .id(selectedViewMode)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: selectedViewMode)

                // Detailed Metrics based on selected mode
                DetailedMetricsSection(metrics: generateMetricsForCurrentMode())
                    .id("metrics-\(selectedViewMode)")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: selectedViewMode)

                // Recommendations
                RecommendationsSection()
                    .padding(.vertical, 8)

                // Action Buttons
                ActionButtonsSection {
                    appState.reset()
                    dismiss()
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
            .onAppear {
                // Calculate metrics and score synchronously
                calculateAndSetScore()

                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    cardsOffset = 0
                    cardsOpacity = 1
                }
                HapticManager.shared.mediumFeedback()
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.1, green: 0.1, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
    
    // MARK: - View Mode Section
    
    @ViewBuilder
    private var viewModeSection: some View {
        if selectedViewMode == .side {
            EnhancedSideComparisonSection(
                sideImageURL: appState.capturedSideImageURL,
                metrics: sideMetrics
            )
        } else {
            EnhancedFrontComparisonSection(
                frontImageURL: appState.capturedFrontImageURL,
                metrics: frontMetrics
            )
        }
    }

    // MARK: - Real Data Functions

    private func calculateAndSetScore() {
        // Calculate metrics directly from appState poses
        var newSideMetrics: SidePostureMetrics?
        var newFrontMetrics: FrontPostureMetrics?
        
        // Debug: Check what poses are available
        print("DEBUG: capturedSidePose exists = \(appState.capturedSidePose != nil)")
        print("DEBUG: capturedFrontPose exists = \(appState.capturedFrontPose != nil)")
        print("DEBUG: userHeightCm = \(appState.userHeightCm)")
        
        if let sidePose = appState.capturedSidePose {
            newSideMetrics = EnhancedPostureAnalyzer.analyzeSidePose(
                from: sidePose,
                userHeightCm: appState.userHeightCm
            )
            sideMetrics = newSideMetrics
            print("DEBUG: Side metrics calculated: headForward = \(newSideMetrics?.headForwardCm ?? -999)")
        } else {
            print("DEBUG: No side pose available")
        }

        if let frontPose = appState.capturedFrontPose {
            newFrontMetrics = EnhancedPostureAnalyzer.analyzeFrontPose(
                from: frontPose,
                userHeightCm: appState.userHeightCm
            )
            frontMetrics = newFrontMetrics
            print("DEBUG: Front metrics calculated: shoulderTilt = \(newFrontMetrics?.shoulderTiltAngle ?? -999)")
        } else {
            print("DEBUG: No front pose available")
        }
        
        // Calculate score with the fresh metrics (not relying on @State)
        if let side = newSideMetrics, let front = newFrontMetrics {
            overallScore = EnhancedPostureAnalyzer.calculateOverallScore(
                sideMetrics: side,
                frontMetrics: front
            )
            print("DEBUG: Score calculated = \(overallScore)")
        } else {
            // Calculate partial score if only one view available
            if let side = newSideMetrics {
                // Calculate score with side only (apply 50% weight)
                let partialScore = min(100, max(0, Int((50.0 * (1.0 - side.headForwardCm / 5.0) + 25.0))))
                overallScore = partialScore
                print("DEBUG: Partial side-only score = \(overallScore)")
            } else if let front = newFrontMetrics {
                // Calculate score with front only  
                let partialScore = min(100, max(0, Int((25.0 * (1.0 - abs(front.shoulderTiltAngle) / 2.0) + 25.0))))
                overallScore = partialScore
                print("DEBUG: Partial front-only score = \(overallScore)")
            } else {
                overallScore = 0
                print("DEBUG: No poses available, score = 0")
            }
        }
    }

    private func calculateOverallScore() -> Int {
        // Fallback: Calculate from appState directly
        guard let sidePose = appState.capturedSidePose,
              let frontPose = appState.capturedFrontPose else {
            return 0
        }
        
        let side = EnhancedPostureAnalyzer.analyzeSidePose(
            from: sidePose,
            userHeightCm: appState.userHeightCm
        )
        let front = EnhancedPostureAnalyzer.analyzeFrontPose(
            from: frontPose,
            userHeightCm: appState.userHeightCm
        )
        
        return EnhancedPostureAnalyzer.calculateOverallScore(
            sideMetrics: side,
            frontMetrics: front
        )
    }

    private func calculateMetrics() {
        // Calculate enhanced metrics from captured poses
        if let sidePose = appState.capturedSidePose {
            sideMetrics = EnhancedPostureAnalyzer.analyzeSidePose(
                from: sidePose,
                userHeightCm: appState.userHeightCm
            )
        }

        if let frontPose = appState.capturedFrontPose {
            frontMetrics = EnhancedPostureAnalyzer.analyzeFrontPose(
                from: frontPose,
                userHeightCm: appState.userHeightCm
            )
        }
    }

    private func calculateSideAnalysis() -> PostureAnalysis {
        guard let pose = appState.capturedSidePose,
              pose.hasValidJoints || pose.hasSideViewCoreJoints else {
            return PostureAnalysis()
        }

        // Assume reasonable frame height for calculations
        let frameHeight: Double = 1920 // Typical photo height
        return PostureAnalyzer.analyzeSidePose(
            from: pose,
            userHeightCm: appState.userHeightCm,
            frameHeight: frameHeight
        )
    }

    private func calculateFrontAnalysis() -> PostureAnalysis {
        guard let pose = appState.capturedFrontPose,
              pose.hasValidJoints else {
            return PostureAnalysis()
        }

        let frameHeight: Double = 1920
        return PostureAnalyzer.analyzeFrontPose(
            from: pose,
            userHeightCm: appState.userHeightCm,
            frameHeight: frameHeight
        )
    }

    private func generateSideAnalysisData() -> SideAnalysisData {
        let analysis = calculateSideAnalysis()
        return SideAnalysisData(
            headAngle: analysis.headTiltAngle,
            shoulderTilt: 0, // Forward/back not applicable in side view
            hipAlignment: analysis.hipOffset,
            overallStatus: combineStatuses(
                analysis.headTiltStatus,
                analysis.shoulderOffsetStatus,
                analysis.hipOffsetStatus
            )
        )
    }

    private func generateFrontAnalysisData() -> FrontAnalysisData {
        let analysis = calculateFrontAnalysis()
        return FrontAnalysisData(
            shoulderLevelness: analysis.headTiltAngle, // Reused for shoulder tilt
            hipBalance: analysis.hipOffset,
            spinalDeviation: Double(analysis.headTiltStatus.hashValue), // Approximate
            overallStatus: combineStatuses(
                analysis.headTiltStatus,
                analysis.shoulderOffsetStatus,
                analysis.hipOffsetStatus
            )
        )
    }

    private func combineStatuses(_ statuses: OffsetStatus...) -> OffsetStatus {
        if statuses.contains(.severe) { return .severe }
        if statuses.contains(.mild) { return .mild }
        if statuses.contains(.good) { return .good }
        return .neutral
    }

    private func generateMetrics() -> [PostureMetric] {
        var metrics: [PostureMetric] = []

        // Use enhanced metrics if available
        if let side = sideMetrics {
            // Head Position (from side view)
            metrics.append(PostureMetric(
                title: "Head Forward",
                value: String(format: "%.1f cm", side.headForwardCm),
                status: side.headStatus,
                icon: "person.fill",
                description: "Head is \(String(format: "%.1f", side.headForwardCm))cm forward from ideal vertical line"
            ))

            // Shoulder Forward
            metrics.append(PostureMetric(
                title: "Shoulders Forward",
                value: String(format: "%.1f cm", side.shoulderForwardCm),
                status: side.shoulderStatus,
                icon: "person.crop.rectangle",
                description: "Shoulders are \(String(format: "%.1f", side.shoulderForwardCm))cm forward from ideal vertical line"
            ))

            // Hip Forward
            metrics.append(PostureMetric(
                title: "Hips Forward",
                value: String(format: "%.1f cm", side.hipForwardCm),
                status: side.hipStatus,
                icon: "figure.walk",
                description: "Hips are \(String(format: "%.1f", side.hipForwardCm))cm from ideal vertical line"
            ))

            // Knee Forward
            metrics.append(PostureMetric(
                title: "Knees Forward",
                value: String(format: "%.1f cm", side.kneeForwardCm),
                status: side.kneeStatus,
                icon: "figure.walk",
                description: "Knees are \(String(format: "%.1f", side.kneeForwardCm))cm from ideal vertical line"
            ))
        }

        // Front view metrics
        if let front = frontMetrics {
            metrics.append(PostureMetric(
                title: "Shoulder Level",
                value: String(format: "%.1f°", abs(front.shoulderTiltAngle)),
                status: front.shoulderStatus,
                icon: "arrow.left.arrow.right",
                description: front.shoulderTiltAngle > 0 ? "Right shoulder higher" : "Left shoulder higher"
            ))

            metrics.append(PostureMetric(
                title: "Hip Level",
                value: String(format: "%.1f°", abs(front.hipTiltAngle)),
                status: front.hipStatus,
                icon: "figure.stand",
                description: front.hipTiltAngle > 0 ? "Right hip higher" : "Left hip higher"
            ))
        }
        
        return metrics
    }
    
    // MARK: - View-Specific Metrics
    
    private func generateMetricsForCurrentMode() -> [PostureMetric] {
        switch selectedViewMode {
        case .side:
            return generateSideMetrics()
        case .front:
            return generateFrontMetrics()
        }
    }
    
    private func generateSideMetrics() -> [PostureMetric] {
        var metrics: [PostureMetric] = []
        
        guard let side = sideMetrics else {
            return [PostureMetric(
                title: "No Data",
                value: "-",
                status: .neutral,
                icon: "exclamationmark.triangle",
                description: "Side view data not available"
            )]
        }
        
        // Head Position
        metrics.append(PostureMetric(
            title: "Head Forward",
            value: String(format: "%.1f cm", side.headForwardCm),
            status: side.headStatus,
            icon: "person.fill",
            description: side.headForwardCm > 0 
                ? "Head is \(String(format: "%.1f", side.headForwardCm))cm forward from ideal"
                : "Good head alignment"
        ))
        
        // Shoulder Forward
        metrics.append(PostureMetric(
            title: "Shoulders Forward",
            value: String(format: "%.1f cm", side.shoulderForwardCm),
            status: side.shoulderStatus,
            icon: "person.crop.rectangle",
            description: side.shoulderForwardCm > 0
                ? "Shoulders are \(String(format: "%.1f", side.shoulderForwardCm))cm forward"
                : "Good shoulder alignment"
        ))
        
        // Hip Forward
        metrics.append(PostureMetric(
            title: "Hips Forward",
            value: String(format: "%.1f cm", side.hipForwardCm),
            status: side.hipStatus,
            icon: "figure.walk",
            description: side.hipForwardCm > 0
                ? "Hips are \(String(format: "%.1f", side.hipForwardCm))cm from ideal"
                : "Good hip alignment"
        ))
        
        // Knee Forward
        metrics.append(PostureMetric(
            title: "Knees Forward",
            value: String(format: "%.1f cm", side.kneeForwardCm),
            status: side.kneeStatus,
            icon: "figure.walk",
            description: side.kneeForwardCm > 0
                ? "Knees are \(String(format: "%.1f", side.kneeForwardCm))cm from ideal"
                : "Good knee alignment"
        ))
        
        // Total Forward Deviation Summary
        let totalDeviation = side.headForwardCm + side.shoulderForwardCm + side.hipForwardCm + side.kneeForwardCm
        let avgDeviation = totalDeviation / 4.0
        let overallStatus: OffsetStatus = {
            if avgDeviation < 2.5 { return .good }
            else if avgDeviation < 5.0 { return .mild }
            else { return .severe }
        }()
        
        metrics.append(PostureMetric(
            title: "Total Forward Deviation",
            value: String(format: "%.1f cm", totalDeviation),
            status: overallStatus,
            icon: "ruler",
            description: "Combined forward deviation of all body parts from ideal vertical line. Average: \(String(format: "%.1f", avgDeviation))cm per part."
        ))
        
        return metrics
    }
    
    private func generateFrontMetrics() -> [PostureMetric] {
        var metrics: [PostureMetric] = []
        
        guard let front = frontMetrics else {
            return [PostureMetric(
                title: "No Data",
                value: "-",
                status: .neutral,
                icon: "exclamationmark.triangle",
                description: "Front view data not available"
            )]
        }
        
        // Shoulder Level
        metrics.append(PostureMetric(
            title: "Shoulder Level",
            value: String(format: "%.1f°", abs(front.shoulderTiltAngle)),
            status: front.shoulderStatus,
            icon: "arrow.left.arrow.right",
            description: abs(front.shoulderTiltAngle) > 2
                ? (front.shoulderTiltAngle > 0 ? "Right shoulder higher" : "Left shoulder higher")
                : "Shoulders are level"
        ))
        
        // Hip Level
        metrics.append(PostureMetric(
            title: "Hip Level",
            value: String(format: "%.1f°", abs(front.hipTiltAngle)),
            status: front.hipStatus,
            icon: "figure.stand",
            description: abs(front.hipTiltAngle) > 2
                ? (front.hipTiltAngle > 0 ? "Right hip higher" : "Left hip higher")
                : "Hips are level"
        ))
        
        // Head Tilt
        metrics.append(PostureMetric(
            title: "Head Tilt",
            value: String(format: "%.1f°", abs(front.headTiltAngle)),
            status: front.headStatus,
            icon: "person.fill",
            description: abs(front.headTiltAngle) > 3
                ? "Head is tilted"
                : "Head is straight"
        ))
        
        // Spine Deviation
        metrics.append(PostureMetric(
            title: "Spine Center",
            value: String(format: "%.1f", front.spineDeviationPx),
            status: front.spineStatus,
            icon: "waveform.path",
            description: "Spine deviation from center"
        ))
        
        return metrics
    }

    // MARK: - Status Description Helpers

    private func headStatusDescription(for analysis: PostureAnalysis) -> String {
        switch analysis.headTiltStatus {
        case .good:
            return "Good alignment, minimal forward head posture"
        case .mild:
            return "Slight forward head posture detected"
        case .severe:
            return "Significant forward head posture, consider neck exercises"
        case .neutral:
            return "Analyzing..."
        }
    }

    private func shoulderStatusDescription(for analysis: PostureAnalysis) -> String {
        switch analysis.shoulderOffsetStatus {
        case .good:
            return "Shoulders are level and well balanced"
        case .mild:
            return "Slight shoulder asymmetry detected"
        case .severe:
            return "Notable shoulder imbalance, strengthening recommended"
        case .neutral:
            return "Analyzing..."
        }
    }

    private func hipStatusDescription(front: PostureAnalysis, side: PostureAnalysis) -> String {
        let status = worseStatus(front.hipOffsetStatus, side.hipOffsetStatus)
        switch status {
        case .good:
            return "Hips are balanced and aligned"
        case .mild:
            return "Minor hip imbalance detected"
        case .severe:
            return "Hip misalignment, core strengthening advised"
        case .neutral:
            return "Analyzing..."
        }
    }

    private func forwardPostureDescription(for analysis: PostureAnalysis) -> String {
        switch analysis.shoulderOffsetStatus {
        case .good:
            return "Shoulders are well positioned over hips"
        case .mild:
            return "Slight rounded shoulder posture"
        case .severe:
            return "Notable forward shoulder posture, upper back exercises recommended"
        case .neutral:
            return "Analyzing..."
        }
    }

    private func worseStatus(_ a: OffsetStatus, _ b: OffsetStatus) -> OffsetStatus {
        let severity: [OffsetStatus: Int] = [.good: 0, .neutral: 1, .mild: 2, .severe: 3]
        return severity[a]! >= severity[b]! ? a : b
    }
}

// MARK: - Report Header

struct ReportHeader: View {
    let dateText: String
    let offset: CGFloat
    let opacity: Double

    var body: some View {
        VStack(spacing: 12) {
            Text("Posture Analysis")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Text(dateText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }

            // Disclaimer
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange.opacity(0.8))
                Text("Results are for informational purposes. Consult a professional for medical advice.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.top, 8)
        }
        .padding(.top, 20)
        .offset(y: offset)
        .opacity(opacity)
    }
}

// MARK: - Overall Score Card

struct OverallScoreCard: View {
    let score: Int
    @State private var animatedScore: Int = 0
    @State private var ringProgress: CGFloat = 0

    var scoreColor: Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return Color(red: 0.3, green: 0.8, blue: 0.4)  // Light green
        case 50..<75: return .yellow
        case 25..<50: return .orange
        default: return .red
        }
    }

    var scoreLabel: String {
        switch score {
        case 90...100: return "Excellent posture"
        case 75..<90: return "Good posture"
        case 50..<75: return "Moderate imbalance"
        case 25..<50: return "Poor posture"
        default: return "Severe posture issues"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 160, height: 160)

                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        scoreColor.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.5), radius: 10)

                // Score text
                VStack(spacing: 4) {
                    Text("\(animatedScore)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("/ 100")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            Text(scoreLabel)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(scoreColor)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringProgress = CGFloat(score) / 100
            }

            // Animate score counting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let duration = 1.0
                let steps = 60
                let increment = Double(score) / Double(steps)

                for i in 0..<steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * duration / Double(steps)) {
                        animatedScore = min(Int(increment * Double(i + 1)), score)
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Comparison Sections (NEW)

struct EnhancedSideComparisonSection: View {
    let sideImageURL: URL?
    let metrics: SidePostureMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Side View Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            // Image with analysis overlay
            SideImageWithOverlay(
                imageURL: sideImageURL,
                metrics: metrics
            )
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "Ideal Plumb Line")
                LegendItem(color: .cyan, label: "Actual Body Line")
                LegendItem(color: .orange, label: "Deviation")
            }

            // Quick stats box
            if let metrics = metrics {
                let headCm = String(format: "%.1f cm", metrics.headForwardCm)
                let shoulderCm = String(format: "%.1f cm", metrics.shoulderForwardCm)
                let hipCm = String(format: "%.1f cm", metrics.hipForwardCm)

                HStack(spacing: 16) {
                    QuickStat(label: "Head Fwd", value: headCm)
                    QuickStat(label: "Shoulders", value: shoulderCm)
                    QuickStat(label: "Hips", value: hipCm)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct EnhancedFrontComparisonSection: View {
    let frontImageURL: URL?
    let metrics: FrontPostureMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Front View Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            // Image with analysis overlay
            FrontImageWithOverlay(
                imageURL: frontImageURL,
                metrics: metrics
            )
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .green, label: "Ideal Horizontal")
                LegendItem(color: .cyan, label: "Center Line")
                LegendItem(color: .orange, label: "Deviation")
            }

            // Quick stats
            if let metrics = metrics {
                let shoulderDeg = String(format: "%.1f°", abs(metrics.shoulderTiltAngle))
                let hipDeg = String(format: "%.1f°", abs(metrics.hipTiltAngle))
                let headDeg = String(format: "%.1f°", abs(metrics.headTiltAngle))

                HStack(spacing: 16) {
                    QuickStat(label: "Shoulder Tilt", value: shoulderDeg)
                    QuickStat(label: "Hip Tilt", value: hipDeg)
                    QuickStat(label: "Head Tilt", value: headDeg)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Side Comparison Section

struct SideComparisonSection: View {
    let sideImageURL: URL?
    let analysisData: SideAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Side View Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            // Image comparison
            HStack(spacing: 12) {
                // Ideal pose visualization
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 180)

                        // Simple posture line visualization
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 30, height: 30)
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 4, height: 60)
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 80, height: 4)
                        }
                        .opacity(0.5)

                        Text("Ideal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(8)
                            .position(x: 40, y: 150)
                    }

                    Text("Reference")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                // Captured image
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 180)

                        if let url = sideImageURL,
                           let imageData = try? Data(contentsOf: url),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No Image")
                                    .foregroundColor(.gray)
                            }
                        }

                        // Analysis overlay
                        SidePostureOverlayLines(data: analysisData)
                    }

                    Text("Your Pose")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            // Quick stats
            let headValue = String(format: "%.1f°", analysisData.headAngle)
            let shoulderValue = String(format: "%.1f°", analysisData.shoulderTilt)
            let hipValue = String(format: "%.1f°", analysisData.hipAlignment)

            HStack(spacing: 16) {
                QuickStat(label: "Head Tilt", value: headValue)
                QuickStat(label: "Shoulder", value: shoulderValue)
                QuickStat(label: "Hips", value: hipValue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Front Comparison Section

struct FrontComparisonSection: View {
    let frontImageURL: URL?
    let analysisData: FrontAnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Front View Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            // Image comparison
            HStack(spacing: 12) {
                // Ideal front pose visualization
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 180)

                        // Front view ideal silhouette
                        VStack(spacing: 0) {
                            // Head
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 34, height: 34)
                            // Neck
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 12, height: 16)
                            // Shoulders - level
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 50, height: 10)
                                    .rotationEffect(.degrees(-8))
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 16, height: 8)
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 50, height: 10)
                                    .rotationEffect(.degrees(8))
                            }
                            // Torso
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 38, height: 70)
                            // Hips - balanced
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 55, height: 12)
                        }
                        .opacity(0.5)

                        Text("Ideal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(8)
                            .position(x: 40, y: 150)
                    }

                    Text("Reference")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                // Captured front image
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 180)

                        if let url = frontImageURL,
                           let imageData = try? Data(contentsOf: url),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No Image")
                                    .foregroundColor(.gray)
                            }
                        }

                        // Analysis overlay for front view
                        FrontPostureOverlayLines(data: analysisData)
                    }

                    Text("Your Pose")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            // Quick stats for front view
            let shoulderValue = String(format: "%.1f°", analysisData.shoulderLevelness)
            let hipValue = String(format: "%.1f°", analysisData.hipBalance)
            let spineValue = String(format: "%.1f°", analysisData.spinalDeviation)

            HStack(spacing: 16) {
                QuickStat(label: "Shoulders", value: shoulderValue)
                QuickStat(label: "Hips", value: hipValue)
                QuickStat(label: "Spine", value: spineValue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Side Posture Overlay Lines

struct SidePostureOverlayLines: View {
    let data: SideAnalysisData

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Center line (ideal)
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 2, height: geometry.size.height * 0.6)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Actual posture line (slightly offset)
                Rectangle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 2, height: geometry.size.height * 0.6)
                    .position(
                        x: geometry.size.width / 2 + CGFloat(data.headAngle * 2),
                        y: geometry.size.height / 2
                    )
                    .rotationEffect(.degrees(Double(data.shoulderTilt)))
            }
        }
    }
}

// MARK: - Front Posture Overlay Lines

struct FrontPostureOverlayLines: View {
    let data: FrontAnalysisData

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Vertical center line (ideal)
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 2, height: geometry.size.height * 0.6)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Horizontal shoulder reference
                Rectangle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: 60, height: 2)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * 0.35
                    )

                // Horizontal hip reference
                Rectangle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: 60, height: 2)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * 0.65
                    )
            }
        }
    }
}

struct QuickStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Detailed Metrics Section

struct DetailedMetricsSection: View {
    let metrics: [PostureMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Analysis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(metrics) { metric in
                    MetricRowView(metric: metric)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct MetricRowView: View {
    let metric: PostureMetric
    @State private var isExpanded = false

    var statusColor: Color {
        switch metric.status {
        case .good: return .green
        case .mild: return .yellow
        case .severe: return .orange
        case .neutral: return .gray
        }
    }

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: metric.icon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(statusColor.opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if !isExpanded {
                            Text(metric.description)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(metric.value)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(statusColor)

                        Text(metric.status.description)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                if isExpanded {
                    Text(metric.description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .padding(.leading, 52)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recommendations Section

struct RecommendationsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                RecommendationCard(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "Ergonomic Setup",
                    description: "Adjust your monitor to eye level and keep feet flat on floor."
                )

                RecommendationCard(
                    icon: "timer",
                    title: "Take Breaks",
                    description: "Stand and stretch every 30 minutes to reduce muscle tension."
                )

                RecommendationCard(
                    icon: "figure.walk",
                    title: "Core Exercises",
                    description: "Strengthen core muscles to improve overall posture stability."
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct RecommendationCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cyan.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Action Buttons Section

struct ActionButtonsSection: View {
    let onScanAgain: () -> Void
    @State private var primaryButtonScale: CGFloat = 1.0
    @State private var shareButtonScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            // Scan Again Button
            Button(action: {
                HapticManager.shared.mediumFeedback()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    primaryButtonScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    primaryButtonScale = 1.0
                    onScanAgain()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Scan Again")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            .scaleEffect(primaryButtonScale)

            // Share Button
            Button(action: {
                HapticManager.shared.lightFeedback()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    shareButtonScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    shareButtonScale = 1.0
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Report")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .scaleEffect(shareButtonScale)
        }
    }
}

// MARK: - Supporting Models

struct SideAnalysisData {
    let headAngle: Double
    let shoulderTilt: Double
    let hipAlignment: Double
    let overallStatus: OffsetStatus
}

struct FrontAnalysisData {
    let shoulderLevelness: Double
    let hipBalance: Double
    let spinalDeviation: Double
    let overallStatus: OffsetStatus
}

struct PostureMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let status: OffsetStatus
    let icon: String
    let description: String
}

// MARK: - Helper Views for Image with Overlay

struct SideImageWithOverlay: View {
    let imageURL: URL?
    let metrics: SidePostureMetrics?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                
                ImageContent(
                    imageURL: imageURL,
                    metrics: metrics,
                    containerSize: geo.size
                )
            }
        }
    }
}

struct FrontImageWithOverlay: View {
    let imageURL: URL?
    let metrics: FrontPostureMetrics?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                
                FrontImageContent(
                    imageURL: imageURL,
                    metrics: metrics,
                    containerSize: geo.size
                )
            }
        }
    }
}

struct ImageContent: View {
    let imageURL: URL?
    let metrics: SidePostureMetrics?
    let containerSize: CGSize
    
    var body: some View {
        ZStack {
            if let url = imageURL,
               let imageData = try? Data(contentsOf: url),
               let uiImage = UIImage(data: imageData) {
                let imageFrame = calculateImageFrame(uiImage: uiImage, containerSize: containerSize)
                
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                if let metrics = metrics, metrics.hasValidData {
                    SideAnalysisOverlay(
                        metrics: metrics,
                        imageSize: imageFrame.size
                    )
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(
                        x: imageFrame.midX,
                        y: imageFrame.midY
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No Image")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func calculateImageFrame(uiImage: UIImage, containerSize: CGSize) -> CGRect {
        let imageSize = uiImage.size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let drawWidth: CGFloat
        let drawHeight: CGFloat
        if imageAspect > containerAspect {
            drawWidth = containerSize.width
            drawHeight = containerSize.width / imageAspect
        } else {
            drawHeight = containerSize.height
            drawWidth = containerSize.height * imageAspect
        }
        
        let drawX = (containerSize.width - drawWidth) / 2
        let drawY = (containerSize.height - drawHeight) / 2
        
        return CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
    }
}

struct FrontImageContent: View {
    let imageURL: URL?
    let metrics: FrontPostureMetrics?
    let containerSize: CGSize
    
    var body: some View {
        ZStack {
            if let url = imageURL,
               let imageData = try? Data(contentsOf: url),
               let uiImage = UIImage(data: imageData) {
                let imageFrame = calculateImageFrame(uiImage: uiImage, containerSize: containerSize)
                
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                if let metrics = metrics, metrics.hasValidData {
                    FrontAnalysisOverlay(metrics: metrics)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(
                            x: imageFrame.midX,
                            y: imageFrame.midY
                        )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No Image")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func calculateImageFrame(uiImage: UIImage, containerSize: CGSize) -> CGRect {
        let imageSize = uiImage.size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let drawWidth: CGFloat
        let drawHeight: CGFloat
        if imageAspect > containerAspect {
            drawWidth = containerSize.width
            drawHeight = containerSize.width / imageAspect
        } else {
            drawHeight = containerSize.height
            drawWidth = containerSize.height * imageAspect
        }
        
        let drawX = (containerSize.width - drawWidth) / 2
        let drawY = (containerSize.height - drawHeight) / 2
        
        return CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
    }
}

#Preview {
    EnhancedReportView()
        .environmentObject(AppState())
}
