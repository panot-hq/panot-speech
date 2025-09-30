# Native iOS Module for expo apps

A native iOS speech-to-text module for Expo applications, built using Apple's Speech framework. This module provides real-time speech recognition with multi-language support, audio visualization, and comprehensive event handling. And will be used in the PANOT app.

## Features

- **Real-time speech recognition** with interim results
- **Multi-language support** (English, Spanish, French, Italian, German, Portuguese, and more)
- **Audio level monitoring** for visualizations and animations
- **Confidence scores** for transcription accuracy
- **iOS native implementation** using Apple's Speech framework
- **Comprehensive permission handling** with Expo's permission system
- **Event-driven architecture** with real-time updates
- **Thread-safe implementation** using Swift actors
- **TypeScript support** with full type definitions
- **Performance optimized** with DSP-accelerated audio processing

## Installation

```bash
npm install panot-speech
```

or

```bash
yarn add panot-speech
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

### Rebuild Your App

After installing, rebuild your iOS app:

```bash
npx expo run:ios
```

## Quick Start

```typescript
import PanotSpeechModule from "panot-speech";
import { useEffect, useState } from "react";

function App() {
  const [transcript, setTranscript] = useState("");

  useEffect(() => {
    // Listen for transcript updates
    const sub = PanotSpeechModule.addListener("onTranscriptUpdate", (event) => {
      setTranscript(event.transcript);
      console.log("Confidence:", event.confidence);
      console.log("Is Final:", event.isFinal);
    });

    return () => sub.remove();
  }, []);

  const startRecording = async () => {
    // Request permissions
    const result = await PanotSpeechModule.requestPermissions();

    if (result.status === "granted") {
      // Start transcribing with interim results in English
      PanotSpeechModule.startTranscribing(true, "en-US");
    }
  };

  const stopRecording = () => {
    PanotSpeechModule.stopTranscribing();
  };

  return (
    <>
      <Text>{transcript}</Text>
      <Button title="Start" onPress={startRecording} />
      <Button title="Stop" onPress={stopRecording} />
    </>
  );
}
```

## API Reference

### Methods

#### `requestPermissions(): Promise<PermissionResponse>`

Requests both microphone and speech recognition permissions.

```typescript
const result = await PanotSpeechModule.requestPermissions();
if (result.status === "granted") {
  // Permissions granted
}
```

#### `getPermissions(): Promise<PermissionResponse>`

Checks the current permission status without requesting.

```typescript
const result = await PanotSpeechModule.getPermissions();
```

#### `startTranscribing(interimResults?: boolean, lang?: string): void`

Starts speech recognition.

**Parameters:**

- `interimResults` (optional): Show partial results as you speak (default: `true`)
- `lang` (optional): Language code (default: `"en-US"`)

**Examples:**

```typescript
// Basic usage (English with interim results)
PanotSpeechModule.startTranscribing();

// Spanish with interim results
PanotSpeechModule.startTranscribing(true, "es-ES");

// French without interim results (only final)
PanotSpeechModule.startTranscribing(false, "fr-FR");
```

#### `stopTranscribing(): void`

Stops the current speech recognition session.

```typescript
PanotSpeechModule.stopTranscribing();
```

#### `resetTranscript(): void`

Stops recognition and clears the current transcript.

```typescript
PanotSpeechModule.resetTranscript();
```

#### `getState(): Promise<RecognitionState>`

Returns the current recognition state.

```typescript
const state = await PanotSpeechModule.getState();
// Returns: "inactive" | "starting" | "recognizing" | "stopping"
```

#### `getSupportedLocales(): Promise<SupportedLocalesResponse>`

Returns all languages supported by the device.

```typescript
const { locales, installedLocales } =
  await PanotSpeechModule.getSupportedLocales();
console.log(locales); // ["en-US", "es-ES", "fr-FR", ...]
```

#### `isLocaleSupported(locale: string): boolean`

Checks if a specific language is supported.

```typescript
const isSupported = PanotSpeechModule.isLocaleSupported("es-ES");
```

### Events

#### `onTranscriptUpdate`

Fired when the transcript is updated (partial or final results).

```typescript
interface TranscriptUpdateEvent {
  transcript: string; // The recognized text
  isFinal: boolean; // Whether this is a final result
  confidence: number; // Confidence score (0.0 to 1.0)
}

