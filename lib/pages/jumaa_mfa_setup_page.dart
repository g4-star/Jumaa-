import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/mfa_service.dart';

class JUMAAMFASetupPage extends StatefulWidget {
  const JUMAAMFASetupPage({super.key});

  @override
  State<JUMAAMFASetupPage> createState() => _JUMAAMFASetupPageState();
}

class _JUMAAMFASetupPageState extends State<JUMAAMFASetupPage> {
  final MFAService _mfa = MFAService.instance;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _verifying = false;
  bool _obscureSecret = true;

  String? _factorId;
  String? _qrCode;
  String? _secret;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    try {
      final response = await _mfa.enroll();

      if (response.totp == null) {
        throw Exception('Supabase did not return TOTP enrollment data.');
      }

      if (!mounted) return;

      setState(() {
        _factorId = response.id;
        _qrCode = response.totp!.qrCode;
        _secret = response.totp!.secret;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError('Unable to start 2FA setup: $e');
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      _showError('Enter the 6-digit code from your authenticator app.');
      return;
    }

    final factorId = _factorId;

    if (factorId == null) {
      _showError('MFA setup is not ready yet.');
      return;
    }

    setState(() {
      _verifying = true;
    });

    try {
      await _mfa.verifyEnrollment(
        factorId: factorId,
        code: code,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _verifying = false;
      });

      _showError(
        'Invalid authentication code. Make sure the code is current and try again.',
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

  Future<void> _copySecret() async {
    final secret = _secret;

    if (secret == null) return;

    await Clipboard.setData(
      ClipboardData(text: secret),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secret key copied.'),
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
          title: const Text('Secure Your JUMAA Account'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _qrCode == null
                  ? _buildErrorState()
                  : _buildSetupContent(),
        ),
      ),
    );
  }

  Widget _buildSetupContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enable Two-Factor Authentication',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your first login requires setting up an authenticator app. '
                'This adds an extra layer of security to your JUMAA account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              _buildStep(
                number: '1',
                title: 'Open your authenticator app',
                description:
                    'Use Google Authenticator, Microsoft Authenticator, Authy, or another TOTP-compatible app.',
              ),

              _buildStep(
                number: '2',
                title: 'Scan this QR code',
                description:
                    'Add JUMAA to your authenticator by scanning the QR code below.',
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Colors.black.withValues(alpha: 0.07),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SvgPicture.string(
                    _qrCode!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Can’t scan the QR code?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter this setup key manually in your authenticator app.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                readOnly: true,
                obscureText: _obscureSecret,
                controller: TextEditingController(text: _secret),
                decoration: InputDecoration(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Show secret',
                        onPressed: () {
                          setState(() {
                            _obscureSecret = !_obscureSecret;
                          });
                        },
                        icon: Icon(
                          _obscureSecret
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy secret',
                        onPressed: _copySecret,
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _buildStep(
                number: '3',
                title: 'Enter your 6-digit code',
                description:
                    'Your authenticator app will generate a new code every few seconds.',
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: const TextStyle(
                  fontSize: 28,
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

              const SizedBox(height: 18),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
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

              const SizedBox(height: 14),

              Text(
                'You must complete 2FA setup before accessing your JUMAA dashboard.',
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
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              '2FA setup could not be started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                });
                _startEnrollment();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
