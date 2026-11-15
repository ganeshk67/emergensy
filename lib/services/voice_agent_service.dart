import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

import 'app_backend.dart';

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

enum VoiceAgentPhase { idle, connecting, thinking, listening, speaking, error }

class VoiceAgentService {
  VoiceAgentService({
    required this.uid,
    required this.repository,
    required this.patientName,
    required this.familyProfiles,
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

  final String uid;
  final AppDataRepository repository;
  final String patientName;
  final List<Map<String, Object?>> familyProfiles;

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
  Map<String, Object?>? _pendingAction;
  bool _confirmationAllowed = false;

  static const _doctors = <String, String>{
    'Dr. Asha Mehta': 'General physician',
    'Dr. Rohan Shah': 'Cardiologist',
    'Dr. Nisha Rao': 'Dermatologist',
    'Dr. Kabir Patel': 'Paediatrician',
  };
  static const _slots = ['10:00 AM', '11:30 AM', '02:00 PM', '04:30 PM'];
  static const _tests = [
    'Complete blood count (CBC)',
    'Blood glucose — fasting',
    'Blood glucose — random',
    'HbA1c',
    'Lipid profile',
    'Thyroid (TSH)',
    'Vitamin D',
    'Urine routine',
  ];

  List<Tool> get _browserTools => [
    Tool.functionDeclarations([
      AutoFunctionDeclaration(
        name: 'prepare_doctor_appointment',
        description: 'Prepare an online appointment request after collecting patient, doctor, date, time, and reason. This only prepares a draft. Never claim it is booked until confirm_pending_action succeeds.',
        parameters: {
          'doctor': Schema.string(),
          'date': Schema.string(),
          'time': Schema.string(),
          'patient': Schema.string(),
          'reason': Schema.string(),
          'mode': Schema.string(),
        },
        optionalParameters: [
          'doctor',
          'date',
          'time',
          'patient',
          'reason',
          'mode',
        ],
        callable: _prepareAppointment,
      ),
      AutoFunctionDeclaration(
        name: 'prepare_lab_request',
        description: 'Prepare a lab test request after collecting patient, test names, date, and collection choice. This only prepares a draft, never save it until the user confirms.',
        parameters: {
          'tests': Schema.array(items: Schema.string()),
          'date': Schema.string(),
          'patient': Schema.string(),
          'collection': Schema.string(),
        },
        optionalParameters: ['tests', 'date', 'patient', 'collection'],
        callable: _prepareLabRequest,
      ),
      AutoFunctionDeclaration(
        name: 'prepare_reminder',
        description: 'Prepare a personal reminder with a title and exact future date-time. This only prepares a draft, never save it until the user confirms.',
        parameters: {
          'title': Schema.string(),
          'details': Schema.string(),
          'date_time': Schema.string(),
        },
        optionalParameters: ['title', 'details', 'date_time'],
        callable: _prepareReminder,
      ),
      AutoFunctionDeclaration(
        name: 'confirm_pending_action',
        description: 'Save the pending appointment, lab request, or reminder only after the user clearly confirms it in their latest message.',
        parameters: const {},
        callable: _confirmPendingAction,
      ),
      AutoFunctionDeclaration(
        name: 'cancel_pending_action',
        description: 'Cancel and discard the currently prepared action when the user says no or cancels.',
        parameters: const {},
        callable: _cancelPendingAction,
      ),
      AutoFunctionDeclaration(
        name: 'list_my_reminders',
        description: 'List the signed-in user\'s saved reminders.',
        parameters: const {},
        callable: _listReminders,
      ),
    ]),
  ];

  Future<Map<String, Object?>> _prepareAppointment(
    Map<String, Object?> args,
  ) async {
    final doctorInput = _stringArg(args, 'doctor');
    final doctor = _resolveDoctor(doctorInput);
    final mode = _stringArg(args, 'mode');
    if (mode.isNotEmpty && mode.toLowerCase().contains('person')) {
      return {
        'result': 'In-person requests need the user to choose a clinic on the app map. Offer to open Doctor appointments and select In-person.',
      };
    }
    final date = _parseDate(_stringArg(args, 'date'));
    final timeInput = _stringArg(args, 'time');
    final slot = _slots.cast<String?>().firstWhere(
      (value) => value!.toLowerCase() == timeInput.toLowerCase(),
      orElse: () => null,
    );
    final patient = _stringArg(args, 'patient').isEmpty
        ? patientName.trim()
        : _stringArg(args, 'patient');
    final missing = <String>[];
    if (doctor == null) missing.add('a doctor from the app list');
    if (date == null) missing.add('the appointment date');
    if (slot == null) missing.add('a time slot (${_slots.join(', ')})');
    if (patient.isEmpty) missing.add('the patient name');
    if (missing.isNotEmpty) {
      return {
        'result':
            'Ask the user for ${missing.join(', ')}. Doctors available: ${_doctors.entries.map((e) => '${e.key} (${e.value})').join('; ')}. Dates must be today or later. Do not guess a time.',
      };
    }
    final parsedDate = date!;
    final today = DateTime.now();
    if (parsedDate.isBefore(DateTime(today.year, today.month, today.day))) {
      return {
        'result': 'That date is in the past. Ask for a current or future date.',
      };
    }
    final member = _familyProfileFor(patient);
    _pendingAction = {
      'type': 'appointment',
      'doctor': doctor!,
      'specialty': _doctors[doctor]!,
      'date': parsedDate.toIso8601String(),
      'slot': slot!,
      'patient': patient,
      'reason': _stringArg(args, 'reason'),
      if (member != null) ...{
        'memberId': member['id'],
        'memberName': member['name'],
      },
    };
    return {
      'result':
          'Draft prepared: ${_appointmentSummary(_pendingAction!)} Read this back and ask the user to clearly say yes to save it. It is not booked yet.',
    };
  }

  Future<Map<String, Object?>> _prepareLabRequest(
    Map<String, Object?> args,
  ) async {
    final rawTests = args['tests'];
    final requested = rawTests is List
        ? rawTests.whereType<String>().map((test) => test.trim()).toList()
        : <String>[];
    final selected = _tests
        .where(
          (test) => requested.any(
            (entry) => entry.toLowerCase() == test.toLowerCase(),
          ),
        )
        .toList();
    final date = _parseDate(_stringArg(args, 'date'));
    final patient = _stringArg(args, 'patient').isEmpty
        ? patientName.trim()
        : _stringArg(args, 'patient');
    final collectionInput = _stringArg(args, 'collection');
    final collection = collectionInput.isEmpty
        ? 'Visit a lab'
        : collectionInput.toLowerCase().contains('home')
        ? 'Home collection'
        : collectionInput.toLowerCase().contains('visit') ||
              collectionInput.toLowerCase().contains('lab')
        ? 'Visit a lab'
        : '';
    final missing = <String>[];
    if (selected.isEmpty) {
      missing.add('which test or tests (${_tests.join('; ')})');
    }
    if (date == null) missing.add('the requested date');
    if (patient.isEmpty) missing.add('the patient name');
    if (collection.isEmpty) {
      missing.add('whether to visit a lab or request home collection');
    }
    if (missing.isNotEmpty) {
      return {
        'result':
            'Ask the user for ${missing.join(', ')}. Only use the listed test names. Dates must be today or later.',
      };
    }
    final parsedDate = date!;
    final today = DateTime.now();
    if (parsedDate.isBefore(DateTime(today.year, today.month, today.day))) {
      return {
        'result': 'That date is in the past. Ask for a current or future date.',
      };
    }
    final member = _familyProfileFor(patient);
    _pendingAction = {
      'type': 'lab',
      'tests': selected,
      'date': parsedDate.toIso8601String(),
      'patient': patient,
      'collection': collection,
      if (member != null) ...{
        'memberId': member['id'],
        'memberName': member['name'],
      },
    };
    return {
      'result':
          'Draft prepared: ${_labSummary(_pendingAction!)} Read this back and ask the user to clearly say yes to save it. This is a request, not a confirmed lab booking.',
    };
  }

  Future<Map<String, Object?>> _prepareReminder(
    Map<String, Object?> args,
  ) async {
    final title = _stringArg(args, 'title');
    final dateTime = DateTime.tryParse(_stringArg(args, 'date_time'));
    if (title.isEmpty || dateTime == null) {
      return {
        'result': 'Ask for a reminder title and exact date and time, then prepare it using ISO 8601 date-time.',
      };
    }
    if (!dateTime.isAfter(DateTime.now())) {
      return {
        'result':
            'That reminder time has passed. Ask for a future date and time.',
      };
    }
    _pendingAction = {
      'type': 'reminder',
      'title': title,
      'details': _stringArg(args, 'details'),
      'reminderAt': dateTime.toIso8601String(),
    };
    return {
      'result':
          'Draft prepared: ${_reminderSummary(_pendingAction!)} Read this back and ask the user to clearly say yes to save it.',
    };
  }

  Future<Map<String, Object?>> _confirmPendingAction(
    Map<String, Object?> args,
  ) async {
    if (!_confirmationAllowed) {
      return {
        'result': 'The user has not clearly confirmed in their latest message. Ask for a clear yes; do not save anything.',
      };
    }
    final action = _pendingAction;
    if (action == null) {
      return {'result': 'There is no pending action to confirm.'};
    }
    try {
      switch (action['type']) {
        case 'appointment':
          await repository.saveAppointment(uid, {
            'doctor': action['doctor'],
            'specialty': action['specialty'],
            'mode': 'Online',
            'date': action['date'],
            'slot': action['slot'],
            'patient': action['patient'],
            'reason': action['reason'],
            'area': '',
            if (action['memberId'] != null) ...{
              'memberId': action['memberId'],
              'memberName': action['memberName'],
            },
          });
          break;
        case 'lab':
          await repository.saveLabBooking(uid, {
            'tests': action['tests'],
            'collection': action['collection'],
            'date': action['date'],
            'patient': action['patient'],
            'status': 'requested',
            if (action['memberId'] != null) ...{
              'memberId': action['memberId'],
              'memberName': action['memberName'],
            },
          });
          break;
        case 'reminder':
          await repository.saveReminder(uid, {
            'title': action['title'],
            'details': action['details'],
            'reminderAt': DateTime.parse(action['reminderAt'] as String),
          });
          break;
        default:
          return {
            'result':
                'The pending action type is unsupported; nothing was saved.',
          };
      }
      final type = action['type'];
      final summary = switch (type) {
        'appointment' => _appointmentSummary(action),
        'lab' => _labSummary(action),
        _ => _reminderSummary(action),
      };
      _pendingAction = null;
      return {
        'result': type == 'appointment'
            ? 'Appointment request saved in Emergensy. It is awaiting provider approval; it is not confirmed with a clinic. $summary'
            : type == 'lab'
            ? 'Lab request saved in Emergensy. It is not sent to an outside lab. $summary'
            : 'Reminder saved in the app. Background push alerts are not currently configured for web, so do not promise a notification if the app is closed. $summary',
      };
    } catch (error) {
      return {
        'result':
            'The action could not be saved: $error. Do not tell the user it succeeded.',
      };
    }
  }

  Future<Map<String, Object?>> _cancelPendingAction(
    Map<String, Object?> args,
  ) async {
    _pendingAction = null;
    return {'result': 'Pending action discarded. Nothing was saved.'};
  }

  Future<Map<String, Object?>> _listReminders(Map<String, Object?> args) async {
    try {
      final reminders = await repository
          .watchReminders(uid)
          .first
          .timeout(const Duration(seconds: 8));
      if (reminders.isEmpty) return {'result': 'There are no saved reminders.'};
      final lines = reminders
          .map((reminder) {
            final title = reminder['title'] ?? 'Reminder';
            final storedTime = reminder['reminderAt'];
            final at = storedTime is Timestamp
                ? storedTime.toDate().toLocal()
                : storedTime;
            return '$title at $at';
          })
          .join('; ');
      return {'result': 'Saved reminders: $lines'};
    } catch (error) {
      return {'result': 'Could not load reminders: $error'};
    }
  }

  String _browserSystemInstruction() =>
      '''$_systemInstruction

Today is ${DateTime.now().toIso8601String().substring(0, 10)}. The signed-in user's name is ${patientName.isEmpty ? 'not available' : patientName}. Authorized family profiles: ${familyProfiles.map((p) => p['name']).whereType<String>().join(', ')}.

Emergensy app features: Emergency SOS prepares an alert and does not dispatch responders (India emergency number 112); First Aid care guides; online doctor appointment requests; nearby hospital map and directions; lab test requests and lab results; health news; demo health shop without checkout; Health Timeline; emergency profile and QR; Family Guardian; dark mode and profile settings; this voice assistant. Always use tools for booking, lab requests, and reminders. Doctor choices: ${_doctors.entries.map((e) => '${e.key} (${e.value})').join('; ')}. Appointment time slots: ${_slots.join(', ')}. Lab tests: ${_tests.join('; ')}. Lab collection: Visit a lab or Home collection.

For requests, ask one question at a time for missing details. Use ISO dates and exact app options. Never invent availability. For appointments and lab requests, distinguish a saved request from a real provider confirmation. For reminders, clearly say that on web the reminder is stored but browser push notifications are not configured, so it may not alert when the app is closed. When any action tool prepares a draft, read back every important detail and wait for a separate clear yes before calling confirm_pending_action. Never infer confirmation from the original booking request.''';

  static String _stringArg(Map<String, Object?> args, String key) =>
      args[key] is String ? (args[key] as String).trim() : '';

  static String? _resolveDoctor(String input) {
    final normalized = input.toLowerCase().replaceFirst(
      RegExp(r'^dr\.?\s*'),
      '',
    );
    for (final entry in _doctors.entries) {
      final name = entry.key.toLowerCase().replaceFirst(
        RegExp(r'^dr\.?\s*'),
        '',
      );
      if (name == normalized || entry.value.toLowerCase() == normalized) {
        return entry.key;
      }
    }
    return null;
  }

  Map<String, Object?>? _familyProfileFor(String patient) {
    for (final profile in familyProfiles) {
      if ((profile['name'] as String?)?.toLowerCase() ==
          patient.toLowerCase()) {
        return profile;
      }
    }
    return null;
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _appointmentSummary(Map<String, Object?> action) =>
      '${action['doctor']} (${action['specialty']}) for ${action['patient']} on ${action['date']} at ${action['slot']} online. Reason: ${(action['reason'] as String?)?.isEmpty == true ? 'not provided' : action['reason']}.';

  static String _labSummary(Map<String, Object?> action) =>
      '${(action['tests'] as List).join(', ')} for ${action['patient']} on ${action['date']}, collection: ${action['collection']}.';

  static String _reminderSummary(Map<String, Object?> action) =>
      '${action['title']} at ${action['reminderAt']}${(action['details'] as String?)?.isNotEmpty == true ? ', ${action['details']}' : ''}.';

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
      _pendingAction = null;
      _confirmationAllowed = false;
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
      model: 'gemini-3.5-flash-lite',
      generationConfig: GenerationConfig(maxOutputTokens: 220),
      systemInstruction: Content.system(_browserSystemInstruction()),
      tools: _browserTools,
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
            const Duration(milliseconds: 500),
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

    _confirmationAllowed = RegExp(
      r'^(yes|yeah|yep|confirm|confirmed|go ahead|do it|okay|ok|please do)( please)?[.! ]*$',
      caseSensitive: false,
    ).hasMatch(userText);

    _browserVoice.stop();
    onUserTranscript(userText);
    onPhaseChanged(VoiceAgentPhase.thinking);

    try {
      final chat = _browserChat;
      if (chat == null) return;
      final answer = StringBuffer();
      final pendingSpeech = StringBuffer();
      var pendingUtterances = 0;
      var generationFinished = false;
      var hasQueuedSpeech = false;
      Object? speechError;
      final speechFinished = Completer<void>();

      void finishSpeechIfReady() {
        if (!generationFinished ||
            pendingUtterances != 0 ||
            speechFinished.isCompleted) {
          return;
        }
        if (speechError case final error?) {
          speechFinished.completeError(error);
        } else {
          speechFinished.complete();
        }
      }

      void queueSpeech(String sentence) {
        final text = sentence.trim();
        if (text.isEmpty || !_isBrowserSessionActive || _isStopping) return;
        if (!hasQueuedSpeech) {
          hasQueuedSpeech = true;
          onPhaseChanged(VoiceAgentPhase.speaking);
        }
        pendingUtterances++;
        _browserVoice.speak(
          text: text,
          onDone: () {
            pendingUtterances--;
            finishSpeechIfReady();
          },
          onError: (error) {
            if (_isBrowserSessionActive && !_isStopping) {
              speechError ??= StateError('Speech output failed: $error');
            }
            pendingUtterances--;
            finishSpeechIfReady();
          },
        );
      }

      void queueCompletedSentences() {
        final text = pendingSpeech.toString();
        final sentenceBoundary = RegExp(r'[.!?](?:\s|$)');
        var consumed = 0;
        for (final match in sentenceBoundary.allMatches(text)) {
          queueSpeech(text.substring(consumed, match.end));
          consumed = match.end;
        }
        if (consumed > 0) {
          pendingSpeech
            ..clear()
            ..write(text.substring(consumed));
        }
      }

      await for (final chunk in chat.sendMessageStream(
        Content.text(userText),
      )) {
        if (!_isBrowserSessionActive || _isStopping) return;
        final text = chunk.text;
        if (text == null || text.isEmpty) continue;
        answer.write(text);
        pendingSpeech.write(text);
        onAssistantTranscript(answer.toString().trim());
        queueCompletedSentences();
      }
      if (!_isBrowserSessionActive || _isStopping) return;

      if (answer.toString().trim().isEmpty) {
        throw StateError('The assistant returned an empty response.');
      }

      queueSpeech(pendingSpeech.toString());
      generationFinished = true;
      finishSpeechIfReady();
      await speechFinished.future;

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
