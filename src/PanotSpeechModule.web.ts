import { registerWebModule, NativeModule } from 'expo';

import { PanotSpeechModuleEvents } from './PanotSpeech.types';

class PanotSpeechModule extends NativeModule<PanotSpeechModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}

export default registerWebModule(PanotSpeechModule, 'PanotSpeechModule');
