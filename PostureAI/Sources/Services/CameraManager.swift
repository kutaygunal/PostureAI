import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var isConfigured = false
    @Published var error: String?
    @Published var capturedImage: UIImage?
    @Published var currentPosition: AVCaptureDevice.Position = .front

    let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")

    var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    var onFrameCaptured: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
    }

    func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            await MainActor.run {
                self.error = "Camera access denied. Please enable in Settings."
            }
            return false
        @unknown default:
            return false
        }
    }

    func setupAndStartSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                // Configure and start session
                self.configureSession()
                
                if !self.session.isRunning {
                    self.session.startRunning()
                    DispatchQueue.main.async { [weak self] in
                        self?.isSessionRunning = self?.session.isRunning ?? false
                    }
                }
                continuation.resume()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input
        addVideoInput(for: currentPosition)

        // Add video output
        if !session.outputs.contains(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }

        // Add photo output
        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }

        // Set video rotation angle for portrait camera (iOS 17+)
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()

        // Create or update preview layer on main thread
        DispatchQueue.main.async {
            if self.videoPreviewLayer == nil {
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                self.videoPreviewLayer?.videoGravity = .resizeAspectFill
            }
            // Set portrait rotation angle for preview layer (iOS 17+)
            if let connection = self.videoPreviewLayer?.connection {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            self.isConfigured = true
        }
    }

    private func addVideoInput(for position: AVCaptureDevice.Position) {
        // Remove existing input
        if let currentInput = videoInput {
            session.removeInput(currentInput)
        }

        let deviceType: AVCaptureDevice.DeviceType = position == .front ? .builtInWideAngleCamera : .builtInWideAngleCamera
        guard let videoDevice = AVCaptureDevice.default(deviceType, for: .video, position: position) else {
            DispatchQueue.main.async {
                self.error = "Could not access \(position == .front ? "front" : "back") camera"
            }
            return
        }

        do {
            try videoDevice.lockForConfiguration()
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoDevice.focusMode = .continuousAutoFocus
            }
            videoDevice.unlockForConfiguration()

            let newInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoInput = newInput
                // Don't update currentPosition here - it's done by the caller on main thread
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Could not configure camera: \(error.localizedDescription)"
            }
        }
    }

    func toggleCamera() async {
        guard isConfigured else { return }
        
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                // Reconfigure for new camera position
                self.session.beginConfiguration()
                self.addVideoInput(for: newPosition)
                self.session.commitConfiguration()
                
                // Re-apply portrait rotation angle to video output (iOS 17+)
                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                }
                
                // Update currentPosition on main thread
                DispatchQueue.main.async {
                    self.currentPosition = newPosition
                }
                
                continuation.resume()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { [weak self] in
                    self?.isSessionRunning = false
                }
            }
        }
    }

    var onPhotoCaptured: ((UIImage?) -> Void)?

    func capturePhoto(completion: ((UIImage?) -> Void)? = nil) {
        onPhotoCaptured = completion
        let settings = AVCapturePhotoSettings()
        // Note: isHighResolutionPhotoEnabled is deprecated in iOS 16, 
        // but we keep it for iOS 15 compatibility. maxPhotoDimensions is used on the output instead.
        if #unavailable(iOS 16.0) {
            settings.isHighResolutionPhotoEnabled = true
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrameCaptured?(sampleBuffer)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.capturedImage = nil
                self.onPhotoCaptured?(nil)
                self.onPhotoCaptured = nil
            }
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
            self.onPhotoCaptured?(image)
            self.onPhotoCaptured = nil
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error.localizedDescription)")
        }
    }
}
