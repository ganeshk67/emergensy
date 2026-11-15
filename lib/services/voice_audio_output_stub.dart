import 'dart:typed_data';

class VoiceAudioOutput {
  Future<void> initialize() async {}

  Future<void> play(Uint8List bytes) async {}

  Future<void> stop() async {}

  Future<void> dispose() async {}
}
