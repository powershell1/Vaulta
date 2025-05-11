import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaulta/main.dart';
import 'dart:ui';

class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({Key? key}) : super(key: key);

  @override
  _PasscodeScreenState createState() => _PasscodeScreenState();
}

class PasscodeDisplay extends StatelessWidget {
  final bool isInput;

  const PasscodeDisplay({Key? key, required this.isInput}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isInput ? Theme.of(context).primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              isInput ? Theme.of(context).primaryColor : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: isInput
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passcodeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _isPasscodeValid(String passcode) async {
    // Simulate a network call or database check
    await Future.delayed(const Duration(seconds: 1));
    return passcode ==
        '123456'; // Replace with your actual passcode validation logic
  }

  Future<void> checkPasscode(String passcode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await _isPasscodeValid(passcode);

      if (isValid) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        _animationController
            .forward()
            .then((_) => _animationController.reverse());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid passcode. Please try again.'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.redAccent,
            margin: const EdgeInsets.all(16),
          ),
        );
        _passcodeController.clear();
        FocusScope.of(context).requestFocus(_focusNode);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
      body: SizedBox(
        height: screenHeight,
        child: Stack(
          children: [
            // Background elements (unchanged)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(
              height: screenHeight - keyboardHeight,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animation.value,
                    child: child,
                  );
                },
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 40),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isLoading
                                  ? SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                theme.colorScheme.primary),
                                      ),
                                    )
                                  : Icon(
                                      Icons.lock_rounded,
                                      size: 48,
                                      color: theme.colorScheme.primary,
                                    ),
                              const SizedBox(height: 6),
                              Text(
                                _isLoading
                                    ? 'Verifying passcode...'
                                    : 'Enter Passcode',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(6, (index) {
                                  return PasscodeDisplay(
                                    isInput:
                                        index < _passcodeController.text.length,
                                  );
                                }),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Enter your 6-digit passcode',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _passcodeController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) {
                  value = value.replaceAll(RegExp(r'[^0-9]'), '');
                  _passcodeController.value = TextEditingValue(
                    text: value,
                    selection: TextSelection.collapsed(offset: value.length),
                  );
                  setState(() {
                    if (value.length == 6 && !_isLoading) {
                      checkPasscode(value);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
