import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.isDoctor = false,
    this.facilityId,
    this.facilityName,
    this.doctorName,
    this.roleResolved = true,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool isDoctor;
  final String? facilityId;
  final String? facilityName;
  final String? doctorName;
  final bool roleResolved;

  factory AppUser.fromFirebase(firebase.User user) => AppUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    roleResolved: false,
  );
}

abstract interface class AppAuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authChanges();
  Future<AppUser> signIn(String email, String password);
  Future<AppUser> signInDoctor(
    String email,
    String password,
    String inviteCode,
    String doctorName,
  );
  Future<AppUser> register(String name, String email, String password);
  Future<AppUser> registerDoctor(
    String name,
    String email,
    String password,
    String inviteCode,
  );
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AppAuthRepository {
  FirebaseAuthRepository({
    firebase.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? firebase.FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final firebase.FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  Completer<void>? _doctorEnrollment;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromFirebase(user);
  }

  @override
  Stream<AppUser?> authChanges() =>
      _auth.idTokenChanges().asyncMap((user) async {
        if (user == null) return null;
        final enrollment = _doctorEnrollment;
        if (enrollment != null) await enrollment.future;
        if (_auth.currentUser?.uid != user.uid) return null;
        return _resolveUser(user);
      });

  Future<AppUser> _resolveUser(
    firebase.User user, {
    bool forceTokenRefresh = false,
  }) async {
    final token = await user.getIdTokenResult(forceTokenRefresh);
    final claims = token.claims ?? const <String, Object?>{};
    final facilityId = claims['facilityId'];
    final isDoctor =
        claims['role'] == 'doctor' &&
        facilityId is String &&
        facilityId.trim().isNotEmpty;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      isDoctor: isDoctor,
      facilityId: isDoctor ? facilityId : null,
      facilityName: isDoctor && claims['facilityName'] is String
          ? claims['facilityName'] as String
          : null,
      doctorName: isDoctor && claims['doctorName'] is String
          ? claims['doctorName'] as String
          : null,
    );
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase returned no signed-in user.');
    return await _resolveUser(user, forceTokenRefresh: true);
  }

  @override
  Future<AppUser> signInDoctor(
    String email,
    String password,
    String inviteCode,
    String doctorName,
  ) async {
    final enrollment = _beginDoctorEnrollment();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase returned no signed-in user.');
      }

      final resolved = await _resolveUser(user, forceTokenRefresh: true);
      if (resolved.isDoctor) return resolved;
      if (inviteCode.trim().isEmpty) {
        await _auth.signOut();
        throw StateError(
          'Enter your clinic invite code to enroll this account as a doctor.',
        );
      }

      try {
        await _validateDoctorInvite(inviteCode);
        await _redeemDoctorInvite(
          inviteCode,
          doctorName.trim().isNotEmpty
              ? doctorName.trim()
              : user.displayName?.trim() ?? '',
        );
      } catch (_) {
        await _auth.signOut();
        rethrow;
      }

      return await _resolveUser(user, forceTokenRefresh: true);
    } finally {
      _endDoctorEnrollment(enrollment);
    }
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase returned no created user.');
    await user.updateDisplayName(name.trim());
    await user.reload();
    final updatedUser = _auth.currentUser;
    if (updatedUser == null) {
      throw StateError('The new account could not be loaded after creation.');
    }
    return _resolveUser(updatedUser);
  }

  @override
  Future<AppUser> registerDoctor(
    String name,
    String email,
    String password,
    String inviteCode,
  ) async {
    final enrollment = _beginDoctorEnrollment();
    firebase.User? createdUser;
    try {
      await _validateDoctorInvite(inviteCode);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase returned no created user.');
      }
      createdUser = user;
      await user.updateDisplayName(name.trim());
      await user.reload();

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw StateError('The new account could not be loaded.');
      }
      await _redeemDoctorInvite(inviteCode, name.trim());
      return await _resolveUser(currentUser, forceTokenRefresh: true);
    } catch (error) {
      if (createdUser != null && _auth.currentUser?.uid == createdUser.uid) {
        try {
          await createdUser.delete();
        } catch (cleanupError) {
          throw StateError(
            'Doctor enrollment failed and account cleanup could not complete: '
            '$cleanupError',
          );
        }
      }
      rethrow;
    } finally {
      _endDoctorEnrollment(enrollment);
    }
  }

  Completer<void> _beginDoctorEnrollment() {
    if (_doctorEnrollment != null) {
      throw StateError('Doctor enrollment is already in progress.');
    }
    return _doctorEnrollment = Completer<void>();
  }

  void _endDoctorEnrollment(Completer<void> enrollment) {
    if (identical(_doctorEnrollment, enrollment)) {
      _doctorEnrollment = null;
    }
    enrollment.complete();
  }

  Future<void> _validateDoctorInvite(String inviteCode) async {
    await _functions.httpsCallable('validateDoctorInvite').call<void>({
      'inviteCode': inviteCode.trim(),
    });
  }

  Future<void> _redeemDoctorInvite(String inviteCode, String doctorName) async {
    await _functions.httpsCallable('redeemDoctorInvite').call<void>({
      'inviteCode': inviteCode.trim(),
      'doctorName': doctorName,
    });
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signOut() => _auth.signOut();
}