PanotSpeechModule.addListener("onTranscriptUpdate", (event) => {
  console.log(event.transcript);
});
```

#### `onError`

Fired when a speech recognition error occurs.

```typescript
interface ErrorEvent {
  error: string; // Error code
  message: string; // Human-readable error message
}

PanotSpeechModule.addListener("onError", (event) => {
  console.error(event.error, event.message);
});
```

**Error Codes:**

- `"not-allowed"` - Permissions not granted
- `"language-not-supported"` - Language not supported
- `"audio-capture"` - Audio capture failed
- `"no-speech"` - No speech detected
- `"service-not-allowed"` - Siri/Dictation disabled

#### `onStatusChange`

Fired when the transcription status changes.

```typescript
interface StatusChangeEvent {
  isTranscribing: boolean;
}

PanotSpeechModule.addListener("onStatusChange", (event) => {
  console.log("Recording:", event.isTranscribing);
});
```

#### `onStart`

Fired when speech recognition starts.

```typescript
PanotSpeechModule.addListener("onStart", () => {
  console.log("Started!");
});
```

#### `onEnd`

Fired when speech recognition ends.

```typescript
PanotSpeechModule.addListener("onEnd", () => {
  console.log("Ended!");
});
```

#### `onVolumeChange`

Fired periodically with audio input level (for visualizations).

```typescript
interface VolumeChangeEvent {
  volume: number; // Range: -2 to 10 (normalized audio level)
}

PanotSpeechModule.addListener("onVolumeChange", (event) => {
  const normalized = (event.volume + 2) / 12; // Convert to 0-1
  // Use for animations, visualizations, etc.
});
```

**Check available languages:**

```typescript
const { locales } = await PanotSpeechModule.getSupportedLocales();
```

## Audio Visualization Example

Create stunning audio visualizations using the volume events:

```typescript
import { Animated } from "react-native";
import { useRef, useEffect } from "react";

function AudioVisualizer() {
  const scaleAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const sub = PanotSpeechModule.addListener("onVolumeChange", (event) => {
      const normalized = (event.volume + 2) / 12; // 0 to 1

      Animated.spring(scaleAnim, {
        toValue: 1 + normalized * 0.5,
        useNativeDriver: true,
      }).start();
    });

    return () => sub.remove();
  }, []);

  return (
    <Animated.View
      style={{
        width: 100,
        height: 100,
        borderRadius: 50,
        backgroundColor: "red",
        transform: [{ scale: scaleAnim }],
      }}
    />
  );
}
```

### Volume Bar Example

```typescript
function VolumeBar() {
  const [volume, setVolume] = useState(0);

  useEffect(() => {
    const sub = PanotSpeechModule.addListener("onVolumeChange", (event) => {
      setVolume((event.volume + 2) / 12);
    });
    return () => sub.remove();
  }, []);

  return (
    <View style={{ height: 100, width: "100%" }}>
      <View
        style={{
          height: `${volume * 100}%`,
          backgroundColor: volume > 0.7 ? "red" : "green",
        }}
      />
    </View>
  );
}
```

## Complete React Component Example

```typescript
import React, { useState, useEffect } from "react";
import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import PanotSpeechModule from "panot-speech";
import { PermissionStatus } from "expo-modules-core";

