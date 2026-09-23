import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool
    let lockedRotationAngle: CGFloat?
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configure(session: session, mirrored: mirrored, lockedRotationAngle: lockedRotationAngle)
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        view.configure(session: session, mirrored: mirrored, lockedRotationAngle: lockedRotationAngle)
    }
}
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var coordinatedDeviceID: String?
    private var lockedRotationAngle: CGFloat?

    func configure(session: AVCaptureSession, mirrored: Bool, lockedRotationAngle: CGFloat?) {
        if previewLayer.session !== session { previewLayer.session = session }
        self.lockedRotationAngle = lockedRotationAngle
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        guard let input = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else { return }
        if coordinatedDeviceID == input.device.uniqueID {
            if let coordinator = rotationCoordinator { applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview) }
            return
        }
        rotationObservation = nil
        rotationCoordinator = nil
        coordinatedDeviceID = input.device.uniqueID
        let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor [weak self] in
                self?.applyPreviewRotation(angle)
            }
        }
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        let selectedAngle = lockedRotationAngle ?? angle
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(selectedAngle) else { return }
        connection.videoRotationAngle = selectedAngle
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspect
    }
}

struct PoseOverlay: View {
    let landmarks: [CGPoint]
    let imageAspectRatio: Double
    private let bones = [(11,13),(13,15),(12,14),(14,16),(11,12),(11,23),(12,24),(23,24),(23,25),(25,27),(24,26),(26,28)]
    var body: some View { GeometryReader { _ in Canvas { context, size in
        let frameAspect = size.width / max(size.height, 1)
        let aspect = CGFloat(imageAspectRatio)
        let imageWidth = frameAspect > aspect ? size.height * aspect : size.width
        let imageHeight = frameAspect > aspect ? size.height : size.width / max(aspect, 0.01)
        let offsetX = (size.width - imageWidth) / 2
        let offsetY = (size.height - imageHeight) / 2
        func p(_ i: Int) -> CGPoint? { guard landmarks.indices.contains(i) else { return nil }; return CGPoint(x: offsetX + landmarks[i].x * imageWidth, y: offsetY + landmarks[i].y * imageHeight) }
        for (a,b) in bones { if let start = p(a), let end = p(b) { var path = Path(); path.move(to: start); path.addLine(to: end); context.stroke(path, with: .color(.green), lineWidth: 3) } }
        for i in landmarks.indices { if let point = p(i) { context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(.yellow)) } }
    }}.allowsHitTesting(false) }
}
