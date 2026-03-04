import Foundation
import CoreGraphics
import Vision

class PostureAnalyzer {
    // MARK: - Body Height Calculation

    static func calculateBodyHeightNorm(from pose: PoseData) -> Double {
        guard let nose = pose.joint(.nose),
              let leftAnkle = pose.joint(.leftAnkle),
              let rightAnkle = pose.joint(.rightAnkle) else {
            print("[DEBUG] Missing joints - nose:\(pose.joint(.nose) != nil), lAnkle:\(pose.joint(.leftAnkle) != nil), rAnkle:\(pose.joint(.rightAnkle) != nil)")
            return 0
        }

        // Calculate mid-point of ankles
        let ankleMidY = (leftAnkle.position.y + rightAnkle.position.y) / 2.0

        // Body height as normalized value (0-1)
        let bodyHeight = ankleMidY - nose.position.y
        
        // Debug: print the coordinates
        print("[DEBUG] Body height calc - Nose Y: \(String(format: "%.3f", nose.position.y)), Ankle Y: \(String(format: "%.3f", ankleMidY)), Height: \(String(format: "%.3f", bodyHeight))")
        
        return bodyHeight
    }

    // MARK: - Angle Calculations

    /// Calculate angle between a vector and vertical axis (in degrees)
    static func calculateAngleFromVertical(from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y

        // Angle from vertical (positive = tilting forward/right, negative = backward/left)
        let angleRadians = atan2(dx, -dy)
        let angleDegrees = angleRadians * 180.0 / .pi

        return angleDegrees
    }

    /// Calculate head tilt angle (side pose)
    static func calculateHeadTilt(from pose: PoseData) -> Double {
        guard let nose = pose.joint(.nose),
              let neck = pose.joint(.neck) else {
            return 0
        }

        return calculateAngleFromVertical(from: neck.position, to: nose.position)
    }

    // MARK: - Offset Calculations (estimated cm)

    static func calculateShoulderForwardOffset(from pose: PoseData, userHeightCm: Double, frameHeight: Double) -> Double {
        guard let leftShoulder = pose.joint(.leftShoulder),
              let rightShoulder = pose.joint(.rightShoulder),
              let leftHip = pose.joint(.leftHip),
              let rightHip = pose.joint(.rightHip) else {
            return 0
        }

        let shoulderMidX = (leftShoulder.position.x + rightShoulder.position.x) / 2.0
        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2.0

        let pixelOffset = abs(shoulderMidX - hipMidX)

        // Convert to cm using user height and frame height ratio
        let heightRatio = pixelOffset / frameHeight
        let estimatedCm = heightRatio * userHeightCm

        return estimatedCm
    }

    static func calculateHipOffset(from pose: PoseData, userHeightCm: Double, frameHeight: Double) -> Double {
        guard let leftHip = pose.joint(.leftHip),
              let rightHip = pose.joint(.rightHip),
              let leftAnkle = pose.joint(.leftAnkle),
              let rightAnkle = pose.joint(.rightAnkle) else {
            return 0
        }

        let hipMidX = (leftHip.position.x + rightHip.position.x) / 2.0
        let ankleMidX = (leftAnkle.position.x + rightAnkle.position.x) / 2.0

        let pixelOffset = abs(hipMidX - ankleMidX)

        // Convert to cm
        let heightRatio = pixelOffset / frameHeight
        let estimatedCm = heightRatio * userHeightCm

        return estimatedCm
    }

    // MARK: - Full Analysis

    static func analyzeSidePose(from pose: PoseData, userHeightCm: Double, frameHeight: Double) -> PostureAnalysis {
        var analysis = PostureAnalysis()

        analysis.bodyHeightNorm = calculateBodyHeightNorm(from: pose)
        analysis.headTiltAngle = calculateHeadTilt(from: pose)
        analysis.shoulderForwardOffset = calculateShoulderForwardOffset(from: pose, userHeightCm: userHeightCm, frameHeight: frameHeight)
        analysis.hipOffset = calculateHipOffset(from: pose, userHeightCm: userHeightCm, frameHeight: frameHeight)

        // Determine status based on thresholds
        analysis.headTiltStatus = categorizeOffset(abs(analysis.headTiltAngle), thresholds: [5.0, 15.0])
        analysis.shoulderOffsetStatus = categorizeOffset(analysis.shoulderForwardOffset, thresholds: [2.0, 5.0])
        analysis.hipOffsetStatus = categorizeOffset(analysis.hipOffset, thresholds: [2.0, 5.0])

        return analysis
    }

