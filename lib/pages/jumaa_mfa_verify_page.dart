import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mfa_service.dart';

class JUMAAMFAVerifyPage extends StatefulWidget {
  const JUMAAMFAVerifyPage({super.key});

  @override
  State<JUMAAMFAVerifyPage> createState() => _JUMAAMFAVerifyPageState();
}

class _JUMAAMFAVerifyPageState extends State<JUMAAMFAVerifyPage> {
  final MFAService _mfa = MFAService.instance;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      _showError('Enter the 6-digit authentication code.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final factor = await _mfa.getVerifiedFactor();

      if (factor == null) {
        throw Exception('No verified authenticator was found.');
      }

      await _mfa.verifyLogin(
        factorId: factor.id,
        code: code,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        'Invalid authentication code. Please check your authenticator app and try again.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Two-Factor Authentication'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.security,
                      size: 70,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Verify Your Identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Open your authenticator app and enter the '
                      '6-digit JUMAA verification code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your account will remain locked until this code is verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
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
