import 'dart:async';
import 'dart:convert';

import 'package:emergensy/firebase_options.dart';
import 'package:emergensy/services/app_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _ink = Color(0xFFEAF2F7);
const _teal = Color(0xFF55E0C1);
const _pale = Color(0xFF09121C);
const _surface = Color(0xFF121F2B);
const _surfaceRaised = Color(0xFF192938);
const _muted = Color(0xFF9BACB9);
const _border = Color(0xFF263948);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? backendError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    backendError = error;
  }
  runApp(MyApp(backendError: backendError));
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
    return MaterialApp(
      title: 'Emergensy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _pale,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: _teal,
          primary: _teal,
          onPrimary: const Color(0xFF071510),
          surface: _surface,
          onSurface: _ink,
        ),
        cardTheme: CardThemeData(
          color: _surface,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceRaised,
          hintStyle: const TextStyle(color: _muted),
          labelStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _teal, width: 1.5),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _pale,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _surface,
          indicatorColor: _teal.withValues(alpha: .16),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            );
          }),
        ),
      ),
      home: backendError != null
          ? _FirebaseStartupError(error: backendError!)
          : AuthGate(
              authRepository: authRepository ?? FirebaseAuthRepository(),
              dataRepository: dataRepository ?? FirestoreDataRepository(),
            ),
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
            const Icon(Icons.cloud_off_outlined, color: _teal, size: 42),
            const SizedBox(height: 14),
            const Text(
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
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
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
  bool _registering = false;
  bool _working = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_registering && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name to create an account.');
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
        await widget.authRepository.register(
          _nameController.text,
          email,
          password,
        );
      } else {
        await widget.authRepository.signIn(email, password);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 44),
                  Text(
                    _registering ? 'Start here.' : 'Good to see you.',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _registering ? 'Create an account for your care details.' : 'Sign in to access your appointments and lab bookings.',
                    style: const TextStyle(color: _muted, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  if (_registering) ...[
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
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
                      style: const TextStyle(color: Color(0xFFFF8995)),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registering ? 'Create account' : 'Sign in'),
                    ),
                  ),
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
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  final List<ShopProduct> _cart = [];

  void _addToCart(ShopProduct product) {
    setState(() => _cart.add(product));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${product.name} added to cart')));
  }

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onNavigate: _changeTab,
        onEmergency: () => Navigator.of(context).push<void>(
          _EmergencyRoute(user: widget.user, repository: widget.dataRepository),
        ),
        onDoctors: () => Navigator.of(context).push<void>(
          _PageRoute(
            child: DoctorBookingsPage(
              user: widget.user,
              repository: widget.dataRepository,
            ),
          ),
        ),
        onLabs: () => Navigator.of(context).push<void>(
          _PageRoute(
            child: LabTestsPage(
              user: widget.user,
              repository: widget.dataRepository,
            ),
          ),
        ),
        onSignOut: widget.authRepository.signOut,
      ),
      _visitedTabs.contains(1)
          ? ShopPage(
              cart: _cart,
              onAdd: _addToCart,
              onRemove: (product) => setState(() => _cart.remove(product)),
            )
          : const SizedBox.shrink(),
      _visitedTabs.contains(2) ? const NewsPage() : const SizedBox.shrink(),
      _visitedTabs.contains(3) ? const FirstAidPage() : const SizedBox.shrink(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _CartIcon(count: _cart.length),
            selectedIcon: _CartIcon(count: _cart.length, selected: true),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
          const NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'First aid',
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
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             EmergencyRequestPage(user: user, repository: repository),
         transitionDuration: const Duration(milliseconds: 420),
         reverseTransitionDuration: const Duration(milliseconds: 300),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: curved,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0, .035),
                 end: Offset.zero,
               ).animate(curved),
               child: child,
             ),
           );
         },
       );
}

