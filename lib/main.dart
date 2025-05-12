import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaulta/screens/chat.dart';
import 'package:vaulta/screens/messagelist.dart';
import 'package:vaulta/screens/passcode.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

// Global navigator key to access navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLifecycleWrapper());
}

// Wrapper to monitor app lifecycle
class AppLifecycleWrapper extends StatefulWidget {
  const AppLifecycleWrapper({super.key});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  bool _showWhiteScreen = false;

  void jailbreakDetection() async {
    bool isJailbreak = await FlutterJailbreakDetection.jailbroken;
    if (isJailbreak) {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else if (Platform.isIOS) {
        exit(0);
      }
    }
  }

  @override
  void initState() {
    jailbreakDetection();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool isHidden = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check for jailbreak detection when the app is resumed
    if (state == AppLifecycleState.hidden) {
      isHidden = true;
    }
    if (state == AppLifecycleState.inactive) {
      setState(() {
        _showWhiteScreen = true;
      });
    }
    if (state == AppLifecycleState.resumed) {
      if (isHidden) {
        isHidden = false;
        jailbreakDetection();
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PasscodeScreen()),
          (route) => false,
        );
      }

      // Reset white screen after navigation
      if (mounted) {
        setState(() {
          _showWhiteScreen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          const MyApp(),
          _showWhiteScreen ? Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
          ) : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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