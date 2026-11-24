import 'dart:async';
import 'dart:convert';

import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EmergencyPassportPage extends StatefulWidget {
  const EmergencyPassportPage({
    required this.user,
    required this.repository,
    this.legacyProfile = const {},
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;
  final Map<String, Object?> legacyProfile;

  @override
  State<EmergencyPassportPage> createState() => _EmergencyPassportPageState();
}

class _EmergencyPassportPageState extends State<EmergencyPassportPage> {
  StreamSubscription<Map<String, Object?>>? _subscription;
  Map<String, Object?> _passport = {};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _subscription = widget.repository
        .watchEmergencyPassport(widget.user.uid)
        .listen(
          (data) {
            if (!mounted) return;
            setState(() {
              _passport = {..._legacyPassport, ...data};
              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _loadError = _errorMessage(error, action: 'load');
            });
          },
        );
  }

  Map<String, Object?> get _legacyPassport => {
    'schemaVersion': 1,
    'bloodGroup': widget.legacyProfile['bloodGroup'] as String? ?? '',
    'heightCm': widget.legacyProfile['heightCm'] as String? ?? '',
    'weightKg': widget.legacyProfile['weightKg'] as String? ?? '',
    'allergies': widget.legacyProfile['allergies'] as String? ?? '',
    'conditions': widget.legacyProfile['conditions'] as String? ?? '',
    'medications': '',
    'emergencyContactName':
        widget.legacyProfile['emergencyContactName'] as String? ?? '',
    'emergencyContactPhone':
        widget.legacyProfile['emergencyContactPhone'] as String? ?? '',
    'emergencyContactRelationship': '',
    'preferredHospital': '',
    'qrConsentName': widget.legacyProfile['qrConsentName'] == true,
    'qrConsentBlood': widget.legacyProfile['qrConsentBlood'] == true,
    'qrConsentHeight': widget.legacyProfile['qrConsentHeight'] == true,
    'qrConsentWeight': widget.legacyProfile['qrConsentWeight'] == true,
    'qrConsentAllergies': widget.legacyProfile['qrConsentAllergies'] == true,
    'qrConsentConditions': widget.legacyProfile['qrConsentConditions'] == true,
    'qrConsentEmergencyContact':
        widget.legacyProfile['qrConsentEmergencyContact'] == true,
    'qrConsentMedications':
        widget.legacyProfile['qrConsentMedications'] == true,
    'qrConsentPreferredHospital':
        widget.legacyProfile['qrConsentPreferredHospital'] == true,
  };

  Map<String, String> get _qrProfile => {
    if (_passport['qrConsentName'] == true) 'name': _displayName,
    if (_passport['qrConsentBlood'] == true) 'bloodGroup': _value('bloodGroup'),
    if (_passport['qrConsentHeight'] == true) 'heightCm': _value('heightCm'),
    if (_passport['qrConsentWeight'] == true) 'weightKg': _value('weightKg'),
    if (_passport['qrConsentAllergies'] == true)
      'allergies': _value('allergies'),
    if (_passport['qrConsentConditions'] == true)
      'conditions': _value('conditions'),
    if (_passport['qrConsentMedications'] == true)
      'medications': _value('medications'),
    if (_passport['qrConsentPreferredHospital'] == true)
      'preferredHospital': _value('preferredHospital'),
    if (_passport['qrConsentEmergencyContact'] == true) ...{
      'emergencyContact': _value('emergencyContactName'),
      'emergencyRelationship': _value('emergencyContactRelationship'),
      'emergencyPhone': _value('emergencyContactPhone'),
    },
  }..removeWhere((key, value) => value == 'Not added' || value.trim().isEmpty);

  bool get _qrFits => utf8.encode(jsonEncode(_qrProfile)).length <= 1500;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _edit() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _PassportEditor(initialData: _passport),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated = {..._passport, ...result};
      await widget.repository.saveEmergencyPassport(widget.user.uid, updated);
      if (!mounted) return;
      setState(() => _passport = {...updated, 'updatedAt': DateTime.now()});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Emergency passport saved.')),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_errorMessage(error, action: 'save'))),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setQrConsent(String key, bool value) async {
    final updated = {..._passport, key: value};
    setState(() => _saving = true);
    try {
      await widget.repository.saveEmergencyPassport(widget.user.uid, updated);
      if (!mounted) return;
      setState(() => _passport = {...updated, 'updatedAt': DateTime.now()});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_errorMessage(error, action: 'save'))),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final qrProfile = _qrProfile;
    final qrData = qrProfile.isEmpty || !_qrFits ? '' : jsonEncode(qrProfile);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Passport 360'),
        actions: [
          IconButton(
            tooltip: 'Edit emergency passport',
            onPressed: _loading || _saving ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 820,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _LoadFailure(message: _loadError!, onRetry: _listen)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _PassportHeader(
                      name: _displayName,
                      updatedAt: _passport['updatedAt'],
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Critical information',
                      icon: Icons.emergency_outlined,
                      rows: [
                        _InfoRow(
                          label: 'Blood group',
                          value: _value('bloodGroup'),
                          note: 'Patient reported',
                        ),
                        _InfoRow(
                          label: 'Allergies',
                          value: _value('allergies'),
                        ),
                        _InfoRow(
                          label: 'Medical conditions',
                          value: _value('conditions'),
                        ),
                        _InfoRow(
                          label: 'Current medications',
                          value: _value('medications'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Personal measurements',
                      icon: Icons.straighten_outlined,
                      rows: [
                        _InfoRow(label: 'Height', value: _value('heightCm')),
                        _InfoRow(label: 'Weight', value: _value('weightKg')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Emergency contact',
                      icon: Icons.contact_phone_outlined,
                      rows: [
                        _InfoRow(
                          label: 'Name',
                          value: _value('emergencyContactName'),
                        ),
                        _InfoRow(
                          label: 'Relationship',
                          value: _value('emergencyContactRelationship'),
                        ),
                        _InfoRow(
                          label: 'Phone',
                          value: _value('emergencyContactPhone'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'Preferred hospital',
                      icon: Icons.local_hospital_outlined,
                      rows: [
                        _InfoRow(
                          label: 'Preference',
                          value: _value('preferredHospital'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _QrSharingCard(
                      name: _displayName,
                      data: qrData,
                      selectedCount: qrProfile.length,
                      saving: _saving,
                      consents: {
                        'qrConsentName': ('Name', 'name'),
                        'qrConsentBlood': ('Blood group', 'bloodGroup'),
                        'qrConsentHeight': ('Height', 'heightCm'),
                        'qrConsentWeight': ('Weight', 'weightKg'),
                        'qrConsentAllergies': ('Allergies', 'allergies'),
                        'qrConsentConditions': (
                          'Medical conditions',
                          'conditions',
                        ),
                        'qrConsentMedications': (
                          'Current medications',
                          'medications',
                        ),
                        'qrConsentEmergencyContact': (
                          'Emergency contact',
                          'emergencyContactPhone',
                        ),
                        'qrConsentPreferredHospital': (
                          'Preferred hospital',
                          'preferredHospital',
                        ),
                      },
                      isSelected: (key) => _passport[key] == true,
                      onChanged: _setQrConsent,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Update passport'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This information is self-reported and stored in your '
                      'signed-in account. It is not a medical record verified '
                      'by a clinician. Keep it current and share it only when '
                      'you choose.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String get _displayName =>
      widget.legacyProfile['displayName'] as String? ??
      widget.user.displayName?.trim() ??
      widget.user.email.split('@').first;

  String _value(String key) {
    final value = _passport[key];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'Not added';
  }

  String _errorMessage(Object error, {required String action}) {
    final details = error.toString();
    if (details.contains('permission-denied') ||
        details.contains('Missing or insufficient permissions')) {
      return 'Firebase denied access to your passport. Confirm the latest '
          'Firestore rules are deployed and that you are signed in, then retry.';
    }
    if (action == 'load') {
      return 'Your passport could not be loaded. Check your connection and '
          'try again. ($error)';
    }
    return 'Could not save your passport: $error';
  }
}

class _PassportHeader extends StatelessWidget {
  const _PassportHeader({required this.name, required this.updatedAt});

  final String name;
  final Object? updatedAt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final updated = _asDate(updatedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: const Icon(Icons.health_and_safety_outlined, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    updated == null
                        ? 'Keep essential details ready for care.'
                        : 'Last updated ${updated.day}/${updated.month}/${updated.year}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _asDate(Object? value) {
    if (value is DateTime) return value;
    try {
      final date = (value as dynamic).toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(width: 9),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              row,
              if (row != rows.last) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (note != null)
                Text(
                  note!,
                  style: TextStyle(
                    color: colors.tertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _QrSharingCard extends StatelessWidget {
  const _QrSharingCard({
    required this.name,
    required this.data,
    required this.selectedCount,
    required this.saving,
    required this.consents,
    required this.isSelected,
    required this.onChanged,
  });

  final String name;
  final String data;
  final int selectedCount;
  final bool saving;
  final Map<String, (String, String)> consents;
  final bool Function(String key) isSelected;
  final ValueChanged2<String, bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Emergency QR',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose which passport fields appear in the QR.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final entry in consents.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: isSelected(entry.key),
                onChanged: saving
                    ? null
                    : (value) => onChanged(entry.key, value ?? false),
                title: Text(entry.value.$1),
              ),
            if (saving) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Center(
              child: data.isNotEmpty
                  ? QrImageView(
                      data: data,
                      size: 210,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: colors.primary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF111827),
                      ),
                    )
                  : Icon(Icons.qr_code_2, size: 100, color: colors.outline),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                data.isNotEmpty
                    ? '$selectedCount selected detail(s) encoded for $name.'
                    : selectedCount > 0
                    ? 'The selected information is too long for one QR code. Shorten the details or select fewer fields.'
                    : 'Select at least one non-empty field to create a QR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anyone who scans this static QR can read and copy its contents. Changing these settings updates the QR shown here, but cannot erase copies already made.',
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

typedef ValueChanged2<T, V> = void Function(T value, V second);

class _PassportEditor extends StatefulWidget {
  const _PassportEditor({required this.initialData});

  final Map<String, Object?> initialData;

  @override
  State<_PassportEditor> createState() => _PassportEditorState();
}

class _PassportEditorState extends State<_PassportEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    'bloodGroup': TextEditingController(
      text: widget.initialData['bloodGroup'] as String? ?? '',
    ),
    'heightCm': TextEditingController(
      text: widget.initialData['heightCm'] as String? ?? '',
    ),
    'weightKg': TextEditingController(
      text: widget.initialData['weightKg'] as String? ?? '',
    ),
    'allergies': TextEditingController(
      text: widget.initialData['allergies'] as String? ?? '',
    ),
    'conditions': TextEditingController(
      text: widget.initialData['conditions'] as String? ?? '',
    ),
    'medications': TextEditingController(
      text: widget.initialData['medications'] as String? ?? '',
    ),
    'emergencyContactName': TextEditingController(
      text: widget.initialData['emergencyContactName'] as String? ?? '',
    ),
    'emergencyContactRelationship': TextEditingController(
      text: widget.initialData['emergencyContactRelationship'] as String? ?? '',
    ),
    'emergencyContactPhone': TextEditingController(
      text: widget.initialData['emergencyContactPhone'] as String? ?? '',
    ),
    'preferredHospital': TextEditingController(
      text: widget.initialData['preferredHospital'] as String? ?? '',
    ),
  };

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update emergency passport'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('bloodGroup', 'Blood group', maxLength: 8),
              _field('heightCm', 'Height (cm)', maxLength: 12),
              _field('weightKg', 'Weight (kg)', maxLength: 12),
              _field(
                'allergies',
                'Allergies',
                maxLength: 1000,
                maxLines: 2,
                hint: 'List known allergies or write “None known”.',
              ),
              _field(
                'conditions',
                'Medical conditions',
                maxLength: 1000,
                maxLines: 2,
              ),
              _field(
                'medications',
                'Current medications',
                maxLength: 2000,
                maxLines: 3,
                hint: 'Include strength and schedule if known.',
              ),
              _field(
                'emergencyContactName',
                'Emergency contact name',
                maxLength: 100,
              ),
              _field(
                'emergencyContactRelationship',
                'Relationship to you',
                maxLength: 60,
              ),
              _field(
                'emergencyContactPhone',
                'Emergency contact phone',
                maxLength: 32,
                keyboardType: TextInputType.phone,
              ),
              _field('preferredHospital', 'Preferred hospital'),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save passport')),
    ],
  );

  Widget _field(
    String key,
    String label, {
    int maxLength = 160,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) => (value?.length ?? 0) > maxLength
          ? 'Keep this under $maxLength characters.'
          : null,
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _fields['emergencyContactPhone']!.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^[+0-9() .-]{7,32}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid emergency phone number.')),
      );
      return;
    }
    Navigator.pop(context, {
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    });
  }
}
