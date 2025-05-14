import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaulta/clink/liboqs_binding.dart';
import 'package:vaulta/screens/auth/login.dart';
import 'package:vaulta/screens/chat.dart';
import 'package:vaulta/screens/messagelist.dart';
import 'package:vaulta/screens/passcode.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

// Global navigator key to access navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Encrypt message using shared secret from KEM
List<int> encryptMessage(List<int> sharedSecret, String plainText) {
  // Use first 32 bytes of shared secret for AES-256 key
  final key = encrypt.Key(Uint8List.fromList(sharedSecret.sublist(0, 32)));

  // Generate a random IV (initialization vector)
  final iv = encrypt.IV.fromSecureRandom(16);

  // Create encrypter
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

  // Encrypt
  final encrypted = encrypter.encrypt(plainText, iv: iv);

  // Combine IV and encrypted data for transmission
  return [...iv.bytes, ...encrypted.bytes];
}

// Decrypt message using shared secret from KEM
String decryptMessage(List<int> sharedSecret, List<int> encryptedData) {
  // Extract IV (first 16 bytes) and ciphertext
  final iv = encrypt.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
  final ciphertext = encrypt.Encrypted(Uint8List.fromList(encryptedData.sublist(16)));

  // Use shared secret as key
  final key = encrypt.Key(Uint8List.fromList(sharedSecret.sublist(0, 32)));

  // Create decrypter
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

  // Decrypt
  return encrypter.decrypt(ciphertext, iv: iv);
}

// Complete example with KEM and message encryption
void encryptionExample() {
  // Get available KEM algorithms
  List<String> algorithms = LibOQS.getKEMAlgorithms();
  print("Available KEM algorithms: $algorithms");

  // Choose an algorithm
  String algorithm = "Kyber768";

  // Generate recipient's key pair
  Map<String, List<int>> recipientKeyPair = LibOQS.generateKEMKeyPair(algorithm);

  // Sender encapsulates a shared secret using recipient's public key
  Map<String, List<int>> encapsulationResult =
  LibOQS.encapsulate(algorithm, recipientKeyPair['publicKey']!);

  List<int> ciphertext = encapsulationResult['ciphertext']!;
  List<int> senderSharedSecret = encapsulationResult['sharedSecret']!;

  // Sender encrypts a message with the shared secret
  String messageToSend = "This is a secret quantum-resistant message!";
  List<int> encryptedMessage = encryptMessage(senderSharedSecret, messageToSend);

  // Send both the ciphertext and encrypted message to recipient

  // Recipient decapsulates the shared secret using their secret key
  List<int> recipientSharedSecret =
  LibOQS.decapsulate(algorithm, ciphertext, recipientKeyPair['secretKey']!);

  // Recipient decrypts the message
  String decryptedMessage = decryptMessage(recipientSharedSecret, encryptedMessage);
  print(recipientSharedSecret);
  // print(recipientKeyPair['publicKey']!.length);
  // print(recipientKeyPair['publicKey']![recipientKeyPair['publicKey']!.length - 1]);


  //print("Original message: $messageToSend");
  print("Encrypted message: ${encryptedMessage}");
  print("Decrypted message: ${decryptedMessage.length}");
}

// Helper to compare lists
bool _listsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLifecycleWrapper());
  // Load the native library
  // Get available signature algorithms
  /*
  List<String> sigAlgs = LibOQS.getSignatureAlgorithms();

  print(sigAlgs);
  // Get all available signature algorithms
  List<String> algorithms = LibOQS.getSignatureAlgorithms();
  print("Available algorithms: $algorithms");

// Generate keys using a specific algorithm (e.g., Dilithium2)
  String algorithm = "Dilithium2";
  Map<String, List<int>> keyPair = LibOQS.generateSignatureKeyPair(algorithm);

// Sign a message
  List<int> message = utf8.encode("Hello quantum world");
  List<int> signature = LibOQS.signMessage(algorithm, message, keyPair['secretKey']!);
  print(signature);

// Verify the signature
  bool isValid = LibOQS.verifySignature(algorithm, message, signature, keyPair['publicKey']!);
  print("Signature valid: $isValid");
   */
  encryptionExample();
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
    print('MMMMM');
    print(state);
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