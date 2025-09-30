# PanotSpeech - Speech to Text for Expo

A native iOS speech-to-text module for Expo applications, built using Apple's Speech framework. This module provides real-time speech recognition capabilities with proper permission handling and event-driven updates.

## Features

- 🎤 Real-time speech recognition
- 📱 iOS native implementation using Apple's Speech framework
- 🔐 Automatic permission handling for microphone and speech recognition
- 📡 Event-driven updates for transcript changes
- ⚡ Promise-based API for easy integration
- 🎯 TypeScript support with full type definitions

## Installation

```sh
npm install panot-speech
```

## Setup

### iOS Permissions

Add the following permissions to your `app.json` or `app.config.js`:

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSMicrophoneUsageDescription": "This app needs access to microphone for speech recognition.",
        "NSSpeechRecognitionUsageDescription": "This app needs speech recognition to convert your speech to text."
      }
    }
  }
}
```

## Usage

### Basic Usage

```typescript
import * as PanotSpeech from "panot-speech";

// Request permissions
const hasPermissions = await PanotSpeech.requestPermissions();

if (hasPermissions) {
  // Start listening
  await PanotSpeech.startTranscribing();

  // Stop listening
  await PanotSpeech.stopTranscribing();

  // Reset transcript
  await PanotSpeech.resetTranscript();
}
```

### Event Listeners

```typescript
import * as PanotSpeech from "panot-speech";

// Listen for transcript updates
const transcriptListener = PanotSpeech.addTranscriptListener((event) => {
  console.log("Transcript:", event.transcript);
});

// Listen for errors
const errorListener = PanotSpeech.addErrorListener((event) => {
  console.error("Speech recognition error:", event.error);
});

// Listen for status changes
const statusListener = PanotSpeech.addStatusListener((event) => {
  console.log("Is transcribing:", event.isTranscribing);
});

// Clean up listeners
PanotSpeech.removeAllListeners("onTranscriptUpdate");
PanotSpeech.removeAllListeners("onError");
PanotSpeech.removeAllListeners("onStatusChange");
```

### React Component Example

```typescript
import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import * as PanotSpeech from 'panot-speech';

export default function SpeechToTextScreen() {
  const [transcript, setTranscript] = useState('');
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [hasPermissions, setHasPermissions] = useState(false);

  useEffect(() => {
    // Check permissions on mount
    checkPermissions();

    // Set up event listeners
    const transcriptListener = PanotSpeech.addTranscriptListener((event) => {
      setTranscript(event.transcript);
    });

    const statusListener = PanotSpeech.addStatusListener((event) => {
      setIsTranscribing(event.isTranscribing);
    });

    const errorListener = PanotSpeech.addErrorListener((event) => {
      console.error('Speech recognition error:', event.error);
    });

    return () => {
      // Clean up listeners
      PanotSpeech.removeAllListeners('onTranscriptUpdate');
      PanotSpeech.removeAllListeners('onStatusChange');
      PanotSpeech.removeAllListeners('onError');
    };
  }, []);

  const checkPermissions = async () => {
    const granted = await PanotSpeech.requestPermissions();
    setHasPermissions(granted);
  };

  const startListening = async () => {
    if (hasPermissions) {
      await PanotSpeech.startTranscribing();
    }
  };

  const stopListening = async () => {
    await PanotSpeech.stopTranscribing();
  };

  return (
    <View style={{ flex: 1, padding: 20 }}>
      <Text>Transcript: {transcript}</Text>
      <Text>Status: {isTranscribing ? 'Listening...' : 'Stopped'}</Text>

      <TouchableOpacity onPress={startListening} disabled={!hasPermissions}>
        <Text>Start Listening</Text>
      </TouchableOpacity>

      <TouchableOpacity onPress={stopListening}>
        <Text>Stop Listening</Text>
      </TouchableOpacity>
    </View>
  );
}
```

## API Reference

### Methods

#### `requestPermissions(): Promise<boolean>`

Requests microphone and speech recognition permissions. Returns `true` if both permissions are granted.

#### `startTranscribing(): Promise<void>`

Starts speech recognition. Requires permissions to be granted first.

#### `stopTranscribing(): Promise<void>`

Stops the current speech recognition session.

#### `resetTranscript(): Promise<void>`

Stops speech recognition and clears the current transcript.

### Properties

#### `isTranscribing: boolean`

Read-only property indicating whether speech recognition is currently active.

### Events

#### `onTranscriptUpdate`

Fired when the speech recognition transcript is updated.

```typescript
interface TranscriptUpdateEvent {
  transcript: string;
}
```

#### `onError`

Fired when a speech recognition error occurs.

```typescript
interface ErrorEvent {
  error: string;
}
```

#### `onStatusChange`

Fired when the transcription status changes.

```typescript
interface StatusChangeEvent {
  isTranscribing: boolean;
}
```

## Requirements

- iOS 10.0+
- Expo SDK 49+
- React Native 0.72+

## Troubleshooting

### Permission Issues

- Ensure you've added the required permissions to your `app.json`
- Check that the user has granted microphone and speech recognition permissions in iOS Settings
- Call `requestPermissions()` before attempting to start transcription

### Speech Recognition Not Working

- Verify that the device has an internet connection (required for speech recognition)
- Check that the device language is supported by Apple's Speech framework
- Ensure the microphone is not being used by another app

## Contributing

Contributions are very welcome! Please refer to guidelines described in the [contributing guide](https://github.com/expo/expo#contributing).

## License

MIT