class _PageRoute extends PageRouteBuilder<void> {
  _PageRoute({required Widget child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .025),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(selected ? Icons.shopping_bag : Icons.shopping_bag_outlined),
    );
  }
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

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onNavigate,
    required this.onEmergency,
    required this.onDoctors,
    required this.onLabs,
    required this.onSignOut,
    super.key,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onEmergency;
  final VoidCallback onDoctors;
  final VoidCallback onLabs;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _Reveal(
            child: _BrandHeader(onSignOut: onSignOut, onEmergency: onEmergency),
          ),
          const SizedBox(height: 34),
          const _Reveal(
            delay: Duration(milliseconds: 70),
            child: Text(
              'WHEN IT\nMATTERS.',
              style: TextStyle(
                color: _ink,
                fontSize: 42,
                height: .98,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Reveal(
            delay: Duration(milliseconds: 130),
            child: Text(
              'A clear next step, without the noise.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          _Reveal(
            delay: const Duration(milliseconds: 190),
            child: _EmergencyCard(onCall: onEmergency),
          ),
          const SizedBox(height: 34),
          const _Reveal(
            delay: Duration(milliseconds: 250),
            child: Text(
              'THE USEFUL STUFF',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Reveal(
            delay: const Duration(milliseconds: 300),
            child: _HomeActionButton(
              icon: Icons.medical_services_outlined,
              title: 'First-aid guide',
              subtitle: 'What to do while help is on the way',
              index: '01',
              onTap: () => onNavigate(3),
            ),
          ),
          const SizedBox(height: 9),
          _Reveal(
            delay: const Duration(milliseconds: 360),
            child: _HomeActionButton(
              icon: Icons.shopping_bag_outlined,
              title: 'Health essentials',
              subtitle: 'Basics for your cabinet',
              index: '02',
              onTap: () => onNavigate(1),
            ),
          ),
          const SizedBox(height: 9),
          _Reveal(
            delay: const Duration(milliseconds: 420),
            child: _HomeActionButton(
              icon: Icons.newspaper_outlined,
              title: 'Health news',
              subtitle: 'The latest, in one place',
              index: '03',
              onTap: () => onNavigate(2),
            ),
          ),
          const SizedBox(height: 9),
          _Reveal(
            delay: const Duration(milliseconds: 480),
            child: _HomeActionButton(
              icon: Icons.calendar_month_outlined,
              title: 'Doctor appointments',
              subtitle: 'Online or in-person visit',
              index: '04',
              onTap: onDoctors,
            ),
          ),
          const SizedBox(height: 9),
          _Reveal(
            delay: const Duration(milliseconds: 540),
            child: _HomeActionButton(
              icon: Icons.biotech_outlined,
              title: 'Lab tests & results',
              subtitle: 'Book blood tests and check reports',
              index: '05',
              onTap: onLabs,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Emergensy does not dispatch responders. In India, call 112 '
            'for urgent help. This app does not replace professional care.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HomeActionButton extends StatefulWidget {
  const _HomeActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.index,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String index;
  final VoidCallback onTap;

  @override
  State<_HomeActionButton> createState() => _HomeActionButtonState();
}

class _HomeActionButtonState extends State<_HomeActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _pressed ? _surfaceRaised : _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _pressed ? _teal : _border),
          ),
          child: Row(
            children: [
              Text(
                widget.index,
                style: const TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(widget.icon, size: 19, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
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
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;

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
  String _mode = 'Online';
  String _slot = '10:00 AM';
  bool _saving = false;
  DateTime _date = DateTime.now().add(const Duration(days: 1));

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
    if (date != null) setState(() => _date = date);
  }

  Future<void> _saveRequest() async {
    final patient = _patientController.text.trim();
    if (patient.isEmpty) {
      _showBookingMessage('Add the patient name to continue.');
      return;
    }
    if (_mode == 'In-person' && _areaController.text.trim().isEmpty) {
      _showBookingMessage('Add the city or area for an in-person visit.');
      return;
    }
    final doctor = _doctors[_doctorIndex];
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _FeatureEyebrow(text: 'CARE, ON YOUR TERMS'),
            const SizedBox(height: 10),
            const Text(
              'Talk to a doctor.',
              style: TextStyle(
                color: _ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a video consult or an in-person visit.',
              style: TextStyle(color: _muted),
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
              text:
                  'Requests are stored in your private Firebase account, but are not sent to a clinic. '
                  'A provider integration is needed to confirm appointments.',
            ),
          ],
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
        const Text(
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
          onSelectionChanged: (value) => setState(() => _mode = value.first),
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
            side: const BorderSide(color: _border),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _slots
              .map(
                (slot) => ChoiceChip(
                  label: Text(slot),
                  selected: _slot == slot,
                  onSelected: (_) => setState(() => _slot = slot),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 17),
        TextField(
          controller: _patientController,
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
            return _FeatureRecordCard(
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
                  '${(request['area'] as String? ?? '').isEmpty ? '' : ' · Area: ${request['area']}'}'
                  '${(request['reason'] as String? ?? '').isEmpty ? '' : ' · ${request['reason']}'}',
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
    return Material(
      color: selected ? const Color(0xFF17332F) : _surface,
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
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doctor.specialty} · ${doctor.experience}',
                      style: const TextStyle(color: _muted, fontSize: 11),
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
  const LabTestsPage({required this.user, required this.repository, super.key});

  final AppUser user;
  final AppDataRepository repository;

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
  int _section = 0;
  String _collection = 'Visit a lab';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const _FeatureEyebrow(text: 'TESTING, MADE SIMPLE'),
            const SizedBox(height: 10),
            const Text(
              'Book a lab test.',
              style: TextStyle(
                color: _ink,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick what you need, then choose a collection option.',
              style: TextStyle(color: _muted),
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
            side: const BorderSide(color: _border),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _patientController,
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
            const Text(
              'Your lab bookings',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
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
                    const Text(
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
    return _FeatureRecordCard(
      icon: Icons.fact_check_outlined,
      title: result['testName'] as String? ?? 'Lab result',
      subtitle:
          '$value $unit${referenceRange.isEmpty ? '' : ' · Reference: $referenceRange'}',
      status: result['status'] as String? ?? 'Reported',
      detail:
          'Reported by ${result['labName'] as String? ?? 'authorized lab'}'
          '${result['reportedAt'] == null ? '' : ' · ${result['reportedAt']}'}',
    );
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
    return Text(
      text,
      style: const TextStyle(
        color: _teal,
        fontSize: 10,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _muted, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.45),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF351C27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF633342)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFFD7DC), height: 1.4),
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
    return Material(
      color: selected ? const Color(0xFF17332F) : _surface,
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
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: const TextStyle(color: _muted, fontSize: 11),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: _teal, size: 30),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.45, fontSize: 12),
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
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
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
                  style: const TextStyle(color: _teal, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(subtitle, style: const TextStyle(color: _muted, height: 1.45)),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class EmergencyRequestPage extends StatefulWidget {
  const EmergencyRequestPage({
    required this.user,
    required this.repository,
    super.key,
  });

  final AppUser user;
  final AppDataRepository repository;

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _showGuidance ? _buildGuidance() : _buildRequestForm(),
        ),
      ),
    );
  }

  Widget _buildRequestForm() {
    return ListView(
      key: const ValueKey('request-form'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFF351C27),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF633342)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFF8995)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This app cannot alert an ambulance or hospital directly. '
                  'It prepares your details and connects you to India’s 112 '
                  'emergency line so you can tell the operator.',
                  style: TextStyle(color: Color(0xFFFFD7DC), height: 1.45),
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
            side: const BorderSide(color: _teal),
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
                const Icon(Icons.location_on_outlined, color: _teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location ready · ${_position!.latitude.toStringAsFixed(4)}, '
                    '${_position!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: _ink, fontSize: 12),
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
            style: const TextStyle(color: Color(0xFFFF8995), fontSize: 12),
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
        const Text(
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
            color: const Color(0xFF351C27),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF633342)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.emergency, color: Color(0xFFFF8995)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your details are ready, but have not been sent. Call 112 '
                  'and tell the operator your emergency and location.',
                  style: TextStyle(color: Color(0xFFFFD7DC), height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
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
              backgroundColor: const Color(0xFFFF5265),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'While help is on the way',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
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
          style: const TextStyle(
            color: _teal,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
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
              color: saved ? _teal : const Color(0xFFFF8995),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error == null ? _ink : const Color(0xFFFF8995),
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
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: _ink, height: 1.35)),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              tooltip: 'Open location in maps',
              onPressed: onTap,
              icon: const Icon(Icons.map_outlined, color: _teal),
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
              style: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _ink, height: 1.45),
            ),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.onSignOut, this.onEmergency});

  final VoidCallback? onSignOut;
  final VoidCallback? onEmergency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.health_and_safety, color: _teal),
        ),
        const SizedBox(width: 10),
        const Text(
          'emergensy',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const Spacer(),
        if (onEmergency != null)
          IconButton(
            tooltip: 'Get emergency help',
            onPressed: onEmergency,
            icon: const Icon(Icons.sos_outlined, color: _teal),
          ),
        if (onSignOut != null)
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, color: _muted),
          ),
      ],
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF49303A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.priority_high_rounded, color: Color(0xFFFF7182)),
              SizedBox(width: 8),
              Text(
                'NEED HELP?',
                style: TextStyle(
                  color: Color(0xFFFFA0AA),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Let’s get you to help.',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A few details first. Then we’ll show you what to do.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Get help'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6576),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
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
                const Text(
                  'Health essentials',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Basic first-aid supplies and everyday essentials',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 5),
                const Text(
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
                    onAdd: () => widget.onAdd(product),
                  ),
                );
              },
            ),
          ),
          if (widget.cart.isNotEmpty)
            _CartSummary(
              cart: widget.cart,
              total: total,
              onRemove: widget.onRemove,
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
                      const Icon(Icons.info_outline, size: 16, color: _muted),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.product.description,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '₹${widget.product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
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
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: _teal),
                const SizedBox(width: 8),
                Text(
                  '${cart.length} item${cart.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
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
            const Text(
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
            const Text(
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
            const Text(
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
          final imageUrl =
              item['thumbnail'] as String? ??
              (enclosure is Map ? enclosure['link'] as String? : null);
          return HealthArticle(
            title: itemTitle,
            description: item['description'] as String? ?? '',
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Health news',
              style: TextStyle(
                color: _ink,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
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
          const Padding(
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
            const Icon(Icons.cloud_off_outlined, size: 44, color: _teal),
            const SizedBox(height: 12),
            const Text(
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
              style: const TextStyle(color: _muted, height: 1.4),
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
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    article.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              if (article.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  article.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.article_outlined, size: 15, color: _teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      article.source,
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'Read article',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new, size: 14, color: _muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text(
            'First aid',
            style: TextStyle(
              color: _ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Simple guidance for common situations',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF302719),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFFC66D)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These tips are not a substitute for professional care. '
                    'For a serious or life-threatening emergency in India, call 112.',
                    style: TextStyle(color: Color(0xFFFFE0A8), height: 1.4),
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
        side: const BorderSide(color: _border),
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
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: [
          Text(
            guide.details,
            style: const TextStyle(color: _ink, height: 1.45),
          ),
        ],
      ),
    );
  }
}
