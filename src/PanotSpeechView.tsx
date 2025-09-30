import { requireNativeView } from 'expo';
import * as React from 'react';

import { PanotSpeechViewProps } from './PanotSpeech.types';

const NativeView: React.ComponentType<PanotSpeechViewProps> =
  requireNativeView('PanotSpeech');

export default function PanotSpeechView(props: PanotSpeechViewProps) {
  return <NativeView {...props} />;
}
