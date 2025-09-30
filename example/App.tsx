import React, { useState, useEffect, useRef } from "react";
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Alert,
  ScrollView,
  Animated,
} from "react-native";
import PanotSpeechModule from "panot-speech";
import { PermissionStatus } from "expo-modules-core";

// Common languages with their locale codes
const LANGUAGES = [
  { code: "en-US", name: "🇺🇸 English (US)", flag: "🇺🇸" },
  { code: "es-ES", name: "🇪🇸 Español (España)", flag: "🇪🇸" },
  { code: "fr-FR", name: "🇫🇷 Français", flag: "🇫🇷" },
  { code: "it-IT", name: "🇮🇹 Italiano", flag: "🇮🇹" },
  { code: "de-DE", name: "🇩🇪 Deutsch", flag: "🇩🇪" },
  { code: "pt-BR", name: "🇧🇷 Português (Brasil)", flag: "🇧🇷" },
];

export default function App() {
  const [hasPermissions, setHasPermissions] = useState<boolean | null>(null);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [confidence, setConfidence] = useState(0);
  const [error, setError] = useState("");
  const [selectedLanguage, setSelectedLanguage] = useState("en-US");
  const [supportedLocales, setSupportedLocales] = useState<string[]>([]);
  const [volume, setVolume] = useState(0);

  // Animation refs for volume bars
  const volumeAnims = useRef(
    Array.from({ length: 10 }, () => new Animated.Value(0))
  ).current;

  useEffect(() => {
    // Load supported locales
    loadSupportedLocales();
  }, []);

  useEffect(() => {
    // Set up event listeners
    const transcriptSub = PanotSpeechModule.addListener(
      "onTranscriptUpdate",
      (event) => {
        setTranscript(event.transcript);
        setConfidence(event.confidence);
        setError("");
        console.log(
          "Transcript:",
          event.transcript,
          "isFinal:",
          event.isFinal,
          "confidence:",
          event.confidence
        );
      }
    );

    const errorSub = PanotSpeechModule.addListener("onError", (event) => {
      setError(event.message);
      console.error("Error:", event.error, event.message);
    });

    const statusSub = PanotSpeechModule.addListener(
      "onStatusChange",
      (event) => {
        setIsTranscribing(event.isTranscribing);
      }
    );

    const startSub = PanotSpeechModule.addListener("onStart", () => {
      console.log("Started transcribing");
      setError("");
    });

    const endSub = PanotSpeechModule.addListener("onEnd", () => {
      console.log("Ended transcribing");
    });

    const volumeSub = PanotSpeechModule.addListener(
      "onVolumeChange",
      (event) => {
        const normalizedVolume = (event.volume + 2) / 12; // Normalize from -2..10 to 0..1
        setVolume(Math.max(0, Math.min(1, normalizedVolume)));

        // Animate volume bars
        volumeAnims.forEach((anim, index) => {
          const barHeight =
            (normalizedVolume * (index + 1)) / volumeAnims.length;
          Animated.timing(anim, {
            toValue: Math.max(0, Math.min(1, barHeight)),
            duration: 100,
            useNativeDriver: false,
          }).start();
        });
      }
    );

    // Check permissions on mount
    checkPermissions();

    return () => {
      transcriptSub.remove();
      errorSub.remove();
      statusSub.remove();
      startSub.remove();
      endSub.remove();
      volumeSub.remove();
    };
  }, []);

  const loadSupportedLocales = async () => {
    try {
      const result = await PanotSpeechModule.getSupportedLocales();
      setSupportedLocales(result.locales);
      console.log("Supported locales:", result.locales);
    } catch (err) {
      console.error("Error loading locales:", err);
    }
  };

  const checkPermissions = async () => {
    try {
      const result = await PanotSpeechModule.getPermissions();
      const granted = result.status === PermissionStatus.GRANTED;
      setHasPermissions(granted);
    } catch (err) {
      console.error("Error checking permissions:", err);
    }
  };

  const requestPermissions = async () => {
    try {
      const result = await PanotSpeechModule.requestPermissions();
      const granted = result.status === PermissionStatus.GRANTED;
      setHasPermissions(granted);

      if (!granted) {
        Alert.alert(
          "Permissions Required",
          "Please enable microphone and speech recognition permissions in Settings."
        );
      }
    } catch (err) {
      console.error("Permission error:", err);
      Alert.alert("Error", String(err));
    }
  };

  const startTranscribing = () => {
    if (!hasPermissions) {
      Alert.alert("Permissions Required", "Please grant permissions first.", [
        { text: "OK", onPress: requestPermissions },
      ]);
      return;
    }

    // Check if selected language is supported
    const isSupported = PanotSpeechModule.isLocaleSupported(selectedLanguage);
    if (!isSupported) {
      Alert.alert(
        "Language Not Supported",
        `${selectedLanguage} is not supported on this device.`
      );
      return;
    }

    // true = show interim results, selectedLanguage = language to use
    PanotSpeechModule.startTranscribing(true, selectedLanguage);
  };

  const stopTranscribing = () => {
    PanotSpeechModule.stopTranscribing();
  };

  const resetTranscript = () => {
    PanotSpeechModule.resetTranscript();
    setTranscript("");
    setConfidence(0);
    setError("");
  };

  return (
    <View style={styles.container}>
      {/* Permission Status */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Permissions</Text>
        <Text style={styles.statusText}>
          {hasPermissions === null
            ? "⏳ Checking..."
            : hasPermissions
              ? "✅ Granted"
              : "❌ Not Granted"}
        </Text>
        {!hasPermissions && (
          <TouchableOpacity
            style={styles.secondaryButton}
            onPress={requestPermissions}
          >
            <Text style={styles.secondaryButtonText}>Request Permissions</Text>
          </TouchableOpacity>
        )}
      </View>
      {/* Volume Visualizer */}
      {isTranscribing && (
        <View style={styles.volumeContainer}>
          <Text style={styles.volumeTitle}>Audio Level</Text>
          <View style={styles.volumeBars}>
            {volumeAnims.map((anim, index) => (
              <Animated.View
                key={index}
                style={[
                  styles.volumeBar,
                  {
                    height: anim.interpolate({
                      inputRange: [0, 1],
                      outputRange: ["10%", "100%"],
                    }),
                    backgroundColor: anim.interpolate({
                      inputRange: [0, 0.5, 1],
                      outputRange: ["#4CAF50", "#FF9800", "#f44336"],
                    }),
                  },
                ]}
              />
            ))}
          </View>
          <View style={styles.recordingIndicator}>
            <View style={styles.recordingDot} />
            <Text style={styles.recordingText}>
              Recording... ({(volume * 100).toFixed(0)}%)
            </Text>
          </View>
        </View>
      )}

      {/* Language Selection */}
      {!isTranscribing && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Idioma / Language</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            <View style={styles.languageContainer}>
              {LANGUAGES.map((lang) => {
                const isSupported = supportedLocales.includes(lang.code);
                const isSelected = selectedLanguage === lang.code;

                return (
                  <TouchableOpacity
                    key={lang.code}
                    style={[
                      styles.languageButton,
                      isSelected && styles.languageButtonSelected,
                      !isSupported && styles.languageButtonDisabled,
                    ]}
                    onPress={() => setSelectedLanguage(lang.code)}
                    disabled={!isSupported || isTranscribing}
                  >
                    <Text style={styles.languageFlag}>{lang.flag}</Text>
                    <Text
                      style={[
                        styles.languageText,
                        isSelected && styles.languageTextSelected,
                        !isSupported && styles.languageTextDisabled,
                      ]}
                    >
                      {lang.code}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          </ScrollView>
          <Text style={styles.languageHint}>
            Selected: {LANGUAGES.find((l) => l.code === selectedLanguage)?.name}
          </Text>
        </View>
      )}

      {/* Transcript Display */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Transcript</Text>
        <ScrollView style={styles.transcriptBox}>
          <Text style={styles.transcriptText}>
            {transcript || "Start speaking to see transcription..."}
          </Text>
        </ScrollView>
        {transcript.length > 0 && (
          <Text style={styles.confidenceText}>
            Confidence: {(confidence * 100).toFixed(0)}%
          </Text>
        )}
      </View>

      {/* Error Display */}
      {error ? (
        <View style={styles.errorCard}>
          <Text style={styles.errorText}>❌ {error}</Text>
        </View>
      ) : null}

      {/* Controls */}
      <View style={styles.controls}>
        {!isTranscribing ? (
          <TouchableOpacity
            style={[styles.button, styles.startButton]}
            onPress={startTranscribing}
            disabled={!hasPermissions}
          >
            <Text style={styles.buttonText}>🎙️ Start Recording</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={[styles.button, styles.stopButton]}
            onPress={stopTranscribing}
          >
            <Text style={styles.buttonText}>⏹️ Stop Recording</Text>
          </TouchableOpacity>
        )}

        <TouchableOpacity
          style={[styles.button, styles.resetButton]}
          onPress={resetTranscript}
        >
          <Text style={styles.buttonText}>🔄 Reset</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: "#f5f5f5",
    paddingTop: 60,
  },
  title: {
    fontSize: 32,
    fontWeight: "bold",
    marginBottom: 20,
    textAlign: "center",
  },
  card: {
    backgroundColor: "white",
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#333",
    marginBottom: 8,
  },
  statusText: {
    fontSize: 18,
    fontWeight: "500",
    marginBottom: 8,
  },
  transcriptBox: {
    minHeight: 120,
    maxHeight: 200,
    backgroundColor: "#f9f9f9",
    borderRadius: 8,
    padding: 12,
    marginTop: 8,
  },
  transcriptText: {
    fontSize: 16,
    color: "#333",
    lineHeight: 24,
  },
  confidenceText: {
    fontSize: 12,
    color: "#666",
    marginTop: 8,
    textAlign: "right",
  },
  errorCard: {
    backgroundColor: "#ffebee",
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
  },
  errorText: {
    fontSize: 14,
    color: "#c62828",
  },
  controls: {
    gap: 12,
  },
  button: {
    padding: 16,
    borderRadius: 12,
    alignItems: "center",
  },
  startButton: {
    backgroundColor: "#aaa",
  },
  stopButton: {
    backgroundColor: "#f44336",
  },
  resetButton: {
    backgroundColor: "#ddd",
  },
  secondaryButton: {
    backgroundColor: "#2196F3",
    padding: 12,
    borderRadius: 8,
    marginTop: 8,
  },
  secondaryButtonText: {
    color: "white",
    fontSize: 14,
    fontWeight: "600",
    textAlign: "center",
  },
  buttonText: {
    color: "white",
    fontSize: 18,
    fontWeight: "bold",
  },
  recordingIndicator: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    marginTop: 16,
    padding: 12,
    backgroundColor: "#ffebee",
    borderRadius: 8,
  },
  recordingDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "#f44336",
    marginRight: 8,
  },
  recordingText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#f44336",
  },
  languageContainer: {
    flexDirection: "row",
    gap: 8,
    paddingVertical: 8,
  },
  languageButton: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: "#f0f0f0",
    borderWidth: 2,
    borderColor: "transparent",
    alignItems: "center",
    minWidth: 80,
  },
  languageButtonSelected: {
    backgroundColor: "#aaa",
    borderColor: "#000",
  },
  languageButtonDisabled: {
    opacity: 0.4,
  },
  languageFlag: {
    fontSize: 24,
    marginBottom: 4,
  },
  languageText: {
    fontSize: 12,
    fontWeight: "600",
    color: "#666",
  },
  languageTextSelected: {
    color: "#000",
    fontWeight: "bold",
  },
  languageTextDisabled: {
    color: "#999",
  },
  languageHint: {
    fontSize: 12,
    color: "#666",
    marginTop: 8,
    fontStyle: "italic",
  },
  volumeContainer: {
    backgroundColor: "white",
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  volumeTitle: {
    fontSize: 14,
    fontWeight: "600",
    color: "#666",
    marginBottom: 12,
    textAlign: "center",
  },
  volumeBars: {
    flexDirection: "row",
    height: 80,
    alignItems: "flex-end",
    justifyContent: "space-between",
    gap: 4,
    marginBottom: 12,
  },
  volumeBar: {
    flex: 1,
    borderRadius: 4,
    minHeight: 8,
  },
});
