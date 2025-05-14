import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class LibOQS {
  static DynamicLibrary? _lib;

  static DynamicLibrary _loadLib() {
    if (_lib != null) return _lib!;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('liboqs.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    return _lib!;
  }

  // Get all supported signature algorithms
  static List<String> getSignatureAlgorithms() {
    final lib = _loadLib();

    // Get number of signature algorithms
    final getNumSigsFunc = lib.lookupFunction<Int32 Function(), int Function()>(
        'OQS_SIG_alg_count'
    );
    final numSigs = getNumSigsFunc();

    // Get each algorithm name
    final getSigNameFunc = lib.lookupFunction<Pointer<Utf8> Function(Int32), Pointer<Utf8> Function(int)>(
        'OQS_SIG_alg_identifier'
    );

    final algorithms = <String>[];
    for (int i = 0; i < numSigs; i++) {
      final namePtr = getSigNameFunc(i);
      algorithms.add(namePtr.toDartString());
    }

    return algorithms;
  }

  // Generate a signature key pair using the specified algorithm
  static Map<String, List<int>> generateSignatureKeyPair(String algorithm) {
    final lib = _loadLib();

    // Create signature object
    final createSigFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_SIG_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final sigPtr = createSigFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (sigPtr.address == 0) {
      throw Exception('Failed to create signature object for $algorithm');
    }

    try {
      // Try to access through the SIG struct fields directly or use hardcoded defaults
      // based on algorithm type (not ideal but works as fallback)
      int pubKeyLen = 2048; // Conservative default
      int secretKeyLen = 4096; // Conservative default

      // Try Dilithium values when possible (adjust as needed for your target algorithm)
      if (algorithm.contains('Dilithium')) {
        if (algorithm.contains('2')) {
          pubKeyLen = 1312;
          secretKeyLen = 2528;
        } else if (algorithm.contains('3')) {
          pubKeyLen = 1952;
          secretKeyLen = 4000;
        } else if (algorithm.contains('5')) {
          pubKeyLen = 2592;
          secretKeyLen = 4864;
        }
      } else if (algorithm.contains('Falcon')) {
        if (algorithm.contains('512')) {
          pubKeyLen = 897;
          secretKeyLen = 1281;
        } else if (algorithm.contains('1024')) {
          pubKeyLen = 1793;
          secretKeyLen = 2305;
        }
      }

      // Allocate memory for keys
      final pubKeyPtr = calloc<Uint8>(pubKeyLen);
      final secretKeyPtr = calloc<Uint8>(secretKeyLen);

      try {
        // Generate keypair
        final keypairFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>)
        >('OQS_SIG_keypair');

        final result = keypairFunc(sigPtr, pubKeyPtr, secretKeyPtr);
        if (result != 0) {
          throw Exception('Failed to generate key pair: error code $result');
        }

        // Convert to Dart lists
        final pubKey = List<int>.generate(pubKeyLen, (i) => pubKeyPtr[i]);
        final secretKey = List<int>.generate(secretKeyLen, (i) => secretKeyPtr[i]);

        return {
          'publicKey': pubKey,
          'secretKey': secretKey,
        };
      } finally {
        calloc.free(pubKeyPtr);
        calloc.free(secretKeyPtr);
      }
    } finally {
      // Free signature object
      final freeSigFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_SIG_free');

      freeSigFunc(sigPtr);
    }
  }

  // Sign a message
  static List<int> signMessage(String algorithm, List<int> message, List<int> secretKey) {
    final lib = _loadLib();

    // Create signature object
    final createSigFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_SIG_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final sigPtr = createSigFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (sigPtr.address == 0) {
      throw Exception('Failed to create signature object for $algorithm');
    }

    try {
      // Use hardcoded signature lengths based on algorithm
      int sigLen = 4096; // Conservative default

      // Set more accurate values for known algorithms
      if (algorithm.contains('Dilithium')) {
        if (algorithm.contains('2')) {
          sigLen = 2420;
        } else if (algorithm.contains('3')) {
          sigLen = 3293;
        } else if (algorithm.contains('5')) {
          sigLen = 4595;
        }
      } else if (algorithm.contains('Falcon')) {
        if (algorithm.contains('512')) {
          sigLen = 666;
        } else if (algorithm.contains('1024')) {
          sigLen = 1280;
        }
      }

      // Prepare buffers
      final msgPtr = calloc<Uint8>(message.length);
      final secretKeyPtr = calloc<Uint8>(secretKey.length);
      final sigPtr2 = calloc<Uint8>(sigLen);
      final lenPtr = calloc<Size>();

      try {
        // Copy data to native buffers
        for (int i = 0; i < message.length; i++) {
          msgPtr[i] = message[i];
        }

        for (int i = 0; i < secretKey.length; i++) {
          secretKeyPtr[i] = secretKey[i];
        }

        // Sign message
        final signFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Size>, Pointer<Uint8>, Size, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Size>, Pointer<Uint8>, int, Pointer<Uint8>)
        >('OQS_SIG_sign');

        final result = signFunc(sigPtr, sigPtr2, lenPtr, msgPtr, message.length, secretKeyPtr);
        if (result != 0) {
          throw Exception('Failed to sign message: error code $result');
        }

        // Convert to Dart list
        final actualLen = lenPtr.value;
        final signature = List<int>.generate(actualLen, (i) => sigPtr2[i]);

        return signature;
      } finally {
        calloc.free(msgPtr);
        calloc.free(secretKeyPtr);
        calloc.free(sigPtr2);
        calloc.free(lenPtr);
      }
    } finally {
      // Free signature object
      final freeSigFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_SIG_free');

      freeSigFunc(sigPtr);
    }
  }

  // Verify a signature
  static bool verifySignature(String algorithm, List<int> message, List<int> signature, List<int> publicKey) {
    final lib = _loadLib();

    // Create signature object
    final createSigFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_SIG_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final sigPtr = createSigFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (sigPtr.address == 0) {
      throw Exception('Failed to create signature object for $algorithm');
    }

    try {
      // Prepare buffers
      final msgPtr = calloc<Uint8>(message.length);
      final sigPtr2 = calloc<Uint8>(signature.length);
      final pubKeyPtr = calloc<Uint8>(publicKey.length);

      try {
        // Copy data to native buffers
        for (int i = 0; i < message.length; i++) {
          msgPtr[i] = message[i];
        }

        for (int i = 0; i < signature.length; i++) {
          sigPtr2[i] = signature[i];
        }

        for (int i = 0; i < publicKey.length; i++) {
          pubKeyPtr[i] = publicKey[i];
        }

        // Verify signature
        final verifyFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Size, Pointer<Uint8>, Size, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>)
        >('OQS_SIG_verify');

        final result = verifyFunc(sigPtr, msgPtr, message.length, sigPtr2, signature.length, pubKeyPtr);

        // Return true if verification succeeded (result == 0)
        return result == 0;
      } finally {
        calloc.free(msgPtr);
        calloc.free(sigPtr2);
        calloc.free(pubKeyPtr);
      }
    } finally {
      // Free signature object
      final freeSigFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_SIG_free');

      freeSigFunc(sigPtr);
    }
  }

  // Get all supported KEM algorithms
  static List<String> getKEMAlgorithms() {
    final lib = _loadLib();

    // Get number of KEM algorithms
    final getNumKemsFunc = lib.lookupFunction<Int32 Function(), int Function()>(
        'OQS_KEM_alg_count'
    );
    final numKems = getNumKemsFunc();

    // Get each algorithm name
    final getKemNameFunc = lib.lookupFunction<Pointer<Utf8> Function(Int32), Pointer<Utf8> Function(int)>(
        'OQS_KEM_alg_identifier'
    );

    final algorithms = <String>[];
    for (int i = 0; i < numKems; i++) {
      final namePtr = getKemNameFunc(i);
      algorithms.add(namePtr.toDartString());
    }

    return algorithms;
  }

