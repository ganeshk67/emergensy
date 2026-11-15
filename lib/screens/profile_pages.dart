import 'dart:convert';

import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:emergensy/widgets/feature_hero_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

typedef ProfileSaveCallback = Future<bool> Function(Map<String, Object?> data);

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.user,
    required this.data,
    required this.darkMode,
    required this.onToggleDarkMode,
    required this.onSaveData,
    required this.onOpenEmergencyProfile,
    required this.onOpenHealthTimeline,
    required this.onOpenFamilyGuardian,
    required this.onSignOut,
    super.key,
  });

  final AppUser user;
  final Map<String, Object?> data;
  final bool darkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final ProfileSaveCallback onSaveData;
  final VoidCallback onOpenEmergencyProfile;
  final VoidCallback onOpenHealthTimeline;
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
      builder: (context) => _EditProfileDialog(
        name: _name,
        bloodGroup: data['bloodGroup'] as String? ?? '',
        heightCm: data['heightCm'] as String? ?? '',
        weightKg: data['weightKg'] as String? ?? '',
        allergies: data['allergies'] as String? ?? '',
        conditions: data['conditions'] as String? ?? '',
        emergencyContactName: data['emergencyContactName'] as String? ?? '',
        emergencyContactPhone: data['emergencyContactPhone'] as String? ?? '',
      ),
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
            icon: Icons.qr_code_2,
            title: 'Emergency QR profile',
            subtitle: 'Choose what to share in an emergency',
            onTap: onOpenEmergencyProfile,
          ),
          _ProfileAction(
            icon: Icons.monitor_heart_outlined,
            title: 'Health timeline',
            subtitle: 'Organize reports and prepare a visit summary',
            onTap: onOpenHealthTimeline,
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
  const _EditProfileDialog({
    required this.name,
    required this.bloodGroup,
    required this.heightCm,
    required this.weightKg,
    required this.allergies,
    required this.conditions,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  final String name;
  final String bloodGroup;
  final String heightCm;
  final String weightKg;
  final String allergies;
  final String conditions;
  final String emergencyContactName;
  final String emergencyContactPhone;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _controllers = [
    TextEditingController(text: widget.name),
    TextEditingController(text: widget.bloodGroup),
    TextEditingController(text: widget.heightCm),
    TextEditingController(text: widget.weightKg),
    TextEditingController(text: widget.allergies),
    TextEditingController(text: widget.conditions),
    TextEditingController(text: widget.emergencyContactName),
    TextEditingController(text: widget.emergencyContactPhone),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Full name',
      'Blood group',
      'Height (cm)',
      'Weight (kg)',
      'Allergies',
      'Medical conditions',
      'Emergency contact name',
      'Emergency contact phone',
    ];
    const keys = [
      'displayName',
      'bloodGroup',
      'heightCm',
      'weightKg',
      'allergies',
      'conditions',
      'emergencyContactName',
      'emergencyContactPhone',
    ];
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                TextField(
                  controller: _controllers[index],
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: labels[index]),
                ),
                if (index < labels.length - 1) const SizedBox(height: 10),
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
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            for (var index = 0; index < keys.length; index++)
              keys[index]: _controllers[index].text.trim(),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class EmergencyProfilePage extends StatefulWidget {
  const EmergencyProfilePage({
    required this.user,
    required this.data,
    required this.onSaveData,
    super.key,
  });

  final AppUser user;
  final Map<String, Object?> data;
  final ProfileSaveCallback onSaveData;

  @override
  State<EmergencyProfilePage> createState() => _EmergencyProfilePageState();
}

class _EmergencyProfilePageState extends State<EmergencyProfilePage> {
  late Map<String, Object?> _data = Map.of(widget.data);
  bool _saving = false;

  String get _name =>
      (_data['displayName'] as String?)?.trim().isNotEmpty == true
      ? _data['displayName'] as String
      : widget.user.displayName?.trim().isNotEmpty == true
      ? widget.user.displayName!
      : widget.user.email.split('@').first;

  Future<void> _setConsent(String key, bool value) async {
    final updated = {..._data, key: value};
    setState(() => _saving = true);
    final saved = await widget.onSaveData(updated);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _data = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final qrProfile = <String, String>{
      if (_data['qrConsentName'] == true) 'name': _name,
      if (_data['qrConsentBlood'] == true)
        'bloodGroup': _data['bloodGroup'] as String? ?? '',
      if (_data['qrConsentHeight'] == true)
        'heightCm': _data['heightCm'] as String? ?? '',
      if (_data['qrConsentWeight'] == true)
        'weightKg': _data['weightKg'] as String? ?? '',
      if (_data['qrConsentAllergies'] == true)
        'allergies': _data['allergies'] as String? ?? '',
      if (_data['qrConsentConditions'] == true)
        'conditions': _data['conditions'] as String? ?? '',
      if (_data['qrConsentEmergencyContact'] == true) ...{
        'emergencyContact': _data['emergencyContactName'] as String? ?? '',
        'emergencyPhone': _data['emergencyContactPhone'] as String? ?? '',
      },
    }..removeWhere((key, value) => value.trim().isEmpty);
    final hasSharedDetails = qrProfile.isNotEmpty;
    final qrData = hasSharedDetails ? jsonEncode(qrProfile) : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency QR profile')),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const FeatureHeroIcon(
                  tag: 'Emergency profile',
                  icon: Icons.qr_code_2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your emergency details',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select which details appear in your QR code. Anyone who scans it can read the selected information.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _ConsentTile(
                    title: 'Name',
                    value: _data['qrConsentName'] == true,
                    onChanged: (value) => _setConsent('qrConsentName', value),
                  ),
                  _ConsentTile(
                    title: 'Blood group',
                    value: _data['qrConsentBlood'] == true,
                    onChanged: (value) => _setConsent('qrConsentBlood', value),
                  ),
                  _ConsentTile(
                    title: 'Height',
                    value: _data['qrConsentHeight'] == true,
                    onChanged: (value) => _setConsent('qrConsentHeight', value),
                  ),
                  _ConsentTile(
                    title: 'Weight',
                    value: _data['qrConsentWeight'] == true,
                    onChanged: (value) => _setConsent('qrConsentWeight', value),
                  ),
                  _ConsentTile(
                    title: 'Allergies',
                    value: _data['qrConsentAllergies'] == true,
                    onChanged: (value) =>
                        _setConsent('qrConsentAllergies', value),
                  ),
                  _ConsentTile(
                    title: 'Medical conditions',
                    value: _data['qrConsentConditions'] == true,
                    onChanged: (value) =>
                        _setConsent('qrConsentConditions', value),
                  ),
                  _ConsentTile(
                    title: 'Emergency contact',
                    value: _data['qrConsentEmergencyContact'] == true,
                    onChanged: (value) =>
                        _setConsent('qrConsentEmergencyContact', value),
                  ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (hasSharedDetails)
                      QrImageView(
                        data: qrData,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: colors.primary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: const Color(0xFF111827),
                        ),
                      )
                    else
                      Icon(Icons.qr_code_2, size: 120, color: colors.outline),
                    const SizedBox(height: 8),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasSharedDetails
                          ? 'Only the details you selected are encoded.'
                          : 'Choose at least one detail above to create your QR code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This QR code is not access-controlled. Keep it private and share it only when you choose.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
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
    'emergencyPhone',
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
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              profile == null
                  ? 'Scan the patient’s consented QR profile.'
                  : 'Shared health details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
    );
  }

  String _fieldLabel(String key) => switch (key) {
    'bloodGroup' => 'Blood group',
    'heightCm' => 'Height',
    'weightKg' => 'Weight',
    'emergencyContact' => 'Emergency contact',
    'emergencyPhone' => 'Emergency phone',
    'allergies' => 'Allergies',
    'conditions' => 'Medical conditions',
    _ => 'Name',
  };
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    onChanged: (checked) => onChanged(checked ?? false),
    title: Text(title),
    controlAffinity: ListTileControlAffinity.leading,
    dense: true,
  );
}

