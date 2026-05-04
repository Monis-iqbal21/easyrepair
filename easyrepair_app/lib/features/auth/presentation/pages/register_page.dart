import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static const _accent = Color(0xFF1D9E75);
  static const _slate = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'CLIENT';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final regex = RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid Pakistani mobile number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(registerNotifierProvider.notifier).register(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerNotifierProvider, (_, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message =
            failure is Failure ? failure.userMessage : 'Registration failed';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final isLoading = ref.watch(registerNotifierProvider).isLoading;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: _accent,
      body: Column(
        children: [
          // ── Branded header ────────────────────────────────────────────────
          SizedBox(
            height: screenHeight * 0.32,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/er-icon.png',
                        height: 56,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'EASYREPAIR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create\naccount',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Join EasyRepair and get started today',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha(190),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form panel ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Name row ───────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: AuthTextField(
                              controller: _firstNameController,
                              label: 'First Name',
                              hint: 'Ali',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) =>
                                  _validateRequired(v, 'First name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AuthTextField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              hint: 'Khan',
                              validator: (v) =>
                                  _validateRequired(v, 'Last name'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Phone ──────────────────────────────────────────────
                      AuthTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        hint: '03XXXXXXXXX',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),

                      // ── Password ───────────────────────────────────────────
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),

                      // ── Role picker ────────────────────────────────────────
                      _RolePicker(
                        selected: _selectedRole,
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                      const SizedBox(height: 30),

                      // ── Submit ─────────────────────────────────────────────
                      _PrimaryButton(
                        label: 'Create Account',
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 24),

                      // ── Login link ─────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?  ',
                            style: TextStyle(color: _slate, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/auth/login'),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role picker ───────────────────────────────────────────────────────────────

class _RolePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RolePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I am a…',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RoleOption(
                label: 'Client',
                subtitle: 'Book services',
                icon: Icons.home_repair_service_outlined,
                isSelected: selected == 'CLIENT',
                onTap: () => onChanged('CLIENT'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleOption(
                label: 'Worker',
                subtitle: 'Offer services',
                icon: Icons.handyman_outlined,
                isSelected: selected == 'WORKER',
                onTap: () => onChanged('WORKER'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  static const _accent = Color(0xFF1D9E75);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _accent.withAlpha(20)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _accent : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? _accent : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _accent : const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D9E75),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor:
              const Color(0xFF1D9E75).withAlpha(150),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
