import 'package:emergensy/main.dart';
import 'package:emergensy/services/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AppAuthRepository {
  @override
  AppUser? get currentUser =>
      const AppUser(uid: 'test-user', email: 'test@example.com');

  @override
  Stream<AppUser?> authChanges() => Stream.value(currentUser);

  @override
  Future<AppUser> register(String name, String email, String password) async =>
      AppUser(uid: 'test-user', email: email, displayName: name);

  @override
  Future<AppUser> signIn(String email, String password) async =>
      AppUser(uid: 'test-user', email: email);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeDataRepository implements AppDataRepository {
  final List<Map<String, Object?>> emergencyAlerts = [];
  final List<Map<String, Object?>> appointments = [];
  final List<Map<String, Object?>> labBookings = [];

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
  Future<void> saveLabBooking(String uid, Map<String, Object?> data) async {
    labBookings.insert(0, {...data});
  }

  @override
  Stream<List<Map<String, Object?>>> watchLabBookings(String uid) =>
      Stream.value(labBookings);

  @override
  Stream<List<Map<String, Object?>>> watchLabResults(String uid) =>
      Stream.value(const []);
}

void main() {
  final authRepository = _FakeAuthRepository();
  final dataRepository = _FakeDataRepository();

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MyApp(authRepository: authRepository, dataRepository: dataRepository),
  );

  testWidgets('dark home presents the emergency and section buttons', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      Theme.of(tester.element(find.byType(AppShell))).brightness,
      Brightness.dark,
    );
    expect(find.text('WHEN IT\nMATTERS.'), findsOneWidget);
    expect(find.text('Get help'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('First-aid guide'), findsOneWidget);
    expect(find.text('Health essentials'), findsOneWidget);
    expect(find.text('Health news'), findsOneWidget);
    expect(find.text('Doctor appointments'), findsOneWidget);
    expect(find.text('Lab tests & results'), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);
  });

  testWidgets('emergency request captures reason and manual location', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get help'));
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
    expect(find.textContaining('SOS details saved to your account'), findsOneWidget);
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

  testWidgets('shop allows adding an item to the cart', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();

    expect(find.text('Health essentials'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pump();

    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('₹89'), findsNWidgets(2));
  });

  testWidgets('first aid tab shows safety guidance', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('First aid').last);
    await tester.pumpAndSettle();

    expect(find.text('Simple guidance for common situations'), findsOneWidget);
    expect(find.text('Minor bleeding'), findsOneWidget);
    expect(find.text('Minor burns'), findsOneWidget);
  });

  testWidgets('news tab explains when the news backend is unavailable', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();

    expect(find.text('Health news'), findsOneWidget);
    expect(find.text('Headlines unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('doctor appointment request can be reviewed', (tester) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doctor appointments'));
    await tester.pumpAndSettle();

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

    expect(find.text('My requests'), findsOneWidget);
    expect(find.text('Dr. Asha Mehta'), findsOneWidget);
    expect(find.text('requested'), findsOneWidget);
    expect(find.textContaining('not sent to a clinic'), findsOneWidget);
    expect(find.textContaining('Area: Pune'), findsOneWidget);
  });

  testWidgets('lab test request is stored and displayed in results', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab tests & results'));
    await tester.pumpAndSettle();

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
}
