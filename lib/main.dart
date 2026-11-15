import 'dart:async';
import 'dart:convert';

import 'package:emergensy/firebase_options.dart';
import 'package:emergensy/screens/hospital_map_page.dart';
import 'package:emergensy/screens/doctor_dashboard.dart';
import 'package:emergensy/screens/profile_pages.dart';
import 'package:emergensy/screens/voice_assistant_page.dart';
import 'package:emergensy/services/app_backend.dart';
import 'package:emergensy/services/hospital_search_service.dart';
import 'package:emergensy/theme/app_theme.dart';
import 'package:emergensy/widgets/centered_content.dart';
import 'package:emergensy/widgets/feature_hero_icon.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

final ValueNotifier<bool> _darkMode = ValueNotifier<bool>(true);

AppPalette get _palette => _darkMode.value ? AppPalette.dark : AppPalette.light;
Color get _ink => _palette.ink;
Color get _teal => _palette.primary;
Color get _surface => _palette.surface;
Color get _surfaceRaised => _palette.raisedSurface;
Color get _muted => _palette.muted;
Color get _border => _palette.border;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? backendError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheck();
  } catch (error) {
    backendError = error;
  }
  runApp(MyApp(backendError: backendError));
}

Future<void> _activateAppCheck() async {
  if (kIsWeb) {
    if (kDebugMode) {
      await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
      return;
    }
    const siteKey = String.fromEnvironment(
      'APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
    );
    if (siteKey.isEmpty) {
      throw StateError(
        'Set APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY for production web builds.',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(siteKey),
    );
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseAppCheck.instance.activate(
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    this.authRepository,
    this.dataRepository,
    this.backendError,
    super.key,
  });

  final AppAuthRepository? authRepository;
  final AppDataRepository? dataRepository;
  final Object? backendError;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _darkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Emergensy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: backendError != null
              ? _FirebaseStartupError(error: backendError!)
              : AuthGate(
                  authRepository: authRepository ?? FirebaseAuthRepository(),
                  dataRepository: dataRepository ?? FirestoreDataRepository(),
                ),
        );
      },
    );
  }
}