export default function SpeechToText() {
  const [hasPermissions, setHasPermissions] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [confidence, setConfidence] = useState(0);
  const [selectedLanguage, setSelectedLanguage] = useState("en-US");

  useEffect(() => {
    // Check permissions
    checkPermissions();

    // Set up event listeners
    const transcriptSub = PanotSpeechModule.addListener(
      "onTranscriptUpdate",
      (event) => {
        setTranscript(event.transcript);
        setConfidence(event.confidence);
      }
    );

    const statusSub = PanotSpeechModule.addListener(
      "onStatusChange",
      (event) => {
        setIsTranscribing(event.isTranscribing);
      }
    );

    const errorSub = PanotSpeechModule.addListener("onError", (event) => {
      console.error(event.error, event.message);
      alert(`Error: ${event.message}`);
    });

    return () => {
      transcriptSub.remove();
      statusSub.remove();
      errorSub.remove();
    };
  }, []);

  const checkPermissions = async () => {
    const result = await PanotSpeechModule.getPermissions();
    setHasPermissions(result.status === PermissionStatus.GRANTED);
  };

  const requestPermissions = async () => {
    const result = await PanotSpeechModule.requestPermissions();
    setHasPermissions(result.status === PermissionStatus.GRANTED);
  };

  const startRecording = () => {
    if (!hasPermissions) {
      requestPermissions();
      return;
    }
    PanotSpeechModule.startTranscribing(true, selectedLanguage);
  };

  const stopRecording = () => {
    PanotSpeechModule.stopTranscribing();
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Speech to Text</Text>

      {/* Permissions */}
      <Text>
        Permissions: {hasPermissions ? "✅ Granted" : "❌ Not Granted"}
      </Text>

      {/* Transcript */}
      <View style={styles.transcriptBox}>
        <Text>{transcript || "Start speaking..."}</Text>
        {transcript && (
          <Text style={styles.confidence}>
            Confidence: {(confidence * 100).toFixed(0)}%
          </Text>
        )}
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        {!isTranscribing ? (
          <TouchableOpacity style={styles.button} onPress={startRecording}>
            <Text style={styles.buttonText}>🎙️ Start</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={styles.stopButton} onPress={stopRecording}>
            <Text style={styles.buttonText}>⏹️ Stop</Text>
          </TouchableOpacity>
        )}
      </View>

      {isTranscribing && <Text style={styles.status}>Recording...</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20 },
  title: { fontSize: 24, fontWeight: "bold", marginBottom: 20 },
  transcriptBox: {
    backgroundColor: "#f5f5f5",
    padding: 16,
    borderRadius: 8,
    marginVertical: 20,
    minHeight: 100,
  },
  confidence: { marginTop: 8, fontSize: 12, color: "#666" },
  controls: { flexDirection: "row", gap: 12 },
  button: {
    backgroundColor: "#4CAF50",
    padding: 16,
    borderRadius: 8,
    flex: 1,
  },
  stopButton: {
    backgroundColor: "#f44336",
    padding: 16,
    borderRadius: 8,
    flex: 1,
  },
  buttonText: {
    color: "white",
    fontSize: 18,
    fontWeight: "bold",
    textAlign: "center",
  },
  status: {
    marginTop: 16,
    textAlign: "center",
    color: "#f44336",
    fontWeight: "600",
  },
});
```

## Advanced Usage

### Switching Languages Dynamically

```typescript
const [language, setLanguage] = useState("en-US");

const switchToSpanish = () => {
  setLanguage("es-ES");
  PanotSpeechModule.stopTranscribing();
  PanotSpeechModule.startTranscribing(true, "es-ES");
};
```

### Getting Only Final Results

```typescript
// Don't show interim results, only final transcriptions
PanotSpeechModule.startTranscribing(false, "en-US");
```

### Checking Recognition State

```typescript
const state = await PanotSpeechModule.getState();

if (state === "recognizing") {
  console.log("Currently recording");
} else if (state === "inactive") {
  console.log("Not recording");
}
```

## Performance

- **Audio Processing**: DSP-accelerated using Apple's Accelerate framework
- **Memory**: Optimized with Swift actors for thread-safety
- **CPU Usage**: Minimal (~2-5% on modern devices)
- **Battery**: Efficient audio pipeline with proper lifecycle management
- **Latency**: <100ms for interim results
- **Accuracy**: Leverages Apple's ML models (depends on language and audio quality)

## Requirements

- **iOS**: 13.4+
- **Expo SDK**: 49+
- **React Native**: 0.72+
- **Swift**: 5.4+

## Troubleshooting

### Permissions Not Working

- Ensure you've added both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` to your `Info.plist`
- Rebuild the app after adding permissions
- Check iOS Settings → Privacy → Microphone/Speech Recognition

### Language Not Supported

- Use `getSupportedLocales()` to check available languages on the device
- Some languages may not be available on all iOS versions
- Download language packs in iOS Settings → General → Keyboard → Keyboards

### Speech Recognition Not Working

- Verify internet connection (required for cloud-based recognition)
- Check that Siri and Dictation are enabled in iOS Settings
- Ensure the microphone is not being used by another app
- Try speaking more clearly or increasing volume

### App Crashes on Permission Request

- Make sure you've added the required usage descriptions to `Info.plist`
- iOS will crash immediately if these are missing

### Audio Visualization Not Updating

- Ensure you're listening to the `onVolumeChange` event
- Check that speech recognition is actively running
- Volume updates occur ~10 times per second

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT

## 🙏 Credits

Built using:

- Apple's Speech Framework
- Expo Modules API
- Swift Actors for concurrency
- Accelerate framework for DSP

---

**Note**: This module currently supports iOS only. Android support may be added in future versions.