abstract interface class AppDataRepository {
  Future<void> saveEmergencyAlert(
    String uid,
    String alertId,
    Map<String, Object?> data,
  );
  Future<void> saveAppointment(String uid, Map<String, Object?> data);
  Stream<List<Map<String, Object?>>> watchAppointments(String uid);
  Stream<List<Map<String, Object?>>> watchFacilityAppointments(
    String facilityId,
  );
  Future<void> reviewAppointment(String appointmentId, String status);
  Stream<List<Map<String, Object?>>> watchAvailability(String facilityId);
  Future<void> publishAvailability(
    String facilityId,
    Map<String, Object?> data,
  );
  Future<void> saveLabBooking(String uid, Map<String, Object?> data);
  Stream<List<Map<String, Object?>>> watchLabBookings(String uid);
  Stream<List<Map<String, Object?>>> watchLabResults(String uid);
  Future<String> summarizeLabResult(String uid, String resultId);
  Stream<Map<String, Object?>> watchProfileData(String uid);
  Future<void> saveProfileData(String uid, Map<String, Object?> data);
  Future<void> saveMessagingToken(String uid, String token);
  Future<void> removeMessagingToken(String uid, String token);
}

class FirestoreDataRepository implements AppDataRepository {
  FirestoreDataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String name,
  ) => _firestore.collection('users').doc(uid).collection(name);

  @override
  Future<void> saveEmergencyAlert(
    String uid,
    String alertId,
    Map<String, Object?> data,
  ) async {
    await _collection(
      uid,
      'alerts',
    ).doc(alertId).set({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> saveAppointment(String uid, Map<String, Object?> data) async {
    final appointment = _firestore.collection('appointments').doc();
    final payload = {
      ...data,
      'patientUid': uid,
      'status': 'requested',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch()
      ..set(appointment, payload)
      ..set(_collection(uid, 'appointments').doc(appointment.id), payload);
    await batch.commit();
  }

  @override
  Stream<List<Map<String, Object?>>> watchAppointments(String uid) =>
      _watch(_collection(uid, 'appointments'));

  @override
  Stream<List<Map<String, Object?>>> watchFacilityAppointments(
    String facilityId,
  ) => _watchQuery(
    _firestore
        .collection('appointments')
        .where('facilityId', isEqualTo: facilityId),
  );

  @override
  Future<void> reviewAppointment(String appointmentId, String status) async {
    await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('reviewAppointment')
        .call<void>({'appointmentId': appointmentId, 'status': status});
  }

  @override
  Stream<List<Map<String, Object?>>> watchAvailability(String facilityId) =>
      _watchQuery(
        _firestore
            .collection('facilities')
            .doc(facilityId)
            .collection('availability'),
      );

  @override
  Future<void> publishAvailability(
    String facilityId,
    Map<String, Object?> data,
  ) async {
    await _firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('availability')
        .add({
          ...data,
          'facilityId': facilityId,
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> saveLabBooking(String uid, Map<String, Object?> data) async {
    await _collection(
      uid,
      'labBookings',
    ).add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Stream<List<Map<String, Object?>>> watchLabBookings(String uid) =>
      _watch(_collection(uid, 'labBookings'));

  @override
  Stream<List<Map<String, Object?>>> watchLabResults(String uid) =>
      _watch(_collection(uid, 'labResults'));

  @override
  Future<String> summarizeLabResult(String uid, String resultId) async {
    final consentRef = _collection(uid, 'aiSummaryConsents').doc(resultId);
    await consentRef.set({
      'accepted': true,
      'version': '2026-01',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final response = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('summarizeLabResult')
        .call<Map<String, dynamic>>({'resultId': resultId, 'consent': true});
    final summary = response.data['summary'];
    if (summary is! String || summary.trim().isEmpty) {
      throw StateError('The AI service returned an empty summary.');
    }
    return summary;
  }

  @override
  Stream<Map<String, Object?>> watchProfileData(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data() ?? <String, Object?>{});

  @override
  Future<void> saveProfileData(String uid, Map<String, Object?> data) =>
      _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

  @override
  Future<void> saveMessagingToken(String uid, String token) => _firestore
      .collection('users')
      .doc(uid)
      .set({'fcmToken': token}, SetOptions(merge: true));

  @override
  Future<void> removeMessagingToken(String uid, String token) async {
    final user = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(user);
      if (snapshot.data()?['fcmToken'] == token) {
        transaction.update(user, {'fcmToken': FieldValue.delete()});
      }
    });
  }

  Stream<List<Map<String, Object?>>> _watch(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (document) => <String, Object?>{
                ...document.data(),
                'id': document.id,
              },
            )
            .toList(),
      );

  Stream<List<Map<String, Object?>>> _watchQuery(
    Query<Map<String, dynamic>> query,
  ) => query.snapshots().map(
    (snapshot) => snapshot.docs
        .map(
          (document) => <String, Object?>{
            ...document.data(),
            'id': document.id,
          },
        )
        .toList(),
  );
}
