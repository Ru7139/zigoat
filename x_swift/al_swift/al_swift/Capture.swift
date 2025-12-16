// Capture.swift
import ScreenCaptureKit
import CoreMedia
import CoreGraphics
import Foundation

var globalFrameCallback: ((UnsafeRawPointer, Int32, Int32, Int32) -> Void)?

@available(macOS 13.0, *)
class RegionRecorder: NSObject, SCStreamDelegate {
    private var stream: SCStream?
    private let targetWidth: Int
    private let targetHeight: Int

    init(width: Int, height: Int) {
        self.targetWidth = width
        self.targetHeight = height
        super.init()
    }

    @available(macOS 13.0, *)
    func start() {
        Task {
            do {
                // ✅ 步骤1: 获取可共享内容
                let content = try await SCShareableContent.getShareableContent(excludingDesktopWindows: false, onScreenWindowsOnly: true)

                // ✅ 步骤2: 找到主显示器对应的 SCDisplay
                let mainDisplayID = CGMainDisplayID()
                guard let scDisplay = content.displays.first(where: { $0.displayID == mainDisplayID }) else {
                    print("❌ 未找到主显示器")
                    return
                }

                // ✅ 步骤3: 创建 filter
                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

                // ✅ 步骤4: 配置
                var config = SCStreamConfiguration()
                config.width = targetWidth
                config.height = targetHeight
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.queueDepth = 3
                config.showsCursor = false
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)

                if #available(macOS 14.0, *) {
                    config.captureResolution = .best
                }

                // ✅ 步骤5: 启动流
                let stream = try SCStream(filter: filter, configuration: config, delegate: self)
                self.stream = stream
                try stream.startCapture()
                print("✅ ScreenCaptureKit 录制已启动")
            } catch {
                print("❌ 启动失败: $error)")
            }
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let totalBytes = bytesPerRow * height

        globalFrameCallback?(baseAddress, Int32(totalBytes), Int32(width), Int32(height))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("🛑 录制停止: $error)")
    }
}

// MARK: - C 兼容接口

private var recorderInstance: RegionRecorder?

@_cdecl("start_region_capture")
public func start_region_capture(
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ fps: Int32,
    _ callback: @convention(c) (UnsafeRawPointer, Int32, Int32, Int32) -> Void
) {
    globalFrameCallback = { (ptr, size, w, h) in
        callback(ptr, size, w, h)
    }

    if #available(macOS 13.0, *) {
        recorderInstance = RegionRecorder(width: Int(width), height: Int(height))
        recorderInstance?.start()
    } else {
        print("❌ 需要 macOS 13.0+")
        return
    }

    RunLoop.current.run()
}
