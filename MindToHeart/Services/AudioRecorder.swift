import AVFoundation
import Observation

/// 把麦克风录音存成临时 m4a 文件。
@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else {
            throw RecorderError.failedToStart
        }

        self.recorder = recorder
        isRecording = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.elapsed = recorder.currentTime
        }
    }

    /// 停止录音，返回录音文件地址
    func stop() -> URL? {
        timer?.invalidate()
        timer = nil
        guard let recorder else { return nil }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recorder.url
    }

    enum RecorderError: LocalizedError {
        case failedToStart

        var errorDescription: String? { "无法开始录音" }
    }
}
