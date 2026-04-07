import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/welcome_toast.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static const _accent = Color(0xFFFF5F15);
  static const _slate = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'CLIENT';

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Splits "John Doe Smith" → firstName: "John", lastName: "Doe Smith".
  /// Single-word names map to firstName with an empty lastName.
  (String firstName, String lastName) _splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], '');
    return (parts.first, parts.skip(1).join(' '));
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    final regex = RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid Pakistani mobile number';
    }
    return null;
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 2) return 'Enter your full name';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final (firstName, lastName) = _splitFullName(_fullNameController.text);
    await ref.read(registerNotifierProvider.notifier).register(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          firstName: firstName,
          lastName: lastName,
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerNotifierProvider, (previous, state) {
      if (state is AsyncError) {
        final failure = state.error;
        final message =
            failure is Failure ? failure.userMessage : 'Registration failed';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      // Show welcome toast exactly once: when loading → data transition
      if (previous?.isLoading == true && state is AsyncData) {
        final (firstName, _) = _splitFullName(_fullNameController.text);
        showWelcomeToast(context, firstName);
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
                        'assets/images/easyrepair_logo.png',
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
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
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
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 1. Phone ────────────────────────────────────────
                      AuthTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        hint: '03XXXXXXXXX',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 16),

                      // ── 2. Full name ────────────────────────────────────
                      AuthTextField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        hint: 'e.g. Ahmed Khan',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: _validateFullName,
                      ),
                      const SizedBox(height: 16),

                      // ── 3. Password ─────────────────────────────────────
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),

                      // ── 4. Role selector ────────────────────────────────
                      _RoleSectionLabel(),
                      const SizedBox(height: 10),
                      _RoleSelector(
                        selected: _selectedRole,
                        onChanged: (role) =>
                            setState(() => _selectedRole = role),
                      ),
                      const SizedBox(height: 28),

                      // ── Submit ──────────────────────────────────────────
                      _PrimaryButton(
                        label: 'Create Account',
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 24),
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

class _RoleSectionLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'I am joining as',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleButton(
            role: 'CLIENT',
            label: 'Client',
            icon: Icons.handyman_outlined,
            description: 'I need repairs',
            isSelected: selected == 'CLIENT',
            onTap: () => onChanged('CLIENT'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleButton(
            role: 'WORKER',
            label: 'Worker',
            icon: Icons.construction_outlined,
            description: 'I do repairs',
            isSelected: selected == 'WORKER',
            onTap: () => onChanged('WORKER'),
          ),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  static const _accent = Color(0xFFFF5F15);
  static const _border = Color(0xFFE2E8F0);

  final String role;
  final String label;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.role,
    required this.label,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _accent : _border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x33FF5F15),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white.withAlpha(200)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          backgroundColor: const Color(0xFFFF5F15),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor: const Color(0xFFFF5F15).withAlpha(150),
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
