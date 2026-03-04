import SwiftUI

struct SkeletonOverlayView: View {
    let pose: PoseData

    var body: some View {
        Canvas { context, size in
            // Draw connections
            for connection in PoseEstimator.jointConnections {
                guard let startJoint = pose.joint(connection.0),
                      let endJoint = pose.joint(connection.1) else {
                    continue
                }

                // Map normalized coordinates directly to canvas size
                let startPoint = CGPoint(
                    x: startJoint.position.x * size.width,
                    y: startJoint.position.y * size.height
                )
                let endPoint = CGPoint(
                    x: endJoint.position.x * size.width,
                    y: endJoint.position.y * size.height
                )

                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)

                let avgConfidence = (startJoint.confidence + endJoint.confidence) / 2
                let color = confidenceColor(avgConfidence)

                context.stroke(path, with: .color(color), lineWidth: 4)
            }

            // Draw joints
            for (_, joint) in pose.joints {
                let point = CGPoint(
                    x: joint.position.x * size.width,
                    y: joint.position.y * size.height
                )

                let circle = Path(ellipseIn: CGRect(
                    x: point.x - 6,
                    y: point.y - 6,
                    width: 12,
                    height: 12
                ))

                let color = confidenceColor(joint.confidence)
                context.fill(circle, with: .color(color))
                context.stroke(circle, with: .color(.white), lineWidth: 2)
            }
        }
        .ignoresSafeArea()
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.7 {
            return .cyan
        } else if confidence >= 0.5 {
            return .yellow
        } else {
            return .orange
        }
    }
}

#Preview {
    ZStack {
        Color.black
        SkeletonOverlayView(pose: PoseData())
    }
}
