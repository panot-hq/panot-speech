// Reexport the native module. On web, it will be resolved to PanotSpeechModule.web.ts
// and on native platforms to PanotSpeechModule.ts
export { default } from './PanotSpeechModule';
export { default as PanotSpeechView } from './PanotSpeechView';
export * from  './PanotSpeech.types';
