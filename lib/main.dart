import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vaulta/screens/passcode.dart';

// Global navigator key to access navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLifecycleWrapper());
}

// Wrapper to monitor app lifecycle
class AppLifecycleWrapper extends StatefulWidget {
  const AppLifecycleWrapper({Key? key}) : super(key: key);

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> with WidgetsBindingObserver {
  bool _showWhiteScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      setState(() {
        _showWhiteScreen = true;
      });
    }
    if (state == AppLifecycleState.resumed) {

      // When app comes back to foreground, navigate to passcode screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PasscodeScreen()),
              (route) => false,
        );
        setState(() {
          _showWhiteScreen = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showWhiteScreen ? Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
    ) : const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vaulta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PasscodeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaulta'),
      ),
      body: const Center(
        child: Text('Welcome to Vaulta'),
      ),
    );
  }
}