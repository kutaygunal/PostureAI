import SwiftUI

enum ViewMode {
    case side
    case front
}

struct ReportView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedViewMode: ViewMode = .side

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Posture AI")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Report scanned on \(dateFormatter.string(from: Date()))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)

                // Disclaimer
                Text("Recommendations are informational. For discomfort or pain, consult a healthcare professional.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)

                // Comparison View Toggle
                Picker("View Mode", selection: $selectedViewMode) {
                    Text("Side View").tag(ViewMode.side)
                    Text("Front View").tag(ViewMode.front)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Side Pose Analysis Card
                if selectedViewMode == .side {
                    SidePoseAnalysisCard(appState: appState)
                } else {
                    FrontPoseAnalysisCard(appState: appState)
                }

                // Detailed Report Section (stub)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detailed Report")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        ReportDetailRow(icon: "figure.stand", title: "Overall Posture", value: "Analyzing...", status: .neutral)
                        ReportDetailRow(icon: "person.fill", title: "Head Position", value: "Analyzing...", status: .neutral)
                        ReportDetailRow(icon: "arrow.left.and.right", title: "Shoulder Alignment", value: "Analyzing...", status: .neutral)
                        ReportDetailRow(icon: "figure.walk", title: "Hip Position", value: "Analyzing...", status: .neutral)
                    }
                }
                .padding(20)
                .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                .cornerRadius(16)
                .padding(.horizontal, 16)

                // Restart button
                Button(action: {
                    appState.reset()
                }) {
                    Text("Scan Again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationBarHidden(true)
    }
}

struct ReportDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let status: OffsetStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Side Pose Analysis Card
struct SidePoseAnalysisCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Side Pose Analysis — Ideal vs Yours")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Thumbnails
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)

                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("Ideal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                            .offset(y: 80)
                    }
                    .frame(height: 200)

                    Text("Ideal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                if let sideURL = appState.capturedSideImageURL,
                   let imageData = try? Data(contentsOf: sideURL),
                   let uiImage = UIImage(data: imageData) {
                    VStack(spacing: 8) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Your Side")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Text("No capture")
                                    .foregroundColor(.gray)
                            )

                        Text("Your Side")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 240)

            // Analysis Table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Body")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("How far off?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)

                    Text("Tilt angle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))

                // Data rows
                ForEach(sideAnalysisRows) { row in
                    HStack {
                        Text(row.bodyPart)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(row.howFarOff)
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity)

                        Text(row.tiltAngle)
                            .font(.system(size: 14))
                            .foregroundColor(tiltAngleColor(row.tiltAngle))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private var sideAnalysisRows: [MetricRow] {
        return [
            MetricRow(bodyPart: "Head", howFarOff: "~2.5 cm est.", tiltAngle: "3.2°"),
            MetricRow(bodyPart: "Shoulder", howFarOff: "~1.8 cm est.", tiltAngle: "1.5°"),
            MetricRow(bodyPart: "Hips", howFarOff: "~0.5 cm est.", tiltAngle: "0.8°")
        ]
    }
}

// MARK: - Front Pose Analysis Card
struct FrontPoseAnalysisCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Front Pose Analysis — Ideal vs Yours")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Thumbnails
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)

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
                            // Shoulders
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
                            // Hips
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 55, height: 12)
                        }
                        .opacity(0.5)

                        Text("Ideal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                            .offset(y: 80)
                    }
                    .frame(height: 200)

                    Text("Ideal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                if let frontURL = appState.capturedFrontImageURL,
                   let imageData = try? Data(contentsOf: frontURL),
                   let uiImage = UIImage(data: imageData) {
                    VStack(spacing: 8) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Your Front")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                Text("No capture")
                                    .foregroundColor(.gray)
                            )

                        Text("Your Front")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 240)

            // Analysis Table
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Body")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Deviation")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)

                    Text("Alignment")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))

                // Data rows
                ForEach(frontAnalysisRows) { row in
                    HStack {
                        Text(row.bodyPart)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(row.howFarOff)
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity)

                        Text(row.tiltAngle)
                            .font(.system(size: 14))
                            .foregroundColor(tiltAngleColor(row.tiltAngle))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private var frontAnalysisRows: [MetricRow] {
        return [
            MetricRow(bodyPart: "Shoulders", howFarOff: "~1.2 cm est.", tiltAngle: "Level"),
            MetricRow(bodyPart: "Hips", howFarOff: "~0.8 cm est.", tiltAngle: "Balanced"),
            MetricRow(bodyPart: "Spine", howFarOff: "Straight", tiltAngle: "0°")
        ]
    }
}

private func tiltAngleColor(_ value: String) -> Color {
    // Extract numeric value from string
    if let degrees = Double(value.replacingOccurrences(of: "°", with: "")) {
        if degrees < 5 {
            return .green
        } else if degrees < 15 {
            return .yellow
        } else {
            return .red
        }
    }
    // For text-based values like "Level", "Balanced"
    let lowercased = value.lowercased()
    if lowercased.contains("level") || lowercased.contains("balanced") || lowercased.contains("straight") {
        return .green
    } else if lowercased.contains("slight") || lowercased.contains("mild") {
        return .yellow
    } else if lowercased.contains("severe") || lowercased.contains("high") {
        return .red
    }
    return .gray
}

#Preview {
    NavigationStack {
        ReportView()
            .environmentObject(AppState())
    }
}
