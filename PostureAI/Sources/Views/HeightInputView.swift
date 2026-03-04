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

#Preview {
    NavigationStack {
        HeightInputView()
            .environmentObject(AppState())
    }
}
