import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class AppUser {
  const AppUser({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;

  factory AppUser.fromFirebase(firebase.User user) => AppUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
  );
}

abstract interface class AppAuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authChanges();
  Future<AppUser> signIn(String email, String password);
  Future<AppUser> register(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AppAuthRepository {
  FirebaseAuthRepository({firebase.FirebaseAuth? auth})
    : _auth = auth ?? firebase.FirebaseAuth.instance;

  final firebase.FirebaseAuth _auth;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromFirebase(user);
  }

  @override
  Stream<AppUser?> authChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : AppUser.fromFirebase(user),
  );

  @override
  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase returned no signed-in user.');
    return AppUser.fromFirebase(user);
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
    return AppUser.fromFirebase(updatedUser);
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
  Future<void> saveLabBooking(String uid, Map<String, Object?> data);
  Stream<List<Map<String, Object?>>> watchLabBookings(String uid);
  Stream<List<Map<String, Object?>>> watchLabResults(String uid);
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
    await _collection(
      uid,
      'appointments',
    ).add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Stream<List<Map<String, Object?>>> watchAppointments(String uid) =>
      _watch(_collection(uid, 'appointments'));

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
}
