import * as React from 'react';

import { PanotSpeechViewProps } from './PanotSpeech.types';

export default function PanotSpeechView(props: PanotSpeechViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
