import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../worker/presentation/providers/worker_providers.dart' show categoriesProvider;
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  static const _accent = Color(0xFFDB6234);
  static const _slate = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  String? _selectedCategoryId;
  String? _roleError;
  String? _skillError;

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
    if (!RegExp(r'^(\+92|0092|92|0)?[3][0-9]{9}$').hasMatch(value.trim())) {
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
    final formValid = _formKey.currentState!.validate();

    setState(() {
      _roleError = _selectedRole == null ? 'Please select your role' : null;
      _skillError = (_selectedRole == 'WORKER' && _selectedCategoryId == null)
          ? 'Please select your main skill'
          : null;
    });

    if (!formValid || _roleError != null || _skillError != null) return;

    await ref.read(registerNotifierProvider.notifier).register(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _selectedRole!,
          categoryId: _selectedCategoryId,
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
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final isSmall = mq.size.height < 680;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: viewInsets + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isSmall ? 24 : 40),

                          // ── Header ────────────────────────────────────────
                          _AuthHeader(
                            title: 'Create\naccount',
                            subtitle: 'Join EasyRepair and get started today',
                            isSmall: isSmall,
                          ),

                          SizedBox(height: isSmall ? 24 : 36),

                          // ── Form ──────────────────────────────────────────
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Name row
                                Row(
                                  children: [
                                    Expanded(
                                      child: AuthTextField(
                                        controller: _firstNameController,
                                        label: 'First Name',
                                        hint: 'Ali',
                                        prefixIcon:
                                            Icons.person_outline_rounded,
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
                                const SizedBox(height: 14),

                                AuthTextField(
                                  controller: _phoneController,
                                  label: 'Mobile Number',
                                  hint: '03XXXXXXXXX',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone_outlined,
                                  validator: _validatePhone,
                                ),
                                const SizedBox(height: 14),

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

                                // Role picker
                                _RolePicker(
                                  selected: _selectedRole,
                                  onChanged: (v) => setState(() {
                                    _selectedRole = v;
                                    _roleError = null;
                                    if (v != 'WORKER') {
                                      _selectedCategoryId = null;
                                      _skillError = null;
                                    }
                                  }),
                                ),
                                if (_roleError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _roleError!,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],

                                if (_selectedRole == 'WORKER') ...[
                                  const SizedBox(height: 16),
                                  _MainSkillPicker(
                                    selectedCategoryId: _selectedCategoryId,
                                    onChanged: (id) => setState(() {
                                      _selectedCategoryId = id;
                                      _skillError = null;
                                    }),
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
                                ],
                                const SizedBox(height: 28),

                                _PrimaryButton(
                                  label: 'Create Account',
                                  isLoading: isLoading,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 24),

                                // Login link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Already have an account?  ',
                                      style: TextStyle(
                                          color: _slate, fontSize: 14),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          context.go('/auth/login'),
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
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
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

// ── Shared header (same as login_page) ───────────────────────────────────────

class _AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSmall;

  const _AuthHeader({
    required this.title,
    required this.subtitle,
    required this.isSmall,
  });

  static const _accent = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo-green.png',
              width: isSmall ? 36 : 44,
              height: isSmall ? 36 : 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Handygo',
              style: TextStyle(
                fontSize: isSmall ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: _accent,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmall ? 16 : 24),
        Text(
          title,
          style: TextStyle(
            fontSize: isSmall ? 30 : 36,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ── Role picker ───────────────────────────────────────────────────────────────

class _RolePicker extends StatelessWidget {
  final String? selected;
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

// ── Main skill picker (Ustaad only) ─────────────────────────────────────────

class _MainSkillPicker extends ConsumerWidget {
  final String? selectedCategoryId;
  final ValueChanged<String> onChanged;

  const _MainSkillPicker({
    required this.selectedCategoryId,
    required this.onChanged,
  });

  static const _accent = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Main Skill',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
              ),
            ),
          ),
          error: (e, _) => const Text(
            'Failed to load skills. Please try again.',
            style: TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
          ),
          data: (categories) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCategoryId,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Select your main skill',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                items: categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
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

  static const _accent = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accent : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? _accent : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? _accent
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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

  static const _accent = Color(0xFFDB6234);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor: _accent.withAlpha(150),
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
