import 'dart:async';

import 'package:emergensy/screens/profile_pages.dart' show ProfileSaveCallback;
import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/services/voice_agent_service.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:emergensy/widgets/section_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Everyday wellbeing tools. Records are kept in the signed-in user's private
/// profile document and are only written after the user chooses to save them.
class WellnessHubPage extends StatefulWidget {
  const WellnessHubPage({
    required this.user,
    required this.data,
    required this.onSaveData,
    required this.onOpenAssistant,
    super.key,
  });

  final AppUser user;
  final Map<String, Object?> data;
  final ProfileSaveCallback onSaveData;
  final ValueChanged<VoiceAssistantFocus> onOpenAssistant;

  @override
  State<WellnessHubPage> createState() => _WellnessHubPageState();
}

class _WellnessHubPageState extends State<WellnessHubPage> {
  late Map<String, Object?> _hub = _map(widget.data['wellnessHub']);
  bool _saving = false;
  Timer? _breathTimer;
  int _breathSeconds = 0;
  bool _breathing = false;
  DateTime? _gymStartedAt;
  String _activeSection = 'Overview';

  static const _tasks = <String>[
    'Take a short walk',
    'Stretch for a few minutes',
    'Try a breathing break',
    'Drink a glass of water',
    'Connect with someone you trust',
  ];
  static const _moods = <(String, String, IconData)>[
    ('Happy', ':)', Icons.sentiment_very_satisfied_rounded),
    ('Calm', '~', Icons.spa_rounded),
    ('Motivated', '+', Icons.bolt_rounded),
    ('Okay', ':|', Icons.sentiment_satisfied_alt_rounded),
    ('Stressed', ':/', Icons.sentiment_dissatisfied_rounded),
    ('Anxious', '?', Icons.cloud_outlined),
    ('Sad', ':(', Icons.water_drop_outlined),
    ('Overwhelmed', '...', Icons.waves_rounded),
    ('Tired', 'zZ', Icons.bedtime_outlined),
  ];

  static Map<String, Object?> _map(Object? value) => value is Map
      ? Map<String, Object?>.from(value)
      : <String, Object?>{};

  String get _today => _dateKey(DateTime.now());
  String get _name {
    final name = widget.user.displayName?.trim();
    return name == null || name.isEmpty ? 'there' : name.split(' ').first;
  }

  List<Map<String, Object?>> _list(String key) {
    final value = _hub[key];
    if (value is! List) return [];
    return value.whereType<Map>().map(_map).toList();
  }

  List<Map<String, Object?>> get _todayTasks {
    final all = _map(_hub['dailyActivities']);
    final value = all[_today];
    if (value is List) return value.whereType<Map>().map(_map).toList();
    return _tasks.map((title) => <String, Object?>{
      'title': title,
      'state': 'open',
    }).toList();
  }

