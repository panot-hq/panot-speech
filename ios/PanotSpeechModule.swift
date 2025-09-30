import ExpoModulesCore
import Foundation
import AVFoundation
import Speech

public enum RecognizerError: Error {
    case nilRecognizer
    case notAuthorizedToRecognize
    case notPermittedToRecord
    case recognizerIsUnavailable
    
    var message: String {
        switch self {
        case .nilRecognizer: return "Can't initialize speech recognizer"
        case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
        case .notPermittedToRecord: return "Not permitted to record audio"
        case .recognizerIsUnavailable: return "Recognizer is unavailable"
        }
    }
}

public class PanotSpeechModule: Module {
    
    private var speechRecognizer: PanotSpeechRecognizer?
    private var isTranscribing = false
    private var currentTranscript = ""

    public func definition() -> ModuleDefinition {
        Name("PanotSpeech")
        
        OnCreate {
            guard let permissionsManager = appContext?.permissions else {
                return
            }
            permissionsManager.register([
                PanotSpeechPermissionRequester(),
                MicrophoneRequester(),
                SpeechRecognizerRequester(),
            ])
        }
        
        OnDestroy {
            Task {
                await speechRecognizer?.abort()
            }
        }
        
        // Functions  
        AsyncFunction("requestPermissions") { (promise: Promise) in
            guard let permissions = self.appContext?.permissions else {
                throw Exceptions.PermissionsModuleNotFound()
            }
            permissions.askForPermission(
                usingRequesterClass: PanotSpeechPermissionRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("getPermissions") { (promise: Promise) in
            guard let permissions = self.appContext?.permissions else {
                throw Exceptions.PermissionsModuleNotFound()
            }
            permissions.getPermissionUsingRequesterClass(
                PanotSpeechPermissionRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("getMicrophonePermissions") { (promise: Promise) in
            self.appContext?.permissions?.getPermissionUsingRequesterClass(
                MicrophoneRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("requestMicrophonePermissions") { (promise: Promise) in
            self.appContext?.permissions?.askForPermission(
                usingRequesterClass: MicrophoneRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("getSpeechRecognizerPermissions") { (promise: Promise) in
            self.appContext?.permissions?.getPermissionUsingRequesterClass(
                SpeechRecognizerRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("requestSpeechRecognizerPermissions") { (promise: Promise) in
            self.appContext?.permissions?.askForPermission(
                usingRequesterClass: SpeechRecognizerRequester.self,
                resolve: promise.resolver,
                reject: promise.legacyRejecter
            )
        }
        
        AsyncFunction("getState") { (promise: Promise) in
            Task {
                let state = await self.speechRecognizer?.getState()
                promise.resolve(state ?? "inactive")
            }
        }
        
        Function("startTranscribing") { (interimResults: Bool, lang: String?) in
            Task {
                do {
                    try await self.startTranscribing(
                        interimResults: interimResults,
                        lang: lang ?? "en-US"
                    )
                } catch {
                    self.sendEvent("onError", [
                        "error": "audio-capture",
                        "message": error.localizedDescription
                    ])
                }
            }
        }
        
        AsyncFunction("getSupportedLocales") { (promise: Promise) in
            let supportedLocales = SFSpeechRecognizer.supportedLocales()
                .map { $0.identifier }
                .sorted()
            
            promise.resolve([
                "locales": supportedLocales,
                "installedLocales": supportedLocales
            ])
        }
        
        Function("isLocaleSupported") { (locale: String) -> Bool in
            let normalizedIdentifier = locale.replacingOccurrences(of: "_", with: "-")
            let supportedLocales = SFSpeechRecognizer.supportedLocales()
            return supportedLocales.contains(where: { 
                $0.identifier == locale || $0.identifier == normalizedIdentifier 
            })
        }
        
        Function("stopTranscribing") {
            Task {
                await self.stopTranscribing()
            }
        }
        
        Function("resetTranscript") {
            Task {
                await self.resetTranscript()
            }
        }
        
        // Events
        Events("onTranscriptUpdate", "onError", "onStatusChange", "onStart", "onEnd", "onVolumeChange")
    }
    
    private func startTranscribing(interimResults: Bool = true, lang: String = "en-US") async throws {
        guard !isTranscribing else { return }
        
        // Check permissions
        guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
            sendEvent("onError", [
                "error": "not-allowed",
                "message": RecognizerError.notAuthorizedToRecognize.message
            ])
            return
        }
        
        guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
            sendEvent("onError", [
                "error": "not-allowed",
                "message": RecognizerError.notPermittedToRecord.message
            ])
            return
        }
        
        // Validate and normalize locale
        guard let locale = resolveLocale(localeIdentifier: lang) else {
            let availableLocales = SFSpeechRecognizer.supportedLocales()
                .map { $0.identifier }
                .joined(separator: ", ")
            
            sendEvent("onError", [
                "error": "language-not-supported",
                "message": "Locale \(lang) is not supported. Available locales: \(availableLocales)"
            ])
            return
        }
        
        // Get current locale of recognizer
        let currentLocale = await speechRecognizer?.getLocale()
        
        // Recreate recognizer if locale changed or doesn't exist
        if self.speechRecognizer == nil || currentLocale != locale.identifier {
            self.speechRecognizer = try await PanotSpeechRecognizer(locale: locale)
        }
        
        // Start recognition
        await speechRecognizer?.start(
            interimResults: interimResults,
            resultHandler: { [weak self] result in
                self?.handleRecognitionResult(result)
            },
            errorHandler: { [weak self] error in
                self?.handleRecognitionError(error)
            },
            endHandler: { [weak self] in
                self?.handleEnd()
            },
            startHandler: { [weak self] in
                self?.handleStart()
            },
            volumeChangeHandler: { [weak self] volume in
                self?.handleVolumeChange(volume)
            }
        )
        
        isTranscribing = true
    }
    
    // Normalize locale for compatibility (e.g., "en_US" -> "en-US")
    private func resolveLocale(localeIdentifier: String) -> Locale? {
        let normalizedIdentifier = localeIdentifier.replacingOccurrences(of: "_", with: "-")
        let localesToCheck = [localeIdentifier, normalizedIdentifier]
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        for identifier in localesToCheck {
            if supportedLocales.contains(where: { $0.identifier == identifier }) {
                return Locale(identifier: identifier)
            }
        }
        
        return nil
    }
    
    private func stopTranscribing() async {
        guard isTranscribing else { return }
        
        if let recognizer = speechRecognizer {
            await recognizer.stop()
        } else {
            handleEnd()
        }
        
        isTranscribing = false
    }
    
    private func resetTranscript() async {
        currentTranscript = ""
        await stopTranscribing()
        sendEvent("onTranscriptUpdate", ["transcript": "", "isFinal": false])
    }
    
    private func handleStart() {
        isTranscribing = true
        sendEvent("onStart")
        sendEvent("onStatusChange", ["isTranscribing": true])
    }
    
    private func handleEnd() {
        isTranscribing = false
        sendEvent("onEnd")
        sendEvent("onStatusChange", ["isTranscribing": false])
    }
    
    private func handleVolumeChange(_ volume: Float) {
        sendEvent("onVolumeChange", ["volume": volume])
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString
        let isFinal = result.isFinal
        
        // Calculate average confidence
        let segments = result.bestTranscription.segments
        let confidence = segments.isEmpty ? 0.0 : 
            segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
        
        currentTranscript = transcript
        
        sendEvent("onTranscriptUpdate", [
            "transcript": transcript,
            "isFinal": isFinal,
            "confidence": confidence
        ])
    }
    
    private func handleRecognitionError(_ error: Error) {
        if let recognitionError = error as? RecognizerError {
            switch recognitionError {
            case .nilRecognizer:
                sendEvent("onError", [
                    "error": "language-not-supported",
                    "message": recognitionError.message
                ])
            case .notAuthorizedToRecognize:
                sendEvent("onError", [
                    "error": "not-allowed",
                    "message": recognitionError.message
                ])
            case .notPermittedToRecord:
                sendEvent("onError", [
                    "error": "not-allowed",
                    "message": recognitionError.message
                ])
            case .recognizerIsUnavailable:
                sendEvent("onError", [
                    "error": "service-not-allowed",
                    "message": recognitionError.message
                ])
            }
            return
        }
        
        // Handle system errors
        let nsError = error as NSError
        let errorCode = nsError.code
        
        let errorTypes: [(codes: [Int], code: String, message: String)] = [
            ([102, 201], "service-not-allowed", "Siri or Dictation is disabled."),
            ([203], "audio-capture", "Failure occurred during speech recognition."),
            ([1110], "no-speech", "No speech was detected."),
            ([1700], "not-allowed", "Request is not authorized.")
        ]
        
        for (codes, code, message) in errorTypes {
            if codes.contains(errorCode) {
                sendEvent("onError", ["error": code, "message": message])
                return
            }
        }
        
        // Unknown error
        if errorCode != 301 {
            sendEvent("onError", [
                "error": "audio-capture",
                "message": error.localizedDescription
            ])
        }
    }
}

// Extensions for permission checking
extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}