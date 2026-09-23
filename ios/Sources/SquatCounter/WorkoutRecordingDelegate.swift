@preconcurrency import AVFoundation

/// O AVFoundation chama estes métodos fora da thread principal.
final class WorkoutRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let started: @MainActor (TimeInterval) -> Void
    private let finished: @MainActor (URL, String?, Bool) -> Void

    init(started: @escaping @MainActor (TimeInterval) -> Void,
         finished: @escaping @MainActor (URL, String?, Bool) -> Void) {
        self.started = started
        self.finished = finished
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo outputFileURL: URL,
                    startPTS: CMTime,
                    from connections: [AVCaptureConnection]) {
        let seconds = startPTS.seconds
        Task { @MainActor [started] in started(seconds) }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        let message = error?.localizedDescription
        let playable = error == nil || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? NSNumber)?.boolValue == true
        Task { @MainActor [finished] in finished(outputFileURL, message, playable) }
    }
}
