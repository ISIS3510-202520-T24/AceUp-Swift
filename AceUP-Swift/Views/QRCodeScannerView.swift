//
//  QRCodeScannerView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCodeScanned: (String) -> Void
    let onError: ((String) -> Void)?
    
    init(isPresented: Binding<Bool>, onCodeScanned: @escaping (String) -> Void, onError: ((String) -> Void)? = nil) {
        self._isPresented = isPresented
        self.onCodeScanned = onCodeScanned
        self.onError = onError
    }
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRCodeScannerView
        
        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            parent.onCodeScanned(code)
            parent.isPresented = false
        }
        
        func didFailWithError(_ error: Error) {
            print("QR Scanner Error: \(error)")
            parent.onError?(error.localizedDescription)
            parent.isPresented = false
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: Error)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }
    
    private func setupCamera() {
        // Check camera permission first
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureCaptureSession()
                    } else {
                        self.delegate?.didFailWithError(QRScannerError.cameraPermissionDenied)
                    }
                }
            }
        case .authorized:
            configureCaptureSession()
        case .restricted, .denied:
            delegate?.didFailWithError(QRScannerError.cameraPermissionDenied)
        @unknown default:
            delegate?.didFailWithError(QRScannerError.cameraPermissionDenied)
        }
    }
    
    private func configureCaptureSession() {
        let session = AVCaptureSession()
        captureSession = session
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(QRScannerError.cameraNotAvailable)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            delegate?.didFailWithError(QRScannerError.cannotAddInput)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError(QRScannerError.cannotAddOutput)
            return
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer = layer
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let scanFrame = CGRect(
            x: view.bounds.width * 0.1,
            y: view.bounds.height * 0.3,
            width: view.bounds.width * 0.8,
            height: view.bounds.width * 0.8
        )
        
        let scanPath = UIBezierPath(rect: overlayView.bounds)
        let scanHole = UIBezierPath(rect: scanFrame)
        scanPath.append(scanHole.reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = scanPath.cgPath
        overlayView.layer.mask = maskLayer
        
        view.addSubview(overlayView)
        
  
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(rect: scanFrame).cgPath
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.lineWidth = 2
        borderLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(borderLayer)
        
        
        let instructionLabel = UILabel()
        instructionLabel.text = "Scan the group's QR code"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50)
        ])
        
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        cancelButton.layer.cornerRadius = 25
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func cancelTapped() {
        captureSession?.stopRunning()
        dismiss(animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        captureSession?.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanCode(stringValue)
        }
    }
}

enum QRScannerError: Error, LocalizedError {
    case cameraNotAvailable
    case cameraPermissionDenied
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera not available"
        case .cameraPermissionDenied:
            return "Camera permission denied. Please enable camera access in Settings."
        case .cannotAddInput:
            return "Cannot add camera input"
        case .cannotAddOutput:
            return "Cannot add metadata output"
        }
    }
}