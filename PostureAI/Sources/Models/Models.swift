import Foundation
import Vision
import CoreGraphics

// MARK: - Pose Data Models

struct DetectedJoint: Identifiable {
    let id: VNHumanBodyPoseObservation.JointName
    let position: CGPoint
    let confidence: Float
}

struct PoseData {
    var joints: [VNHumanBodyPoseObservation.JointName: DetectedJoint]
    var timestamp: Date

    init(joints: [VNHumanBodyPoseObservation.JointName: DetectedJoint] = [:], timestamp: Date = Date()) {
        self.joints = joints
        self.timestamp = timestamp
    }

    var hasValidJoints: Bool {
        let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder,
            .leftHip, .rightHip, .leftAnkle, .rightAnkle
        ]
        return requiredJoints.allSatisfy { joints[$0]?.confidence ?? 0 > 0.3 }
    }
    
    /// LENIENT: For side view, only require core body joints
    /// Arms/hands may be occluded, so we ignore them
    var hasSideViewCoreJoints: Bool {
        // Must have: nose (for height), at least one shoulder pair OR both hips, ankles
        guard let _ = joints[.nose],
              joints[.leftAnkle]?.confidence ?? 0 > 0.3 || joints[.rightAnkle]?.confidence ?? 0 > 0.3 else {
            return false
        }
        
        // Need shoulders OR hips to detect rotation
        let hasLeftShoulder = joints[.leftShoulder]?.confidence ?? 0 > 0.3
        let hasRightShoulder = joints[.rightShoulder]?.confidence ?? 0 > 0.3
        let hasLeftHip = joints[.leftHip]?.confidence ?? 0 > 0.3
        let hasRightHip = joints[.rightHip]?.confidence ?? 0 > 0.3
        
        // Allow capture if we have shoulders OR hips (for rotation check)
        return (hasLeftShoulder && hasRightShoulder) || (hasLeftHip && hasRightHip) || (hasLeftShoulder && hasLeftHip) || (hasRightShoulder && hasRightHip)
    }

    func joint(_ name: VNHumanBodyPoseObservation.JointName) -> DetectedJoint? {
        return joints[name]
    }
}

// MARK: - Analysis Models

struct PostureAnalysis {
    var headTiltAngle: Double = 0
    var shoulderForwardOffset: Double = 0
    var hipOffset: Double = 0
    var bodyHeightNorm: Double = 0

    var headTiltStatus: OffsetStatus = .neutral
    var shoulderOffsetStatus: OffsetStatus = .neutral
    var hipOffsetStatus: OffsetStatus = .neutral
}

enum OffsetStatus {
    case good
    case mild
    case severe
    case neutral

    var description: String {
        switch self {
        case .good: return "Good"
        case .mild: return "Mild"
        case .severe: return "Severe"
        case .neutral: return "-"
        }
    }
}

struct MetricRow: Identifiable {
    let id = UUID()
    let bodyPart: String
    let howFarOff: String
    let tiltAngle: String
}

// MARK: - Scan Mode

enum ScanMode: String, CaseIterable {
    case front = "Front Pose"
    case side = "Side Pose"
}

// MARK: - Scan Status

enum ScanStatus: String {
    case moveCloser = "Move closer"
    case moveBack = "Move back"
    case detectedHoldStill = "Detected, hold still"
    case captured = "Captured!"
    case noDetection = "No body detected"
    
    // Side view specific statuses
    case turnToSide = "Turn to side"
    case turnMoreToSide = "Turn more to side"
    case sideViewGood = "Side profile good"

    // Computed property for UI display text
    var displayText: String {
        return self.rawValue
    }

    var isGood: Bool {
        return self == .detectedHoldStill || self == .captured || self == .sideViewGood
    }
}

// MARK: - Stability Tracker

class PoseStabilityTracker {
    private var jointPositions: [[VNHumanBodyPoseObservation.JointName: CGPoint]] = []
    private let maxHistory = 42 // ~0.7 seconds at 60fps
    private let keyJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck, .leftShoulder, .rightShoulder, .leftHip, .rightHip
    ]

    var isStable: Bool {
        guard jointPositions.count >= maxHistory else { return false }

        let recentPositions = Array(jointPositions.suffix(maxHistory))
        var totalMovement: CGFloat = 0
        var jointCount = 0

        for jointName in keyJoints {
            let positions = recentPositions.compactMap { $0[jointName] }
            guard positions.count > 1 else { continue }

            let avgX = positions.map { $0.x }.reduce(0, +) / CGFloat(positions.count)
            let avgY = positions.map { $0.y }.reduce(0, +) / CGFloat(positions.count)
            let avgPoint = CGPoint(x: avgX, y: avgY)

            for pos in positions {
                let dx = pos.x - avgPoint.x
                let dy = pos.y - avgPoint.y
                totalMovement += sqrt(dx * dx + dy * dy)
                jointCount += 1
            }
        }

        guard jointCount > 0 else { return false }
        let averageMovement = totalMovement / CGFloat(jointCount)
        return averageMovement < 0.015 // Threshold for stability
    }

    var stabilityDuration: TimeInterval {
        return Double(jointPositions.count) / 60.0 // Assuming 60fps
    }

    func addPose(_ pose: PoseData) {
        var frameJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for jointName in keyJoints {
            if let joint = pose.joint(jointName) {
                frameJoints[jointName] = joint.position
            }
        }
        jointPositions.append(frameJoints)

        if jointPositions.count > maxHistory * 2 {
            jointPositions.removeFirst(jointPositions.count - maxHistory)
        }
    }

    func reset() {
        jointPositions.removeAll()
    }
}

// MARK: - Persistence Manager

class PersistenceManager {
    static let shared = PersistenceManager()

    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        let capturedDir = documentsDirectory.appendingPathComponent("CapturedImages")
        if !fileManager.fileExists(atPath: capturedDir.path) {
            try? fileManager.createDirectory(at: capturedDir, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ imageData: Data, filename: String) -> URL? {
        let capturedDir = documentsDirectory.appendingPathComponent("CapturedImages")
        let fileURL = capturedDir.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    func loadImage(from url: URL) -> Data? {
        return try? Data(contentsOf: url)
    }

    func deleteImage(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    func clearAllCapturedImages() {
        let capturedDir = documentsDirectory.appendingPathComponent("CapturedImages")
        if let files = try? fileManager.contentsOfDirectory(at: capturedDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
