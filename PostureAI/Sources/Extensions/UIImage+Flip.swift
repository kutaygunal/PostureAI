import UIKit

extension UIImage {
    /// Returns a horizontally flipped version of the image
    func flippedHorizontally() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Flip horizontally by translating and scaling
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        draw(in: CGRect(origin: .zero, size: size))
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return flippedImage
    }
}
