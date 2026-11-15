import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/screens/profile_pages.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:flutter/material.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({
    required this.user,
    required this.authRepository,
    required this.repository,
    super.key,
  });

  final AppUser user;
  final AppAuthRepository authRepository;
  final AppDataRepository repository;

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class DoctorDemoPage extends StatefulWidget {
  const DoctorDemoPage({super.key});

  @override
  State<DoctorDemoPage> createState() => _DoctorDemoPageState();
}

class _DoctorDemoPageState extends State<DoctorDemoPage> {
  int _section = 0;
  final List<Map<String, String>> _requests = [
    {
      'id': 'sample-001',
      'patient': 'SAMPLE PATIENT 001',
      'visit': 'General consultation · Video',
      'time': 'Tomorrow · 10:30 AM',
      'status': 'Pending',
    },
    {
      'id': 'sample-002',
      'patient': 'SAMPLE PATIENT 002',
      'visit': 'Cardiology · In person',
      'time': 'Tomorrow · 12:00 PM',
      'status': 'Pending',
    },
  ];
  final List<String> _slots = ['Tomorrow · 10:30 AM', 'Tomorrow · 12:00 PM'];

  void _setRequestStatus(Map<String, String> request, String status) {
    setState(() => request['status'] = status);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo only — nothing was sent or saved.'),
      ),
    );
  }

  void _addSampleSlot() {
    setState(() => _slots.add('Tomorrow · ${_slots.length + 10}:00 AM'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample slot added in this demo only.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                avatar: Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: colors.tertiary,
                ),
                label: const Text('DEMO'),
              ),
            ),
          ),
        ],
      ),
      body: CenteredContent(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Explore the doctor workspace',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: colors.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: colors.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Everything below is synthetic sample data. Demo actions only change this temporary screen; no patient records are loaded, and nothing is sent to or saved for a real clinic.',
                        style: TextStyle(
                          color: colors.onTertiaryContainer,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.inbox_outlined),
                  label: Text('Sample requests'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Sample availability'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
            const SizedBox(height: 16),
            if (_section == 0)
              ..._requests.map(
                (request) => Card(
                  key: ValueKey(request['id']),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                request['patient']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StatusPill(status: request['status']!),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${request['visit']}\n${request['time']}'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: request['status'] == 'Pending'
                                  ? () => _setRequestStatus(
                                      request,
                                      'Approved · demo',
                                    )
                                  : null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Approve sample'),
                            ),
                            OutlinedButton.icon(
                              onPressed: request['status'] == 'Pending'
                                  ? () => _setRequestStatus(
                                      request,
                                      'Declined · demo',
                                    )
                                  : null,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Decline sample'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: _addSampleSlot,
                icon: const Icon(Icons.add),
                label: const Text('Add sample slot'),
              ),
              const SizedBox(height: 8),
              for (final slot in _slots)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.event_available_outlined,
                      color: colors.tertiary,
                    ),
                    title: Text(slot),
                    subtitle: const Text('DEMO ONLY · not bookable'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  static const _slots = ['09:00 AM', '10:30 AM', '12:00 PM', '02:30 PM'];

  int _section = 0;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _slot = _slots.first;
  String? _workingAppointment;
  bool _publishing = false;

  String get _facilityId => widget.user.facilityId!;

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _publishSlot() async {
    setState(() => _publishing = true);
    try {
      await widget.repository.publishAvailability(_facilityId, {
        'date': _dateKey(_date),
        'slot': _slot,
        'doctorUid': widget.user.uid,
        'doctorName': widget.user.doctorName ?? widget.user.displayName ?? '',
        'facilityName': widget.user.facilityName ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability added for patients.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish availability: $error')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _review(String appointmentId, String status) async {
    setState(() => _workingAppointment = appointmentId);
    try {
      await widget.repository.reviewAppointment(appointmentId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Appointment approved.'
                : 'Appointment declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review appointment: $error')),
      );
    } finally {
      if (mounted) setState(() => _workingAppointment = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final facility = widget.user.facilityName?.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor workspace'),
        actions: [
          IconButton(
            tooltip: 'Scan patient QR',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const HealthQrScannerPage(),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.authRepository.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: CenteredContent(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Welcome, ${widget.user.doctorName ?? widget.user.displayName ?? 'Doctor'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: colors.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facility == null || facility.isEmpty
                        ? 'Verified facility · ${widget.user.facilityId}'
                        : facility,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.inbox_outlined),
                  label: Text('Requests'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Availability'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _section == 0 ? _requests() : _availability(),
            ),
            const SizedBox(height: 18),
            Text(
              'Patient information is shown only for requests assigned to your verified facility. Review it in accordance with your clinic’s privacy procedures.',
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

  Widget _requests() => StreamBuilder<List<Map<String, Object?>>>(
    stream: widget.repository.watchFacilityAppointments(_facilityId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DoctorError(message: 'Could not load requests: ${snapshot.error}');
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final requests = (snapshot.data ?? const <Map<String, Object?>>[])
          .where((request) => request['status'] == 'requested')
          .toList();
      if (requests.isEmpty) {
        return const _DoctorEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No requests waiting',
          subtitle: 'New appointment requests for this facility will appear here.',
        );
      }
      return Column(
        children: requests.map((request) {
          final id = request['id'] as String? ?? '';
          final date = DateTime.tryParse(request['date'] as String? ?? '');
          final member = request['memberName'] as String?;
          final hospital = request['hospitalName'] as String?;
          final working = _workingAppointment == id;
          return Card(
            key: ValueKey(id),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.tertiary.withValues(alpha: .14),
                        foregroundColor: Theme.of(context).colorScheme.tertiary,
                        child: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          member?.trim().isNotEmpty == true
                              ? member!
                              : request['patient'] as String? ?? 'Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _StatusPill(status: 'requested'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${request['specialty'] ?? 'General'} · ${request['mode'] ?? 'In-person'}\n'
                    '${date == null ? request['date'] ?? 'Date not set' : _dateLabel(date)} · ${request['slot'] ?? 'Time not selected'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (hospital?.isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Facility: $hospital',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if ((request['reason'] as String? ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Reason: ${request['reason']}'),
                  ],
                  if (request['patientUid'] is String) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Contact the patient through your clinic workflow; contact details are not exposed in this request.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: working || id.isEmpty
                            ? null
                            : () => _review(id, 'approved'),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(working ? 'Updating…' : 'Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: working || id.isEmpty
                            ? null
                            : () => _review(id, 'declined'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );

  Widget _availability() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publish a visit slot',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patients can request only the availability you publish for this facility.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateLabel(_date)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _slots.map((slot) {
                    return ChoiceChip(
                      label: Text(slot),
                      selected: _slot == slot,
                      onSelected: (_) => setState(() => _slot = slot),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _publishing ? null : _publishSlot,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _publishing ? 'Publishing…' : 'Publish availability',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Published slots',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, Object?>>>(
          stream: widget.repository.watchAvailability(_facilityId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _DoctorError(
                message: 'Could not load availability: ${snapshot.error}',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final slots = (snapshot.data ?? const <Map<String, Object?>>[])
                .where((slot) => slot['status'] == 'available')
                .toList();
            if (slots.isEmpty) {
              return const _DoctorEmptyState(
                icon: Icons.event_available_outlined,
                title: 'No availability published',
                subtitle: 'Add a date and time for patients to request.',
              );
            }
            return Column(
              children: slots.map((slot) {
                final date = DateTime.tryParse(slot['date'] as String? ?? '');
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.event_available_outlined,
                      color: colors.tertiary,
                    ),
                    title: Text(
                      '${date == null ? slot['date'] ?? '' : _dateLabel(date)} · ${slot['slot'] ?? ''}',
                    ),
                    subtitle: Text(slot['doctorName'] as String? ?? ''),
                    trailing: const _StatusPill(status: 'available'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAvailable = status == 'available';
    final color = isAvailable ? colors.tertiary : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DoctorEmptyState extends StatelessWidget {
  const _DoctorEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.tertiary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

class _DoctorError extends StatelessWidget {
  const _DoctorError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