class _FirebaseStartupError extends StatelessWidget {
  const _FirebaseStartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: _teal, size: 42),
            const SizedBox(height: 14),
            Text(
              'Could not connect to Firebase',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthWelcomeBanner extends StatelessWidget {
  const _AuthWelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      height: 118,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -54,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.onPrimary.withValues(alpha: .14),
                  width: 22,
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .72, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 720),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                Icons.health_and_safety_rounded,
                size: 78,
                color: colors.onPrimary.withValues(alpha: .9),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 90, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CARE THAT MEETS YOU HERE',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: .82),
                    fontSize: 9,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Your next step starts with a little hello.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 19,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
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

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authRepository,
    required this.dataRepository,
    super.key,
  });

  final AppAuthRepository authRepository;
  final AppDataRepository dataRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authRepository.authChanges(),
      initialData: authRepository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FirebaseStartupError(error: snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return SignInPage(authRepository: authRepository);
        }
        if (!user.roleResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user.isDoctor) {
          return DoctorDashboardPage(
            user: user,
            authRepository: authRepository,
            repository: dataRepository,
          );
        }
        return AppShell(
          user: user,
          authRepository: authRepository,
          dataRepository: dataRepository,
        );
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({required this.authRepository, super.key});

  final AppAuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _doctorInviteCodeController = TextEditingController();
  bool _registering = false;
  bool _doctorMode = false;
  bool _working = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _doctorInviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_registering && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name to create an account.');
      return;
    }
    if (_registering &&
        _doctorMode &&
        _doctorInviteCodeController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your clinic invite code to continue.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (_registering) {
        if (_doctorMode) {
          await widget.authRepository.registerDoctor(
            _nameController.text,
            email,
            password,
            _doctorInviteCodeController.text,
          );
        } else {
          await widget.authRepository.register(
            _nameController.text,
            email,
            password,
          );
        }
      } else {
        final user = _doctorMode
            ? await widget.authRepository.signInDoctor(
                email,
                password,
                _doctorInviteCodeController.text,
                _nameController.text,
              )
            : await widget.authRepository.signIn(email, password);
        if (user.isDoctor != _doctorMode) {
          await widget.authRepository.signOut();
          if (mounted) {
            setState(() {
              _error = _doctorMode
                  ? 'This account is not enrolled with a clinic. Enter a valid clinic invite code.'
                  : 'This account is verified as a doctor. Choose Doctor sign in.';
            });
          }
          return;
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first to reset your password.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.authRepository.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _openDoctorDemo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const DoctorDemoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: .08),
                      blurRadius: 38,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 24),
                    const _AuthWelcomeBanner(),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.person_outline),
                          label: Text('Patient'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.medical_services_outlined),
                          label: Text('Doctor'),
                        ),
                      ],
                      selected: {_doctorMode},
                      onSelectionChanged: _working
                          ? null
                          : (selection) => setState(() {
                              _doctorMode = selection.first;
                              _registering = false;
                              _error = null;
                            }),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _registering
                          ? _doctorMode
                                ? 'Join your clinic.'
                                : 'Start here.'
                          : _doctorMode
                          ? 'Doctor sign in.'
                          : 'Good to see you.',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _registering
                          ? _doctorMode
                                ? 'Create a doctor account using your clinic’s invite code.'
                                : 'Create an account for your care details.'
                          : _doctorMode
                          ? 'Sign in, or enroll with the invite code from your clinic.'
                          : 'Sign in to access your appointments and lab bookings.',
                      style: TextStyle(color: _muted, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    if (_registering || _doctorMode) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: _registering
                              ? 'Full name'
                              : 'Doctor name (for enrollment)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_doctorMode) ...[
                      TextField(
                        controller: _doctorInviteCodeController,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Clinic invite code',
                          helperText:
                              'Use the active code provided by your clinic.',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        _registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _working ? null : _submit,
                        child: _working
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_registering ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    if (_doctorMode && !_registering) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : _openDoctorDemo,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Try doctor demo'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Synthetic records only · no clinic or patient access',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                    if (!_registering)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _working ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    Center(
                      child: TextButton(
                        onPressed: _working
                            ? null
                            : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              }),
                        child: Text(
                          _registering
                              ? 'Already have an account? Sign in'
                              : _doctorMode
                              ? 'New doctor? Create an account'
                              : 'New here? Create an account',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _DemoServiceNotice(
                      text:
                          'Your health and booking information is stored under your Firebase account. '
                          'Use a password you do not use elsewhere.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Wait a bit and try again.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => 'Authentication failed: ${error.message ?? error.code}',
    };
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'permission-denied' => 'That clinic invite code is invalid or inactive. Ask your clinic for its current code.',
      'failed-precondition' =>
        error.message ?? 'This account cannot be enrolled with that clinic.',
      'unauthenticated' => 'Sign in again and retry clinic enrollment.',
      'unavailable' =>
        'Clinic enrollment is temporarily unavailable. Try again.',
      _ => 'Clinic enrollment failed: ${error.message ?? error.code}',
    };
  }
  if (error is StateError) return error.message.toString();
  return 'Authentication failed: $error';
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.user,
    required this.authRepository,
    required this.dataRepository,
    super.key,
  });

  final AppUser user;
  final AppAuthRepository authRepository;
  final AppDataRepository dataRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<ShopProduct> _cart = [];
  StreamSubscription<Map<String, Object?>>? _profileSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Map<String, Object?> _profileData = {};
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.dataRepository is FirestoreDataRepository) {
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('A new lab result is ready to review.'),
              action: SnackBarAction(
                label: 'View reports',
                onPressed: () => _openLabs(initialSection: 1),
              ),
            ),
          );
      });
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _saveMessagingToken,
        onError: (Object error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not update notification setup: $error'),
            ),
          );
        },
      );
      unawaited(_registerMessaging());
    }
    _profileSubscription = widget.dataRepository
        .watchProfileData(widget.user.uid)
        .listen(
          (data) {
            if (!mounted) return;
            setState(() => _profileData = data);
            final savedDarkMode = data['darkMode'];
            if (savedDarkMode is bool && savedDarkMode != _darkMode.value) {
              _darkMode.value = savedDarkMode;
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to load your profile: $error')),
            );
          },
        );
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _messageSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _registerMessaging() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveMessagingToken(token);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Push notifications are unavailable: $error')),
      );
    }
  }

  Future<void> _saveMessagingToken(String token) async {
    try {
      await widget.dataRepository.saveMessagingToken(widget.user.uid, token);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not register result notifications: $error'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    if (!kIsWeb && widget.dataRepository is FirestoreDataRepository) {
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await widget.dataRepository.removeMessagingToken(
            widget.user.uid,
            token,
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not clear result notifications: $error'),
            ),
          );
        }
      }
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not disable push notifications: $error'),
            ),
          );
        }
      }
    }
    await widget.authRepository.signOut();
  }

  Future<bool> _saveProfileData(Map<String, Object?> data) async {
    try {
      await widget.dataRepository.saveProfileData(widget.user.uid, data);
      if (mounted) {
        setState(() => _profileData = {..._profileData, ...data});
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save profile details: $error')),
        );
      }
      return false;
    }
  }

  void _setDarkMode(bool enabled) {
    _darkMode.value = enabled;
    unawaited(_saveProfileData({'darkMode': enabled}));
  }

  void _addToCart(ShopProduct product) {
    setState(() => _cart.add(product));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${product.name} added to cart')));
  }

  Future<void> _pushPage(Widget child) async {
    await Navigator.of(context).push<void>(_PageRoute<void>(child: child));
    if (mounted && _selectedDestination != 0) {
      setState(() => _selectedDestination = 0);
    }
  }

  Future<void> _launchEmergency() async {
    setState(() => _selectedDestination = 1);
    await Navigator.of(context).push<void>(
      _EmergencyRoute(
        user: widget.user,
        repository: widget.dataRepository,
        emergencyContactName: _profileData['emergencyContactName'] is String
            ? _profileData['emergencyContactName'] as String
            : null,
        emergencyContactPhone: _profileData['emergencyContactPhone'] is String
            ? _profileData['emergencyContactPhone'] as String
            : null,
      ),
    );
    if (mounted) setState(() => _selectedDestination = 0);
  }

  void _selectDestination(int index) {
    if (index == 0) {
      setState(() => _selectedDestination = 0);
      return;
    }
    setState(() => _selectedDestination = index);
    switch (index) {
      case 1:
        unawaited(_launchEmergency());
        break;
      case 2:
        _openDoctors();
        break;
      case 3:
        _openNews();
        break;
      case 4:
        _openProfile();
        break;
    }
  }

  void _openDoctors({
    String initialMode = 'Online',
    String heroTag = 'Doctor appointments',
    Map<String, Object?>? familyMember,
  }) {
    _pushPage(
      DoctorBookingsPage(
        user: widget.user,
        repository: widget.dataRepository,
        familyProfiles: _familyProfiles,
        initialFamilyMember: familyMember,
        initialMode: initialMode,
        heroTag: heroTag,
      ),
    );
  }

  List<Map<String, Object?>> get _familyProfiles {
    final profiles = _profileData['familyProfiles'];
    if (profiles is! List) return const [];
    return profiles
        .whereType<Map>()
        .map((profile) => Map<String, Object?>.from(profile))
        .indexed
        .map((entry) {
          final profile = entry.$2;
          return {
            ...profile,
            'id': profile['id'] as String? ?? 'legacy-family-${entry.$1}',
          };
        })
        .where((profile) => profile['authorized'] == true)
        .toList();
  }

  void _openLabs({int initialSection = 0, Map<String, Object?>? familyMember}) {
    _pushPage(
      LabTestsPage(
        user: widget.user,
        repository: widget.dataRepository,
        familyProfiles: _familyProfiles,
        initialFamilyMember: familyMember,
        initialSection: initialSection,
        heroTag: initialSection == 1 ? 'My reports' : 'Lab tests',
      ),
    );
  }

  void _openShop() {
    _pushPage(
      Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: CenteredContent(
          maxWidth: 920,
          child: ShopPage(
            cart: _cart,
            onAdd: _addToCart,
            onRemove: (product) => setState(() => _cart.remove(product)),
          ),
        ),
      ),
    );
  }

  void _openNews() {
    _pushPage(
      Scaffold(
        appBar: AppBar(title: const Text('News')),
        body: const CenteredContent(maxWidth: 820, child: NewsPage()),
      ),
    );
  }

  void _openFirstAid() {
    _pushPage(
      Scaffold(
        appBar: AppBar(title: const Text('Care guide')),
        body: const CenteredContent(maxWidth: 820, child: FirstAidPage()),
      ),
    );
  }

  void _openVoiceAssistant() {
    _pushPage(
      VoiceAssistantPage(
        user: widget.user,
        repository: widget.dataRepository,
        familyProfiles: _familyProfiles,
        patientName: widget.user.displayName?.trim() ?? '',
      ),
    );
  }

  void _openProfile() {
    _pushPage(
      Scaffold(
        appBar: AppBar(title: const Text('Profile & settings')),
        body: CenteredContent(
          maxWidth: 720,
          child: ValueListenableBuilder<bool>(
            valueListenable: _darkMode,
            builder: (context, darkMode, _) => ProfilePage(
              user: widget.user,
              data: _profileData,
              darkMode: darkMode,
              onToggleDarkMode: _setDarkMode,
              onSaveData: _saveProfileData,
              onOpenEmergencyProfile: () => _pushPage(
                EmergencyProfilePage(
                  user: widget.user,
                  data: _profileData,
                  onSaveData: _saveProfileData,
                ),
              ),
              onOpenHealthTimeline: () => _pushPage(
                HealthTimelinePage(
                  data: _profileData,
                  onSaveData: _saveProfileData,
                ),
              ),
              onOpenFamilyGuardian: _openFamilyGuardian,
              onSignOut: _signOut,
            ),
          ),
        ),
      ),
    );
  }

  void _openEmergencyProfile() {
    _pushPage(
      EmergencyProfilePage(
        user: widget.user,
        data: _profileData,
        onSaveData: _saveProfileData,
      ),
    );
  }

  void _openHealthTimeline() {
    _pushPage(
      HealthTimelinePage(data: _profileData, onSaveData: _saveProfileData),
    );
  }

  void _openFamilyGuardian() {
    _pushPage(
      FamilyGuardianPage(
        data: _profileData,
        onSaveData: _saveProfileData,
        onBookAppointments: (member) => _openDoctors(familyMember: member),
        onBookLabTests: (member) => _openLabs(familyMember: member),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: HomePage(
        user: widget.user,
        onEmergency: () => unawaited(_launchEmergency()),
        onDoctors: _openDoctors,
        onHospitalVisits: () => _openDoctors(
          initialMode: 'In-person',
          heroTag: 'Hospitals & offline visits',
        ),
        onLabs: _openLabs,
        onReports: () => _openLabs(initialSection: 1),
        onShop: _openShop,
        onNews: _openNews,
        onFirstAid: _openFirstAid,
        onVoiceAssistant: _openVoiceAssistant,
        onEmergencyProfile: _openEmergencyProfile,
        onHealthTimeline: _openHealthTimeline,
        onFamilyGuardian: _openFamilyGuardian,
        onProfile: _openProfile,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDestination,
        onDestinationSelected: _selectDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.error.withValues(alpha: .24),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.sos_rounded, color: Colors.white),
            ),
            selectedIcon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, color: Colors.white),
            ),
            label: 'Emergency',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Appointments',
          ),
          const NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper_rounded),
            label: 'Medical news',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _EmergencyRoute extends PageRouteBuilder<void> {
  _EmergencyRoute({
    required AppUser user,
    required AppDataRepository repository,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             EmergencyRequestPage(
               user: user,
               repository: repository,
               emergencyContactName: emergencyContactName,
               emergencyContactPhone: emergencyContactPhone,
             ),
         transitionDuration: const Duration(milliseconds: 420),
         reverseTransitionDuration: const Duration(milliseconds: 300),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.of(context).disableAnimations) return child;
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: curved,
             child: ScaleTransition(
               scale: Tween<double>(begin: .985, end: 1).animate(curved),
               child: SlideTransition(
                 position: Tween<Offset>(
                   begin: const Offset(0, .035),
                   end: Offset.zero,
                 ).animate(curved),
                 child: child,
               ),
             ),
           );
         },
       );
}

class _PageRoute<T> extends PageRouteBuilder<T> {
  _PageRoute({required Widget child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.of(context).disableAnimations) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: .99, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .025),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ),
          );
        },
      );
}

class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, .045),
      end: Offset.zero,
    ).animate(curve);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

