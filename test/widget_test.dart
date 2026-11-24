import 'package:emergensy/main.dart';
import 'package:emergensy/services/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AppAuthRepository {
  String? registeredDoctorInviteCode;
  String? registeredPatientName;
  String? registeredPatientEmail;

  AppUser signedInUser = const AppUser(
    uid: 'test-user',
    email: 'test@example.com',
  );

  @override
  AppUser? get currentUser => signedInUser;

  @override
  Stream<AppUser?> authChanges() => Stream.value(signedInUser);

  @override
  Future<AppUser> register(String name, String email, String password) async {
    registeredPatientName = name;
    registeredPatientEmail = email;
    return AppUser(uid: 'test-user', email: email, displayName: name);
  }

  @override
  Future<AppUser> registerDoctor(
    String name,
    String email,
    String password,
    String inviteCode,
  ) async {
    registeredDoctorInviteCode = inviteCode;
    return AppUser(
      uid: 'doctor-user',
      email: email,
      displayName: name,
      isDoctor: true,
      facilityId: 'clinic-123',
    );
  }

  @override
  Future<AppUser> signIn(String email, String password) async => signedInUser;

  @override
  Future<AppUser> signInDoctor(
    String email,
    String password,
    String inviteCode,
    String doctorName,
  ) async => signedInUser;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeDataRepository implements AppDataRepository {
  final List<Map<String, Object?>> emergencyAlerts = [];
  final List<Map<String, Object?>> appointments = [];
  final List<Map<String, Object?>> availability = [];
  final List<Map<String, Object?>> labBookings = [];
  final List<Map<String, Object?>> reminders = [];
  Map<String, Object?> profileData = {};
  Map<String, Object?> passportData = {};
  bool passportLoadFails = false;
  bool passportSaveFails = false;

  @override
  Future<void> saveEmergencyAlert(
    String uid,
    String alertId,
    Map<String, Object?> data,
  ) async {
    emergencyAlerts.insert(0, {...data, 'id': alertId, 'uid': uid});
  }

  @override
  Future<void> saveAppointment(String uid, Map<String, Object?> data) async {
    appointments.insert(0, {...data});
  }

  @override
  Stream<List<Map<String, Object?>>> watchAppointments(String uid) =>
      Stream.value(appointments);
  @override
  Stream<List<Map<String, Object?>>> watchFacilityAppointments(
    String facilityId,
  ) => Stream.value(
    appointments
        .where((appointment) => appointment['facilityId'] == facilityId)
        .toList(),
  );

  @override
  Future<void> reviewAppointment(String appointmentId, String status) async {
    for (final appointment in appointments) {
      if (appointment['id'] == appointmentId) {
        appointment['status'] = status;
      }
    }
  }

  @override
  Stream<List<Map<String, Object?>>> watchAvailability(String facilityId) =>
      Stream.value(availability);

  @override
  Future<void> publishAvailability(
    String facilityId,
    Map<String, Object?> data,
  ) async {
    availability.add({...data, 'facilityId': facilityId});
  }

  @override
  Future<void> saveLabBooking(String uid, Map<String, Object?> data) async {
    labBookings.insert(0, {...data});
  }

  @override
  Future<void> saveReminder(String uid, Map<String, Object?> data) async {
    reminders.insert(0, {...data});
  }

  @override
  Stream<List<Map<String, Object?>>> watchReminders(String uid) =>
      Stream.value(reminders);

  @override
  Stream<List<Map<String, Object?>>> watchLabBookings(String uid) =>
      Stream.value(labBookings);

  @override
  Stream<List<Map<String, Object?>>> watchLabResults(String uid) =>
      Stream.value(const []);

  @override
  Future<String> summarizeLabResult(String uid, String resultId) async =>
      'Summary for $resultId';

  @override
  Stream<Map<String, Object?>> watchProfileData(String uid) =>
      Stream.value(profileData);

  @override
  Future<void> saveProfileData(String uid, Map<String, Object?> data) async {
    profileData = {...profileData, ...data};
    const passportKeys = [
      'bloodGroup',
      'heightCm',
      'weightKg',
      'allergies',
      'conditions',
      'emergencyContactName',
      'emergencyContactPhone',
      'qrConsentName',
      'qrConsentBlood',
      'qrConsentHeight',
      'qrConsentWeight',
      'qrConsentAllergies',
      'qrConsentConditions',
      'qrConsentEmergencyContact',
      'qrConsentMedications',
      'qrConsentPreferredHospital',
    ];
    if (data.keys.any(passportKeys.contains)) {
      passportData = {
        ...passportData,
        for (final key in passportKeys)
          if (data[key] is String || data[key] is bool) key: data[key],
      };
    }
  }

  @override
  Stream<Map<String, Object?>> watchEmergencyPassport(String uid) =>
      passportLoadFails
      ? Stream.error(StateError('cloud_firestore/permission-denied'))
      : Stream.value(passportData);

  @override
  Future<void> saveEmergencyPassport(
    String uid,
    Map<String, Object?> passport,
  ) async {
    if (passportSaveFails) throw StateError('simulated write failure');
    passportData = {...passport};
    for (final key in [
      'bloodGroup',
      'heightCm',
      'weightKg',
      'allergies',
      'conditions',
      'emergencyContactName',
      'emergencyContactPhone',
      'qrConsentName',
      'qrConsentBlood',
      'qrConsentHeight',
      'qrConsentWeight',
      'qrConsentAllergies',
      'qrConsentConditions',
      'qrConsentEmergencyContact',
      'qrConsentMedications',
      'qrConsentPreferredHospital',
    ]) {
      if (passport[key] is String || passport[key] is bool) {
        profileData[key] = passport[key];
      }
    }
  }

  @override
  Future<void> saveMessagingToken(String uid, String token) async {
    profileData['fcmToken'] = token;
  }

  @override
  Future<void> removeMessagingToken(String uid, String token) async {
    if (profileData['fcmToken'] == token) profileData.remove('fcmToken');
  }
}

