import 'dart:convert';

import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:emergensy/widgets/feature_hero_icon.dart';
import 'package:emergensy/widgets/section_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef ProfileSaveCallback = Future<bool> Function(Map<String, Object?> data);

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.user,
    required this.data,
    required this.darkMode,
    required this.onToggleDarkMode,
    required this.onSaveData,
    required this.onOpenEmergencyPassport,
    required this.onOpenWellnessHub,
    required this.onOpenFamilyGuardian,
    required this.onSignOut,
    super.key,
  });

  final AppUser user;
  final Map<String, Object?> data;
  final bool darkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final ProfileSaveCallback onSaveData;
  final VoidCallback onOpenEmergencyPassport;
  final VoidCallback onOpenWellnessHub;
  final VoidCallback onOpenFamilyGuardian;
  final VoidCallback onSignOut;

  String get _name =>
      (data['displayName'] as String?)?.trim().isNotEmpty == true
      ? data['displayName'] as String
      : user.displayName?.trim().isNotEmpty == true
      ? user.displayName!
      : user.email.split('@').first;

  Future<void> _editProfile(BuildContext context) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _EditProfileDialog(name: _name),
    );
    if (result != null) await onSaveData(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Row(
            children: [
              const FeatureHeroIcon(
                tag: 'Profile & settings',
                icon: Icons.person_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your care details and preferences',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(Icons.person, color: colors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.email,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'YOUR HEALTH',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _ProfileAction(
            icon: Icons.health_and_safety_outlined,
            title: 'Emergency Passport 360',
            subtitle: 'Medical details, emergency QR, and sharing controls',
            onTap: onOpenEmergencyPassport,
          ),
          _ProfileAction(
            icon: Icons.monitor_heart_outlined,
            title: 'Wellness Hub',
            subtitle: 'Everyday physical and mental wellbeing tools',
            onTap: onOpenWellnessHub,
          ),
          _ProfileAction(
            icon: Icons.family_restroom_outlined,
            title: 'Family guardian mode',
            subtitle: 'Manage family profiles with their authorization',
            onTap: onOpenFamilyGuardian,
          ),
          const SizedBox(height: 18),
          Text(
            'PREFERENCES',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: darkMode,
              onChanged: onToggleDarkMode,
              secondary: Icon(
                darkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              title: const Text('Dark mode'),
              subtitle: Text(
                darkMode
                    ? 'Midnight navy with cyan and emergency-red accents'
                    : 'Hospital white and red palette',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: onSignOut,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Emergency and health information is stored in your signed-in account. '
            'Only share QR details you are comfortable disclosing.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.name});

  final String name;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _nameController = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'displayName': _nameController.text.trim(),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class HealthQrScannerPage extends StatefulWidget {
  const HealthQrScannerPage({super.key});

  @override
  State<HealthQrScannerPage> createState() => _HealthQrScannerPageState();
}

class _HealthQrScannerPageState extends State<HealthQrScannerPage> {
  static const _allowedFields = {
    'name',
    'bloodGroup',
    'heightCm',
    'weightKg',
    'allergies',
    'conditions',
    'emergencyContact',
    'emergencyRelationship',
    'emergencyPhone',
    'medications',
    'preferredHospital',
  };

  Map<String, String>? _scannedProfile;
  String? _scanError;
  bool _handled = false;

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      _handled = true;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('QR data must be a JSON object.');
        }
        final profile = <String, String>{};
        for (final entry in decoded.entries) {
          if (_allowedFields.contains(entry.key) && entry.value is String) {
            final value = (entry.value as String).trim();
            if (value.isNotEmpty) profile[entry.key as String] = value;
          }
        }
        if (profile.isEmpty) {
          throw const FormatException(
            'This QR code does not contain supported health details.',
          );
        }
        setState(() {
          _scannedProfile = profile;
          _scanError = null;
        });
      } on FormatException catch (error) {
        setState(() {
          _scanError = error.message;
          _scannedProfile = null;
        });
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _scannedProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan health QR')),
      body: SectionBackdrop(
        icon: Icons.qr_code_scanner_rounded,
        accent: Theme.of(context).colorScheme.tertiary,
        child: CenteredContent(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              profile == null
                  ? 'Scan the patient’s consented QR profile.'
                  : 'Shared health details',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Details are shown only on this screen and are not saved or sent by EM3RGENSY. The patient controls which fields their QR code contains.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (profile == null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: MobileScanner(onDetect: _handleCapture),
                ),
              ),
              if (_scanError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _scanError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ] else ...[
              Card(
                child: Column(
                  children: [
                    for (final entry in profile.entries)
                      ListTile(
                        title: Text(_fieldLabel(entry.key)),
                        subtitle: Text(entry.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _handled = false;
                  _scannedProfile = null;
                }),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan another code'),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  String _fieldLabel(String key) => switch (key) {
    'bloodGroup' => 'Blood group',
    'heightCm' => 'Height',
    'weightKg' => 'Weight',
    'emergencyContact' => 'Emergency contact',
    'emergencyPhone' => 'Emergency phone',
    'emergencyRelationship' => 'Emergency contact relationship',
    'allergies' => 'Allergies',
    'conditions' => 'Medical conditions',
    'medications' => 'Current medications',
    'preferredHospital' => 'Preferred hospital',
    _ => 'Name',
  };
}

class FamilyGuardianPage extends StatefulWidget {
  const FamilyGuardianPage({
    required this.data,
    required this.onSaveData,
    required this.onBookAppointments,
    required this.onBookLabTests,
    super.key,
  });

  final Map<String, Object?> data;
  final ProfileSaveCallback onSaveData;
  final ValueChanged<Map<String, Object?>> onBookAppointments;
  final ValueChanged<Map<String, Object?>> onBookLabTests;

  @override
  State<FamilyGuardianPage> createState() => _FamilyGuardianPageState();
}

class _FamilyGuardianPageState extends State<FamilyGuardianPage> {
  late Map<String, Object?> _data = Map.of(widget.data);
  bool _saving = false;

  List<Map<String, Object?>> get _profiles {
    final value = _data['familyProfiles'];
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((profile) => Map<String, Object?>.from(profile))
        .indexed
        .map(
          (entry) => {
            ...entry.$2,
            'id': entry.$2['id'] as String? ?? 'legacy-family-${entry.$1}',
          },
        )
        .toList();
  }

  Future<void> _save(Map<String, Object?> updated) async {
    setState(() => _saving = true);
    final saved = await widget.onSaveData(updated);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _data = updated;
    });
  }

  Future<void> _addFamilyProfile() async {
    final profile = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => const _AddFamilyProfileDialog(),
    );
    if (profile == null) return;
    await _save({
      ..._data,
      'familyProfiles': [
        ..._profiles,
        {...profile, 'id': DateTime.now().microsecondsSinceEpoch.toString()},
      ],
    });
  }

  Future<void> _toggleAuthorization(
    int index,
    Map<String, Object?> profile,
    bool authorized,
  ) async {
    final updatedProfiles = [..._profiles];
    updatedProfiles[index] = {...profile, 'authorized': authorized};
    await _save({..._data, 'familyProfiles': updatedProfiles});
  }

  Future<void> _removeProfile(int index) async {
    final updatedProfiles = [..._profiles]..removeAt(index);
    await _save({..._data, 'familyProfiles': updatedProfiles});
  }

  Future<void> _addMedicineReminder(
    int index,
    Map<String, Object?> profile,
  ) async {
    final reminder = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => const _AddMedicineReminderDialog(),
    );
    if (reminder == null || !mounted) return;
    final updatedProfiles = [..._profiles];
    final current = (profile['medicationReminders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    updatedProfiles[index] = {
      ...profile,
      'medicationReminders': [
        ...current,
        {...reminder, 'id': DateTime.now().microsecondsSinceEpoch.toString()},
      ],
    };
    await _save({..._data, 'familyProfiles': updatedProfiles});
  }

  Future<void> _removeMedicineReminder(
    int index,
    Map<String, Object?> profile,
    String reminderId,
  ) async {
    final updatedProfiles = [..._profiles];
    final reminders = (profile['medicationReminders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .where((item) => item['id'] != reminderId)
        .toList();
    updatedProfiles[index] = {...profile, 'medicationReminders': reminders};
    await _save({..._data, 'familyProfiles': updatedProfiles});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profiles = _profiles;
    return Scaffold(
      appBar: AppBar(title: const Text('Family guardian mode')),
      body: SectionBackdrop(
        icon: Icons.family_restroom_rounded,
        accent: colors.tertiary,
        child: CenteredContent(
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                const FeatureHeroIcon(
                  tag: 'Family guardian',
                  icon: Icons.family_restroom_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Care for the people you love.',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Create profiles for family members you are authorized to support. Get their permission before storing or managing their information.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _addFamilyProfile,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add family profile'),
            ),
            const SizedBox(height: 14),
            if (profiles.isEmpty)
              const _FamilyEmptyState()
            else
              for (final entry in profiles.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colors.primaryContainer,
                              child: Icon(
                                Icons.person_outline,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.$2['name'] as String? ??
                                        'Family member',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    entry.$2['relationship'] as String? ?? '',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove profile',
                              onPressed: _saving
                                  ? null
                                  : () => _removeProfile(entry.$1),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: entry.$2['authorized'] == true,
                          onChanged: _saving
                              ? null
                              : (value) => _toggleAuthorization(
                                  entry.$1,
                                  entry.$2,
                                  value,
                                ),
                          title: const Text('I have their authorization'),
                          subtitle: const Text(
                            'Only enable this after they give permission.',
                          ),
                        ),
                        if (entry.$2['authorized'] == true) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Medicine reminders',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 5),
                          ...((entry.$2['medicationReminders'] as List? ??
                                      const [])
                                  .whereType<Map>()
                                  .map(
                                    (item) => Map<String, Object?>.from(item),
                                  ))
                              .map((reminder) {
                                final times =
                                    (reminder['times'] as List? ?? const [])
                                        .whereType<String>()
                                        .map(_displayMedicineTime)
                                        .join(', ');
                                final name =
                                    reminder['name'] as String? ?? 'Medicine';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.medication_outlined,
                                    color: colors.tertiary,
                                  ),
                                  title: Text(name),
                                  subtitle: Text(
                                    [
                                          if ((reminder['dose'] as String? ??
                                                  '')
                                              .isNotEmpty)
                                            reminder['dose'] as String,
                                          times,
                                        ]
                                        .where((value) => value.isNotEmpty)
                                        .join(' · '),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Remove medicine reminder',
                                    onPressed: _saving
                                        ? null
                                        : () => _removeMedicineReminder(
                                            entry.$1,
                                            entry.$2,
                                            reminder['id'] as String? ?? '',
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                );
                              }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _addMedicineReminder(
                                      entry.$1,
                                      entry.$2,
                                    ),
                              icon: const Icon(Icons.add_alarm_outlined),
                              label: const Text('Add medicine reminder'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Times repeat on the selected days. Set the dose and notes exactly as prescribed. Mobile alerts need notifications enabled.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onBookAppointments(entry.$2),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: const Text('Book appointment'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onBookLabTests(entry.$2),
                                icon: const Icon(Icons.biotech_outlined),
                                label: const Text('Book lab tests'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            if (_saving) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'These profiles are private to your signed-in account. This feature does not grant legal authority or send information to family members.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

String _displayMedicineTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  final time = TimeOfDay(hour: hour, minute: minute);
  return '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

class _AddMedicineReminderDialog extends StatefulWidget {
  const _AddMedicineReminderDialog();

  @override
  State<_AddMedicineReminderDialog> createState() =>
      _AddMedicineReminderDialogState();
}

class _AddMedicineReminderDialogState
    extends State<_AddMedicineReminderDialog> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _instructions = TextEditingController();
  final List<TimeOfDay> _times = [];
  final Set<int> _days = {1, 2, 3, 4, 5, 6, 7};
  String? _error;

  static const _weekdays = [
    (1, 'Mon'),
    (2, 'Tue'),
    (3, 'Wed'),
    (4, 'Thu'),
    (5, 'Fri'),
    (6, 'Sat'),
    (7, 'Sun'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (!_times.any(
        (time) => time.hour == picked.hour && time.minute == picked.minute,
      )) {
        _times.add(picked);
        _times.sort(
          (a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute),
        );
      }
    });
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the medicine name.');
      return;
    }
    if (_times.isEmpty) {
      setState(() => _error = 'Add at least one reminder time.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Choose at least one day.');
      return;
    }
    Navigator.pop(context, <String, Object?>{
      'name': _name.text.trim(),
      'dose': _dose.text.trim(),
      'instructions': _instructions.text.trim(),
      'times': _times
          .map(
            (time) =>
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          )
          .toList(),
      'days': _days.toList()..sort(),
      'active': true,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Medicine reminder'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Medicine name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dose,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dose (as prescribed, optional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructions,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'For example, take after food',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reminder times',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final time in _times)
                  InputChip(
                    label: Text(time.format(context)),
                    onDeleted: () => setState(() => _times.remove(time)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add time'),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Repeat on', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 2,
              children: [
                for (final (day, label) in _weekdays)
                  FilterChip(
                    label: Text(label),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save reminder')),
    ],
  );
}

class _AddFamilyProfileDialog extends StatefulWidget {
  const _AddFamilyProfileDialog();

  @override
  State<_AddFamilyProfileDialog> createState() =>
      _AddFamilyProfileDialogState();
}

class _AddFamilyProfileDialogState extends State<_AddFamilyProfileDialog> {
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _contact = TextEditingController();
  bool _authorized = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter their name.');
      return;
    }
    if (!_authorized) {
      setState(() => _error = 'Confirm you have their permission first.');
      return;
    }
    Navigator.pop(context, <String, Object?>{
      'name': _name.text.trim(),
      'relationship': _relationship.text.trim(),
      'contact': _contact.text.trim(),
      'authorized': _authorized,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add family profile'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact number (optional)',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _authorized,
              onChanged: (value) =>
                  setState(() => _authorized = value ?? false),
              title: const Text(
                'I have their permission to manage this profile.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Add profile')),
    ],
  );
}

class _FamilyEmptyState extends StatelessWidget {
  const _FamilyEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.family_restroom_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No family profiles yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Add someone only after they have agreed to let you help manage their profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
