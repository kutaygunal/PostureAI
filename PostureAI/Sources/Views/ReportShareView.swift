import SwiftUI
import UIKit
import PDFKit
import Combine

// MARK: - Report Share Sheet

/// A view that presents the native iOS share sheet for sharing the posture report
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    var completion: ((Bool) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        
        // Exclude some activities if needed
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Report Generator

/// Generates a well-formatted PDF report with posture analysis data
class PostureReportGenerator {
    
    /// Generate a PDF report from the posture analysis data
    static func generateReport(
        score: Int,
        sideMetrics: SidePostureMetrics?,
        frontMetrics: FrontPostureMetrics?,
        sideImageURL: URL?,
        frontImageURL: URL?,
        userHeightCm: Double
    ) -> Data? {
        
        let pdfMetaData = [
            kCGPDFContextCreator: "PostureAI",
            kCGPDFContextTitle: "Posture Analysis Report",
            kCGPDFContextAuthor: "PostureAI App"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // A4 size
        let pageWidth: CGFloat = 612  // 8.5 inches
        let pageHeight: CGFloat = 792 // 11 inches
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var currentY: CGFloat = 40
            let margin: CGFloat = 60
            let contentWidth = pageWidth - (margin * 2)
            
            // MARK: - Header
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
            ]
            
            let title = NSAttributedString(string: "PostureAI Report", attributes: titleAttributes)
            title.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 40))
            
            currentY += 50
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: Date())
            
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.gray
            ]
            let dateAttr = NSAttributedString(string: "Generated on \(dateString)", attributes: dateAttributes)
            dateAttr.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 20))
            
            currentY += 35
            
            // Divider
            drawDivider(at: currentY, width: contentWidth, x: margin)
            currentY += 25
            
            // MARK: - Overall Score Section
            let scoreBackgroundColor = scoreColor(for: score)
            let scoreRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 120)
            
            // Score box background
            let scorePath = UIBezierPath(roundedRect: scoreRect, cornerRadius: 12)
            scoreBackgroundColor.withAlphaComponent(0.15).setFill()
            scorePath.fill()
            
            // Score border
            scoreBackgroundColor.setStroke()
            scorePath.lineWidth = 2
            scorePath.stroke()
            
            // Score number
            let scoreNumberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: scoreBackgroundColor
            ]
            let scoreNumber = NSAttributedString(string: "\(score)", attributes: scoreNumberAttributes)
            scoreNumber.draw(in: CGRect(x: margin + 20, y: currentY + 25, width: 120, height: 60))
            
            // Score label
            let scoreLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.darkGray
            ]
            let scoreLabelText = scoreLabel(for: score)
            let scoreLabel = NSAttributedString(string: scoreLabelText, attributes: scoreLabelAttributes)
            scoreLabel.draw(in: CGRect(x: margin + 20, y: currentY + 75, width: contentWidth - 40, height: 30))
            
            currentY += 140
            
            // Divider
            drawDivider(at: currentY, width: contentWidth, x: margin)
            currentY += 25
            
            // MARK: - Side View Metrics
            if let sideMetrics = sideMetrics {
                let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
                ]
                let sectionTitle = NSAttributedString(string: "Side View Analysis", attributes: sectionTitleAttributes)
                sectionTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 30))
                currentY += 35
                
                // Side view metrics
                let metrics: [(String, String, OffsetStatus)] = [
                    ("Head Forward", String(format: "%.1f cm", sideMetrics.headForwardCm), sideMetrics.headStatus),
                    ("Shoulders Forward", String(format: "%.1f cm", sideMetrics.shoulderForwardCm), sideMetrics.shoulderStatus),
                    ("Hips Forward", String(format: "%.1f cm", sideMetrics.hipForwardCm), sideMetrics.hipStatus),
                    ("Knees Forward", String(format: "%.1f cm", sideMetrics.kneeForwardCm), sideMetrics.kneeStatus)
                ]
                
                for metric in metrics {
                    currentY = drawMetricRow(
                        title: metric.0,
                        value: metric.1,
                        status: metric.2,
                        at: currentY,
                        width: contentWidth,
                        margin: margin
                    )
                    currentY += 8
                }
                
                currentY += 15
            }
            
            // MARK: - Front View Metrics
            if let frontMetrics = frontMetrics {
                // Check if we need a new page
                if currentY > pageHeight - 250 {
                    context.beginPage()
                    currentY = 40
                }
                
                let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
                ]
                let sectionTitle = NSAttributedString(string: "Front View Analysis", attributes: sectionTitleAttributes)
                sectionTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 30))
                currentY += 35
                
                // Front view metrics
                let metrics: [(String, String, OffsetStatus)] = [
                    ("Shoulder Tilt", String(format: "%.1f°", abs(frontMetrics.shoulderTiltAngle)), frontMetrics.shoulderStatus),
                    ("Hip Tilt", String(format: "%.1f°", abs(frontMetrics.hipTiltAngle)), frontMetrics.hipStatus),
                    ("Head Tilt", String(format: "%.1f°", abs(frontMetrics.headTiltAngle)), frontMetrics.headStatus)
                ]
                
                for metric in metrics {
                    currentY = drawMetricRow(
                        title: metric.0,
                        value: metric.1,
                        status: metric.2,
                        at: currentY,
                        width: contentWidth,
                        margin: margin
                    )
                    currentY += 8
                }
                
                currentY += 20
            }
            
            // Check if we need a new page
            if currentY > pageHeight - 200 {
                context.beginPage()
                currentY = 40
            }
            
            // Divider
            drawDivider(at: currentY, width: contentWidth, x: margin)
            currentY += 25
            
            // MARK: - Recommendations Section
            let recTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
            ]
            let recTitle = NSAttributedString(string: "Recommendations", attributes: recTitleAttributes)
            recTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 30))
            currentY += 40
            
            let recommendations = getRecommendations(for: score, sideMetrics: sideMetrics, frontMetrics: frontMetrics)
            
            for rec in recommendations {
                let recParagraph = NSMutableParagraphStyle()
                recParagraph.lineSpacing = 4
                
                let bulletAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1.0),
                    .paragraphStyle: recParagraph
                ]
                let bullet = NSAttributedString(string: "• \(rec.title): ", attributes: bulletAttributes)
                
                let descAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: recParagraph
                ]
                let desc = NSAttributedString(string: rec.description, attributes: descAttributes)
                
                let combined = NSMutableAttributedString()
                combined.append(bullet)
                combined.append(desc)
                
                let textRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 60)
                combined.draw(in: textRect)
                
                currentY += 50
            }
            
            // MARK: - Footer
            let footerY = pageHeight - 60
            drawDivider(at: footerY - 10, width: contentWidth, x: margin)
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            let footerText = "This report is for informational purposes only. Consult a healthcare professional for medical advice."
            let footer = NSAttributedString(string: footerText, attributes: footerAttributes)
            footer.draw(in: CGRect(x: margin, y: footerY, width: contentWidth, height: 40))
            
            // MARK: - Add Images on Second Page if available
            if sideImageURL != nil || frontImageURL != nil {
                context.beginPage()
                currentY = 40
                
                let imagesTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
                ]
                let imagesTitle = NSAttributedString(string: "Analysis Images", attributes: imagesTitleAttributes)
                imagesTitle.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 30))
                currentY += 50
                
                // Draw Side Image
                if let sideURL = sideImageURL,
                   let imageData = try? Data(contentsOf: sideURL),
                   let uiImage = UIImage(data: imageData) {
                    
                    let imageWidth = contentWidth / 2 - 10
                    let aspectRatio = uiImage.size.width / uiImage.size.height
                    let imageHeight = imageWidth / aspectRatio
                    
                    let imageRect = CGRect(x: margin, y: currentY, width: imageWidth, height: min(imageHeight, 300))
                    uiImage.draw(in: imageRect)
                    
                    // Image label
                    let labelAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: UIColor.darkGray
                    ]
                    let label = NSAttributedString(string: "Side View", attributes: labelAttributes)
                    label.draw(in: CGRect(x: margin, y: currentY - 20, width: 100, height: 20))
                }
                
                // Draw Front Image
                if let frontURL = frontImageURL,
                   let imageData = try? Data(contentsOf: frontURL),
                   let uiImage = UIImage(data: imageData) {
                    
                    let imageWidth = contentWidth / 2 - 10
                    let aspectRatio = uiImage.size.width / uiImage.size.height
                    let imageHeight = imageWidth / aspectRatio
                    
                    let xOffset = sideImageURL != nil ? margin + contentWidth / 2 + 10 : margin
                    let imageRect = CGRect(x: xOffset, y: currentY, width: imageWidth, height: min(imageHeight, 300))
                    uiImage.draw(in: imageRect)
                    
                    // Image label
                    let labelAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: UIColor.darkGray
                    ]
                    let label = NSAttributedString(string: "Front View", attributes: labelAttributes)
                    label.draw(in: CGRect(x: xOffset, y: currentY - 20, width: 100, height: 20))
                }
            }
        }
        
        return data
    }
    
    // MARK: - Helper Functions
    
    private static func drawDivider(at y: CGFloat, width: CGFloat, x: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        UIColor.lightGray.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
    
    private static func drawMetricRow(
        title: String,
        value: String,
        status: OffsetStatus,
        at y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        let titleAttr = NSAttributedString(string: title, attributes: titleAttributes)
        titleAttr.draw(in: CGRect(x: margin, y: y, width: width / 2, height: 25))
        
        // Value
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let valueAttr = NSAttributedString(string: value, attributes: valueAttributes)
        let valueX = margin + width / 2
        valueAttr.draw(in: CGRect(x: valueX, y: y, width: width / 4, height: 25))
        
        // Status badge
        let statusText = status.description
        let statusColor = statusColor(status)
        
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: statusColor
        ]
        let badgeAttr = NSAttributedString(string: statusText, attributes: badgeAttributes)
        
        let badgeSize = badgeAttr.size()
        let badgeX = margin + width - badgeSize.width - 10
        let badgeRect = CGRect(x: badgeX - 8, y: y - 2, width: badgeSize.width + 16, height: 22)
        
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6)
        statusColor.withAlphaComponent(0.1).setFill()
        badgePath.fill()
        
        badgeAttr.draw(in: CGRect(x: badgeX, y: y + 2, width: badgeSize.width, height: 20))
        
        return y + 30
    }
    
    private static func scoreColor(for score: Int) -> UIColor {
        switch score {
        case 90...100: return UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        case 75..<90: return UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        case 50..<75: return UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        case 25..<50: return UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        default: return UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
    
    private static func scoreLabel(for score: Int) -> String {
        switch score {
        case 90...100: return "Excellent posture"
        case 75..<90: return "Good posture"
        case 50..<75: return "Moderate imbalance"
        case 25..<50: return "Poor posture"
        default: return "Severe posture issues"
        }
    }
    
    private static func statusColor(_ status: OffsetStatus) -> UIColor {
        switch status {
        case .good: return UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        case .mild: return UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        case .severe: return UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0)
        case .neutral: return UIColor.gray
        }
    }
    
    private static func getRecommendations(
        for score: Int,
        sideMetrics: SidePostureMetrics?,
        frontMetrics: FrontPostureMetrics?
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // General recommendations
        recommendations.append(Recommendation(
            title: "Ergonomic Setup",
            description: "Adjust your monitor to eye level and keep feet flat on floor."
        ))
        
        recommendations.append(Recommendation(
            title: "Take Breaks",
            description: "Stand and stretch every 30 minutes to reduce muscle tension."
        ))
        
        // Specific recommendations based on metrics
        if let side = sideMetrics {
            if side.headForwardCm > 3 {
                recommendations.append(Recommendation(
                    title: "Neck Posture",
                    description: "Practice chin tucks to reduce forward head posture."
                ))
            }
            if side.shoulderForwardCm > 3 {
                recommendations.append(Recommendation(
                    title: "Shoulder Alignment",
                    description: "Perform scapular retraction exercises to pull shoulders back."
                ))
            }
        }
        
        recommendations.append(Recommendation(
            title: "Core Exercises",
            description: "Strengthen core muscles to improve overall posture stability."
        ))
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct Recommendation {
    let title: String
    let description: String
}

// MARK: - View Extension for Sharing

extension View {
    func sharePostureReport(
        isPresented: Binding<Bool>,
        reportData: PDFReportData
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            if let pdfData = reportData.pdfData {
                ShareSheet(activityItems: [
                    pdfData,
                    "My PostureAI Analysis Report"
                ]) { completed in
                    isPresented.wrappedValue = false
                }
            }
        }
    }
}

// MARK: - Report Data Observable

class PDFReportData: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    var pdfURL: URL? {
        didSet {
            objectWillChange.send()
        }
    }
    
    var pdfData: Data? {
        didSet {
            objectWillChange.send()
        }
    }
    
    func generate(
        score: Int,
        sideMetrics: SidePostureMetrics?,
        frontMetrics: FrontPostureMetrics?,
        sideImageURL: URL?,
        frontImageURL: URL?,
        userHeightCm: Double
    ) {
        // Generate PDF data
        let data = PostureReportGenerator.generateReport(
            score: score,
            sideMetrics: sideMetrics,
            frontMetrics: frontMetrics,
            sideImageURL: sideImageURL,
            frontImageURL: frontImageURL,
            userHeightCm: userHeightCm
        )
        
        self.pdfData = data
        
        // Save to temporary file for sharing
        if let data = data {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "PostureAI_Report_\(dateString()).pdf"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL, options: .atomic)
                self.pdfURL = fileURL
            } catch {
                print("Failed to save PDF: \(error)")
                self.pdfURL = nil
            }
        }
    }
    
    func clear() {
        // Clean up temp file
        if let url = pdfURL {
            try? FileManager.default.removeItem(at: url)
        }
        pdfData = nil
        pdfURL = nil
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
