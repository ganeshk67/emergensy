import 'dart:async';

import 'package:emergensy/services/voice_agent_service.dart';
import 'package:emergensy/widgets/section_backdrop.dart';
import 'package:emergensy/services/app_backend.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({
    required this.user,
    required this.repository,
    this.familyProfiles = const [],
    this.patientName = '',
    this.focus = VoiceAssistantFocus.general,
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;
  final List<Map<String, Object?>> familyProfiles;
  final String patientName;
  final VoiceAssistantFocus focus;

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage>
    with WidgetsBindingObserver {
  late final VoiceAgentService _agent;
  VoiceAgentPhase _phase = VoiceAgentPhase.idle;
  String _userTranscript = '';
  String _assistantTranscript = '';
  String? _error;

  bool get _isActive =>
      _phase == VoiceAgentPhase.connecting ||
      _phase == VoiceAgentPhase.thinking ||
      _phase == VoiceAgentPhase.listening ||
      _phase == VoiceAgentPhase.speaking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agent = VoiceAgentService(
      uid: widget.user.uid,
      repository: widget.repository,
      patientName: widget.patientName,
      familyProfiles: widget.familyProfiles,
      focus: widget.focus,
      onPhaseChanged: (phase) {
        if (mounted) setState(() => _phase = phase);
      },
      onUserTranscript: (transcript) {
        if (mounted) setState(() => _userTranscript = transcript);
      },
      onAssistantTranscript: (transcript) {
        if (mounted) setState(() => _assistantTranscript = transcript);
      },
      onError: (error) {
        if (mounted) setState(() => _error = _friendlyError(error));
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _agent.dispose().catchError((Object error) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'voice assistant',
            context: ErrorDescription('while stopping the voice session'),
          ),
        );
      }),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        _isActive) {
      unawaited(_endConversation());
    }
  }

  Future<void> _toggleConversation() async {
    if (_isActive) {
      await _endConversation();
      return;
    }
    if (!_agent.supportsPlatform) return;
    final consented = await _confirmAudioProcessing();
    if (!consented || !mounted) return;

    setState(() {
      _userTranscript = '';
      _assistantTranscript = '';
      _error = null;
      _phase = VoiceAgentPhase.connecting;
    });
    try {
      await _agent.start();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = VoiceAgentPhase.error;
        _error = _friendlyError(error);
      });
    }
  }

  Future<bool> _confirmAudioProcessing() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mic_none_rounded),
          title: const Text('Voice and AI processing'),
          content: Text(
            kIsWeb
                ? 'Your browser uses speech recognition to turn your speech '
                      'into text. That transcript is sent to Google Gemini '
                      'through Firebase AI Logic, and your browser speaks the '
                      'reply. Browser speech recognition may process audio '
                      'according to your browser provider\'s settings. '
                      'Emergensy does not save this conversation.'
                : 'Your microphone audio is streamed to Google Gemini through '
                      'Firebase AI Logic to generate a reply. Emergensy does '
                      'not save this conversation. Avoid sharing details you '
                      'do not want processed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _endConversation() async {
    try {
      await _agent.stop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = VoiceAgentPhase.error;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is UnsupportedError) return error.message ?? error.toString();
    final message = error.toString();
    if (error is FirebaseAIException) {
      if (message.contains('DEADLINE_EXCEEDED') || message.contains('503')) {
        return 'The AI service took too long to reply. Please try again.';
      }
      return error.message;
    }
    if (message.toLowerCase().contains('permission')) {
      return 'Allow microphone access in your device settings, then try again.';
    }
    final diagnostic = message.replaceAll(
      RegExp(r'([?&]key=)[^\s&#]+', caseSensitive: false),
      r'$1[redacted]',
    );
    return 'The voice chat could not continue. Check your connection and try '
        'again. Details: $diagnostic';
  }

  String get _statusLabel => switch (_phase) {
    VoiceAgentPhase.idle => 'Ready when you are',
    VoiceAgentPhase.connecting => 'Connecting securely...',
    VoiceAgentPhase.thinking => 'Thinking...',
    VoiceAgentPhase.listening => 'Listening',
    VoiceAgentPhase.speaking => 'Emergensy is speaking',
    VoiceAgentPhase.error => 'Could not connect',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final supported = _agent.supportsPlatform;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.focus) {
          VoiceAssistantFocus.general => 'Voice assistant',
          VoiceAssistantFocus.mentalWellness => 'Mental wellness companion',
          VoiceAssistantFocus.physicalWellness => 'Fitness and wellness assistant',
        }),
        actions: [
          if (_isActive)
            IconButton(
              tooltip: 'End voice chat',
              onPressed: _endConversation,
              icon: const Icon(Icons.call_end_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SectionBackdrop(
          icon: widget.focus == VoiceAssistantFocus.mentalWellness
              ? Icons.psychology_alt_rounded
              : widget.focus == VoiceAssistantFocus.physicalWellness
              ? Icons.fitness_center_rounded
              : Icons.graphic_eq_rounded,
          accent: widget.focus == VoiceAssistantFocus.mentalWellness
              ? colors.tertiary
              : colors.primary,
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _VoiceHeader(
                  phase: _phase,
                  statusLabel: _statusLabel,
                  onStop: _isActive ? _endConversation : null,
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: .13),
                        colors.tertiary.withValues(alpha: .10),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .16),
                    ),
                  ),
                  child: Column(
                    children: [
                      _VoiceOrb(
                        active: _isActive,
                        speaking: _phase == VoiceAgentPhase.speaking,
                        enabled: supported,
                        onTap: _toggleConversation,
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _phase == VoiceAgentPhase.idle
                              ? 'Tap to start talking'
                              : _phase == VoiceAgentPhase.error
                              ? 'Tap to try again'
                              : _phase == VoiceAgentPhase.connecting
                              ? 'Getting your voice chat ready'
                              : _phase == VoiceAgentPhase.thinking
                              ? 'I’m thinking of a reply'
                              : _phase == VoiceAgentPhase.speaking
                              ? 'Tap the end button when you\'re done'
                              : 'Go ahead - I\'m listening',
                          key: ValueKey(_phase),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_isActive) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _endConversation,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('End conversation'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Text(
                    'Try asking: “What appointments do I have this week?” or “What medicine is due for my family today?”',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!supported)
                  const _NoticeCard(
                    icon: Icons.phone_android_rounded,
                    title: 'Voice chat unavailable',
                    message:
                        'Web voice chat needs a browser with speech '
                        'recognition support. The Android and iOS apps use '
                        'live voice chat.',
                  )
                else if (_error case final error?)
                  _NoticeCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Voice chat unavailable',
                    message: error,
                    isError: true,
                  ),
                const SizedBox(height: 14),
                _TranscriptCard(
                  title: 'You',
                  text: _userTranscript,
                  placeholder: 'Your words will appear here.',
                  icon: Icons.graphic_eq_rounded,
                  accent: colors.tertiary,
                ),
                const SizedBox(height: 10),
                _TranscriptCard(
                  title: 'Emergensy',
                  text: _assistantTranscript,
                  placeholder: 'I\'ll reply here and speak my answer aloud.',
                  icon: Icons.auto_awesome_rounded,
                  accent: colors.primary,
                ),
                const SizedBox(height: 18),
                const _NoticeCard(
                  icon: Icons.health_and_safety_outlined,
                  title: 'For urgent help',
                  message:
                      'This assistant provides general information only and '
                      'does not replace a clinician or emergency services. '
                      'In India, call 112 for an emergency.',
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _VoiceHeader extends StatelessWidget {
  const _VoiceHeader({
    required this.phase,
    required this.statusLabel,
    required this.onStop,
  });

  final VoiceAgentPhase phase;
  final String statusLabel;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected =
        phase == VoiceAgentPhase.connecting ||
        phase == VoiceAgentPhase.thinking ||
        phase == VoiceAgentPhase.listening ||
        phase == VoiceAgentPhase.speaking;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A calmer next step, by voice.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Row(
                  key: ValueKey(statusLabel),
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: connected
                            ? colors.tertiary
                            : phase == VoiceAgentPhase.error
                            ? colors.error
                            : colors.outlineVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onStop != null)
          IconButton.filledTonal(
            tooltip: 'End voice chat',
            onPressed: onStop,
            icon: const Icon(Icons.call_end_rounded),
          ),
      ],
    );
  }
}

class _VoiceOrb extends StatefulWidget {
  const _VoiceOrb({
    required this.active,
    required this.speaking,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool speaking;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && !MediaQuery.of(context).disableAnimations) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = widget.active ? Icons.call_end_rounded : Icons.mic_rounded;
    final label = widget.active ? 'End voice chat' : 'Start voice chat';
    return SizedBox(
      height: 224,
      width: 224,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulse = widget.active ? _pulse.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var ring = 0; ring < 3; ring++)
                Container(
                  width: 150 + ring * 26 + pulse * 18,
                  height: 150 + ring * 26 + pulse * 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          (widget.speaking ? colors.tertiary : colors.primary)
                              .withValues(
                                alpha: widget.active
                                    ? .10 + pulse * .08
                                    : .07 - ring * .012,
                              ),
                    ),
                  ),
                ),
              Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  onTap: widget.enabled ? widget.onTap : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: 112 + pulse * 7,
                    height: 112 + pulse * 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.active
                            ? [colors.tertiary, colors.primary]
                            : [
                                colors.primary,
                                colors.primary.withValues(alpha: .78),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(
                            alpha: widget.active ? .22 + pulse * .12 : .20,
                          ),
                          blurRadius: 28 + pulse * 14,
                          spreadRadius: 2 + pulse * 3,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 38, color: colors.onPrimary),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.title,
    required this.text,
    required this.placeholder,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String text;
  final String placeholder;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    text.isEmpty ? placeholder : text,
                    key: ValueKey(text.isEmpty ? placeholder : text),
                    style: TextStyle(
                      height: 1.45,
                      color: text.isEmpty
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = isError ? colors.error : colors.tertiary;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
