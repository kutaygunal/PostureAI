import Foundation
import CoreGraphics
import Vision

// MARK: - Enhanced Posture Analysis Results

struct SidePostureMetrics {
    // Forward deviation in cm from vertical plumb line
    let headForwardCm: Double
    let shoulderForwardCm: Double
    let hipForwardCm: Double
    let kneeForwardCm: Double
    
    // Tilt angles in degrees
    let headTiltAngle: Double
    let shoulderTiltAngle: Double
    let hipTiltAngle: Double
    let kneeAngle: Double
    
    // Status
    let headStatus: OffsetStatus
    let shoulderStatus: OffsetStatus
    let hipStatus: OffsetStatus
    let kneeStatus: OffsetStatus
    
    // Raw positions for drawing (normalized 0-1)
    let anklePosition: CGPoint?
    let kneePosition: CGPoint?
    let hipPosition: CGPoint?
    let shoulderPosition: CGPoint?
    let neckPosition: CGPoint?
    let earPosition: CGPoint?
    let nosePosition: CGPoint?
    
    // Reference vertical line X position
    let verticalLineX: Double
    
    var hasValidData: Bool {
        return anklePosition != nil && (earPosition != nil || nosePosition != nil)
    }
}

struct FrontPostureMetrics {
    // Shoulder asymmetry in degrees (0 = level)
    let shoulderTiltAngle: Double
    // Hip asymmetry in degrees (0 = level)
    let hipTiltAngle: Double
    // Head tilt relative to vertical
    let headTiltAngle: Double
    // Vertical alignment deviation
    let spineDeviationPx: Double
    
    // Status
    let shoulderStatus: OffsetStatus
    let hipStatus: OffsetStatus
    let headStatus: OffsetStatus
    let spineStatus: OffsetStatus
    
    // Positions for drawing
    let leftShoulder: CGPoint?
    let rightShoulder: CGPoint?
    let leftHip: CGPoint?
    let rightHip: CGPoint?
    let leftKnee: CGPoint?
    let rightKnee: CGPoint?
    let leftAnkle: CGPoint?
    let rightAnkle: CGPoint?
    let nose: CGPoint?
    
    var hasValidData: Bool {
        return leftShoulder != nil && rightShoulder != nil
    }
}

// MARK: - Enhanced Posture Analyzer

class EnhancedPostureAnalyzer {
    
    // MARK: - Thresholds
    
    // Forward posture thresholds (in cm from vertical)
    static let mildForwardThreshold: Double = 2.5   // cm
    static let severeForwardThreshold: Double = 5.0 // cm
    
    // Tilt angle thresholds (in degrees)
    static let mildTiltThreshold: Double = 5.0
    static let severeTiltThreshold: Double = 15.0
    
    // MARK: - Side View Analysis
    