String _firstName(AppUser user) {
  final name = user.displayName?.trim();
  final firstName = name != null && name.isNotEmpty
      ? name.split(RegExp(r'\s+')).first
      : user.email.split('@').first;
  return firstName.isEmpty ? 'there' : firstName;
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.user,
    required this.onEmergency,
    required this.onDoctors,
    required this.onHospitalVisits,
    required this.onLabs,
    required this.onReports,
    required this.onShop,
    required this.onNews,
    required this.onFirstAid,
    required this.onVoiceAssistant,
    required this.onEmergencyProfile,
    required this.onHealthTimeline,
    required this.onFamilyGuardian,
    required this.onProfile,
    super.key,
  });

  final AppUser user;
  final VoidCallback onEmergency;
  final VoidCallback onDoctors;
  final VoidCallback onHospitalVisits;
  final VoidCallback onLabs;
  final VoidCallback onReports;
  final VoidCallback onShop;
  final VoidCallback onNews;
  final VoidCallback onFirstAid;
  final VoidCallback onVoiceAssistant;
  final VoidCallback onEmergencyProfile;
  final VoidCallback onHealthTimeline;
  final VoidCallback onFamilyGuardian;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const quotes = [
      'Good health begins with one clear, caring next step.',
      'Small acts of care can make a difficult day feel lighter.',
      'Your wellbeing deserves time, attention, and compassion.',
    ];
    final quote = quotes[DateTime.now().day % quotes.length];
    final features = [
      _HomeFeature(
        Icons.graphic_eq_rounded,
        'Voice assistant',
        'Talk through a health question',
        onVoiceAssistant,
      ),
      _HomeFeature(
        Icons.calendar_month_outlined,
        'Doctor appointments',
        'Choose a doctor and visit time',
        onDoctors,
      ),
      _HomeFeature(
        Icons.local_hospital_outlined,
        'Hospitals & offline visits',
        'Find nearby care and get directions',
        onHospitalVisits,
      ),
      _HomeFeature(
        Icons.medical_services_outlined,
        'First-aid guide',
        'Simple steps for common situations',
        onFirstAid,
      ),
      _HomeFeature(
        Icons.biotech_outlined,
        'Lab tests',
        'Browse tests and request a booking',
        onLabs,
      ),
      _HomeFeature(
        Icons.folder_shared_outlined,
        'My reports',
        'View test requests and results',
        onReports,
      ),
      _HomeFeature(
        Icons.monitor_heart_outlined,
        'Health timeline',
        'Keep notes for your next visit',
        onHealthTimeline,
      ),
      _HomeFeature(
        Icons.qr_code_2,
        'Emergency profile',
        'Choose details to share by QR',
        onEmergencyProfile,
      ),
      _HomeFeature(
        Icons.family_restroom_outlined,
        'Family guardian',
        'Manage profiles with permission',
        onFamilyGuardian,
      ),
      _HomeFeature(
        Icons.shopping_bag_outlined,
        'Health essentials',
        'Everyday first-aid supplies',
        onShop,
      ),
      _HomeFeature(
        Icons.newspaper_outlined,
        'Health news',
        'Read current health headlines',
        onNews,
      ),
      _HomeFeature(
        Icons.person_outline,
        'Profile & settings',
        'Personal details and appearance',
        onProfile,
      ),
    ];

    return SafeArea(
      child: CenteredContent(
        maxWidth: 1120,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 3 : 2;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                _BrandHeader(
                  user: user,
                  onProfile: onProfile,
                  onEmergency: onEmergency,
                ),
                const SizedBox(height: 24),
                Text(
                  'Good ${_greeting()},',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _firstName(user),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 15, color: _teal),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Location shared only when you request help',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _EmergencyCard(onCall: onEmergency),
                const SizedBox(height: 14),
                _HomeHero(quote: quote),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Care, all in one place',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${features.length} features',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: features.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 164,
                  ),
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    return _Reveal(
                      duration: Duration(milliseconds: 380 + (index % 3) * 70),
                      child: _HomeFeatureButton(
                        index: (index + 1).toString().padLeft(2, '0'),
                        feature: feature,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Emergensy does not dispatch responders. In India, call 112 '
                  'for urgent help. This app does not replace professional care.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _HomeFeatureButton extends StatefulWidget {
  const _HomeFeatureButton({required this.feature, required this.index});

  final _HomeFeature feature;
  final String index;

  @override
  State<_HomeFeatureButton> createState() => _HomeFeatureButtonState();
}

class _HomeFeatureButtonState extends State<_HomeFeatureButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _pressed || _hovered;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AnimatedScale(
      scale: reduceMotion ? 1 : (_pressed ? .97 : (_hovered ? 1.015 : 1)),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: widget.feature.onTap,
          onHover: (hovered) => setState(() => _hovered = hovered),
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: motionDuration,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? [colors.primaryContainer, colors.surface]
                    : [
                        colors.surface,
                        Color.lerp(
                          colors.surface,
                          colors.primaryContainer,
                          .4,
                        )!,
                      ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active ? colors.primary.withValues(alpha: .42) : _border,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: active ? .13 : .055),
                  blurRadius: active ? 22 : 14,
                  offset: Offset(0, active ? 8 : 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FeatureHeroIcon(
                      tag: widget.feature.title,
                      icon: widget.feature.icon,
                      size: 44,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.index,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.feature.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.feature.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: colors.primary.withValues(alpha: .82),
                      size: 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;
        return Container(
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFF102B43), Color(0xFF091827)],
            ),
            border: Border.all(color: colors.tertiary.withValues(alpha: .28)),
            boxShadow: [
              BoxShadow(
                color: colors.tertiary.withValues(alpha: .08),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -42,
                top: -50,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: .78, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 850),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.onPrimary.withValues(alpha: .12),
                        width: 30,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 55,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: .72, end: 1),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 126,
                    color: colors.tertiary.withValues(alpha: .22),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 36,
                child: CustomPaint(
                  size: const Size(140, 50),
                  painter: _HeartbeatPainter(
                    color: colors.tertiary.withValues(alpha: .76),
                  ),
                ),
              ),
              Positioned(
                right: 49,
                bottom: 48,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 20,
                  color: colors.tertiary,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(22, 24, compact ? 70 : 132, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CARE, CLOSER',
                      style: TextStyle(
                        color: colors.tertiary,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'WHEN IT\nMATTERS.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 30 : 35,
                        height: .98,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      quote,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  const _HeartbeatPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .56)
      ..lineTo(size.width * .28, size.height * .56)
      ..lineTo(size.width * .39, size.height * .22)
      ..lineTo(size.width * .51, size.height * .82)
      ..lineTo(size.width * .64, size.height * .39)
      ..lineTo(size.width * .72, size.height * .56)
      ..lineTo(size.width, size.height * .56);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeartbeatPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Doctor {
  const _Doctor(this.name, this.specialty, this.experience, this.initials);

  final String name;
  final String specialty;
  final String experience;
  final String initials;
}

const _doctors = [
  _Doctor('Dr. Asha Mehta', 'General physician', '8 years experience', 'AM'),
  _Doctor('Dr. Rohan Shah', 'Cardiologist', '12 years experience', 'RS'),
  _Doctor('Dr. Nisha Rao', 'Dermatologist', '7 years experience', 'NR'),
  _Doctor('Dr. Kabir Patel', 'Paediatrician', '10 years experience', 'KP'),
];

class DoctorBookingsPage extends StatefulWidget {
  const DoctorBookingsPage({
    required this.user,
    required this.repository,
    this.familyProfiles = const [],
    this.initialFamilyMember,
    this.initialMode = 'Online',
    this.heroTag = 'Doctor appointments',
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;
  final List<Map<String, Object?>> familyProfiles;
  final Map<String, Object?>? initialFamilyMember;
  final String initialMode;
  final String heroTag;

  @override
  State<DoctorBookingsPage> createState() => _DoctorBookingsPageState();
}

class _DoctorBookingsPageState extends State<DoctorBookingsPage> {
  static const _slots = ['10:00 AM', '11:30 AM', '02:00 PM', '04:30 PM'];

  final _patientController = TextEditingController();
  final _reasonController = TextEditingController();
  final _areaController = TextEditingController();
  int _section = 0;
  int _doctorIndex = 0;
  late String _mode = widget.initialMode;
  String _slot = '10:00 AM';
  Map<String, Object?>? _selectedFamilyMember;
  String? _selectedAvailabilityId;
  HospitalPlace? _selectedHospital;
  bool _saving = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _selectedFamilyMember = widget.initialFamilyMember;
    final name = _selectedFamilyMember?['name'];
    if (name is String) _patientController.text = name;
  }

  @override
  void dispose() {
    _patientController.dispose();
    _reasonController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (date != null) {
      setState(() {
        _date = date;
        _selectedAvailabilityId = null;
      });
    }
  }

  Future<void> _findHospital() async {
    final hospital = await Navigator.of(context)
        .push<HospitalPlace>(_PageRoute(child: const HospitalMapPage()));
    if (hospital == null || !mounted) return;
    setState(() {
      _selectedHospital = hospital;
      _selectedAvailabilityId = null;
      _areaController.text = hospital.address.isEmpty
          ? hospital.name
          : hospital.address;
    });
  }

  Future<void> _openDirections(double latitude, double longitude) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No maps app could open this destination.');
      }
    } catch (error) {
      if (!mounted) return;
      _showBookingMessage('Unable to open directions: $error');
    }
  }

  Future<void> _saveRequest() async {
    final patient = _patientController.text.trim();
    if (patient.isEmpty) {
      _showBookingMessage('Add the patient name to continue.');
      return;
    }
    if (_mode == 'In-person' && _selectedHospital == null) {
      _showBookingMessage(
        'Choose a nearby hospital or clinic from the map for an in-person request.',
      );
      return;
    }
    final doctor = _doctors[_doctorIndex];
    final member = _selectedFamilyMember;
    setState(() {
      _saving = true;
    });
    try {
      await widget.repository.saveAppointment(widget.user.uid, {
        'doctor': doctor.name,
        'specialty': doctor.specialty,
        'mode': _mode,
        'date': _date.toIso8601String(),
        'slot': _slot,
        'patient': patient,
        'reason': _reasonController.text.trim(),
        'area': _areaController.text.trim(),
        if (member != null) ...{
          'memberId': member['id'],
          'memberName': member['name'],
        },
        if (_selectedAvailabilityId != null)
          'availabilityId': _selectedAvailabilityId,
        if (_selectedHospital != null) ...{
          'facilityId': _selectedHospital!.id,
          'hospitalId': _selectedHospital!.id,
          'hospitalName': _selectedHospital!.name,
          'hospitalAddress': _selectedHospital!.address,
          'hospitalLatitude': _selectedHospital!.latitude,
          'hospitalLongitude': _selectedHospital!.longitude,
        },
        'status': 'requested',
      });
      if (mounted) setState(() => _section = 1);
    } catch (error) {
      if (mounted) {
        _showBookingMessage('Could not save appointment: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showBookingMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor appointments')),
      body: SafeArea(
        top: false,
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  FeatureHeroIcon(
                    tag: widget.heroTag,
                    icon: widget.initialMode == 'In-person'
                        ? Icons.local_hospital_outlined
                        : Icons.calendar_month_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FeatureEyebrow(text: 'CARE, ON YOUR TERMS'),
                        const SizedBox(height: 8),
                        Text(
                          'Talk to a doctor.',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose a video consult or an in-person visit.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Book a visit')),
                  ButtonSegment(value: 1, label: Text('My requests')),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _section == 0 ? _bookingForm() : _requestHistory(),
              ),
              const SizedBox(height: 14),
              const _DemoServiceNotice(
                text: 'Online requests stay in your private Firebase account. In-person requests for a selected facility appear in its verified doctor queue, but are not confirmed until a doctor approves them. Map listings are not proof that a facility is connected.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingForm() {
    return Column(
      key: const ValueKey('doctor-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FeatureEyebrow(text: 'VISIT TYPE'),
        const SizedBox(height: 4),
        Text(
          'Sample directory and time slots · availability is not live',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
        const SizedBox(height: 9),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Online',
              icon: Icon(Icons.videocam_outlined),
              label: Text('Online'),
            ),
            ButtonSegment(
              value: 'In-person',
              icon: Icon(Icons.location_on_outlined),
              label: Text('In person'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() {
            _mode = value.first;
            if (_mode != 'In-person') {
              _selectedHospital = null;
              _selectedAvailabilityId = null;
            }
          }),
        ),
        const SizedBox(height: 20),
        const _FeatureEyebrow(text: 'PICK A DOCTOR'),
        const SizedBox(height: 9),
        ..._doctors.indexed.map((entry) {
          final selected = _doctorIndex == entry.$1;
          final doctor = entry.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SelectableDoctorCard(
              doctor: doctor,
              selected: selected,
              onTap: () => setState(() => _doctorIndex = entry.$1),
            ),
          );
        }),
        const SizedBox(height: 10),
        const _FeatureEyebrow(text: 'WHEN WORKS FOR YOU'),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: _chooseDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_formatDate(_date)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _ink,
            side: BorderSide(color: _border),
          ),
        ),
        const SizedBox(height: 10),
        if (_mode == 'In-person' && _selectedHospital != null)
          _facilityAvailability()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slots
                .map(
                  (slot) => ChoiceChip(
                    label: Text(slot),
                    selected: _slot == slot,
                    onSelected: (_) => setState(() {
                      _slot = slot;
                      _selectedAvailabilityId = null;
                    }),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 17),
        if (widget.familyProfiles.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: _selectedFamilyMember?['id'] as String?,
            decoration: const InputDecoration(labelText: 'Booking for'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Myself'),
              ),
              ...widget.familyProfiles.map(
                (member) => DropdownMenuItem<String?>(
                  value: member['id'] as String?,
                  child: Text(member['name'] as String? ?? 'Family member'),
                ),
              ),
            ],
            onChanged: (id) {
              Map<String, Object?>? member;
              for (final profile in widget.familyProfiles) {
                if (profile['id'] == id) {
                  member = profile;
                  break;
                }
              }
              setState(() {
                _selectedFamilyMember = member;
                _patientController.text = member?['name'] as String? ?? '';
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _patientController,
          readOnly: _selectedFamilyMember != null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Patient name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _reasonController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What would you like help with? (optional)',
            alignLabelWithHint: true,
          ),
        ),
        if (_mode == 'In-person') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _findHospital,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Choose a nearby hospital or clinic'),
          ),
          Text(
            'Nearby locations are shown first. A request is only confirmed after an assigned doctor approves it.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
          if (_selectedHospital != null) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedHospital!.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (_selectedHospital!.address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _selectedHospital!.address,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openDirections(
                          _selectedHospital!.latitude,
                          _selectedHospital!.longitude,
                        ),
                        icon: const Icon(Icons.directions_outlined),
                        label: const Text('Get directions'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _areaController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Preferred city or area',
              hintText: 'For example, Pune or Koregaon Park',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveRequest,
            icon: const Icon(Icons.arrow_forward),
            label: Text(_saving ? 'Saving…' : 'Book appointment'),
          ),
        ),
      ],
    );
  }

  Widget _facilityAvailability() => StreamBuilder<List<Map<String, Object?>>>(
    stream: widget.repository.watchAvailability(_selectedHospital!.id),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _FeatureError(
          message: 'Could not load clinic availability: ${snapshot.error}',
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator();
      }
      final today = DateTime.now();
      final firstDay = DateTime(today.year, today.month, today.day);
      final slots = (snapshot.data ?? const <Map<String, Object?>>[]).where((
        slot,
      ) {
        final date = DateTime.tryParse(slot['date'] as String? ?? '');
        return slot['status'] == 'available' &&
            date != null &&
            !date.isBefore(firstDay);
      }).toList();
      if (slots.isEmpty) {
        return Text(
          'No doctor-published times at this location yet. You can still request your preferred time.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: slots.map((slot) {
          final id = slot['id'] as String? ?? '';
          final date = DateTime.tryParse(slot['date'] as String? ?? '');
          final time = slot['slot'] as String? ?? 'Time not set';
          return ChoiceChip(
            label: Text(
              '${date == null ? '' : '${_formatDate(date)} · '}$time',
            ),
            selected: _selectedAvailabilityId == id,
            onSelected: (_) => setState(() {
              _selectedAvailabilityId = id;
              _slot = time;
              if (date != null) _date = date;
            }),
          );
        }).toList(),
      );
    },
  );

  Widget _requestHistory() {
    return StreamBuilder<List<Map<String, Object?>>>(
      key: const ValueKey('doctor-history'),
      stream: widget.repository.watchAppointments(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FeatureError(
            message: 'Could not load appointments: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data ?? const <Map<String, Object?>>[];
        if (requests.isEmpty) {
          return const _EmptyFeatureState(
            icon: Icons.event_note_outlined,
            title: 'Nothing booked yet',
            subtitle: 'Your appointment requests will show up here.',
          );
        }
        return Column(
          children: requests.map((request) {
            final mode = request['mode'] as String? ?? 'Online';
            final date = DateTime.tryParse(request['date'] as String? ?? '');
            final latitude = request['hospitalLatitude'];
            final longitude = request['hospitalLongitude'];
            final hasCoordinates = latitude is num && longitude is num;
            return Column(
              children: [
                _FeatureRecordCard(
                  icon: mode == 'Online'
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                  title: request['doctor'] as String? ?? 'Doctor appointment',
                  subtitle:
                      '${request['specialty'] ?? 'General'} · $mode · '
                      '${date == null ? 'Date not set' : _formatDate(date)} at ${request['slot'] ?? 'Time not set'}',
                  status: request['status'] as String? ?? 'requested',
                  detail:
                      'Patient: ${request['patient'] ?? ''}'
                      '${(request['memberName'] as String? ?? '').isEmpty ? '' : ' · For family member: ${request['memberName']}'}'
                      '${(request['hospitalName'] as String? ?? '').isEmpty ? '' : ' · Hospital: ${request['hospitalName']}'}'
                      '${(request['area'] as String? ?? '').isEmpty ? '' : ' · Area: ${request['area']}'}'
                      '${(request['reason'] as String? ?? '').isEmpty ? '' : ' · ${request['reason']}'}',
                ),
                if (hasCoordinates)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openDirections(
                        latitude.toDouble(),
                        longitude.toDouble(),
                      ),
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Directions to hospital'),
                    ),
                  ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _SelectableDoctorCard extends StatelessWidget {
  const _SelectableDoctorCard({
    required this.doctor,
    required this.selected,
    required this.onTap,
  });

  final _Doctor doctor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _teal : _border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _surfaceRaised,
                foregroundColor: _teal,
                child: Text(
                  doctor.initials,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doctor.specialty} · ${doctor.experience}',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? _teal : _muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabTestsPage extends StatefulWidget {
  const LabTestsPage({
    required this.user,
    required this.repository,
    this.familyProfiles = const [],
    this.initialFamilyMember,
    this.initialSection = 0,
    this.heroTag = 'Lab tests',
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;
  final List<Map<String, Object?>> familyProfiles;
  final Map<String, Object?>? initialFamilyMember;
  final int initialSection;
  final String heroTag;

  @override
  State<LabTestsPage> createState() => _LabTestsPageState();
}

class _LabTestsPageState extends State<LabTestsPage> {
  static const _tests = [
    ('Complete blood count (CBC)', 'Blood'),
    ('Blood glucose — fasting', 'Blood sugar'),
    ('Blood glucose — random', 'Blood sugar'),
    ('HbA1c', 'Blood sugar'),
    ('Lipid profile', 'Blood'),
    ('Thyroid (TSH)', 'Blood'),
    ('Vitamin D', 'Blood'),
    ('Urine routine', 'Urine'),
  ];

  final _patientController = TextEditingController();
  final Set<String> _selectedTests = {};
  final Map<String, String> _summaries = {};
  final Set<String> _summarizing = {};
  Map<String, Object?>? _selectedFamilyMember;
  late int _section = widget.initialSection;
  String _collection = 'Visit a lab';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedFamilyMember = widget.initialFamilyMember;
    final name = _selectedFamilyMember?['name'];
    if (name is String) _patientController.text = name;
  }

  @override
  void dispose() {
    _patientController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _saveRequest() async {
    final patient = _patientController.text.trim();
    if (_selectedTests.isEmpty) {
      _showMessage('Choose at least one test.');
      return;
    }
    if (patient.isEmpty) {
      _showMessage('Add the patient name to continue.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.saveLabBooking(widget.user.uid, {
        'tests': _tests
            .map((test) => test.$1)
            .where(_selectedTests.contains)
            .toList(),
        'collection': _collection,
        'date': _date.toIso8601String(),
        'patient': patient,
        if (_selectedFamilyMember != null) ...{
          'memberId': _selectedFamilyMember!['id'],
          'memberName': _selectedFamilyMember!['name'],
        },
        'status': 'requested',
      });
      if (mounted) setState(() => _section = 1);
    } catch (error) {
      if (mounted) _showMessage('Could not save lab booking: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lab tests')),
      body: SafeArea(
        top: false,
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  FeatureHeroIcon(
                    tag: widget.heroTag,
                    icon: widget.heroTag == 'My reports'
                        ? Icons.folder_shared_outlined
                        : Icons.biotech_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FeatureEyebrow(text: 'TESTING, MADE SIMPLE'),
                        const SizedBox(height: 8),
                        Text(
                          'Book a lab test.',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick what you need, then choose a collection option.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Book tests')),
                  ButtonSegment(value: 1, label: Text('Results')),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _section == 0 ? _bookingForm() : _results(),
              ),
              const SizedBox(height: 14),
              const _DemoServiceNotice(
                text:
                    'Bookings are stored in your private Firebase account, but are not sent to a lab. '
                    'Verified reports require a lab integration.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingForm() {
    return Column(
      key: const ValueKey('lab-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FeatureEyebrow(text: 'CHOOSE TESTS'),
        const SizedBox(height: 9),
        ..._tests.map((test) {
          final selected = _selectedTests.contains(test.$1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _TestChoiceTile(
              name: test.$1,
              category: test.$2,
              selected: selected,
              onTap: () => setState(() {
                if (selected) {
                  _selectedTests.remove(test.$1);
                } else {
                  _selectedTests.add(test.$1);
                }
              }),
            ),
          );
        }),
        const SizedBox(height: 13),
        const _FeatureEyebrow(text: 'SAMPLE COLLECTION'),
        const SizedBox(height: 9),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Visit a lab',
              icon: Icon(Icons.biotech_outlined),
              label: Text('At lab'),
            ),
            ButtonSegment(
              value: 'Home collection',
              icon: Icon(Icons.home_outlined),
              label: Text('At home'),
            ),
          ],
          selected: {_collection},
          onSelectionChanged: (value) =>
              setState(() => _collection = value.first),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _chooseDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_formatDate(_date)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _ink,
            side: BorderSide(color: _border),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.familyProfiles.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: _selectedFamilyMember?['id'] as String?,
            decoration: const InputDecoration(labelText: 'Booking for'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Myself'),
              ),
              ...widget.familyProfiles.map(
                (member) => DropdownMenuItem<String?>(
                  value: member['id'] as String?,
                  child: Text(member['name'] as String? ?? 'Family member'),
                ),
              ),
            ],
            onChanged: (id) {
              Map<String, Object?>? member;
              for (final profile in widget.familyProfiles) {
                if (profile['id'] == id) {
                  member = profile;
                  break;
                }
              }
              setState(() {
                _selectedFamilyMember = member;
                _patientController.text = member?['name'] as String? ?? '';
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _patientController,
          readOnly: _selectedFamilyMember != null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Patient name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveRequest,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              _saving ? 'Saving…' : 'Book ${_selectedTests.length} test(s)',
            ),
          ),
        ),
      ],
    );
  }

  Widget _results() {
    return StreamBuilder<List<Map<String, Object?>>>(
      key: const ValueKey('lab-results'),
      stream: widget.repository.watchLabBookings(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FeatureError(
            message: 'Could not load lab bookings: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snapshot.data ?? const <Map<String, Object?>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your lab bookings',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verified results appear after a connected lab submits them.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 12),
            if (bookings.isEmpty)
              const _EmptyFeatureState(
                icon: Icons.description_outlined,
                title: 'No lab bookings yet',
                subtitle:
                    'Your bookings and verified reports will appear here.',
              )
            else
              ...bookings.map(_labBookingCard),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, Object?>>>(
              stream: widget.repository.watchLabResults(widget.user.uid),
              builder: (context, resultSnapshot) {
                if (resultSnapshot.hasError) {
                  return _FeatureError(
                    message:
                        'Could not load lab results: ${resultSnapshot.error}',
                  );
                }
                final results =
                    resultSnapshot.data ?? const <Map<String, Object?>>[];
                if (results.isEmpty) {
                  return const _EmptyFeatureState(
                    icon: Icons.fact_check_outlined,
                    title: 'No verified results',
                    subtitle: 'Only reports submitted by an authorized lab integration appear here.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified results',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...results.map(_labResultCard),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _labBookingCard(Map<String, Object?> booking) {
    final tests = (booking['tests'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();
    final date = DateTime.tryParse(booking['date'] as String? ?? '');
    return _FeatureRecordCard(
      icon: Icons.biotech_outlined,
      title: '${tests.length} test(s) · ${booking['patient'] ?? ''}',
      subtitle:
          '${booking['collection'] ?? 'Collection not selected'} · '
          '${date == null ? 'Date not set' : _formatDate(date)}\n${tests.join(', ')}',
      status: booking['status'] as String? ?? 'requested',
      detail: 'Saved to your Firebase account. Not yet sent to a lab.',
    );
  }

  Widget _labResultCard(Map<String, Object?> result) {
    final value = result['value']?.toString() ?? 'Value not provided';
    final unit = result['unit'] as String? ?? '';
    final referenceRange = result['referenceRange'] as String? ?? '';
    final resultId = result['id'] as String?;
    final savedSummary = result['aiSummary'] as String?;
    final summary = resultId == null
        ? savedSummary
        : _summaries[resultId] ?? savedSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeatureRecordCard(
          icon: Icons.fact_check_outlined,
          title: result['testName'] as String? ?? 'Lab result',
          subtitle:
              '$value $unit${referenceRange.isEmpty ? '' : ' · Reference: $referenceRange'}'
              '${(result['memberName'] as String? ?? '').isEmpty ? '' : '\nFor: ${result['memberName']}'}',
          status: result['status'] as String? ?? 'Reported',
          detail:
              'Reported by ${result['labName'] as String? ?? 'authorized lab'}'
              '${result['reportedAt'] == null ? '' : ' · ${result['reportedAt']}'}',
        ),
        if (summary != null && summary.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _teal.withValues(alpha: .25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FeatureEyebrow(text: 'AI EXPLANATION'),
                const SizedBox(height: 8),
                Text(summary, style: TextStyle(color: _ink, height: 1.45)),
              ],
            ),
          )
        else if (resultId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _summarizing.contains(resultId)
                  ? null
                  : () => _requestAiSummary(resultId),
              icon: _summarizing.contains(resultId)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _summarizing.contains(resultId)
                    ? 'Preparing explanation…'
                    : 'Explain this result with AI',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _requestAiSummary(String resultId) async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI result explanation'),
        content: const Text(
          'With your permission, EM3RGENSY will send this result’s test name, value, units, reference range and status to Google Vertex AI to create a plain-language explanation. Your name and contact details are not sent. AI can make mistakes; this is not a diagnosis and does not replace your clinician.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree and explain'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() => _summarizing.add(resultId));
    try {
      final summary = await widget.repository.summarizeLabResult(
        widget.user.uid,
        resultId,
      );
      if (mounted) setState(() => _summaries[resultId] = summary);
    } catch (error) {
      if (mounted) {
        _showMessage('Could not explain this result: $error');
      }
    } finally {
      if (mounted) setState(() => _summarizing.remove(resultId));
    }
  }
}

String _formatDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

class _FeatureEyebrow extends StatelessWidget {
  const _FeatureEyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _teal),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: _teal,
              fontSize: 10,
              letterSpacing: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoServiceNotice extends StatelessWidget {
  const _DemoServiceNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_surfaceRaised, _surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border.withValues(alpha: .8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_outline_rounded, color: _teal, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureError extends StatelessWidget {
  const _FeatureError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: .28)),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.onErrorContainer, height: 1.4),
      ),
    );
  }
}

class _TestChoiceTile extends StatelessWidget {
  const _TestChoiceTile({
    required this.name,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _teal : _border),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? _teal : _muted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeatureState extends StatelessWidget {
  const _EmptyFeatureState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            Color.lerp(colors.surface, colors.primaryContainer, .32)!,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withValues(alpha: .12),
                  colors.tertiary.withValues(alpha: .22),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _teal, size: 27),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FeatureRecordCard extends StatelessWidget {
  const _FeatureRecordCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _teal),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: _teal, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(subtitle, style: TextStyle(color: _muted, height: 1.45)),
          const SizedBox(height: 8),
          Text(detail, style: TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class EmergencyRequestPage extends StatefulWidget {
  const EmergencyRequestPage({
    required this.user,
    required this.repository,
    this.emergencyContactName,
    this.emergencyContactPhone,
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  @override
  State<EmergencyRequestPage> createState() => _EmergencyRequestPageState();
}

class _EmergencyRequestPageState extends State<EmergencyRequestPage> {
  static const _situations = [
    'Breathing / choking',
    'Severe bleeding',
    'Burn',
    'Unconscious / faint',
    'Seizure',
    'Other',
  ];

  final _detailsController = TextEditingController();
  final _manualLocationController = TextEditingController();
  String? _situation;
  Position? _position;
  bool _findingLocation = false;
  bool _showGuidance = false;
  bool _savingAlert = false;
  bool _alertSaved = false;
  String? _locationError;
  String? _alertSaveError;
  String? _alertId;

  @override
  void dispose() {
    _detailsController.dispose();
    _manualLocationController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _findingLocation = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Turn on device location services, or enter an address.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Enter an address instead.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is disabled in settings. Enter an address instead.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _locationError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
  }

  String get _reason {
    final details = _detailsController.text.trim();
    if (details.isEmpty) return _situation ?? '';
    return '${_situation ?? 'Emergency'}: $details';
  }

  String get _location {
    final manual = _manualLocationController.text.trim();
    if (manual.isNotEmpty) return manual;
    if (_position case final position?) {
      return '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';
    }
    return '';
  }

  void _continueToGuidance() {
    if (_situation == null) {
      _showMessage('Choose the closest emergency type.');
      return;
    }
    if (_situation == 'Other' && _detailsController.text.trim().isEmpty) {
      _showMessage('Briefly describe the emergency.');
      return;
    }
    if (_location.isEmpty) {
      _showMessage('Detect your location or enter an address/landmark.');
      return;
    }
    setState(() {
      _showGuidance = true;
      _savingAlert = true;
      _alertSaveError = null;
      _alertId ??= DateTime.now().microsecondsSinceEpoch.toString();
    });
    _saveEmergencyAlert();
  }

  Future<void> _saveEmergencyAlert() async {
    final position = _position;
    try {
      await widget.repository.saveEmergencyAlert(widget.user.uid, _alertId!, {
        'type': 'Critical',
        'situation': _situation!,
        'reason': _reason,
        'location': _location,
        'status': 'prepared',
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      });
      if (!mounted) return;
      setState(() {
        _savingAlert = false;
        _alertSaved = true;
        _alertSaveError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingAlert = false;
        _alertSaved = false;
        _alertSaveError = 'Could not save this SOS to your account: $error';
      });
    }
  }

  void _retrySaveEmergencyAlert() {
    setState(() {
      _savingAlert = true;
      _alertSaveError = null;
      _alertId = DateTime.now().microsecondsSinceEpoch.toString();
    });
    _saveEmergencyAlert();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency help'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CenteredContent(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showGuidance ? _buildGuidance() : _buildRequestForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('request-form'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.error.withValues(alpha: .28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: colors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This app cannot alert an ambulance or hospital directly. '
                  'It prepares your details and connects you to India’s 112 '
                  'emergency line so you can tell the operator.',
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _EmergencyStepLabel(number: '01', title: 'What happened?'),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _situations.map((situation) {
            return ChoiceChip(
              label: Text(situation),
              selected: _situation == situation,
              onSelected: (_) => setState(() => _situation = situation),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _detailsController,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Anything else to tell the operator? (optional)',
            hintText: 'For example, number of people injured',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 22),
        const _EmergencyStepLabel(number: '02', title: 'Where are you?'),
        const SizedBox(height: 11),
        OutlinedButton.icon(
          onPressed: _findingLocation ? null : _detectLocation,
          icon: _findingLocation
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(
            _findingLocation ? 'Getting location…' : 'Use my location',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _teal,
            side: BorderSide(color: _teal),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_position != null) ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: _teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location ready · ${_position!.latitude.toStringAsFixed(4)}, '
                    '${_position!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(color: _ink, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_locationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _locationError!,
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _manualLocationController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Address or nearby landmark',
            hintText: 'Building, street, area, city',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'When you continue, your emergency type and location are saved to '
          'your private Emergensy account. This does not alert responders; '
          'share your details with the 112 operator.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _continueToGuidance,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Show immediate safety steps'),
          ),
        ),
      ],
    );
  }

  Widget _buildGuidance() {
    final colors = Theme.of(context).colorScheme;
    final steps = switch (_situation) {
      'Severe bleeding' => const [
        'Call 112 now. Put the call on speaker and follow the operator’s instructions.',
        'Press firmly on the wound with clean cloth or gauze. Keep steady pressure.',
        'If blood soaks through, add more cloth on top. Do not remove an embedded object.',
        'Keep the person lying still and warm. Do not give food or drink.',
      ],
      'Burn' => const [
        'Call 112 for a large, deep, facial, chemical, or electrical burn.',
        'For a minor heat burn, cool it under clean, cool running water for 20 minutes.',
        'Remove tight jewellery or clothing near the burn if it is not stuck to skin.',
        'Do not use ice, butter, creams, or break blisters. Follow dispatcher advice.',
      ],
      'Breathing / choking' => const [
        'Call 112 now and put the phone on speaker. Follow the dispatcher’s instructions.',
        'If the person can cough or speak, encourage them to keep coughing.',
        'If they cannot breathe or speak, get help from someone nearby and follow the dispatcher’s first-aid guidance.',
        'If they become unresponsive or are not breathing normally, start CPR only if trained or directed by the dispatcher.',
      ],
      'Unconscious / faint' => const [
        'Call 112 if they do not wake quickly, are injured, or have breathing trouble.',
        'Check whether they respond and are breathing normally. Follow the operator’s instructions.',
        'If they are breathing, keep them safe and warm. Avoid moving them if you suspect a serious injury.',
        'Do not give food, drink, or medicine while they are not fully alert.',
      ],
      'Seizure' => const [
        'Call 112 for a first seizure, a seizure lasting about 5 minutes, repeated seizures, injury, or breathing difficulty.',
        'Move nearby hazards away and cushion the person’s head.',
        'Do not restrain them and do not put anything in their mouth.',
        'When movements stop, check breathing and follow the dispatcher’s instructions.',
      ],
      _ => const [
        'Call 112 now and clearly describe what happened. Put the call on speaker if you need both hands.',
        'Keep the person away from immediate danger and stay with them.',
        'Check responsiveness and breathing. Do not give food, drink, or medicine if they are drowsy or unconscious.',
        'Follow the emergency operator’s instructions until help arrives.',
      ],
    };

    return ListView(
      key: const ValueKey('emergency-guidance'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _EmergencyAlertSaveStatus(
          saving: _savingAlert,
          saved: _alertSaved,
          error: _alertSaveError,
          onRetry: _retrySaveEmergencyAlert,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.error.withValues(alpha: .28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.emergency, color: colors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your details are ready, but have not been sent. Call 112 '
                  'and tell the operator your emergency and location.',
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Tell the operator',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _EmergencyDetailRow(
          icon: Icons.warning_amber_rounded,
          label: 'Emergency',
          value: _reason,
        ),
        const SizedBox(height: 8),
        _EmergencyDetailRow(
          icon: Icons.location_on_outlined,
          label: 'Your location',
          value: _location,
          onTap: _position == null ? null : _openMap,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () => _callEmergency(context, _reason, _location),
            icon: const Icon(Icons.call),
            label: const Text('Call 112 now'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
          ),
        ),
        if (widget.emergencyContactPhone?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _callSavedEmergencyContact(
                context,
                widget.emergencyContactName,
                widget.emergencyContactPhone!,
              ),
              icon: const Icon(Icons.person_pin_circle_outlined),
              label: Text(
                'Call ${widget.emergencyContactName?.trim().isNotEmpty == true ? widget.emergencyContactName : 'emergency contact'}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'While help is on the way',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Keep the call on speaker and follow the dispatcher’s instructions first.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        ...steps.indexed.map(
          (entry) => _ImmediateStep(number: entry.$1 + 1, text: entry.$2),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showGuidance = false),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Edit emergency details'),
        ),
      ],
    );
  }

  Future<void> _openMap() async {
    final position = _position;
    if (position == null) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${position.latitude},${position.longitude}',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No maps app could open the location.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to open the map: $error');
    }
  }
}

class _EmergencyStepLabel extends StatelessWidget {
  const _EmergencyStepLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: TextStyle(
            color: _teal,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmergencyAlertSaveStatus extends StatelessWidget {
  const _EmergencyAlertSaveStatus({
    required this.saving,
    required this.saved,
    required this.error,
    required this.onRetry,
  });

  final bool saving;
  final bool saved;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = saving
        ? 'Saving SOS details to your account…'
        : saved
        ? 'SOS details saved to your account. No responders were contacted.'
        : error ?? 'SOS details have not been saved.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (saving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              saved ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: saved ? _teal : colors.error,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error == null ? _ink : colors.error,
                height: 1.4,
              ),
            ),
          ),
          if (error != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmergencyDetailRow extends StatelessWidget {
  const _EmergencyDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: _teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: _muted, fontSize: 11)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: _ink, height: 1.35)),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              tooltip: 'Open location in maps',
              onPressed: onTap,
              icon: Icon(Icons.map_outlined, color: _teal),
            ),
        ],
      ),
    );
  }
}

class _ImmediateStep extends StatelessWidget {
  const _ImmediateStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: _teal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text, style: TextStyle(color: _ink, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

Future<void> _callEmergency(
  BuildContext context,
  String reason,
  String location,
) async {
  final uri = Uri(scheme: 'tel', path: '112');
  final snackMessage = 'Tell the operator: $reason. Location: $location';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(snackMessage),
        duration: const Duration(seconds: 8),
      ),
    );
  try {
    if (!await launchUrl(uri)) {
      throw Exception('Your device could not open the phone app.');
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to start the emergency call: $error')),
    );
  }
}

Future<void> _callSavedEmergencyContact(
  BuildContext context,
  String? name,
  String phone,
) async {
  final uri = Uri(scheme: 'tel', path: phone.trim());
  try {
    if (!await launchUrl(uri)) {
      throw StateError('Your device could not open the phone app.');
    }
  } catch (error) {
    if (!context.mounted) return;
    final contact = name?.trim().isNotEmpty == true ? name!.trim() : 'contact';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to call $contact: $error')));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.user, this.onProfile, this.onEmergency});

  final AppUser? user;
  final VoidCallback? onProfile;
  final VoidCallback? onEmergency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.tertiary.withValues(alpha: .12),
            border: Border.all(color: colors.tertiary.withValues(alpha: .26)),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: colors.tertiary.withValues(alpha: .1),
                blurRadius: 18,
              ),
            ],
          ),
          child: Icon(Icons.health_and_safety_rounded, color: colors.tertiary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EM3RGENSY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Text(
                'CARE, MADE CLOSER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (onEmergency != null)
          IconButton(
            tooltip: 'Get emergency help',
            onPressed: onEmergency,
            style: IconButton.styleFrom(
              foregroundColor: colors.error,
              backgroundColor: colors.error.withValues(alpha: .1),
              minimumSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.sos_rounded),
          ),
        if (user != null && onProfile != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: colors.tertiary.withValues(alpha: .15),
              foregroundColor: colors.tertiary,
              child: Text(
                _firstName(user!).substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.error.withValues(alpha: .28)),
        boxShadow: [
          BoxShadow(
            color: colors.error.withValues(alpha: .09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.emergency_rounded, color: colors.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SOS · IMMEDIATE ASSISTANCE',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'One tap from getting help.',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share what happened and where you are. We’ll show immediate safety steps.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.sos_rounded),
              label: const Text('Get help'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'In India, call 112 for emergency services. This app does not dispatch an ambulance.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    required this.category,
    this.isMedicine = false,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final IconData icon;
  final String category;
  final bool isMedicine;
}

const _products = [
  ShopProduct(
    id: 'bandage',
    name: 'Adhesive bandages',
    description: 'Flexible assorted strips · 20 pack',
    price: 89,
    icon: Icons.healing_outlined,
    category: 'First aid',
  ),
  ShopProduct(
    id: 'gauze',
    name: 'Sterile gauze pads',
    description: 'Individually wrapped · 10 pack',
    price: 129,
    icon: Icons.medical_services_outlined,
    category: 'First aid',
  ),
  ShopProduct(
    id: 'antiseptic',
    name: 'Antiseptic solution',
    description: 'For minor wound cleansing · 100 ml',
    price: 75,
    icon: Icons.water_drop_outlined,
    category: 'First aid',
  ),
  ShopProduct(
    id: 'thermometer',
    name: 'Digital thermometer',
    description: 'Reusable personal care device',
    price: 249,
    icon: Icons.device_thermostat_outlined,
    category: 'Devices',
  ),
  ShopProduct(
    id: 'saline',
    name: 'Saline wound wash',
    description: 'Sterile wound irrigation · 100 ml',
    price: 110,
    icon: Icons.local_drink_outlined,
    category: 'First aid',
  ),
  ShopProduct(
    id: 'paracetamol',
    name: 'Paracetamol',
    description: 'Common OTC medicine · 10 tablets',
    price: 30,
    icon: Icons.medication_outlined,
    category: 'Basic medicines',
    isMedicine: true,
  ),
  ShopProduct(
    id: 'ors',
    name: 'Oral rehydration salts',
    description: 'ORS sachets · 5 pack',
    price: 60,
    icon: Icons.medication_outlined,
    category: 'Basic medicines',
    isMedicine: true,
  ),
  ShopProduct(
    id: 'cetirizine',
    name: 'Cetirizine',
    description: 'Common OTC antihistamine · 10 tablets',
    price: 25,
    icon: Icons.medication_outlined,
    category: 'Basic medicines',
    isMedicine: true,
  ),
];

class ShopPage extends StatefulWidget {
  const ShopPage({
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<ShopProduct> cart;
  final ValueChanged<ShopProduct> onAdd;
  final ValueChanged<ShopProduct> onRemove;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _category = 'All';
  static const _categories = ['All', 'First aid', 'Basic medicines', 'Devices'];

  void _addProduct(ShopProduct product) {
    widget.onAdd(product);
    setState(() {});
  }

  void _removeProduct(ShopProduct product) {
    widget.onRemove(product);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = _category == 'All'
        ? _products
        : _products.where((product) => product.category == _category).toList();
    final total = widget.cart.fold<double>(0, (sum, item) => sum + item.price);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FeatureHeroIcon(
                      tag: 'Health essentials',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health essentials',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.55,
                            ),
                          ),
                          Text(
                            'Good care starts with the little things.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Basic first-aid supplies and everyday essentials',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 5),
                Text(
                  'Use medicines only as directed on the package or by a pharmacist.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return _Reveal(
                  key: ValueKey('product-${product.id}'),
                  delay: Duration(milliseconds: 35 * (index % 6)),
                  duration: const Duration(milliseconds: 380),
                  child: _ProductCard(
                    key: ValueKey(product.id),
                    product: product,
                    onAdd: () => _addProduct(product),
                  ),
                );
              },
            ),
          ),
          if (widget.cart.isNotEmpty)
            _CartSummary(
              cart: widget.cart,
              total: total,
              onRemove: _removeProduct,
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.onAdd, super.key});

  final ShopProduct product;
  final VoidCallback onAdd;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _added = false;
  Timer? _addedTimer;

  void _addToCart() {
    widget.onAdd();
    _addedTimer?.cancel();
    setState(() => _added = true);
    _addedTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  void dispose() {
    _addedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _surfaceRaised,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(widget.product.icon, color: _teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (widget.product.isMedicine)
                      Icon(Icons.info_outline, size: 16, color: _muted),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.product.description,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '₹${widget.product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: FilledButton.tonalIcon(
                        onPressed: _addToCart,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _added ? Icons.check : Icons.add,
                            key: ValueKey(_added),
                            size: 17,
                          ),
                        ),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _added ? 'Added' : 'Add',
                            key: ValueKey(_added),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.cart,
    required this.total,
    required this.onRemove,
  });

  final List<ShopProduct> cart;
  final double total;
  final ValueChanged<ShopProduct> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: _teal),
                const SizedBox(width: 8),
                Text(
                  '${cart.length} item${cart.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: 'Remove last item',
                  onPressed: () => onRemove(cart.last),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showDemoCheckout(context, cart, total),
                child: const Text('Review cart'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Demo shop: checkout is not connected to a pharmacy or payment provider.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDemoCheckout(
  BuildContext context,
  List<ShopProduct> cart,
  double total,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cart review',
              style: TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...cart.map(
              (product) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(product.name)),
                    Text('₹${product.price.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'This is a preview only. No order or payment will be submitted.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class HealthArticle {
  const HealthArticle({
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    this.imageUrl,
  });

  final String title;
  final String description;
  final String source;
  final String url;
  final String? imageUrl;

  factory HealthArticle.fromJson(Map<String, dynamic> json) {
    final sourceJson = json['source'];
    return HealthArticle(
      title: json['title'] as String? ?? 'Untitled article',
      description: json['description'] as String? ?? '',
      source: sourceJson is Map<String, dynamic>
          ? sourceJson['name'] as String? ?? 'News source'
          : 'News source',
      url: json['url'] as String? ?? '',
      imageUrl: json['urlToImage'] as String?,
    );
  }
}

class NewsApiService {
  NewsApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<HealthArticle>> fetchHealthNews() async {
    final feedUrl = Uri.https('news.google.com', '/rss/search', {
      'q': 'health India',
      'hl': 'en-IN',
      'gl': 'IN',
      'ceid': 'IN:en',
    });
    final uri = Uri.https('api.rss2json.com', '/v1/api.json', {
      'rss_url': feedUrl.toString(),
    });

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw NewsRequestException(
        'News service returned ${response.statusCode}. Please try again later.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['status'] != 'ok' ||
        decoded['items'] is! List) {
      final message = decoded is Map ? decoded['message'] : null;
      throw NewsRequestException(
        message is String && message.isNotEmpty
            ? message
            : 'The news service returned an unexpected response.',
      );
    }

    return (decoded['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final itemTitle = item['title'] as String? ?? 'Untitled article';
          final titleParts = itemTitle.split(' - ');
          final source = titleParts.length > 1
              ? titleParts.last
              : 'Google News';
          final enclosure = item['enclosure'];
          final description = item['description'] as String? ?? '';
          final imageUrl = _firstValidImageUrl([
            item['thumbnail'],
            if (enclosure is Map) enclosure['link'],
            _imageFromHtml(description),
          ]);
          return HealthArticle(
            title: itemTitle,
            description: description,
            source: source,
            url: item['link'] as String? ?? '',
            imageUrl: imageUrl,
          );
        })
        .where(
          (article) =>
              article.url.isNotEmpty &&
              Uri.tryParse(article.url)?.scheme == 'https',
        )
        .toList();
  }

  void close() => _client.close();
}

String? _firstValidImageUrl(Iterable<Object?> candidates) {
  for (final candidate in candidates) {
    if (candidate is! String || candidate.trim().isEmpty) continue;
    final value = candidate.trim().replaceAll('&amp;', '&');
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _imageFromHtml(String html) => RegExp(
  r"""<img[^>]+src=['"]([^'"]+)['"]""",
  caseSensitive: false,
).firstMatch(html)?.group(1);

class NewsRequestException implements Exception {
  const NewsRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final NewsApiService _service = NewsApiService();
  late Future<List<HealthArticle>> _articles;

  @override
  void initState() {
    super.initState();
    _articles = _service.fetchHealthNews();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  void _reload() {
    setState(() => _articles = _service.fetchHealthNews());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                const FeatureHeroIcon(
                  tag: 'Health news',
                  icon: Icons.newspaper_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Health news',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'Latest health headlines · India',
              style: TextStyle(color: _muted),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<HealthArticle>>(
              future: _articles,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _NewsError(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }
                final articles = snapshot.data ?? const <HealthArticle>[];
                if (articles.isEmpty) {
                  return _NewsError(
                    message: 'No health headlines are available right now.',
                    onRetry: _reload,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _Reveal(
                      key: ValueKey('article-${articles[index].url}'),
                      delay: Duration(milliseconds: 45 * (index % 5)),
                      duration: const Duration(milliseconds: 380),
                      child: _ArticleCard(article: articles[index]),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'News is for general information only and is not medical advice.',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsError extends StatelessWidget {
  const _NewsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: _teal),
            const SizedBox(height: 12),
            Text(
              'Headlines unavailable',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final HealthArticle article;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openArticle(context, article.url),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: article.imageUrl == null
                      ? const _NewsImagePlaceholder()
                      : Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const _NewsImagePlaceholder(),
                          errorBuilder: (_, _, _) =>
                              const _NewsImagePlaceholder(),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.article_outlined, size: 15, color: _teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      article.source,
                      style: TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Read article',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 14, color: _muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: _surfaceRaised,
    alignment: Alignment.center,
    child: Icon(Icons.image_outlined, size: 36, color: _muted),
  );
}

Future<void> _openArticle(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This article link is not valid.')),
    );
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No browser app could open the article.');
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to open article: $error')));
  }
}

class FirstAidPage extends StatelessWidget {
  const FirstAidPage({super.key});

  static const _guides = [
    _AidGuide(
      icon: Icons.bloodtype_outlined,
      title: 'Minor bleeding',
      summary: 'Apply firm, steady pressure with clean gauze.',
      details:
          'Use clean gauze or cloth and apply steady direct pressure. '
          'If bleeding is severe, does not stop, or the wound is deep, '
          'call emergency services immediately. Do not remove an embedded object.',
    ),
    _AidGuide(
      icon: Icons.local_fire_department_outlined,
      title: 'Minor burns',
      summary: 'Cool the area under clean, cool running water.',
      details:
          'Cool a minor burn under clean, cool running water for 20 minutes. '
          'Do not use ice, butter, or creams. Seek urgent medical help for '
          'large, deep, facial, or chemical/electrical burns.',
    ),
    _AidGuide(
      icon: Icons.air_outlined,
      title: 'Choking',
      summary: 'Call for help if the person cannot breathe or speak.',
      details:
          'If someone cannot cough, breathe, or speak, call emergency services '
          'and follow instructions from the dispatcher. If they become '
          'unresponsive, begin CPR only if you are trained or guided to do so.',
    ),
    _AidGuide(
      icon: Icons.sick_outlined,
      title: 'Feeling faint',
      summary: 'Help them lie down safely and monitor their breathing.',
      details:
          'Help the person lie down in a safe place and loosen tight clothing. '
          'Do not give food or drink if they are unconscious or not fully alert. '
          'Call emergency services if they do not recover quickly or have '
          'chest pain, trouble breathing, or an injury.',
    ),
  ];

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
                tag: 'First-aid guide',
                icon: Icons.medical_services_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'First aid',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Simple guidance for common situations',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.tertiary.withValues(alpha: .24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These tips are not a substitute for professional care. '
                    'For a serious or life-threatening emergency in India, call 112.',
                    style: TextStyle(
                      color: colors.onTertiaryContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._guides.indexed.map(
            (entry) => _Reveal(
              key: ValueKey('aid-${entry.$2.title}'),
              delay: Duration(milliseconds: 55 * entry.$1),
              duration: const Duration(milliseconds: 400),
              child: _AidCard(guide: entry.$2),
            ),
          ),
        ],
      ),
    );
  }
}

class _AidGuide {
  const _AidGuide({
    required this.icon,
    required this.title,
    required this.summary,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String summary;
  final String details;
}

class _AidCard extends StatelessWidget {
  const _AidCard({required this.guide});

  final _AidGuide guide;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _surfaceRaised,
          child: Icon(guide.icon, color: _teal),
        ),
        title: Text(
          guide.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          guide.summary,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: [
          Text(guide.details, style: TextStyle(color: _ink, height: 1.45)),
        ],
      ),
    );
  }
}
