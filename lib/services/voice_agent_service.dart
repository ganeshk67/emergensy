import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm;
import 'package:record/record.dart';

enum VoiceAgentPhase { idle, connecting, listening, speaking, error }

class VoiceAgentService {
  VoiceAgentService({
    required this.onPhaseChanged,
    required this.onUserTranscript,
    required this.onAssistantTranscript,
    required this.onError,
  });

  static const _modelName = 'gemini-3.1-flash-live-preview';
  static const _systemInstruction =
      'You are Emergensy, a calm and concise voice assistant. Give general '
      'health information only; do not diagnose, prescribe, or claim certainty. '
      'Respond in the language the user speaks when possible. '
      'For a potentially life-threatening emergency, tell the user to call '
      'local emergency services now. In India, call 112. Emergensy does not '
      'dispatch responders. Do not claim access to the user\'s location, '
      'medical records, or emergency contacts.';

  final void Function(VoiceAgentPhase phase) onPhaseChanged;
  final void Function(String transcript) onUserTranscript;
  final void Function(String transcript) onAssistantTranscript;
  final void Function(Object error) onError;

  AudioRecorder? _recorder;
  LiveSession? _session;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<LiveServerResponse>? _responseSubscription;
  Future<void> _sendQueue = Future<void>.value();
  Future<void> _responseQueue = Future<void>.value();
  bool _isRecording = false;
  bool _pcmInitialized = false;
  bool _isStopping = false;
  int _queuedAudioChunks = 0;
  int _generation = 0;