class HealthTimelinePage extends StatefulWidget {
  const HealthTimelinePage({
    required this.data,
    required this.onSaveData,
    super.key,
  });

  final Map<String, Object?> data;
  final ProfileSaveCallback onSaveData;

  @override
  State<HealthTimelinePage> createState() => _HealthTimelinePageState();
}

class _HealthTimelinePageState extends State<HealthTimelinePage> {
  late Map<String, Object?> _data = Map.of(widget.data);
  bool _saving = false;

  List<Map<String, Object?>> get _records {
    final value = _data['healthRecords'];
    if (value is! List) return [];
    final records = value
        .whereType<Map>()
        .map((record) => Map<String, Object?>.from(record))
        .toList();
    records.sort((a, b) => _date(b).compareTo(_date(a)));
    return records;
  }

  DateTime _date(Map<String, Object?> record) =>
      DateTime.tryParse(record['date'] as String? ?? '') ?? DateTime(1970);

  Future<void> _addRecord() async {
    final record = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => const _AddHealthRecordDialog(),
    );
    if (record == null) return;
    final records = [..._records, record];
    await _save({..._data, 'healthRecords': records});
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

  String _consultationSummary() {
    final records = _records.take(5).toList();
    if (records.isEmpty) return 'No reports have been added yet.';
    return records
        .map((record) {
          final date = _date(record);
          final dateText =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          final summary = (record['summary'] as String?)?.trim() ?? '';
          final metrics = (record['parameters'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (parameter) =>
                    '${parameter['name']}: ${parameter['value']} ${parameter['unit']}'
                        .trim(),
              )
              .join(', ');
          return '$dateText · ${record['title']}\n${[summary, metrics].where((part) => part.isNotEmpty).join('\n')}';
        })
        .join('\n\n');
  }

  void _showGlossary() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          shrinkWrap: true,
          children: const [
            Text(
              'Common report terms',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 16),
            _GlossaryTerm(
              term: 'Blood pressure',
              explanation: 'A measurement of the force of blood against artery walls. A clinician can interpret it in your context.',
            ),
            _GlossaryTerm(
              term: 'Hemoglobin (Hb)',
              explanation: 'A protein in red blood cells that carries oxygen. Reference ranges depend on the lab and individual.',
            ),
            _GlossaryTerm(
              term: 'Fasting glucose',
              explanation: 'A blood sugar measurement taken after not eating for a period specified by your clinician or lab.',
            ),
            _GlossaryTerm(
              term: 'Reference range',
              explanation: 'A lab-provided interval for comparison; being outside it does not by itself establish a diagnosis.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copySummary() async {
    final summary = _consultationSummary();
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Consultation summary copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final records = _records;
    return Scaffold(
      appBar: AppBar(title: const Text('Health timeline')),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                const FeatureHeroIcon(
                  tag: 'Health timeline',
                  icon: Icons.monitor_heart_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your health, in one place.',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Add key information from your reports, compare recorded values, and take a summary to your doctor.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'This tool organizes information you enter. It does not extract uploaded files, diagnose conditions, or replace medical advice.',
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saving ? null : _addRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add report summary'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showGlossary,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Explain common terms'),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comparison',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _HealthComparison(records: records, date: _date),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reports',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${records.length}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final record in records)
                _HealthRecordCard(record: record, date: _date),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor consultation summary',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(_consultationSummary()),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _copySummary,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy summary'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 22),
              const _TimelineEmptyState(),
            ],
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _AddHealthRecordDialog extends StatefulWidget {
  const _AddHealthRecordDialog();

  @override
  State<_AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends State<_AddHealthRecordDialog> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _parameters = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _parameters.dispose();
    super.dispose();
  }

  Map<String, String> _parseParameter(String line) {
    final divider = line.indexOf(':');
    if (divider < 1) return {};
    final name = line.substring(0, divider).trim();
    final rawValue = line.substring(divider + 1).trim();
    final match = RegExp(r'^([-+]?[0-9]*\.?[0-9]+)\s*(.*)$')
        .firstMatch(rawValue);
    if (name.isEmpty || rawValue.isEmpty) return {};
    return {
      'name': name,
      'value': match?.group(1) ?? rawValue,
      'unit': match?.group(2)?.trim() ?? '',
    };
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a report name.');
      return;
    }
    final parameters = _parameters.text
        .split('\n')
        .map(_parseParameter)
        .where((parameter) => parameter.isNotEmpty)
        .toList();
    Navigator.pop(context, <String, Object?>{
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'summary': _summary.text.trim(),
      'parameters': parameters,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add report summary'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Report or test name',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summary,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes or findings'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _parameters,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Key values (one per line)',
                hintText: 'Hemoglobin: 13.2 g/dL\nHeart rate: 72 bpm',
                helperText:
                    'Use “Name: value unit”. Add only values from your report.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
      FilledButton(onPressed: _submit, child: const Text('Add to timeline')),
    ],
  );
}

class _HealthRecordCard extends StatelessWidget {
  const _HealthRecordCard({required this.record, required this.date});

