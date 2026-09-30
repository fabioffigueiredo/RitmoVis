#if DEBUG
import AVFoundation
import QuartzCore

/// A prerecorded input for device QA. The exposed player drives the preview;
/// its video output supplies the same playback frames to the live inference queue.
@MainActor
final class RecordedCameraSource: NSObject {
    let player: AVPlayer

    private let item: AVPlayerItem
    private let output: AVPlayerItemVideoOutput
    private let onFrame: @MainActor (CMSampleBuffer) -> Void
    private let onEnd: @MainActor () -> Void
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: RecordedCameraDisplayLinkTarget?
    private var endObserver: (any NSObjectProtocol)?
    private var isRunning = false
    private var lastPresentationTime: CMTime = .invalid

    init(url: URL,
         onFrame: @escaping @MainActor (CMSampleBuffer) -> Void,
         onEnd: @escaping @MainActor () -> Void) {
        precondition(url.isFileURL, "Recorded camera QA accepts only local files.")
        player = AVPlayer(url: url)
        item = player.currentItem!
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        self.onFrame = onFrame
        self.onEnd = onEnd
        super.init()
        item.add(output)
        player.actionAtItemEnd = .pause
        player.isMuted = true
    }

    /// Starts or resumes playback without reading ahead or accumulating frames.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.playbackDidEnd() }
        }
        let target = RecordedCameraDisplayLinkTarget(source: self)
        let link = CADisplayLink(target: target, selector: #selector(RecordedCameraDisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        displayLinkTarget = target
        displayLink = link
        link.add(to: .main, forMode: .common)
        player.play()
    }

    /// Safe to call repeatedly, including after the end callback.
    func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.pause()
    }

    isolated deinit {
        displayLink?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player.pause()
    }

    fileprivate func tick(_ link: CADisplayLink) {
        guard isRunning else { return }
        let itemTime = output.itemTime(forHostTime: link.timestamp)
        guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return }
        var presentationTime = CMTime.invalid
        guard let pixels = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: &presentationTime),
              presentationTime.isNumeric,
              !lastPresentationTime.isNumeric || CMTimeCompare(presentationTime, lastPresentationTime) > 0,
              let sample = Self.sampleBuffer(pixels: pixels, presentationTime: presentationTime) else { return }
        lastPresentationTime = presentationTime
        onFrame(sample)
    }

    private func playbackDidEnd() {
        guard isRunning else { return }
        stop()
        onEnd()
    }

    /// Test seam for checking that wrapping preserves the image and movie PTS.
    static func sampleBuffer(pixels: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        guard presentationTime.isNumeric else { return nil }
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: pixels, formatDescriptionOut: &format
        ) == noErr, let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: presentationTime,
                                        decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: pixels, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sample
        ) == noErr else { return nil }
        return sample
    }
}

/// CADisplayLink retains its target. This weak proxy lets the source deinitialize
/// even when its owner forgets to stop playback explicitly.
@MainActor
private final class RecordedCameraDisplayLinkTarget: NSObject {
    private weak var source: RecordedCameraSource?

    init(source: RecordedCameraSource) {
        self.source = source
        super.init()
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let source else {
            link.invalidate()
            return
        }
        source.tick(link)
    }
}
#endif