// Generate a KEM key pair using the specified algorithm
  static Map<String, List<int>> generateKEMKeyPair(String algorithm) {
    final lib = _loadLib();

    // Create KEM object
    final createKemFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_KEM_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final kemPtr = createKemFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (kemPtr.address == 0) {
      throw Exception('Failed to create KEM object for $algorithm');
    }

    try {
      // Hardcoded key lengths based on algorithm
      int pubKeyLen = 1568; // Default for Kyber512
      int secretKeyLen = 2368; // Default for Kyber512

      if (algorithm.contains('Kyber')) {
        if (algorithm.contains('512')) {
          pubKeyLen = 800;
          secretKeyLen = 1632;
        } else if (algorithm.contains('768')) {
          pubKeyLen = 1184;
          secretKeyLen = 2400;
        } else if (algorithm.contains('1024')) {
          pubKeyLen = 1568;
          secretKeyLen = 3168;
        }
      } else if (algorithm.contains('NTRU')) {
        pubKeyLen = 1138;
        secretKeyLen = 1450;
      }

      // Allocate memory for keys
      final pubKeyPtr = calloc<Uint8>(pubKeyLen);
      final secretKeyPtr = calloc<Uint8>(secretKeyLen);

      try {
        // Generate keypair
        final keypairFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>)
        >('OQS_KEM_keypair');

        final result = keypairFunc(kemPtr, pubKeyPtr, secretKeyPtr);
        if (result != 0) {
          throw Exception('Failed to generate KEM key pair: error code $result');
        }

        // Convert to Dart lists
        final pubKey = List<int>.generate(pubKeyLen, (i) => pubKeyPtr[i]);
        final secretKey = List<int>.generate(secretKeyLen, (i) => secretKeyPtr[i]);

        return {
          'publicKey': pubKey,
          'secretKey': secretKey,
        };
      } finally {
        calloc.free(pubKeyPtr);
        calloc.free(secretKeyPtr);
      }
    } finally {
      // Free KEM object
      final freeKemFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_KEM_free');

      freeKemFunc(kemPtr);
    }
  }