    /// Analyze side pose to calculate forward deviations and tilt angles
    /// - Parameters:
    ///   - pose: The detected pose data
    ///   - userHeightCm: User's actual height in cm
    ///   - isRightSide: true if right side facing camera, false if left side
    static func analyzeSidePose(
        from pose: PoseData,
        userHeightCm: Double,
        isRightSide: Bool = true
    ) -> SidePostureMetrics {
        
        // Get relevant joints
        let ankle = isRightSide ? pose.joint(.rightAnkle) : pose.joint(.leftAnkle)
        let knee = isRightSide ? pose.joint(.rightKnee) : pose.joint(.leftKnee)
        let hip = isRightSide ? pose.joint(.rightHip) : pose.joint(.leftHip)
        let shoulder = isRightSide ? pose.joint(.rightShoulder) : pose.joint(.leftShoulder)
        let neck = pose.joint(.neck)
        let ear = isRightSide ? pose.joint(.rightEar) : pose.joint(.leftEar)
        let nose = pose.joint(.nose)
        
        // Determine which points are available and best to use
        let anklePos = ankle?.position
        let kneePos = knee?.position
        let hipPos = hip?.position ?? calculateMidpoint(
            pose.joint(.leftHip)?.position,
            pose.joint(.rightHip)?.position
        )
        let shoulderPos = shoulder?.position ?? calculateMidpoint(
            pose.joint(.leftShoulder)?.position,
            pose.joint(.rightShoulder)?.position
        )
        let neckPos = neck?.position
        let earPos = ear?.position ?? nose?.position // Fall back to nose if ear unavailable
        let nosePos = nose?.position
        
        // Need at least ankle and head reference to calculate
        guard let anklePt = anklePos, let headPt = earPos ?? nosePos else {
            return emptySideMetrics(verticalLineX: 0.5)
        }
        
        // Calculate body midpoint X for context (for fallback vertical line)
        let bodyMidX: Double
        if let leftAnkle = pose.joint(.leftAnkle), let rightAnkle = pose.joint(.rightAnkle) {
            bodyMidX = (Double(leftAnkle.position.x) + Double(rightAnkle.position.x)) / 2.0
        } else {
            bodyMidX = Double(anklePt.x)
        }
        
        // Calculate normalized body height in frame
        let bodyHeightNorm = calculateBodyHeightNormalized(from: pose)
        let pixelToCmRatio = userHeightCm / bodyHeightNorm
        
        // Vertical plumb line: from ankle straight up (reference line)
        // For side view, this should ideally pass through or near the ankle
        let verticalLineX = Double(anklePt.x)
        
        // Calculate forward deviations (horizontal distance from vertical line)
        let headForwardPx = abs(Double((earPos ?? nosePos)!.x) - verticalLineX)
        let shoulderForwardPx = shoulderPos != nil ? abs(Double(shoulderPos!.x) - verticalLineX) : 0
        let hipForwardPx = hipPos != nil ? abs(Double(hipPos!.x) - verticalLineX) : 0
        let kneeForwardPx = kneePos != nil ? abs(Double(kneePos!.x) - verticalLineX) : 0
        
        // Convert to cm using deviation line calculations
        // Deviation is the horizontal distance from ideal plumb line to actual body part
        let headForwardCm = headForwardPx * pixelToCmRatio
        let shoulderForwardCm = shoulderForwardPx * pixelToCmRatio
        let hipForwardCm = hipForwardPx * pixelToCmRatio
        let kneeForwardCm = kneeForwardPx * pixelToCmRatio
        
        // Calculate tilt angles relative to vertical
        // Negative = backward, Positive = forward
        let headTilt = neckPos != nil && earPos != nil ? 
            calculateTiltFromVertical(start: neckPos!, end: earPos!) : 0
        
        let shoulderTilt = neckPos != nil && shoulderPos != nil ?
            calculateTiltFromVertical(start: neckPos!, end: shoulderPos!) : 0
        
        let hipTilt = shoulderPos != nil && hipPos != nil ?
            calculateTiltFromVertical(start: shoulderPos!, end: hipPos!) : 0
            
        let kneeAngle = hipPos != nil && kneePos != nil && anklePos != nil ?
            calculateKneeAngle(hip: hipPos!, knee: kneePos!, ankle: anklePos!) : 0
        
        // Determine statuses
        let headStatus = categorizeForwardDeviation(headForwardCm)
        let shoulderStatus = categorizeForwardDeviation(shoulderForwardCm)
        let hipStatus = categorizeForwardDeviation(hipForwardCm)
        let kneeStatus = categorizeForwardDeviation(kneeForwardCm)
        
        return SidePostureMetrics(
            headForwardCm: headForwardCm,
            shoulderForwardCm: shoulderForwardCm,
            hipForwardCm: hipForwardCm,
            kneeForwardCm: kneeForwardCm,
            headTiltAngle: headTilt,
            shoulderTiltAngle: shoulderTilt,
            hipTiltAngle: hipTilt,
            kneeAngle: kneeAngle,
            headStatus: headStatus,
            shoulderStatus: shoulderStatus,
            hipStatus: hipStatus,
            kneeStatus: kneeStatus,
            anklePosition: anklePos,
            kneePosition: kneePos,
            hipPosition: hipPos,
            shoulderPosition: shoulderPos,
            neckPosition: neckPos,
            earPosition: earPos,
            nosePosition: nosePos,
            verticalLineX: verticalLineX
        )
    }
    
    // MARK: - Front View Analysis
    
