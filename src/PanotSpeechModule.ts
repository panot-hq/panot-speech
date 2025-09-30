import { NativeModule, requireNativeModule } from "expo";
import { EventSubscription } from "react-native";
import { PermissionResponse } from "expo-modules-core";

export interface TranscriptUpdateEvent {
  transcript: string;
  isFinal: boolean;
  confidence: number;
}

export interface ErrorEvent {
  error: string;
  message: string;
}

export interface StatusChangeEvent {
  isTranscribing: boolean;
}

export interface VolumeChangeEvent {
  volume: number;
}

export type RecognitionState =
  | "inactive"
  | "starting"
  | "recognizing"
  | "stopping";

export interface SupportedLocalesResponse {
  locales: string[];
  installedLocales: string[];
}

declare class PanotSpeechModule extends NativeModule {
  isTranscribing: boolean;

  // Permission methods
  requestPermissions(): Promise<PermissionResponse>;
  getPermissions(): Promise<PermissionResponse>;
  requestMicrophonePermissions(): Promise<PermissionResponse>;
  getMicrophonePermissions(): Promise<PermissionResponse>;
  requestSpeechRecognizerPermissions(): Promise<PermissionResponse>;
  getSpeechRecognizerPermissions(): Promise<PermissionResponse>;

  // Speech recognition methods
  getState(): Promise<RecognitionState>;
  startTranscribing(interimResults?: boolean, lang?: string): void;
  stopTranscribing(): void;
  resetTranscript(): void;

  // Locale methods
  getSupportedLocales(): Promise<SupportedLocalesResponse>;
  isLocaleSupported(locale: string): boolean;

  // Event listeners
  addListener(
    eventName: "onTranscriptUpdate",
    listener: (event: TranscriptUpdateEvent) => void
  ): EventSubscription;
  addListener(
    eventName: "onError",
    listener: (event: ErrorEvent) => void
  ): EventSubscription;
  addListener(
    eventName: "onStatusChange",
    listener: (event: StatusChangeEvent) => void
  ): EventSubscription;
  addListener(eventName: "onStart", listener: () => void): EventSubscription;
  addListener(eventName: "onEnd", listener: () => void): EventSubscription;
  addListener(
    eventName: "onVolumeChange",
    listener: (event: VolumeChangeEvent) => void
  ): EventSubscription;
  removeAllListeners(eventName: string): void;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<PanotSpeechModule>("PanotSpeech");
