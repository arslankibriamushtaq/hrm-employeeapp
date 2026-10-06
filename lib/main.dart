import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await Session.load();
  runApp(EmployeeApp(session: session));
}

class EmployeeApp extends StatefulWidget {
  const EmployeeApp({super.key, required this.session});

  final Session session;

  @override
  State<EmployeeApp> createState() => _EmployeeAppState();
}

class _EmployeeAppState extends State<EmployeeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late bool _wasLoggedIn = widget.session.isLoggedIn;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// On sign-out (manual or an expired token) drop any pushed screens so the login
  /// screen is not hidden underneath them.
  void _onSessionChanged() {
    final loggedIn = widget.session.isLoggedIn;
    if (_wasLoggedIn && !loggedIn) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    _wasLoggedIn = loggedIn;
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5), brightness: brightness),
        cardTheme: const CardTheme(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: widget.session,
      child: MaterialApp(
        title: 'HR Employee',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) =>
              widget.session.isLoggedIn ? const HomeShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
