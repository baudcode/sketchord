import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "de.onenightproductions.sketchord/audio_input",
      binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "decodeToWav" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let sourcePath = arguments["audioPath"] as? String else {
        result(FlutterError(code: "invalid_audio", message: "A source audio path is required.", details: nil))
        return
      }
      do {
        result(try self.decodeToWav(sourcePath: sourcePath))
      } catch {
        result(FlutterError(code: "decode_failed", message: error.localizedDescription, details: nil))
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func decodeToWav(sourcePath: String) throws -> String {
    let source = try AVAudioFile(forReading: URL(fileURLWithPath: sourcePath))
    let input = source.processingFormat
    let targetFormat = AVAudioFormat(standardFormatWithSampleRate: input.sampleRate, channels: 1)!
    let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("transcription-pcm", isDirectory: true)
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let name = URL(fileURLWithPath: sourcePath).deletingPathExtension().lastPathComponent
    let destination = cache.appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970 * 1000)).wav")
    let output = try AVAudioFile(forWriting: destination, settings: targetFormat.settings)
    let frames: AVAudioFrameCount = 4096
    guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: frames),
          let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frames),
          let outputSamples = targetBuffer.floatChannelData else {
      throw NSError(domain: "AudioInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate audio buffers."])
    }
    while true {
      try source.read(into: sourceBuffer, frameCount: frames)
      if sourceBuffer.frameLength == 0 { break }
      guard let inputSamples = sourceBuffer.floatChannelData else {
        throw NSError(domain: "AudioInput", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read PCM samples."])
      }
      let channelCount = Int(input.channelCount)
      let frameCount = Int(sourceBuffer.frameLength)
      for frame in 0..<frameCount {
        var sum: Float = 0
        for channel in 0..<channelCount { sum += inputSamples[channel][frame] }
        outputSamples[0][frame] = sum / Float(channelCount)
      }
      targetBuffer.frameLength = sourceBuffer.frameLength
      try output.write(from: targetBuffer)
    }
    return destination.path
  }
}
