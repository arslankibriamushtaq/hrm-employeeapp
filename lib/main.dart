import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'session.dart';
import 'theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: widget.session,
      child: MaterialApp(
        title: 'MYTM HRM',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        // Light only: the MYTM theme has no dark variant.
        theme: buildAppTheme(),
        home: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) =>
              widget.session.isLoggedIn ? const HomeShell() : const LoginScreen(),
        ),
      ),
    );
  }
}