  final Map<String, Object?> record;
  final DateTime Function(Map<String, Object?>) date;

  @override
  Widget build(BuildContext context) {
    final timestamp = date(record);
    final dateText = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    final parameters = (record['parameters'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record['title'] as String? ?? 'Health report',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  dateText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if ((record['summary'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(record['summary'] as String),
            ],
            for (final parameter in parameters)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${parameter['name']}: ${parameter['value']} ${parameter['unit']}'
                      .trim(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HealthComparison extends StatelessWidget {
  const _HealthComparison({required this.records, required this.date});

  final List<Map<String, Object?>> records;
  final DateTime Function(Map<String, Object?>) date;

  @override
  Widget build(BuildContext context) {
    final latest = records.first;
    final previous = records.skip(1).firstOrNull;
    final priorParameters = {
      for (final parameter
          in (previous?['parameters'] as List? ?? const []).whereType<Map>())
        parameter['name']: parameter,
    };
    final currentParameters = (latest['parameters'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final colors = Theme.of(context).colorScheme;
    if (currentParameters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Add key values to your reports to compare them over time.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    final previousDate = previous == null ? null : date(previous);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              previous == null
                  ? 'Latest recorded values'
                  : 'Latest and previous entry${previousDate == null ? '' : ' · ${previousDate.day}/${previousDate.month}/${previousDate.year}'}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final parameter in currentParameters)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('${parameter['name']}')),
                    Text(
                      '${parameter['value']} ${parameter['unit']}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (priorParameters[parameter['name']] case final prior?)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'was ${prior['value']} ${prior['unit']}'.trim(),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Text(
              'Values are shown as entered; a clinician should interpret any changes.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlossaryTerm extends StatelessWidget {
  const _GlossaryTerm({required this.term, required this.explanation});

  final String term;
  final String explanation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(term, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          explanation,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'Your timeline starts here',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Add a report summary and the key values you want to discuss with your doctor.',
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
        .map((entry) => {
          ...entry.$2,
          'id':
              entry.$2['id'] as String? ??
              'legacy-family-${entry.$1}',
        })
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
        {
          ...profile,
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
        },
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profiles = _profiles;
    return Scaffold(
      appBar: AppBar(title: const Text('Family guardian mode')),
      body: CenteredContent(
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
    );
  }
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
