import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm;
import 'package:record/record.dart';

import 'browser_voice_stub.dart'
    if (dart.library.js_interop) 'browser_voice_web.dart'
    as browser_voice;
import 'voice_audio_output_stub.dart'
    if (dart.library.js_interop) 'voice_audio_output_web.dart'
    as browser_audio;

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
      'Use plain language, keep spoken answers brief, and ask one question at a time. '
      'Respond in the language the user speaks when possible. '
      'For a potentially life-threatening emergency, tell the user to call '
      'local emergency services now. In India, call 112. Emergensy does not '
      'dispatch responders. Do not claim access to the user\'s location, '
      'medical records, or emergency contacts.';

  final void Function(VoiceAgentPhase phase) onPhaseChanged;
  final void Function(String transcript) onUserTranscript;
  final void Function(String transcript) onAssistantTranscript;
  final void Function(Object error) onError;

  final browser_voice.BrowserVoice _browserVoice = browser_voice.BrowserVoice();
  AudioRecorder? _recorder;
  final browser_audio.VoiceAudioOutput _browserAudioOutput =
      browser_audio.VoiceAudioOutput();
  LiveSession? _session;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<LiveServerResponse>? _responseSubscription;
  Future<void> _sendQueue = Future<void>.value();
  Future<void> _responseQueue = Future<void>.value();
  bool _isRecording = false;
  bool _audioOutputInitialized = false;
  bool _isStopping = false;
  bool _isBrowserSessionActive = false;
  int _queuedAudioChunks = 0;
  int _generation = 0;
  ChatSession? _browserChat;
  Timer? _browserTurnTimer;
  String _browserFinalTranscript = '';
  String _browserInterimTranscript = '';

  bool get supportsPlatform =>
      (kIsWeb && _browserVoice.isSupported) ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  Future<void> start() async {
    if (_session != null || _isBrowserSessionActive || _isStopping) return;
    if (!supportsPlatform) {
      throw UnsupportedError(
        'Live voice is currently available in the Android and iOS apps.',
      );
    }

    final generation = ++_generation;
    onPhaseChanged(VoiceAgentPhase.connecting);

    if (kIsWeb) {
      try {
        await _startBrowserConversation(generation);
      } catch (error) {
        try {
          await stop();
        } catch (cleanupError) {
          onError(
            StateError(
              'Could not start voice chat ($error); cleanup also failed '
              '($cleanupError).',
            ),
          );
        }
        rethrow;
      }
      return;
    }

    final recorder = AudioRecorder();
    _recorder = recorder;

    try {
      if (!await recorder.hasPermission()) {
        throw StateError('Microphone permission is required to start a chat.');
      }
      if (!_isCurrent(generation)) return;

      await _initializeAudioOutput();
      if (!_isCurrent(generation)) {
        await _releaseAudioOutput();
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

    if (kIsWeb) {
      _browserTurnTimer?.cancel();
      _browserTurnTimer = null;
      _isBrowserSessionActive = false;
      _browserVoice
        ..stop()
        ..stopSpeaking();
      _browserChat = null;
      _browserFinalTranscript = '';
      _browserInterimTranscript = '';
      _isStopping = false;
      onPhaseChanged(VoiceAgentPhase.idle);
      return;
    }

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
      if (_audioOutputInitialized) {
        await attempt(_releaseAudioOutput);
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

  Future<void> _startBrowserConversation(int generation) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
      systemInstruction: Content.system(_systemInstruction),
    );
    if (!_isCurrent(generation)) return;

    _browserChat = model.startChat();
    _isBrowserSessionActive = true;
    _startBrowserRecognition();
    onPhaseChanged(VoiceAgentPhase.listening);
  }

  void _startBrowserRecognition() {
    if (!_isBrowserSessionActive || _isStopping) return;
    _browserVoice.start(
      onResult: (finalText, interimText) {
        if (!_isBrowserSessionActive || _isStopping) return;
        if (finalText.isNotEmpty) _browserFinalTranscript += finalText;
        _browserInterimTranscript = interimText;

        final visibleTranscript =
            '$_browserFinalTranscript$_browserInterimTranscript'.trim();
        if (visibleTranscript.isNotEmpty) onUserTranscript(visibleTranscript);

        if (finalText.isNotEmpty) {
          _browserTurnTimer?.cancel();
          _browserTurnTimer = Timer(
            const Duration(milliseconds: 800),
            () => unawaited(_sendBrowserTurn()),
          );
        }
      },
      onError: (error) {
        if (!_isBrowserSessionActive || _isStopping) return;
        if (error == 'not-allowed' || error == 'service-not-allowed') {
          unawaited(
            _handleFailure(
              StateError('Microphone permission was denied by the browser.'),
            ),
          );
        } else {
          unawaited(
            _handleFailure(StateError('Speech recognition failed: $error')),
          );
        }
      },
    );
  }

  Future<void> _sendBrowserTurn() async {
    if (!_isBrowserSessionActive || _isStopping) return;
    final userText = _browserFinalTranscript.trim();
    _browserFinalTranscript = '';
    _browserInterimTranscript = '';
    if (userText.isEmpty) return;

    _browserVoice.stop();
    onUserTranscript(userText);
    onPhaseChanged(VoiceAgentPhase.connecting);

    try {
      final chat = _browserChat;
      if (chat == null) return;
      final response = await chat.sendMessage(Content.text(userText));
      if (!_isBrowserSessionActive || _isStopping) return;

      final answer = response.text?.trim();
      if (answer == null || answer.isEmpty) {
        throw StateError('The assistant returned an empty response.');
      }

      onAssistantTranscript(answer);
      onPhaseChanged(VoiceAgentPhase.speaking);
      final spoken = Completer<void>();
      _browserVoice.speak(
        text: answer,
        onDone: () {
          if (!spoken.isCompleted) spoken.complete();
        },
        onError: (error) {
          if (!_isBrowserSessionActive || _isStopping) {
            if (!spoken.isCompleted) spoken.complete();
          } else if (!spoken.isCompleted) {
            spoken.completeError(StateError('Speech output failed: $error'));
          }
        },
      );
      await spoken.future;

      if (_isBrowserSessionActive && !_isStopping) {
        _startBrowserRecognition();
        onPhaseChanged(VoiceAgentPhase.listening);
      }
    } catch (error) {
      if (_isBrowserSessionActive && !_isStopping) {
        await _handleFailure(error);
      }
    }
  }

  Future<void> _initializeAudioOutput() async {
    if (kIsWeb) {
      await _browserAudioOutput.initialize();
    } else {
      await pcm.FlutterPcmSound.setup(
        sampleRate: 24000,
        channelCount: 1,
        iosAudioCategory: pcm.IosAudioCategory.playAndRecord,
      );
    }
    _audioOutputInitialized = true;
  }

  Future<void> _releaseAudioOutput() async {
    if (kIsWeb) {
      await _browserAudioOutput.dispose();
    } else {
      await pcm.FlutterPcmSound.release();
    }
    _audioOutputInitialized = false;
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

    if (message.interrupted == true && _audioOutputInitialized) {
      if (kIsWeb) {
        await _browserAudioOutput.stop();
      } else {
        await pcm.FlutterPcmSound.release();
        _audioOutputInitialized = false;
        if (_isStopping || !identical(_session, session)) return;
        await _initializeAudioOutput();
      }
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
    if (kIsWeb) {
      await _browserAudioOutput.play(bytes);
      return;
    }
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