  Future<void> _persist(Map<String, Object?> next) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSaveData({'wellnessHub': next});
      if (!mounted) return;
      if (ok) {
        setState(() => _hub = next);
      } else {
        _message('Could not save this update. Please try again.');
      }
    } catch (_) {
      if (mounted) _message('Could not save this update. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setTask(int index, String state) async {
    final daily = _map(_hub['dailyActivities']);
    final today = _todayTasks;
    today[index] = {...today[index], 'state': state};
    daily[_today] = today;
    await _persist({..._hub, 'dailyActivities': daily});
  }

  Future<void> _customizeTasks() async {
    final current = _todayTasks;
    final title = TextEditingController();
    final result = await showDialog<List<Map<String, Object?>>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: const Text('Todays activities'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: ListView(shrinkWrap: true, children: current.indexed.map((entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.$2['title'] as String? ?? ''),
            trailing: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Remove activity', onPressed: () => update(() => current.removeAt(entry.$1))),
          )).toList())),
          TextField(controller: title, maxLength: 60, decoration: const InputDecoration(labelText: 'Add an activity', hintText: 'For example, take a screen break')),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () { final value = title.text.trim(); if (value.isEmpty || current.length >= 8) return; update(() { current.add({'title': value, 'state': 'open'}); title.clear(); }); }, icon: const Icon(Icons.add), label: const Text('Add'))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, current), child: const Text('Save routine'))],
      )),
    );
    title.dispose();
    if (result == null) return;
    final daily = _map(_hub['dailyActivities']);
    daily[_today] = result;
    await _persist({..._hub, 'dailyActivities': daily});
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tasks = _todayTasks;
    final completed = tasks.where((task) => task['state'] == 'done').length;
    final moods = _list('moodHistory');
    final workouts = _list('workouts');
    final cardio = _list('cardio');
    final greeting = DateTime.now().hour < 12
        ? 'Good morning'
        : DateTime.now().hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness Hub'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          else
            IconButton(
              tooltip: 'Privacy and data controls',
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: _privacyInfo,
            ),
        ],
      ),
      body: SectionBackdrop(
        icon: Icons.spa_rounded,
        accent: colors.tertiary,
        child: CenteredContent(
          maxWidth: 980,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            _sectionSelector(colors),
            const SizedBox(height: 18),
            if (_activeSection == 'Overview') ...[
              _welcomeCard(colors, greeting, completed, tasks.length),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: _heading('A little care for today', 'Choose what feels doable.')),
                TextButton.icon(onPressed: _customizeTasks, icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('Edit')),
              ]),
              const SizedBox(height: 12),
              ...tasks.indexed.map((item) => _taskTile(item.$1, item.$2)),
              const SizedBox(height: 18),
              _heading('Check in with yourself', 'Optional. There is no right answer.'),
              const SizedBox(height: 10),
              _moodCard(moods),
              const SizedBox(height: 22),
              _heading('Explore your wellbeing', 'Small steps, at your pace.'),
              const SizedBox(height: 12),
              _quickLinks(),
            ] else if (_activeSection == 'Physical') ...[
              _heading('Physical health', 'Move in a way that works for you.'),
              const SizedBox(height: 12),
              _workoutCard(workouts),
              const SizedBox(height: 12),
              _gymTrackerCard(workouts),
              const SizedBox(height: 12),
              _cardioCard(cardio),
              const SizedBox(height: 12),
              _progressCard(workouts, cardio),
              const SizedBox(height: 12),
              _assistantCard(
                title: 'Fitness assistant',
                subtitle: 'Ask about workouts, exercise technique, cardio or recovery.',
                focus: VoiceAssistantFocus.physicalWellness,
              ),
            ] else ...[
              _heading('Mental wellness', 'A gentle space for everyday support.'),
              const SizedBox(height: 12),
              _moodCard(moods),
              const SizedBox(height: 12),
              _breathingCard(),
              const SizedBox(height: 12),
              _gameCard(),
              const SizedBox(height: 12),
              _professionalSupportCard(),
              const SizedBox(height: 12),
              _assistantCard(
                title: 'AI companion',
                subtitle: 'Talk through how you are feeling and explore gentle next steps.',
                focus: VoiceAssistantFocus.mentalWellness,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Wellness tools support everyday habits; they do not diagnose or treat health conditions.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _sectionSelector(ColorScheme colors) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Overview', label: Text('Overview'), icon: Icon(Icons.grid_view_rounded)),
        ButtonSegment(value: 'Physical', label: Text('Physical'), icon: Icon(Icons.directions_walk_rounded)),
        ButtonSegment(value: 'Mental', label: Text('Mental'), icon: Icon(Icons.spa_outlined)),
      ],
      selected: {_activeSection},
      showSelectedIcon: false,
      onSelectionChanged: (value) => setState(() => _activeSection = value.first),
    ),
  );

  Widget _welcomeCard(ColorScheme colors, String greeting, int done, int total) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primaryContainer, colors.tertiaryContainer],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$greeting, $_name', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('You can take today one small step at a time.', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Row(children: [
              Icon(Icons.favorite_border_rounded, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('$done of $total activities done', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 7, borderRadius: BorderRadius.circular(8)),
          ]),
        ),
      );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );

  Widget _taskTile(int index, Map<String, Object?> task) {
    final state = task['state'] as String? ?? 'open';
    final done = state == 'done';
    final skipped = state == 'skipped';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined, color: done ? Theme.of(context).colorScheme.primary : null),
        title: Text(task['title'] as String? ?? 'Wellness activity', style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
        subtitle: skipped ? const Text('Skipped today. That is okay.') : null,
        trailing: PopupMenuButton<String>(
          tooltip: 'Update activity',
          onSelected: (value) => _setTask(index, value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'done', child: Text('Mark complete')),
            PopupMenuItem(value: 'skipped', child: Text('Skip today')),
            PopupMenuItem(value: 'open', child: Text('Reset')),
          ],
        ),
        onTap: () => _setTask(index, done ? 'open' : 'done'),
      ),
    );
  }

  Widget _moodCard(List<Map<String, Object?>> moods) {
    final latest = moods.isEmpty ? null : moods.first;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (latest != null && latest['date'] == _today)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Today you recorded: ${latest['mood']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        Wrap(spacing: 8, runSpacing: 8, children: _moods.map((mood) => ActionChip(
          avatar: Text(mood.$2), label: Text(mood.$1),
          onPressed: () => _recordMood(mood.$1),
        )).toList()),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: _showMoodHistory, icon: const Icon(Icons.insights_outlined), label: Text('Mood history (${moods.length})')),
      ]),
    ));
  }

  Future<void> _recordMood(String mood) async {
    final note = TextEditingController();
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('How are you feeling? $mood'),
      content: TextField(controller: note, maxLength: 280, maxLines: 3, decoration: const InputDecoration(labelText: 'Optional note', hintText: 'Anything you would like to remember?')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save check-in'))],
    ));
    if (save != true) { note.dispose(); return; }
    final moods = _list('moodHistory');
    moods.insert(0, {'mood': mood, 'note': note.text.trim(), 'date': _today, 'createdAt': DateTime.now().toIso8601String()});
    note.dispose();
    await _persist({..._hub, 'moodHistory': moods.take(180).toList()});
  }

  void _showMoodHistory() {
    final moods = _list('moodHistory');
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => SafeArea(
      child: SizedBox(height: 420, child: moods.isEmpty
        ? const Center(child: Text('Mood tracking is optional. Your check-ins will appear here.'))
        : ListView(padding: const EdgeInsets.all(16), children: moods.map((entry) => ListTile(
          leading: const Icon(Icons.spa_outlined), title: Text(entry['mood'] as String? ?? ''),
          subtitle: Text([entry['date'], entry['note']].whereType<String>().where((v) => v.isNotEmpty).join('  ')),
        )).toList())),
    ));
  }

  Widget _quickLinks() => Wrap(spacing: 10, runSpacing: 10, children: [
    _quickCard('Move gently', Icons.directions_run_rounded, () => setState(() => _activeSection = 'Physical')),
    _quickCard('Take a pause', Icons.self_improvement_rounded, () => setState(() => _activeSection = 'Mental')),
  ]);

  Widget _quickCard(String label, IconData icon, VoidCallback onTap) => ActionChip(
    avatar: Icon(icon, size: 19), label: Text(label), onPressed: onTap,
  );

  Widget _workoutCard(List<Map<String, Object?>> workouts) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _CardHeading(icon: Icons.fitness_center_rounded, title: 'Workout plans', subtitle: 'Pick a gentle session or log your own.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: ['General fitness', 'Strength', 'Endurance', 'Flexibility', 'Weight management', 'Mobility'].map((goal) => OutlinedButton(onPressed: () => _startWorkout(goal), child: Text(goal))).toList()),
      const SizedBox(height: 8),
      Text('Beginner  Home or gym  Warm up and cool down at your own pace.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      const Divider(height: 24),
      _historySummary('Workout history', workouts, 'minutes'),
    ],
  )));

  Future<void> _startWorkout(String goal) async {
    final minutes = TextEditingController(text: '20');
    final notes = TextEditingController();
    String level = 'Beginner';
    String place = 'Home';
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text('$goal session'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_planDescription(goal, level)),
        DropdownButtonFormField<String>(initialValue: level, decoration: const InputDecoration(labelText: 'Experience'), items: ['Beginner', 'Intermediate', 'Advanced'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setDialog(() => level = v ?? level)),
        DropdownButtonFormField<String>(initialValue: place, decoration: const InputDecoration(labelText: 'Where'), items: ['Home', 'Gym'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setDialog(() => place = v ?? place)),
        TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)')),
        TextField(controller: notes, maxLength: 280, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'goal': goal, 'level': level, 'place': place, 'minutes': int.tryParse(minutes.text) ?? 20, 'notes': notes.text.trim()}), child: const Text('Save session'))],
    )));
    minutes.dispose(); notes.dispose();
    if (result == null) return;
    final logs = _list('workouts');
    logs.insert(0, {...result, 'date': _today, 'createdAt': DateTime.now().toIso8601String()});
    await _persist({..._hub, 'workouts': logs.take(100).toList()});
  }

  Widget _gymTrackerCard(List<Map<String, Object?>> workouts) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _CardHeading(icon: Icons.timer_outlined, title: 'Gym session tracker', subtitle: 'Start when you are ready; finish to save a private log.'),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _gymStartedAt == null ? _startGymSession : _finishGymSession,
          icon: Icon(_gymStartedAt == null ? Icons.play_arrow_rounded : Icons.stop_rounded),
          label: Text(_gymStartedAt == null ? 'Start gym session' : 'Finish and save session'),
        ),
        if (_gymStartedAt != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Session in progress on this device.')),
        const Divider(height: 24),
        _historySummary('Recent sessions', workouts, 'min'),
      ]),
    ),
  );

  void _startGymSession() => setState(() => _gymStartedAt = DateTime.now());

  Future<void> _finishGymSession() async {
    final started = _gymStartedAt;
    if (started == null) return;
    final exercise = TextEditingController();
    final sets = TextEditingController();
    final reps = TextEditingController();
    final weight = TextEditingController();
    final notes = TextEditingController();
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (context) => AlertDialog(
      title: const Text('Finish gym session'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Elapsed: ${DateTime.now().difference(started).inMinutes} minutes'),
        TextField(controller: exercise, decoration: const InputDecoration(labelText: 'Exercise (optional)')),
        Row(children: [Expanded(child: TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets'))), const SizedBox(width: 8), Expanded(child: TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps')))]),
        TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight in kg (optional)')),
        TextField(controller: notes, maxLength: 280, decoration: const InputDecoration(labelText: 'Session notes')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'exercise': exercise.text.trim(), 'sets': int.tryParse(sets.text) ?? 0, 'reps': int.tryParse(reps.text) ?? 0, 'weightKg': double.tryParse(weight.text) ?? 0, 'notes': notes.text.trim()}), child: const Text('Save session'))],
    ));
    exercise.dispose(); sets.dispose(); reps.dispose(); weight.dispose(); notes.dispose();
    if (result == null) return;
    final duration = DateTime.now().difference(started).inMinutes.clamp(1, 1440);
    setState(() => _gymStartedAt = null);
    final logs = _list('workouts');
    logs.insert(0, {...result, 'goal': 'Gym session', 'place': 'Gym', 'level': 'Self-paced', 'minutes': duration, 'date': _today, 'createdAt': DateTime.now().toIso8601String()});
    await _persist({..._hub, 'workouts': logs.take(100).toList()});
  }

  String _planDescription(String goal, String level) {
    final multiplier = level == 'Advanced' ? '3' : level == 'Intermediate' ? '2' : '1';
    final plan = switch (goal) {
      'Strength' => '$level idea: chair squats ($multiplier sets of 8), wall push-ups ($multiplier sets of 8), and glute bridges ($multiplier sets of 10). Rest 60 seconds between sets. Warm up gently for 5 minutes and cool down with easy stretches.',
      'Endurance' => 'Beginner idea: alternate 2 minutes of comfortable walking with 1 minute easy pace for 15 minutes. Rest or slow down whenever needed. Warm up and cool down for 5 minutes.',
      'Flexibility' => 'Beginner idea: shoulder rolls, seated hamstring stretch, and gentle calf stretch. Hold each comfortable stretch for 20 seconds; do not bounce or force range.',
      'Mobility' => 'Beginner idea: shoulder circles, sit-to-stands, and ankle circles for 2 comfortable rounds. Rest as needed and move within a pain-free range.',
      'Weight management' => 'Beginner idea: choose a comfortable 1520 minute walk or light movement session. Sustainable activity is personal; avoid extreme targets and consider a qualified professional for individualized support.',
      _ => '$level idea: chair sit-to-stands ($multiplier sets of 8), wall push-ups ($multiplier sets of 8), and a comfortable 5-minute walk. Rest 60 seconds between rounds. Warm up and cool down for 5 minutes.',
    };
    return '$plan This is a general example, not individualized medical guidance.';
  }

  Widget _cardioCard(List<Map<String, Object?>> records) => Card(child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _CardHeading(icon: Icons.directions_bike_rounded, title: 'Cardio tracker', subtitle: 'Record a walk, run, ride, swim or other activity.'),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(onPressed: _addCardio, icon: const Icon(Icons.add), label: const Text('Log cardio activity')),
      const Divider(height: 24),
      _historySummary('Recent cardio', records, 'minutes'),
    ],
  )));

  Future<void> _addCardio() async {
    final minutes = TextEditingController();
    final distance = TextEditingController();
    final pace = TextEditingController();
    final note = TextEditingController();
    String activity = 'Walking';
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Log cardio'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: activity, items: ['Walking', 'Running', 'Cycling', 'Swimming', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setDialog(() => activity = v ?? activity)),
        TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration in minutes')),
        TextField(controller: distance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Distance in km (optional)')),
        TextField(controller: pace, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Pace in min/km (optional)')),
        TextField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'Note (optional)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, {'activity': activity, 'minutes': int.tryParse(minutes.text) ?? 0, 'distanceKm': double.tryParse(distance.text) ?? 0, 'paceMinPerKm': double.tryParse(pace.text) ?? 0, 'note': note.text.trim()}), child: const Text('Save'))],
    )));
    minutes.dispose(); distance.dispose(); pace.dispose(); note.dispose();
    if (result == null) return;
    final logs = _list('cardio');
    logs.insert(0, {...result, 'date': _today, 'createdAt': DateTime.now().toIso8601String()});
    await _persist({..._hub, 'cardio': logs.take(100).toList()});
  }

  Widget _historySummary(String title, List<Map<String, Object?>> items, String unit) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    if (items.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No sessions yet. Your activity stays private.'))
    else ...items.take(3).map((item) => ListTile(
      contentPadding: EdgeInsets.zero, dense: true,
      leading: const Icon(Icons.history_rounded),
      title: Text('${item['goal'] ?? item['activity'] ?? 'Activity'}  ${item['minutes'] ?? 0} $unit'),
      subtitle: Text([item['date'], item['level'], item['place'], item['notes'], item['note']].whereType<String>().where((v) => v.isNotEmpty).join('  ')),
    )),
  ]);

  Widget _progressCard(List<Map<String, Object?>> workouts, List<Map<String, Object?>> cardio) {
    final week = DateTime.now().subtract(const Duration(days: 6));
    final recentWorkouts = workouts.where((item) => _parseDate(item['date'])?.isAfter(DateTime(week.year, week.month, week.day).subtract(const Duration(seconds: 1))) ?? false).length;
    final recentCardio = cardio.where((item) => _parseDate(item['date'])?.isAfter(DateTime(week.year, week.month, week.day).subtract(const Duration(seconds: 1))) ?? false).length;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _CardHeading(icon: Icons.insights_rounded, title: 'Your activity', subtitle: 'A simple look at the last 7 days.'),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _statBox('Workouts', '$recentWorkouts')), const SizedBox(width: 10), Expanded(child: _statBox('Cardio', '$recentCardio'))]),
      const SizedBox(height: 16),
      _weeklyBars(workouts, cardio),
      const SizedBox(height: 8),
      Text('Progress is personal. Rest days count too.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ])));
  }

  Widget _weeklyBars(List<Map<String, Object?>> workouts, List<Map<String, Object?>> cardio) {
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - index));
      final key = _dateKey(date);
      final total = [...workouts, ...cardio].where((item) => item['date'] == key).length;
      return (date, total);
    });
    final peak = days.map((entry) => entry.$2).fold<int>(0, (max, value) => value > max ? value : max);
    return SizedBox(height: 96, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: days.map((entry) {
      final height = entry.$2 == 0 ? 6.0 : 12.0 + 44.0 * entry.$2 / (peak == 0 ? 1 : peak);
      return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('${entry.$2}', style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 4),
        Container(height: height, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: entry.$2 == 0 ? .2 : .8), borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 5),
        Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][entry.$1.weekday - 1], style: const TextStyle(fontSize: 10)),
      ])));
    }).toList()));
  }

  Widget _statBox(String label, String value) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: Column(children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), Text(label)]));

  Widget _breathingCard() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _CardHeading(icon: Icons.air_rounded, title: 'Breathing pause', subtitle: 'A short paced breathing exercise. Stop if it feels uncomfortable.'),
    const SizedBox(height: 12),
    Center(child: AnimatedContainer(duration: const Duration(milliseconds: 500), width: _breathing ? 104 : 76, height: _breathing ? 104 : 76, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer), child: Center(child: Text(_breathing ? '${_breathSeconds}s' : 'Breathe', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))))),
    const SizedBox(height: 10),
    Center(child: FilledButton.tonalIcon(onPressed: _breathing ? _stopBreathing : _startBreathing, icon: Icon(_breathing ? Icons.stop_rounded : Icons.play_arrow_rounded), label: Text(_breathing ? 'Stop' : 'Start 1 minute'))),
  ])));

  void _startBreathing() {
    setState(() { _breathing = true; _breathSeconds = 60; });
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_breathSeconds <= 1) { timer.cancel(); setState(() { _breathing = false; _breathSeconds = 0; }); return; }
      setState(() => _breathSeconds--);
    });
  }

  void _stopBreathing() { _breathTimer?.cancel(); setState(() { _breathing = false; _breathSeconds = 0; }); }

  Widget _gameCard() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _CardHeading(icon: Icons.extension_rounded, title: 'Mindful moment', subtitle: 'A quick, low-pressure memory game.'),
    const SizedBox(height: 10),
    FilledButton.tonalIcon(onPressed: _playMemory, icon: const Icon(Icons.grid_view_rounded), label: const Text('Play a matching game')),
    const SizedBox(height: 6),
    OutlinedButton.icon(onPressed: _gratitudePrompt, icon: const Icon(Icons.edit_note_rounded), label: const Text('A small gratitude prompt')),
  ])));

  Future<void> _playMemory() async {
    final icons = [Icons.sunny, Icons.spa, Icons.water_drop, Icons.favorite];
    final values = [...icons, ...icons]..shuffle();
    final open = <int>{};
    final matched = <int>{};
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Find the pairs'),
      content: SizedBox(width: 300, child: GridView.builder(shrinkWrap: true, itemCount: values.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8), itemBuilder: (context, index) => InkWell(
        borderRadius: BorderRadius.circular(12), onTap: matched.contains(index) || open.contains(index) || open.length == 2 ? null : () {
          update(() => open.add(index));
          if (open.length == 2) {
            final pair = open.toList();
            if (values[pair[0]] == values[pair[1]]) { matched.addAll(pair); open.clear(); }
            else Future<void>.delayed(const Duration(milliseconds: 650), () { if (context.mounted) update(() => open.clear()); });
          }
        }, child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(open.contains(index) || matched.contains(index) ? values[index] : Icons.circle_outlined)),
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(matched.length == values.length ? 'Done!' : 'Close'))],
    )));
  }

  Future<void> _gratitudePrompt() async {
    final note = TextEditingController();
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Something that felt okay today'),
      content: TextField(controller: note, maxLength: 300, maxLines: 3, decoration: const InputDecoration(hintText: 'A person, a moment, or something small.'),),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Skip')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save privately'))],
    ));
    if (save == true && note.text.trim().isNotEmpty) {
      final journal = _list('reflections');
      journal.insert(0, {'date': _today, 'text': note.text.trim()});
      await _persist({..._hub, 'reflections': journal.take(90).toList()});
    }
    note.dispose();
  }

  Widget _professionalSupportCard() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _CardHeading(icon: Icons.support_agent_rounded, title: 'Professional support', subtitle: 'AI and self-care tools are not a substitute for professional care.'),
    const SizedBox(height: 8),
    const Text('Verified therapist discovery and appointment booking are not connected in this app yet. Ask your doctor or local health service for a referral.'),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: _crisisHelp, icon: const Icon(Icons.call_outlined), label: const Text('Urgent support options')),
  ])));

  Future<void> _crisisHelp() async {
    final call = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('If you may be in immediate danger'),
      content: const Text('Please contact your local emergency service now, or go to the nearest emergency department. If you can, tell someone you trust and ask them to stay with you. This app cannot provide crisis response.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Call 112 (India)'))],
    ));
    if (call == true) await launchUrl(Uri(scheme: 'tel', path: '112'));
  }

  Widget _assistantCard({
    required String title,
    required String subtitle,
    required VoiceAssistantFocus focus,
  }) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _CardHeading(icon: Icons.chat_bubble_outline_rounded, title: title, subtitle: subtitle),
    const SizedBox(height: 10),
    FilledButton.icon(
      onPressed: () => widget.onOpenAssistant(focus),
      icon: const Icon(Icons.mic_none_rounded),
      label: const Text('Start voice chat'),
    ),
    const SizedBox(height: 6),
    Text('Voice and AI processing requires your consent. This is general support, not diagnosis or professional care.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
  ])));

  Future<void> _privacyInfo() async {
    final remove = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Your wellness data'),
      content: const Text('Mood check-ins, reflections and activity logs are stored in your signed-in account. They are optional and are not shared publicly. You can remove all Wellness Hub records from this account.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete my records'))],
    ));
    if (remove == true) await _persist({});
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ])),
  ]);
}

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime? _parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;
