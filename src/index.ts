import PanotSpeechModule, {
  TranscriptUpdateEvent,
  ErrorEvent,
  StatusChangeEvent,
} from "./PanotSpeechModule";

export { TranscriptUpdateEvent, ErrorEvent, StatusChangeEvent };

export default PanotSpeechModule;

// Convenience functions
export const requestPermissions = (): Promise<boolean> => {
  return PanotSpeechModule.requestPermissions();
};

export const startTranscribing = (): Promise<void> => {
  return PanotSpeechModule.startTranscribing();
};

export const stopTranscribing = (): Promise<void> => {
  return PanotSpeechModule.stopTranscribing();
};

export const resetTranscript = (): Promise<void> => {
  return PanotSpeechModule.resetTranscript();
};

export const addTranscriptListener = (
  listener: (event: TranscriptUpdateEvent) => void
) => {
  return PanotSpeechModule.addListener("onTranscriptUpdate", listener);
};

export const addErrorListener = (listener: (event: ErrorEvent) => void) => {
  return PanotSpeechModule.addListener("onError", listener);
};

export const addStatusListener = (
  listener: (event: StatusChangeEvent) => void
) => {
  return PanotSpeechModule.addListener("onStatusChange", listener);
};

export const removeAllListeners = (eventName: string) => {
  return PanotSpeechModule.removeAllListeners(eventName);
};
