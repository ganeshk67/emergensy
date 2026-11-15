import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class VoiceAudioOutput {
  static const _sampleRate = 24000;

  web.AudioContext? _context;
  final List<web.AudioBufferSourceNode> _sources = [];
  double _nextStartTime = 0;

  Future<void> initialize() async {
    final context = web.AudioContext();
    _context = context;
    try {
      await context.resume().toDart;
    } catch (_) {
      _context = null;
      await context.close().toDart;
      rethrow;
    }
  }

  Future<void> play(Uint8List bytes) async {
    final context = _context;
    if (context == null) {
      throw StateError('Browser audio output has not been initialized.');
    }

    final sampleCount = bytes.lengthInBytes ~/ 2;
    if (sampleCount == 0) return;

    final samples = ByteData.sublistView(bytes);
    final floatSamples = Float32List(sampleCount);
    for (var index = 0; index < sampleCount; index++) {
      floatSamples[index] = samples.getInt16(index * 2, Endian.little) / 32768;
    }

    final buffer = context.createBuffer(1, sampleCount, _sampleRate);
    buffer.copyToChannel(floatSamples.toJS, 0);

    final source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(context.destination);
    _sources.add(source);
    source.onended = (() {
      _sources.remove(source);
    }).toJS;

    _nextStartTime = _nextStartTime < context.currentTime
        ? context.currentTime
        : _nextStartTime;
    source.start(_nextStartTime);
    _nextStartTime += sampleCount / _sampleRate;
  }

  Future<void> stop() async {
    final sources = List<web.AudioBufferSourceNode>.of(_sources);
    _sources.clear();
    for (final source in sources) {
      source.stop();
    }
    final context = _context;
    if (context != null) _nextStartTime = context.currentTime;
  }

  Future<void> dispose() async {
    await stop();
    final context = _context;
    _context = null;
    if (context != null) await context.close().toDart;
  }
}