void main() {
  final authRepository = _FakeAuthRepository();
  final dataRepository = _FakeDataRepository();

  Future<void> pumpApp(WidgetTester tester, {bool disableAnimations = true}) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: disableAnimations);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    return tester.pumpWidget(
      MyApp(authRepository: authRepository, dataRepository: dataRepository),
    );
  }

  Future<void> tapText(WidgetTester tester, String title) async {
    final target = find.text(title);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapHomeFeature(WidgetTester tester, String title) async {
    final target = find.text(title);
    for (var attempt = 0; target.evaluate().isEmpty && attempt < 8; attempt++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tapText(tester, title);
  }

  testWidgets('dark home presents the emergency and section buttons', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      Theme.of(tester.element(find.byType(AppShell))).brightness,
      Brightness.dark,
    );
    expect(
      find.text('Location shared only when you request help'),
      findsOneWidget,
    );
    expect(find.text('Your next step, made clear.'), findsOneWidget);
    expect(find.text('Call India’s emergency number 112'), findsOneWidget);
    expect(find.text('PREPARE SOS DETAILS'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('First-aid guide'), findsOneWidget);
    expect(find.text('Health essentials'), findsOneWidget);
    expect(find.text('Health news'), findsOneWidget);
    expect(find.text('Doctor appointments'), findsOneWidget);
    expect(find.text('Lab tests'), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);
  });

  testWidgets('SOS dashboard renders with motion enabled', (tester) async {
    await pumpApp(tester, disableAnimations: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PREPARE SOS DETAILS'), findsOneWidget);
    expect(find.text('Call India’s emergency number 112'), findsOneWidget);
  });

  testWidgets('home features use a two-column grid on phone screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('home opens the voice assistant', (tester) async {
    await pumpApp(tester);

    await tapHomeFeature(tester, 'Voice assistant');

    expect(find.text('Voice assistant'), findsOneWidget);
    expect(find.text('Tap to start talking'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Voice and AI processing'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to start talking'), findsOneWidget);
  });

  testWidgets('bottom navigation opens appointments and resets on return', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Appointments').last);
    await tester.pumpAndSettle();
    expect(find.text('Talk to a doctor.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('dashboard navigation fits a narrow phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified doctor custom claim opens doctor workspace', (
    tester,
  ) async {
    final previousUser = authRepository.signedInUser;
    authRepository.signedInUser = const AppUser(
      uid: 'verified-doctor',
      email: 'doctor@example.com',
      isDoctor: true,
      facilityId: 'clinic-123',
      facilityName: 'North Clinic',
      doctorName: 'Dr. Example',
    );
    addTearDown(() => authRepository.signedInUser = previousUser);

    await pumpApp(tester);

    expect(find.text('Doctor workspace'), findsOneWidget);
    expect(find.text('North Clinic'), findsOneWidget);
    expect(find.text('Welcome, Dr. Example'), findsOneWidget);
  });

  testWidgets('112 call action is available before signing in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SignInPage(authRepository: authRepository)),
    );

    expect(find.text('Call 112 now'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('patient registration submits name and email to auth backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SignInPage(authRepository: authRepository)),
    );
    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Create an account for your care details.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), 'Sam Example');
    await tester.enterText(find.byType(TextField).at(1), 'sam@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'safe-password');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(authRepository.registeredPatientName, 'Sam Example');
    expect(authRepository.registeredPatientEmail, 'sam@example.com');
  });

  testWidgets('emergency passport loads, saves and labels self-reported data', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Emergency Passport 360');

    expect(find.text('Emergency Passport 360'), findsOneWidget);
    expect(find.text('Patient reported'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit emergency passport'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Blood group'),
      'O+',
    );
    await tester.tap(find.text('Save passport'));
    await tester.pumpAndSettle();

    expect(dataRepository.passportData['bloodGroup'], 'O+');
    expect(dataRepository.profileData['bloodGroup'], 'O+');
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Emergency passport saved.'), findsOneWidget);
  });

  testWidgets('emergency passport shows load failure and retry state', (
    tester,
  ) async {
    dataRepository.passportLoadFails = true;
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Emergency Passport 360');

    expect(find.textContaining('Firestore rules are deployed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    dataRepository.passportLoadFails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Blood group'), findsOneWidget);
    dataRepository.passportLoadFails = false;
  });

  testWidgets('emergency passport keeps edits local when save fails', (
    tester,
  ) async {
    final savedBefore = Map<String, Object?>.from(dataRepository.passportData);
    dataRepository.passportSaveFails = true;
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Emergency Passport 360');
    await tester.tap(find.byTooltip('Edit emergency passport'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Blood group'),
      'AB+',
    );
    await tester.tap(find.text('Save passport'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save your passport'), findsOneWidget);
    expect(dataRepository.passportData, savedBefore);
    dataRepository.passportSaveFails = false;
  });

  testWidgets('doctor demo uses synthetic data without backend writes', (
    tester,
  ) async {
    final appointmentCount = dataRepository.appointments.length;
    await tester.pumpWidget(
      MaterialApp(home: SignInPage(authRepository: authRepository)),
    );

    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();
    expect(find.text('Try doctor demo'), findsOneWidget);
    await tapText(tester, 'Try doctor demo');

    expect(find.text('Doctor demo'), findsOneWidget);
    expect(find.text('SAMPLE PATIENT 001'), findsOneWidget);
    expect(
      find.textContaining('Everything below is synthetic sample data'),
      findsOneWidget,
    );
    await tester.tap(find.text('Approve sample').first);
    await tester.pumpAndSettle();

    expect(find.text('Approved · demo'), findsOneWidget);
    expect(dataRepository.appointments, hasLength(appointmentCount));
  });

  testWidgets('doctor registration requires and submits a clinic invite code', (
    tester,
  ) async {
    authRepository.registeredDoctorInviteCode = null;
    await tester.pumpWidget(
      MaterialApp(home: SignInPage(authRepository: authRepository)),
    );

    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();
    await tapText(tester, 'New doctor? Create an account');
    expect(find.text('Clinic invite code'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Dr. Example');
    await tester.enterText(fields.at(1), 'NorthClinic-Invite-2026');
    await tester.enterText(fields.at(2), 'doctor@example.com');
    await tester.enterText(fields.at(3), 'secure-password');
    await tapText(tester, 'Create account');

    expect(
      authRepository.registeredDoctorInviteCode,
      'NorthClinic-Invite-2026',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('emergency request captures reason and manual location', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('PREPARE SOS DETAILS'));
    await tester.pumpAndSettle();

    expect(find.text('What happened?'), findsOneWidget);
    expect(find.textContaining('cannot alert an ambulance'), findsOneWidget);
    await tester.tap(find.text('Severe bleeding'));
    await tester.enterText(find.byType(TextField).last, '12 Main Street, Pune');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show immediate safety steps'));
    await tester.pumpAndSettle();

    expect(find.text('Call 112 now'), findsOneWidget);
    expect(find.text('Severe bleeding'), findsOneWidget);
    expect(find.text('12 Main Street, Pune'), findsOneWidget);
    expect(
      find.textContaining('SOS details saved to your account'),
      findsOneWidget,
    );
    expect(dataRepository.emergencyAlerts, hasLength(1));
    expect(dataRepository.emergencyAlerts.single['type'], 'Critical');
    expect(
      dataRepository.emergencyAlerts.single['location'],
      '12 Main Street, Pune',
    );
    expect(dataRepository.emergencyAlerts.single['status'], 'prepared');
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Press firmly on the wound'), findsOneWidget);
  });

  testWidgets('saved emergency contact is available during guidance', (
    tester,
  ) async {
    final previousProfile = dataRepository.profileData;
    dataRepository.profileData = {
      ...previousProfile,
      'emergencyContactName': 'Asha',
      'emergencyContactPhone': '+911234567890',
    };
    addTearDown(() => dataRepository.profileData = previousProfile);

    await pumpApp(tester);
    await tester.tap(find.text('PREPARE SOS DETAILS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Severe bleeding'));
    await tester.enterText(find.byType(TextField).last, '12 Main Street, Pune');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show immediate safety steps'));
    await tester.pumpAndSettle();

    expect(find.text('Call 112 now'), findsOneWidget);
    expect(find.text('Call Asha'), findsOneWidget);
  });

  testWidgets('shop allows adding an item to the cart', (tester) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Health essentials');

    expect(find.text('Health essentials'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('₹89'), findsNWidgets(2));
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Health essentials'), findsOneWidget);
  });

  testWidgets('first aid tab shows safety guidance', (tester) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'First-aid guide');

    expect(find.text('Simple guidance for common situations'), findsOneWidget);
    expect(find.text('Minor bleeding'), findsOneWidget);
    expect(find.text('Minor burns'), findsOneWidget);
  });

  testWidgets('news tab explains when the news backend is unavailable', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Health news');

    expect(find.text('Health news'), findsOneWidget);
    expect(find.text('Headlines unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('in-person booking requires a clinic and online requests save', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tapHomeFeature(tester, 'Doctor appointments');

    expect(find.text('Talk to a doctor.'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('In person'), findsOneWidget);
    await tester.tap(find.text('In person'));
    await tester.enterText(find.byType(TextField).first, 'Sam Example');
    await tester.enterText(find.byType(TextField).last, 'Pune');
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book appointment'));
    await tester.pumpAndSettle();
    expect(find.text('My requests'), findsNothing);
    expect(
      find.text(
        'Choose a nearby hospital or clinic from the map for an in-person request.',
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book appointment'));
    await tester.pumpAndSettle();

    expect(find.text('My requests'), findsOneWidget);
    expect(find.text('Dr. Asha Mehta'), findsOneWidget);
    expect(find.text('requested'), findsOneWidget);
    expect(find.textContaining('Online requests stay'), findsOneWidget);
  });

  testWidgets('hospital homepage card opens offline booking with map option', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Hospitals & offline visits');

    expect(find.text('Doctor appointments'), findsOneWidget);
    expect(find.text('Choose a nearby hospital or clinic'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hospitals & offline visits'), findsOneWidget);
  });

  testWidgets('lab test request is stored and displayed in results', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tapHomeFeature(tester, 'Lab tests');

    expect(find.text('Book a lab test.'), findsOneWidget);
    await tester.tap(find.text('Blood glucose — fasting'));
    await tester.enterText(find.byType(TextField).first, 'Sam Example');
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book 1 test(s)'));
    await tester.pumpAndSettle();

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('1 test(s) · Sam Example'), findsOneWidget);
    expect(find.text('requested'), findsOneWidget);
    expect(find.textContaining('Not yet sent to a lab'), findsOneWidget);
  });

  testWidgets('passport unifies details and consented QR controls', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Profile & settings');

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Dark mode'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Dark mode'))).brightness,
      Brightness.light,
    );
    expect(dataRepository.profileData['darkMode'], isFalse);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Dark mode'))).brightness,
      Brightness.dark,
    );
    expect(dataRepository.profileData['darkMode'], isTrue);

    await tester.drag(find.byType(ListView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Sam Example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emergency Passport 360'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Passport 360'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Emergency QR'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit emergency passport'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Blood group'),
      'A+',
    );
    await tester.tap(find.text('Save passport'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select at least one non-empty field to create a QR.'),
      findsOneWidget,
    );
    expect(dataRepository.passportData['bloodGroup'], 'A+');
    final nameConsent = find.widgetWithText(CheckboxListTile, 'Name');
    await tester.ensureVisible(nameConsent);
    await tester.tap(nameConsent);
    await tester.pumpAndSettle();
    final bloodConsent = find.widgetWithText(CheckboxListTile, 'Blood group');
    await tester.ensureVisible(bloodConsent);
    await tester.tap(bloodConsent);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 selected detail(s) encoded'), findsOneWidget);
    expect(dataRepository.passportData['qrConsentName'], isTrue);
    expect(dataRepository.passportData['qrConsentBlood'], isTrue);
    expect(dataRepository.profileData['qrConsentName'], isTrue);
    expect(dataRepository.profileData['qrConsentBlood'], isTrue);
    expect(dataRepository.passportData['bloodGroup'], 'A+');
  });

  testWidgets('health timeline adds a report and consultation summary', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Profile & settings');
    await tapText(tester, 'Health timeline');
    await tester.tap(find.text('Add report summary'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Blood test');
    await tester.enterText(find.byType(TextField).at(1), 'Routine check');
    await tester.enterText(
      find.byType(TextField).at(2),
      'Hemoglobin: 13.2 g/dL',
    );
    await tester.tap(find.text('Add to timeline'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Blood test'), findsOneWidget);
    expect(find.text('Hemoglobin: 13.2 g/dL'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Doctor consultation summary'), findsOneWidget);
    expect(dataRepository.profileData['healthRecords'], hasLength(1));
  });

  testWidgets('family profile requires authorization before it can be added', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapHomeFeature(tester, 'Profile & settings');
    await tapText(tester, 'Family guardian mode');
    await tester.tap(find.text('Add family profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Asha Example');
    await tester.enterText(find.byType(TextField).at(1), 'Parent');
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Confirm you have their permission first.'),
      findsOneWidget,
    );
    await tester.tap(
      find.text('I have their permission to manage this profile.'),
    );
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();

    expect(find.text('Asha Example'), findsOneWidget);
    expect(dataRepository.profileData['familyProfiles'], hasLength(1));
    await tapText(tester, 'Add medicine reminder');
    await tester.enterText(find.byType(TextField).at(0), 'Daily medicine');
    await tester.enterText(find.byType(TextField).at(1), '1 tablet');
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Daily medicine'), findsOneWidget);
    expect(
      ((dataRepository.profileData['familyProfiles'] as List).single
          as Map)['medicationReminders'],
      hasLength(1),
    );
    expect(find.text('Book appointment'), findsOneWidget);
    await tester.tap(find.text('Book appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Booking for'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Asha Example',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book appointment'));
    await tester.pumpAndSettle();
    expect(dataRepository.appointments.first['memberName'], 'Asha Example');
    expect(
      dataRepository.appointments.first['memberId'],
      (dataRepository.profileData['familyProfiles'] as List).single['id'],
    );
  });
}
