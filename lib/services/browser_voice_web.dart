import 'dart:js_interop';

@JS('emergensyVoice.isSupported')
external JSBoolean get _isSupported;

@JS('emergensyVoice.start')
external void _startRecognition(JSFunction onResult, JSFunction onError);

@JS('emergensyVoice.stop')
external void _stopRecognition();

@JS('emergensyVoice.speak')
external void _speak(JSString text, JSFunction onDone, JSFunction onError);

@JS('emergensyVoice.stopSpeaking')
external void _stopSpeaking();

class BrowserVoice {
  bool get isSupported => _isSupported.toDart;

  void start({
    required void Function(String finalText, String interimText) onResult,
    required void Function(String error) onError,
  }) {
    _startRecognition(
      ((JSString finalText, JSString interimText) {
        onResult(finalText.toDart, interimText.toDart);
      }).toJS,
      ((JSString error) => onError(error.toDart)).toJS,
    );
  }

  void stop() => _stopRecognition();

  void speak({
    required String text,
    required void Function() onDone,
    required void Function(String error) onError,
  }) {
    _speak(
      text.toJS,
      (() => onDone()).toJS,
      ((JSString error) => onError(error.toDart)).toJS,
    );
  }

  void stopSpeaking() => _stopSpeaking();
}
