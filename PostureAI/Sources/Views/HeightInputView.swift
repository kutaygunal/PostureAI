import SwiftUI

struct HeightInputView: View {
    @EnvironmentObject var appState: AppState
    @State private var heightCm: Double = 170.0
    @State private var useMetric = true
    @State private var feet: Int = 5
    @State private var inches: Int = 7

    private let heightRangeCm: ClosedRange<Double> = 120...220
    private let feetRange = 4...7
    private let inchesRange = 0...11

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("Your Height")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Enter your height for accurate posture analysis")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                Spacer()

                // Unit toggle
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation {
                            useMetric = true
                        }
                    }) {
                        Text("cm")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(useMetric ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(useMetric ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        withAnimation {
                            useMetric = false
                        }
                    }) {
                        Text("ft/in")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(!useMetric ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(!useMetric ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }
                }
                .padding(4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 32)

                // Height input
                if useMetric {
                    VStack(spacing: 16) {
                        Text("\(Int(heightCm)) cm")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(.white)

                        Slider(value: $heightCm, in: heightRangeCm)
                            .accentColor(.blue)
                            .padding(.horizontal, 32)

                        HStack {
                            Text("120 cm")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("220 cm")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 32)
                    }
                } else {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // Feet picker
                            VStack(spacing: 8) {
                                Picker("Feet", selection: $feet) {
                                    ForEach(feetRange, id: \.self) { ft in
                                        Text("\(ft) ft").tag(ft)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 120)
                                .clipped()

                                // Inches picker
                                Picker("Inches", selection: $inches) {
                                    ForEach(inchesRange, id: \.self) { inch in
                                        Text("\(inch) in").tag(inch)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 120)
                                .clipped()
                            }
                        }

                        // Converted value display
                        Text("\(Int(convertedHeightCm)) cm")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Continue button
                NavigationLink(destination: ReportView()) {
                    Text("Generate Report")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Initialize with user's saved height or default
            if appState.userHeightCm > 0 {
                heightCm = appState.userHeightCm
            }
        }
        .onChange(of: heightCm) { _, newValue in
            appState.userHeightCm = newValue
        }
        .onChange(of: feet) { _, _ in
            appState.userHeightCm = convertedHeightCm
        }
        .onChange(of: inches) { _, _ in
            appState.userHeightCm = convertedHeightCm
        }
    }

    private var convertedHeightCm: Double {
        return Double(feet) * 30.48 + Double(inches) * 2.54
    }
}

// MARK: - Height Input Sheet (for Enhanced Scan flow)

struct HeightInputSheet: View {
    @EnvironmentObject var appState: AppState
    @State private var heightCm: Double = 170.0
    @State private var useMetric: Bool
    @State private var feet: Int = 5
    @State private var inches: Int = 7

    let onContinue: () -> Void

    private let heightRangeCm: ClosedRange<Double> = 120...220

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        _useMetric = State(initialValue: Locale.current.measurementSystem == .metric)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Header
            VStack(spacing: 10) {
                Image(systemName: "ruler.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Enter Your Height")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("For accurate posture measurements")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)

            // Unit toggle
            HStack(spacing: 0) {
                unitButton(title: "cm", isSelected: useMetric) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        useMetric = true
                    }
                }
                unitButton(title: "ft / in", isSelected: !useMetric) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        useMetric = false
                        syncImperialFromCm()
                    }
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal, 40)

            // Height display (always visible)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if useMetric {
                    Text("\(Int(heightCm))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("cm")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                } else {
                    Text("\(feet)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("ft")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    Text("\(inches)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.leading, 8)
                    Text("in")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
            }

            // Height controls
            if useMetric {
                VStack(spacing: 8) {
                    Slider(value: $heightCm, in: heightRangeCm, step: 1)
                        .tint(.blue)
                        .padding(.horizontal, 32)

                    HStack {
                        Text("120 cm")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("220 cm")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 36)
                }
            } else {
                HStack(spacing: 24) {
                    Picker("Feet", selection: $feet) {
                        ForEach(3...7, id: \.self) { ft in
                            Text("\(ft) ft").tag(ft)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 120)
                    .clipped()

                    Picker("Inches", selection: $inches) {
                        ForEach(0...11, id: \.self) { inch in
                            Text("\(inch) in").tag(inch)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 120)
                    .clipped()
                }
            }

            Spacer()

            // Continue button
            Button {
                let finalHeight: Double
                if useMetric {
                    finalHeight = heightCm
                } else {
                    finalHeight = Double(feet) * 30.48 + Double(inches) * 2.54
                }
                appState.userHeightCm = finalHeight
                HapticManager.shared.mediumFeedback()
                onContinue()
            } label: {
                HStack(spacing: 8) {
                    Text("Continue to Results")
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18))
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
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea())
        .onAppear {
            syncImperialFromCm()
        }
    }

    private func unitButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
        }
    }

    private func syncImperialFromCm() {
        let totalInches = Int(heightCm / 2.54)
        feet = totalInches / 12
        inches = totalInches % 12
    }
}

#Preview {
    NavigationStack {
        HeightInputView()
            .environmentObject(AppState())
    }
}
