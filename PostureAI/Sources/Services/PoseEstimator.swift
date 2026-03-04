import Vision
import CoreGraphics
import Combine
import AVFoundation

class PoseEstimator: ObservableObject {
    @Published var currentPose: PoseData?
    @Published var isDetecting = false
    
    // Camera position to handle mirroring
    var cameraPosition: AVCaptureDevice.Position = .front

    private let sequenceHandler = VNSequenceRequestHandler()
    private let minimumConfidence: Float = 0.3

    // Key joint connections for skeleton drawing (all 19 joints)
    static let jointConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Head
        (.nose, .leftEye),
        (.nose, .rightEye),
        (.leftEye, .leftEar),
        (.rightEye, .rightEar),
        (.leftEye, .rightEye),
        
        // Head to body
        (.nose, .neck),
        
        // Body core
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .rightShoulder),
        (.neck, .root),
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .rightHip),

        // Left arm
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),

        // Right arm
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),

        // Left leg
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),

        // Right leg
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                print("Vision error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self.currentPose = nil
                }
                return
            }

            let poseData = self.extractPoseData(from: observation)

            DispatchQueue.main.async {
                self.currentPose = poseData
            }
        }

        // Use .up orientation - coordinate conversion happens in extractPoseData
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            print("Failed to perform pose detection: \(error.localizedDescription)")
        }
    }

    private func extractPoseData(from observation: VNHumanBodyPoseObservation) -> PoseData {
        var joints: [VNHumanBodyPoseObservation.JointName: DetectedJoint] = [:]

        // All 19 joints that Apple Vision detects
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            // Head (5)
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            // Torso (4)
            .neck, .leftShoulder, .rightShoulder, .root,
            // Arms (4)
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            // Legs (6)
            .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]

        for jointName in jointNames {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence >= minimumConfidence {

                // Vision with .up orientation:
                // - x: 0=left, 1=right (normal)
                // - y: 0=bottom, 1=top (inverted from UI)
                // 
                // For front camera: Vision mirrors the image, so x is reversed
                // For back camera: x is normal
                
                var normalizedX = point.location.x
                let normalizedY = 1.0 - point.location.y  // Flip Y for UI (top-left origin)
                
                // Front camera: un-mirror the x coordinate
                // Back camera: keep x as-is
                if cameraPosition == .front {
                    normalizedX = 1.0 - point.location.x
                }
                
                let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
                joints[jointName] = DetectedJoint(
                    id: jointName,
                    position: normalizedPoint,
                    confidence: point.confidence
                )
            }
        }

        return PoseData(joints: joints)
    }
}