    static func analyzeFrontPose(
        from pose: PoseData,
        userHeightCm: Double
    ) -> FrontPostureMetrics {
        
        let leftShoulder = pose.joint(.leftShoulder)?.position
        let rightShoulder = pose.joint(.rightShoulder)?.position
        let leftHip = pose.joint(.leftHip)?.position
        let rightHip = pose.joint(.rightHip)?.position
        let leftKnee = pose.joint(.leftKnee)?.position
        let rightKnee = pose.joint(.rightKnee)?.position
        let leftAnkle = pose.joint(.leftAnkle)?.position
        let rightAnkle = pose.joint(.rightAnkle)?.position
        let nose = pose.joint(.nose)?.position
        
        // Calculate tilts
        let shoulderTilt = calculateHorizontalTilt(left: leftShoulder, right: rightShoulder)
        let hipTilt = calculateHorizontalTilt(left: leftHip, right: rightHip)
        let headTilt = calculateHeadTilt(pose: pose)
        
        // Calculate spine deviation (how far off center is the spine)
        let spineDev = calculateSpineDeviation(
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftHip: leftHip,
            rightHip: rightHip
        )
        
        // Determine statuses
        let shoulderStatus = categorizeTilt(abs(shoulderTilt))
        let hipStatus = categorizeTilt(abs(hipTilt))
        let headStatus = categorizeTilt(abs(headTilt))
        let spineStatus = categorizeTilt(abs(spineDev))
        
        return FrontPostureMetrics(
            shoulderTiltAngle: shoulderTilt,
            hipTiltAngle: hipTilt,
            headTiltAngle: headTilt,
            spineDeviationPx: spineDev,
            shoulderStatus: shoulderStatus,
            hipStatus: hipStatus,
            headStatus: headStatus,
            spineStatus: spineStatus,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftHip: leftHip,
            rightHip: rightHip,
            leftKnee: leftKnee,
            rightKnee: rightKnee,
            leftAnkle: leftAnkle,
            rightAnkle: rightAnkle,
            nose: nose
        )
    }
    
    // MARK: - Helper Functions
    
    private static func calculateBodyHeightNormalized(from pose: PoseData) -> Double {
        // Get visible body extent and extrapolate to full body height
        // Full body height = crown (top of head) to floor (bottom of foot)
        // Visible in photo = approx nose to ankle (~85% of total height)
        
        guard let nose = pose.joint(.nose)?.position,
              let leftAnkle = pose.joint(.leftAnkle)?.position,
              let rightAnkle = pose.joint(.rightAnkle)?.position else {
            return 1.0
        }
        
        let ankleMidY = (Double(leftAnkle.y) + Double(rightAnkle.y)) / 2.0
        let visibleBodyHeight = ankleMidY - Double(nose.y)
        
        // Correction factor: visible body is ~85-88% of total height
        // Missing: ~10cm nose-to-crown + ~12cm ankle-to-floor = ~22cm
        // For typical person 170cm, visible = 148cm, factor = 170/148 = 1.15
        let fullBodyCorrectionFactor = 1.15
        
        return visibleBodyHeight * fullBodyCorrectionFactor
    }
    