// Encapsulate (encrypt) a shared secret using the recipient's public key
  static Map<String, List<int>> encapsulate(String algorithm, List<int> publicKey) {
    final lib = _loadLib();

    // Create KEM object
    final createKemFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_KEM_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final kemPtr = createKemFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (kemPtr.address == 0) {
      throw Exception('Failed to create KEM object for $algorithm');
    }

    try {
      // Hardcoded lengths based on algorithm
      int ciphertextLen = 1088; // Default for Kyber512
      int sharedSecretLen = 32;  // Usually fixed at 32 bytes

      if (algorithm.contains('Kyber')) {
        if (algorithm.contains('512')) {
          ciphertextLen = 768;
        } else if (algorithm.contains('768')) {
          ciphertextLen = 1088;
        } else if (algorithm.contains('1024')) {
          ciphertextLen = 1568;
        }
      } else if (algorithm.contains('NTRU')) {
        ciphertextLen = 1138;
      }

      // Prepare buffers
      final pubKeyPtr = calloc<Uint8>(publicKey.length);
      final ciphertextPtr = calloc<Uint8>(ciphertextLen);
      final sharedSecretPtr = calloc<Uint8>(sharedSecretLen);

      try {
        // Copy public key to native buffer
        for (int i = 0; i < publicKey.length; i++) {
          pubKeyPtr[i] = publicKey[i];
        }

        // Encapsulate shared secret
        final encapsulateFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>)
        >('OQS_KEM_encaps');

        final result = encapsulateFunc(kemPtr, ciphertextPtr, sharedSecretPtr, pubKeyPtr);
        if (result != 0) {
          throw Exception('Failed to encapsulate shared secret: error code $result');
        }

        // Convert to Dart lists
        final ciphertext = List<int>.generate(ciphertextLen, (i) => ciphertextPtr[i]);
        final sharedSecret = List<int>.generate(sharedSecretLen, (i) => sharedSecretPtr[i]);

        return {
          'ciphertext': ciphertext,
          'sharedSecret': sharedSecret,
        };
      } finally {
        calloc.free(pubKeyPtr);
        calloc.free(ciphertextPtr);
        calloc.free(sharedSecretPtr);
      }
    } finally {
      // Free KEM object
      final freeKemFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_KEM_free');

      freeKemFunc(kemPtr);
    }
  }

// Decapsulate (decrypt) a shared secret using the recipient's secret key
  static List<int> decapsulate(String algorithm, List<int> ciphertext, List<int> secretKey) {
    final lib = _loadLib();

    // Create KEM object
    final createKemFunc = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)
    >('OQS_KEM_new');

    final algorithmUtf8 = algorithm.toNativeUtf8();
    final kemPtr = createKemFunc(algorithmUtf8);
    malloc.free(algorithmUtf8);

    if (kemPtr.address == 0) {
      throw Exception('Failed to create KEM object for $algorithm');
    }

    try {
      // Shared secret length (usually fixed at 32 bytes)
      final int sharedSecretLen = 32;

      // Prepare buffers
      final ciphertextPtr = calloc<Uint8>(ciphertext.length);
      final secretKeyPtr = calloc<Uint8>(secretKey.length);
      final sharedSecretPtr = calloc<Uint8>(sharedSecretLen);

      try {
        // Copy data to native buffers
        for (int i = 0; i < ciphertext.length; i++) {
          ciphertextPtr[i] = ciphertext[i];
        }

        for (int i = 0; i < secretKey.length; i++) {
          secretKeyPtr[i] = secretKey[i];
        }

        // Decapsulate shared secret
        final decapsulateFunc = lib.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>),
            int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>)
        >('OQS_KEM_decaps');

        final result = decapsulateFunc(kemPtr, sharedSecretPtr, ciphertextPtr, secretKeyPtr);
        if (result != 0) {
          throw Exception('Failed to decapsulate shared secret: error code $result');
        }

        // Convert to Dart list
        final sharedSecret = List<int>.generate(sharedSecretLen, (i) => sharedSecretPtr[i]);
        return sharedSecret;
      } finally {
        calloc.free(ciphertextPtr);
        calloc.free(secretKeyPtr);
        calloc.free(sharedSecretPtr);
      }
    } finally {
      // Free KEM object
      final freeKemFunc = lib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
      >('OQS_KEM_free');

      freeKemFunc(kemPtr);
    }
  }
}