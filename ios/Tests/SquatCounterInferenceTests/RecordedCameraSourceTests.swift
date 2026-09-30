import XCTest
import AVFoundation
@testable import SquatCounter

@MainActor
final class RecordedCameraSourceTests: XCTestCase {
    func testFrameWrapperPreservesPixelDimensionsAndMovieTime() throws {
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 64, 48,
            kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        let time = CMTime(value: 123, timescale: 30)
        let frame = try XCTUnwrap(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel),
                                                                   presentationTime: time))
        XCTAssertEqual(CMSampleBufferGetPresentationTimeStamp(frame), time)
        let output = try XCTUnwrap(CMSampleBufferGetImageBuffer(frame))
        XCTAssertEqual(CVPixelBufferGetWidth(output), 64)
        XCTAssertEqual(CVPixelBufferGetHeight(output), 48)
        XCTAssertTrue(output === pixel)
    }

    func testInvalidMovieTimeCannotEnterInference() throws {
        var pixel: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32,
            kCVPixelFormatType_32BGRA, nil, &pixel), kCVReturnSuccess)
        XCTAssertNil(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel), presentationTime: .invalid))
        XCTAssertNil(RecordedCameraSource.sampleBuffer(pixels: try XCTUnwrap(pixel), presentationTime: .indefinite))
    }

    func testStopIsIdempotentAndSourceDoesNotRetainItself() {
        var source: RecordedCameraSource? = RecordedCameraSource(url: URL(fileURLWithPath: "/missing-qa-file.mov"),
            onFrame: { _ in XCTFail("Missing file must not emit pixels") }, onEnd: {})
        weak var retained = source
        source?.start()
        source?.start()
        source?.stop()
        source?.stop()
        XCTAssertEqual(source?.player.rate, 0)
        source = nil
        XCTAssertNil(retained)
    }
}