    private static func calculateMidpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        guard let a = a, let b = b else { return a ?? b }
        return CGPoint(
            x: (a.x + b.x) / 2.0,
            y: (a.y + b.y) / 2.0
        )
    }
    
    /// Calculate tilt from vertical (0° = vertical)
    /// Positive = tilting forward/to the right
    /// Negative = tilting backward/to the left
    private static func calculateTiltFromVertical(start: CGPoint, end: CGPoint) -> Double {
        let dx = Double(end.x - start.x)
        let dy = Double(end.y - start.y)
        
        // atan2(dx, -dy) gives angle from vertical
        // Positive dx = tilting forward (to the right in normalized coords)
        let radians = atan2(dx, -dy)
        let degrees = radians * 180.0 / .pi
        
        return degrees
    }
    
    /// Calculate tilt from horizontal (for front view shoulders/hips)
    /// Positive = right side higher than left
    private static func calculateHorizontalTilt(left: CGPoint?, right: CGPoint?) -> Double {
        guard let left = left, let right = right else { return 0 }
        let dx = Double(right.x - left.x)
        let dy = Double(right.y - left.y)
        
        // Angle from horizontal
        let radians = atan2(dy, dx)
        return radians * 180.0 / .pi
    }
    
    private static func calculateHeadTilt(pose: PoseData) -> Double {
        guard let nose = pose.joint(.nose)?.position,
              let neck = pose.joint(.neck)?.position else { return 0 }
        return calculateTiltFromVertical(start: neck, end: nose)
    }
    
    private static func calculateKneeAngle(hip: CGPoint, knee: CGPoint, ankle: CGPoint) -> Double {
        let v1 = CGPoint(x: hip.x - knee.x, y: hip.y - knee.y)
        let v2 = CGPoint(x: ankle.x - knee.x, y: ankle.y - knee.y)
        
        let dot = Double(v1.x * v2.x + v1.y * v2.y)
        let mag1 = sqrt(Double(v1.x * v1.x + v1.y * v1.y))
        let mag2 = sqrt(Double(v2.x * v2.x + v2.y * v2.y))
        
        guard mag1 > 0 && mag2 > 0 else { return 0 }
        
        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1, min(1, cosAngle))
        let degrees = acos(clampedCos) * 180.0 / .pi
        
        return degrees
    }
    
    private static func calculateSpineDeviation(
        leftShoulder: CGPoint?,
        rightShoulder: CGPoint?,
        leftHip: CGPoint?,
        rightHip: CGPoint?
    ) -> Double {
        guard let ls = leftShoulder, let rs = rightShoulder,
              let lh = leftHip, let rh = rightHip else { return 0 }
        
        let shoulderMidX = (Double(ls.x) + Double(rs.x)) / 2.0
        let hipMidX = (Double(lh.x) + Double(rh.x)) / 2.0
        
        // Deviation between shoulder and hip midpoints
        return abs(shoulderMidX - hipMidX) * 100 // Scale up for visibility
    }
    
    // MARK: - Categorization
    
    private static func categorizeForwardDeviation(_ cm: Double) -> OffsetStatus {
        if cm < mildForwardThreshold {
            return .good
        } else if cm < severeForwardThreshold {
            return .mild
        } else {
            return .severe
        }
    }
    
    private static func categorizeTilt(_ degrees: Double) -> OffsetStatus {
        if degrees < mildTiltThreshold {
            return .good
        } else if degrees < severeTiltThreshold {
            return .mild
        } else {
            return .severe
        }
    }
    
    private static func emptySideMetrics(verticalLineX: Double) -> SidePostureMetrics {
        return SidePostureMetrics(
            headForwardCm: 0,
            shoulderForwardCm: 0,
            hipForwardCm: 0,
            kneeForwardCm: 0,
            headTiltAngle: 0,
            shoulderTiltAngle: 0,
            hipTiltAngle: 0,
            kneeAngle: 0,
            headStatus: .neutral,
            shoulderStatus: .neutral,
            hipStatus: .neutral,
            kneeStatus: .neutral,
            anklePosition: nil,
            kneePosition: nil,
            hipPosition: nil,
            shoulderPosition: nil,
            neckPosition: nil,
            earPosition: nil,
            nosePosition: nil,
            verticalLineX: verticalLineX
        )
    }
    
    // MARK: - Score Calculation
    
    static func calculateOverallScore(
        sideMetrics: SidePostureMetrics,
        frontMetrics: FrontPostureMetrics
    ) -> Int {
        var score = 100
        
        // Side view penalties
        switch sideMetrics.headStatus {
        case .mild: score -= 12
        case .severe: score -= 25
        default: break
        }
        
        switch sideMetrics.shoulderStatus {
        case .mild: score -= 10
        case .severe: score -= 20
        default: break
        }
        
        switch sideMetrics.hipStatus {
        case .mild: score -= 8
        case .severe: score -= 15
        default: break
        }
        
        // Front view penalties
        switch frontMetrics.shoulderStatus {
        case .mild: score -= 8
        case .severe: score -= 15
        default: break
        }
        
        switch frontMetrics.hipStatus {
        case .mild: score -= 5
        case .severe: score -= 12
        default: break
        }
        
        return max(0, min(100, score))
    }
}