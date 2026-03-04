# PostureAI

An iOS application that uses computer vision and AI to analyze and assess body posture through camera scanning.

## Overview

PostureAI is a SwiftUI-based iOS app that leverages Apple's Vision framework to detect human body poses, analyze posture alignment, and provide feedback on:

- **Head tilt angle** - Detects forward head posture
- **Shoulder alignment** - Identifies shoulder asymmetry and forward rounding
- **Hip alignment** - Detects pelvic tilts and imbalances

## Features

- 📷 **Dual Camera Scanning** - Capture both front and side view poses
- 🦴 **Real-time Skeleton Overlay** - Visualize detected body joints
- 📊 **Posture Analysis** - Get detailed metrics on body alignment
- 📱 **Modern SwiftUI Interface** - Clean, intuitive user experience
- 🔔 **Stability Detection** - Automatically captures when the user holds still
- 📏 **Height-based Normalization** - Analysis adjusts to user's height

## Requirements

- **iOS 16.0+**
- **Xcode 15.0+**
- **Swift 5.9**
- Physical iOS device with camera (Simulator not supported for camera features)

## Project Structure

```
PostureAI/
├── Sources/
│   ├── App/
│   │   └── PostureAIApp.swift          # App entry point
│   ├── Models/
│   │   └── Models.swift                # Data models (PoseData, PostureAnalysis, etc.)
│   ├── Views/
│   │   ├── ContentView.swift           # Main content container
│   │   ├── OnboardingView.swift        # Onboarding flow
│   │   ├── ScanView.swift              # Camera scanning interface
│   │   ├── HeightInputView.swift       # Height input screen
│   │   ├── SilhouetteGuideView.swift   # Pose guidance overlay
│   │   ├── SkeletonOverlayView.swift   # Body joint visualization
│   │   └── ReportView.swift            # Analysis results display
│   ├── ViewModels/
│   │   └── ScanViewModel.swift         # Scan screen logic
│   └── Services/
│       ├── CameraManager.swift         # Camera capture management
│       ├── PoseEstimator.swift         # Vision framework pose detection
│       └── PostureAnalyzer.swift      # Posture analysis algorithms
├── Resources/
│   ├── Assets.xcassets/               # App icons and assets
│   └── Info.plist                    # App configuration
└── project.yml                       # XcodeGen project specification
```

## How to Run in Xcode

### Option 1: Using XcodeGen (Recommended)

1. **Install XcodeGen** (if not already installed):
   ```bash
   brew install xcodegen
   ```

2. **Navigate to project directory**:
   ```bash
   cd /Users/kutaygunal/Desktop/PostureAI
   ```

3. **Generate Xcode project**:
   ```bash
   xcodegen generate
   ```

4. **Open the generated project**:
   ```bash
   open PostureAI.xcodeproj
   ```

5. **Select your device** in Xcode (iPhone required, simulator won't work for camera)

6. **Build and Run** (⌘+R)

### Option 2: Manual Setup

1. Open **Xcode 15.0+**

2. Select **File → New → Project from Existing Sources...**

3. Navigate to `/Users/kutaygunal/Desktop/PostureAI` and select the folder

4. Configure the project:
   - Set **Deployment Target** to iOS 16.0
   - Set **Bundle Identifier** (e.g., `com.yourname.postureai`)
   - Select your **Development Team** for code signing

5. Add source files to the target by dragging:
   - `Sources/` folder → "Create groups"
   - `Resources/` folder → "Create groups"

6. Enable required capabilities in **Signing & Capabilities**:
   - Camera usage is defined in Info.plist

7. Select a **physical iOS device** (camera features don't work on simulator)

8. **Build and Run** (⌘+R)

### Code Signing Setup

If you encounter signing errors:

1. Select the project in the navigator
2. Go to **Targets → PostureAI → Signing & Capabilities**
3. Select your **Team** from the dropdown
4. Set **Bundle Identifier** to something unique (e.g., `com.yourname.postureai`)

## Usage

1. **Launch the app** - Complete the onboarding tutorial
2. **Enter your height** - Used for normalized measurements
3. **Capture front pose**:
   - Stand facing the camera
   - Align with the silhouette guide
   - Hold still - the app will auto-capture when stable
4. **Capture side pose**:
   - Turn 90 degrees to show your profile
   - Again, hold still for auto-capture
5. **View report** - See detailed posture analysis with metrics

## Technical Details

### Pose Detection
Uses `VNDetectHumanBodyPoseRequest` from Apple's Vision framework to detect:
- Nose, neck, and head position
- Left and right shoulders
- Left and right hips
- Left and right ankles

### Stability Detection
The app tracks pose stability over ~0.7 seconds (42 frames at 60fps) before auto-capturing to ensure accurate measurements.

### Analysis Metrics
- **Head Tilt**: Angle of neck forward from vertical
- **Shoulder Offset**: Asymmetry between left and right shoulder height/position
- **Hip Offset**: Pelvic tilt and asymmetry detection

## Permissions

The app requires:
- **Camera Access** - For pose detection and image capture

Permission is requested at first launch with the description: *"Posture AI needs camera access to scan your posture and provide analysis."*

## Troubleshooting

### Camera not working on Simulator
- This is expected - camera features require a physical device
- Connect an iPhone and select it as the run target

### Build errors about missing files
- Ensure all files in `Sources/` are added to the target
- Clean build folder (Shift+⌘+K) and rebuild

### Signing errors
- Ensure you've selected a valid Development Team
- Use a unique Bundle Identifier

## License

This project is for educational purposes.

---

**Note**: This app uses on-device machine learning through Apple's Vision framework. No data is sent to external servers.