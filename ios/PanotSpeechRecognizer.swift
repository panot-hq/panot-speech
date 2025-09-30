import AVFoundation
import Accelerate
import Foundation
import Speech

actor PanotSpeechRecognizer: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    @MainActor var endHandler: (() -> Void)?
    @MainActor var volumeChangeHandler: ((Float) -> Void)?
    
    init(locale: Locale) async throws {
        recognizer = SFSpeechRecognizer(locale: locale)
        
        guard recognizer != nil else {
            throw RecognizerError.nilRecognizer
        }
    }
    
    func getLocale() -> String? {
        return recognizer?.locale.identifier
    }
    
    @MainActor func start(
        interimResults: Bool = true,
        resultHandler: @escaping (SFSpeechRecognitionResult) -> Void,
        errorHandler: @escaping (Error) -> Void,
        endHandler: (() -> Void)?,
        startHandler: @escaping () -> Void,
        volumeChangeHandler: @escaping (Float) -> Void
    ) {
        self.endHandler = endHandler
        self.volumeChangeHandler = volumeChangeHandler
        Task {
            await startRecognizer(
                interimResults: interimResults,
                resultHandler: resultHandler,
                errorHandler: errorHandler,
                startHandler: startHandler
            )
        }
    }
    
    @MainActor func stop() {
        Task {
            let taskState = await task?.state
            if taskState == .running || taskState == .starting {
                await stopListening()
            } else {
                await reset(andEmitEnd: true)
            }
        }
    }
    
    @MainActor func abort() {
        Task {
            await reset(andEmitEnd: true)
        }
    }
    
    func getState() -> String {
        switch task?.state {
        case .none:
            return "inactive"
        case .some(.starting), .some(.running):
            return "recognizing"
        case .some(.canceling):
            return "stopping"
        default:
            return "inactive"
        }
    }
    
    private func startRecognizer(
        interimResults: Bool,
        resultHandler: @escaping (SFSpeechRecognitionResult) -> Void,
        errorHandler: @escaping (Error) -> Void,
        startHandler: @escaping () -> Void
    ) {
        reset(andEmitEnd: false)
        
        self.request = nil
        
        guard let recognizer, recognizer.isAvailable else {
            errorHandler(RecognizerError.recognizerIsUnavailable)
            reset(andEmitEnd: true)
            return
        }
        
        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = interimResults
            
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = false
            }
            
            self.request = request
            
            try prepareMicrophoneRecognition(request: request)
            
            startRecognitionTask(
                with: request,
                recognizer: recognizer,
                resultHandler: resultHandler,
                errorHandler: errorHandler
            )
            
            startHandler()
        } catch {
            errorHandler(error)
            reset(andEmitEnd: true)
        }
    }
    
    private func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        recognizer: SFSpeechRecognizer,
        resultHandler: @escaping (SFSpeechRecognitionResult) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        let audioEngine = self.audioEngine
        
        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.recognitionHandler(
                audioEngine: audioEngine,
                result: result,
                error: error,
                resultHandler: resultHandler,
                errorHandler: errorHandler
            )
        }
    }
    
    private func prepareMicrophoneRecognition(
        request: SFSpeechRecognitionRequest
    ) throws {
        try setupAudioSession()
        self.audioEngine = AVAudioEngine()
        
        guard let audioEngine = self.audioEngine else {
            throw RecognizerError.nilRecognizer
        }
        
        let inputNode = audioEngine.inputNode
        let audioFormat = inputNode.outputFormat(forBus: 0)
        
        guard audioFormat.sampleRate > 0 else {
            throw RecognizerError.notPermittedToRecord
        }
        
        guard let audioBufferRequest = request as? SFSpeechAudioBufferRecognitionRequest else {
            throw RecognizerError.nilRecognizer
        }
        
        // Create mixer node for audio processing
        let mixerNode = AVAudioMixerNode()
        audioEngine.attach(mixerNode)
        audioEngine.connect(inputNode, to: mixerNode, format: audioFormat)
        
        // Install tap for speech recognition
        mixerNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { buffer, _ in
            audioBufferRequest.append(buffer)
        }
        
        // Install separate tap for volume monitoring with larger buffer
        let volumeBufferSize = AVAudioFrameCount(audioFormat.sampleRate * 0.1) // 100ms
        let volumeMixerNode = AVAudioMixerNode()
        audioEngine.attach(volumeMixerNode)
        audioEngine.connect(mixerNode, to: volumeMixerNode, format: audioFormat)
        
        volumeMixerNode.installTap(onBus: 0, bufferSize: volumeBufferSize, format: audioFormat) { [weak self] buffer, _ in
            guard let power = Self.calculatePower(buffer: buffer) else { return }
            
            // Normalize power to a more useful range (0.0 to 1.0)
            let minDb: Float = -60.0
            let maxDb: Float = 0.0
            let normalized: Float = (power - minDb) / (maxDb - minDb)
            let clampedNormalized = min(max(normalized, 0.0), 1.0)
            
            // Scale to -2 to 10 range (matching expo-speech-recognition behavior)
            let scaledValue = clampedNormalized * (10 - (-2)) + (-2)
            
            Task { @MainActor in
                self?.volumeChangeHandler?(scaledValue)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // Calculate power/volume from audio buffer
    private static func calculatePower(buffer: AVAudioPCMBuffer) -> Float? {
        let length = vDSP_Length(buffer.frameLength)
        let channel = 0
        
        if let floatData = buffer.floatChannelData {
            return calculatePowers(data: floatData[channel], strideFrames: buffer.stride, length: length)
        } else if let int16Data = buffer.int16ChannelData {
            // Convert int16 to float
            var floatChannelData: [Float] = Array(repeating: 0.0, count: Int(buffer.frameLength))
            vDSP_vflt16(int16Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
            var scalar = Float(INT16_MAX)
            vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)
            return calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length)
        } else if let int32Data = buffer.int32ChannelData {
            // Convert int32 to float
            var floatChannelData: [Float] = Array(repeating: 0.0, count: Int(buffer.frameLength))
            vDSP_vflt32(int32Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
            var scalar = Float(INT32_MAX)
            vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)
            return calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length)
        }
        
        return nil
    }
    
    private static func calculatePowers(
        data: UnsafePointer<Float>, strideFrames: Int, length: vDSP_Length
    ) -> Float? {
        let kMinLevel: Float = 1e-7  // -160 dB
        var max: Float = 0.0
        vDSP_maxv(data, strideFrames, &max, length)
        if max < kMinLevel {
            max = kMinLevel
        }
        return 20.0 * log10(max)
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func stopListening() {
        if let request = request as? SFSpeechAudioBufferRecognitionRequest {
            request.endAudio()
        }
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.inputNode.reset()
            audioEngine?.reset()
            audioEngine = nil
        }
        task?.finish()
    }
    
    private func reset(andEmitEnd: Bool = false) {
        let taskWasRunning = task != nil
        let shouldEmitEndEvent = andEmitEnd || taskWasRunning
        
        task?.cancel()
        audioEngine?.stop()
        audioEngine?.attachedNodes.forEach { $0.removeTap(onBus: 0) }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.inputNode.reset()
        audioEngine?.reset()
        audioEngine = nil
        
        request = nil
        task = nil
        
        if shouldEmitEndEvent {
            end()
        }
    }
    
    private func end() {
        Task {
            await MainActor.run {
                self.endHandler?()
            }
        }
    }
    
    nonisolated private func recognitionHandler(
        audioEngine: AVAudioEngine?,
        result: SFSpeechRecognitionResult?,
        error: Error?,
        resultHandler: @escaping (SFSpeechRecognitionResult) -> Void,
        errorHandler: @escaping (Error) -> Void
    ) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if let result = result {
            Task { @MainActor in
                let taskState = await task?.state
                if taskState != .none {
                    resultHandler(result)
                }
            }
        }
        
        if let error = error {
            Task { @MainActor in
                if await task != nil {
                    errorHandler(error)
                }
            }
        }
        
        if receivedError || receivedFinalResult {
            Task { @MainActor in
                await reset()
            }
            return
        }
    }
}