  bool get supportsPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start() async {
    if (_session != null || _isStopping) return;
    if (!supportsPlatform) {
      throw UnsupportedError(
        'Live voice is currently available in the Android and iOS apps.',
      );
    }

    final generation = ++_generation;
    onPhaseChanged(VoiceAgentPhase.connecting);
    final recorder = AudioRecorder();
    _recorder = recorder;

    try {
      if (!await recorder.hasPermission()) {
        throw StateError('Microphone permission is required to start a chat.');
      }
      if (!_isCurrent(generation)) return;

      await _initializeAudioOutput();
      if (!_isCurrent(generation)) {
        await pcm.FlutterPcmSound.release();
        _pcmInitialized = false;
        return;
      }

      final model = FirebaseAI.googleAI().liveGenerativeModel(
        model: _modelName,
        systemInstruction: Content.system(_systemInstruction),
        liveGenerationConfig: LiveGenerationConfig(
          responseModalities: [ResponseModalities.audio],
          inputAudioTranscription: AudioTranscriptionConfig(),
          outputAudioTranscription: AudioTranscriptionConfig(),
          realtimeInputConfig: RealtimeInputConfig(
            activityHandling: ActivityHandling.interrupt,
            turnCoverage: TurnCoverage.onlyActivity,
          ),
        ),
      );
      if (!_isCurrent(generation)) return;
      final session = await model.connect();
      if (!_isCurrent(generation)) {
        await session.close();
        return;
      }
      _session = session;
      _responseSubscription = session.receive().listen(
        (response) => _queueResponse(response, session),
        onError: (Object error) => unawaited(_handleFailure(error)),
      );
      if (!_isCurrent(generation)) return;

      final audioStream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (!_isCurrent(generation)) {
        await recorder.stop();
        return;
      }
      _isRecording = true;
      _audioSubscription = audioStream.listen(
        _queueAudio,
        onError: (Object error) => unawaited(_handleFailure(error)),
      );
      onPhaseChanged(VoiceAgentPhase.listening);
    } catch (error) {
      try {
        await stop();
      } catch (cleanupError) {
        onError(
          StateError(
            'Could not start the voice chat ($error), and cleanup also failed '
            '($cleanupError).',
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_isStopping) return;
    _isStopping = true;
    _generation++;
    final cleanupErrors = <Object>[];

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        cleanupErrors.add(error);
      }
    }

    try {
      await attempt(() async => _audioSubscription?.cancel());
      _audioSubscription = null;
      await attempt(() async {
        if (_isRecording && _recorder != null) {
          await _recorder!.stop();
        }
      });
      _isRecording = false;
      await attempt(() async => _responseSubscription?.cancel());
      _responseSubscription = null;
      final session = _session;
      _session = null;
      await attempt(() async => session?.close());
      final recorder = _recorder;
      _recorder = null;
      await attempt(() async => recorder?.dispose());
      if (_pcmInitialized) {
        await attempt(pcm.FlutterPcmSound.release);
        _pcmInitialized = false;
      }
      _sendQueue = Future<void>.value();
      _responseQueue = Future<void>.value();
      _queuedAudioChunks = 0;
    } finally {
      _isStopping = false;
      onPhaseChanged(VoiceAgentPhase.idle);
    }

    if (cleanupErrors.isNotEmpty) {
      throw StateError(
        'Could not fully stop the voice chat: ${cleanupErrors.join('; ')}',
      );
    }
  }

  Future<void> dispose() => stop();

  Future<void> _initializeAudioOutput() async {
    await pcm.FlutterPcmSound.setup(
      sampleRate: 24000,
      channelCount: 1,
      iosAudioCategory: pcm.IosAudioCategory.playAndRecord,
    );
    _pcmInitialized = true;
  }

  void _queueAudio(Uint8List bytes) {
    final session = _session;
    if (session == null || _isStopping) return;
    if (_queuedAudioChunks >= 80) {
      unawaited(
        _handleFailure(
          StateError('The network cannot keep up with the live audio stream.'),
        ),
      );
      return;
    }

    _queuedAudioChunks++;
    _sendQueue = _sendQueue
        .then((_) async {
          if (identical(_session, session) && !_isStopping) {
            await session.sendAudioRealtime(
              InlineDataPart('audio/pcm;rate=16000', bytes),
            );
          }
        })
        .catchError((Object error) {
          unawaited(_handleFailure(error));
        })
        .whenComplete(() {
          if (identical(_session, session)) _queuedAudioChunks--;
        });
  }

  void _queueResponse(LiveServerResponse response, LiveSession session) {
    _responseQueue = _responseQueue
        .then((_) => _handleResponse(response, session))
        .catchError((Object error) {
          unawaited(_handleFailure(error));
        });
  }

  Future<void> _handleResponse(
    LiveServerResponse response,
    LiveSession session,
  ) async {
    if (_isStopping || !identical(_session, session)) return;
    final message = response.message;
    if (message is! LiveServerContent) return;

    final input = message.inputTranscription?.text;
    if (input != null && input.trim().isNotEmpty) {
      onUserTranscript(input);
    }
    final output = message.outputTranscription?.text;
    if (output != null && output.trim().isNotEmpty) {
      onAssistantTranscript(output);
      onPhaseChanged(VoiceAgentPhase.speaking);
    }

    if (message.interrupted == true && _pcmInitialized) {
      await pcm.FlutterPcmSound.release();
      _pcmInitialized = false;
      if (_isStopping || !identical(_session, session)) return;
      await _initializeAudioOutput();
    }

    for (final part in message.modelTurn?.parts ?? const <Part>[]) {
      if (_isStopping || !identical(_session, session)) return;
      if (part is InlineDataPart && part.mimeType.startsWith('audio/pcm')) {
        onPhaseChanged(VoiceAgentPhase.speaking);
        await _playAudio(part.bytes, session);
      } else if (part is TextPart && part.text.trim().isNotEmpty) {
        onAssistantTranscript(part.text);
      }
    }

    if (message.turnComplete == true) {
      onPhaseChanged(VoiceAgentPhase.listening);
    }
  }

  Future<void> _playAudio(Uint8List bytes, LiveSession session) async {
    final alignedLength = bytes.lengthInBytes - bytes.lengthInBytes % 2;
    if (alignedLength == 0 || !identical(_session, session)) return;
    final audio = ByteData.sublistView(bytes, 0, alignedLength);
    final samples = List<int>.generate(
      alignedLength ~/ 2,
      (index) => audio.getInt16(index * 2, Endian.little),
      growable: false,
    );
    await pcm.FlutterPcmSound.feed(pcm.PcmArrayInt16.fromList(samples));
  }

  bool _isCurrent(int generation) => generation == _generation && !_isStopping;

  Future<void> _handleFailure(Object error) async {
    if (_isStopping) return;
    onError(error);
    try {
      await stop();
    } catch (cleanupError) {
      onError(cleanupError);
    }
    onPhaseChanged(VoiceAgentPhase.error);
  }
}