    private static func categorizeOffset(_ value: Double, thresholds: [Double]) -> OffsetStatus {
        guard thresholds.count >= 2 else { return .neutral }

        if value < thresholds[0] {
            return .good
        } else if value < thresholds[1] {
            return .mild
        } else {
            return .severe
        }
    }

    // MARK: - Fit Status (Front View)

    static func determineFitStatus(bodyHeightNorm: Double) -> ScanStatus {
        // More reasonable target: ~70% of frame for comfortable full body
        let idealHeight: Double = 0.70
        // Tolerance: ±12% (58% to 82% is acceptable)
        let tolerance: Double = 0.12

        print("[DEBUG] determineFitStatus - bodyHeight: \(String(format: "%.3f", bodyHeightNorm)), ideal: \(idealHeight), min: \(idealHeight - tolerance), max: \(idealHeight + tolerance)")

        if bodyHeightNorm < idealHeight - tolerance {
            return .moveCloser
        } else if bodyHeightNorm > idealHeight + tolerance {
            return .moveBack
        } else {
            return .detectedHoldStill
        }
    }

    // MARK: - Side View Detection (LENIENT)
    
    /// Analyze pose for side view capture
    /// LENIENT: Only checks core body parts, ignores arms/hands
    static func analyzeSideViewPose(from pose: PoseData) -> ScanStatus {
        // 1. Check height first - need nose + ankles (these are core)
        guard let nose = pose.joint(.nose),
              let leftAnkle = pose.joint(.leftAnkle),
              let rightAnkle = pose.joint(.rightAnkle) else {
            return .noDetection
        }
        
        let ankleMidY = (leftAnkle.position.y + rightAnkle.position.y) / 2.0
        let bodyHeight = ankleMidY - nose.position.y
        let heightStatus = determineFitStatus(bodyHeightNorm: bodyHeight)

        // If height is wrong, show that first
        guard heightStatus == .detectedHoldStill else {
            return heightStatus
        }

        // 2. Check rotation - ONLY need shoulders and hips (ignore arms/hands)
        // In side view, far arm may be occluded, so we only check core body
        let leftShoulder = pose.joint(.leftShoulder)
        let rightShoulder = pose.joint(.rightShoulder)
        let leftHip = pose.joint(.leftHip)
        let rightHip = pose.joint(.rightHip)
        
        // For side detection, we need at least one shoulder pair OR hip pair
        // But prefer both for accuracy
        var bodyWidth: CGFloat = 0
        var hasShoulders = false
        var hasHips = false
        
        if let ls = leftShoulder, let rs = rightShoulder {
            bodyWidth += abs(ls.position.x - rs.position.x)
            hasShoulders = true
        }
        
        if let lh = leftHip, let rh = rightHip {
            bodyWidth += abs(lh.position.x - rh.position.x)
            hasHips = true
        }
        
        // If we have neither shoulders nor hips, can't determine rotation
        // BUT: if height is good and we have basic joints, allow capture anyway
        guard hasShoulders || hasHips else {
            // No rotation data, but height is good - allow capture (be lenient)
            return .sideViewGood
        }
        
        // Average width (if we have both, use average; if only one, use that)
        let divisor = (hasShoulders ? 1 : 0) + (hasHips ? 1 : 0)
        let avgWidth = bodyWidth / CGFloat(divisor)

        // For side view, body should be THIN (shoulders overlap)
        // Front view: width ≈ 0.25-0.35 (broad)
        // Side view: width ≈ 0.08-0.15 (thin)
        let thinThreshold: CGFloat = 0.18      // Below this = good side profile
        let rotatedThreshold: CGFloat = 0.25   // Above this = too rotated

        print("[DEBUG] Side view - width: \(String(format: "%.3f", avgWidth)), hasShoulders: \(hasShoulders), hasHips: \(hasHips)")

        if avgWidth > rotatedThreshold {
            // Too wide - person is facing camera
            return .turnToSide
        } else if avgWidth < thinThreshold {
            // Good side profile!
            return .sideViewGood
        } else {
            // In between - slightly angled
            return .turnMoreToSide
        }
    }
}
