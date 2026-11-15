class BrowserVoice {
  bool get isSupported => false;

  void start({
    required void Function(String finalText, String interimText) onResult,
    required void Function(String error) onError,
  }) {
    throw UnsupportedError('Browser speech recognition is unavailable.');
  }

  void stop() {}

  void speak({
    required String text,
    required void Function() onDone,
    required void Function(String error) onError,
  }) {
    onError('Browser speech output is unavailable.');
  }

  void stopSpeaking() {}
}
