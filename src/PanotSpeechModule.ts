import { NativeModule, requireNativeModule } from 'expo';

import { PanotSpeechModuleEvents } from './PanotSpeech.types';

declare class PanotSpeechModule extends NativeModule<PanotSpeechModuleEvents> {
  PI: number;
  hello(): string;
  setValueAsync(value: string): Promise<void>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<PanotSpeechModule>('PanotSpeech');
