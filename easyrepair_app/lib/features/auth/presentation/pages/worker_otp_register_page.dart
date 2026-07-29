import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../worker/presentation/providers/worker_providers.dart'
    show categoriesProvider;
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_otp_providers.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input_section.dart';

/// Redesigned Ustaad registration — full CNIC name, OTP-verified phone,
/// password (kept for fallback login), and a dynamically-loaded skill
/// dropdown (no hardcoded categories/IDs).
class WorkerOtpRegisterPage extends ConsumerStatefulWidget {
  const WorkerOtpRegisterPage({super.key});

  @override
  ConsumerState<WorkerOtpRegisterPage> createState() =>
      _WorkerOtpRegisterPageState();
}

class _WorkerOtpRegisterPageState
    extends ConsumerState<WorkerOtpRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _selectedCategoryId;
  String? _skillError;
  String _otp = '';
  bool _sendInFlight = false;
  bool _registerInFlight = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Poora naam likhein.';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number likhein.';
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
      return 'Sahi Pakistani mobile number likhein.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password likhein.';
    if (value.length < 8) {
      return 'Password kam az kam 8 characters ka hona chahiye.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (_sendInFlight) return;
    final nameError = _validateName(_nameCtrl.text);
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (nameError != null || phoneError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(nameError ?? phoneError!)));
      return;
    }
    setState(() => _sendInFlight = true);
    try {
      await ref
          .read(otpRequestNotifierProvider.notifier)
          .request(_phoneCtrl.text.trim(), OtpPurpose.workerRegister);
    } finally {
      if (mounted) setState(() => _sendInFlight = false);
    }
  }

  Future<void> _register() async {
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _skillError = _selectedCategoryId == null ? 'Skill select karein.' : null;
    });
    if (!formValid || _skillError != null || _otp.length != 6 || _registerInFlight) {
      return;
    }
    setState(() => _registerInFlight = true);
    try {
      await ref.read(workerOtpRegisterNotifierProvider.notifier).register(
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            otp: _otp,
            password: _passwordCtrl.text,
            categoryId: _selectedCategoryId!,
          );
    } finally {
      if (mounted) setState(() => _registerInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workerOtpRegisterNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Account nahi ban saka.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    ref.listen(otpRequestNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message = failure is Failure ? failure.message : 'Code bhejne mein masla hua.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final expiresAt = ref.watch(otpRequestNotifierProvider).valueOrNull;
    final showOtp = expiresAt != null;
    final registerState = ref.watch(workerOtpRegisterNotifierProvider);
    final hasOtpError = registerState is AsyncError;
    final categoriesAsync = ref.watch(categoriesProvider);

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: viewInsets + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isSmall ? 16 : 28),
                            AuthHeader(
                              title: 'Naya Ustaad account\nbanayein',
                              subtitle: 'HandyGo par apna naya account banayein.',
                              isSmall: isSmall,
                              showBackButton: true,
                            ),
                            SizedBox(height: isSmall ? 20 : 32),
                            const Text(
                              'Apne CNIC wala poora naam dalain',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: kAuthGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AuthTextField(
                              controller: _nameCtrl,
                              label: 'Poora naam',
                              hint: 'Muhammad Ali Khan',
                              prefixIcon: Icons.badge_outlined,
                              validator: _validateName,
                              enabled: !showOtp,
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _phoneCtrl,
                              label: 'Mobile number',
                              hint: '03XXXXXXXXX',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              validator: _validatePhone,
                              enabled: !showOtp,
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _passwordCtrl,
                              label: 'Password banayein',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: true,
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Apni skill select karein',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kAuthDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            categoriesAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kAuthAccent,
                                    ),
                                  ),
                                ),
                              ),
                              error: (e, _) => const Text(
                                'Skills load nahi ho sakin. Dobara koshish karein.',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12.5,
                                ),
                              ),
                              data: (categories) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kAuthBorder),
                                  color: kAuthBg,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategoryId,
                                    isExpanded: true,
                                    hint: const Text(
                                      'Skill select karein',
                                      style: TextStyle(
                                        color: kAuthGray,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(
                                              c.name,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _selectedCategoryId = v;
                                      _skillError = null;
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            if (_skillError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _skillError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (showOtp) ...[
                              const SizedBox(height: 24),
                              OtpInputSection(
                                expiresAt: expiresAt,
                                hasError: hasOtpError,
                                resendInFlight: _sendInFlight,
                                onChanged: (v) => setState(() => _otp = v),
                                onCompleted: (v) => setState(() => _otp = v),
                                onResend: _sendCode,
                              ),
                            ],
                            SizedBox(height: isSmall ? 20 : 28),
                            AuthPrimaryButton(
                              label: showOtp ? 'Account Banayein' : 'Code Bhejein',
                              isLoading: showOtp ? _registerInFlight : _sendInFlight,
                              onPressed: showOtp
                                  ? (_otp.length == 6 ? _register : null)
                                  : _sendCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
