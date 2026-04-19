import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = false;
  bool _isForgotPassword = false;
  bool _obscurePassword = true;
  File? _profilePhoto;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image != null) setState(() => _profilePhoto = File(image.path));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = ref.read(authControllerProvider.notifier);

    if (_isForgotPassword) {
      final ok = await controller.sendPasswordReset(_emailController.text.trim());
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );
        setState(() => _isForgotPassword = false);
      }
      return;
    }

    if (_isSignUp) {
      final ok = await controller.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        profilePhoto: _profilePhoto,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please verify your email and sign in.')),
        );
        setState(() {
          _isSignUp = false;
          _passwordController.clear();
          _nameController.clear();
          _profilePhoto = null;
        });
      }
    } else {
      final result = await controller.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      switch (result) {
        case EmailSignInResult.success:
          context.go('/dashboard');
          break;
        case EmailSignInResult.unverified:
          // Route to verify-email screen so the user can resend / wait.
          // The user remains signed in to Firebase but no backend calls
          // happen until the email is verified.
          context.go('/verify-email');
          break;
        case EmailSignInResult.failure:
          // Error already surfaced via authState.error in the form.
          break;
      }
    }
  }

  Future<void> _googleSignIn() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (ok && mounted) context.go('/dashboard');
  }

  Future<void> _githubSignIn() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithGitHub();
    if (ok && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Logo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryEnd.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 30),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Zenno',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Auth card
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!_isForgotPassword) ...[
                            // Segmented toggle
                            _SegmentedToggle(
                              isSignUp: _isSignUp,
                              onChanged: (v) => setState(() {
                                _isSignUp = v;
                                _profilePhoto = null;
                              }),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your email to receive a reset link.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Profile photo (sign up only)
                          if (_isSignUp && !_isForgotPassword) ...[
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                                backgroundImage: _profilePhoto != null ? FileImage(_profilePhoto!) : null,
                                child: _profilePhoto == null
                                    ? Icon(Icons.camera_alt_outlined,
                                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, size: 28)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Optional',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Name field (sign up)
                          if (_isSignUp && !_isForgotPassword) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                hintText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),

                          // Password
                          if (!_isForgotPassword) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                if (v.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                          ],

                          // Forgot password link
                          if (!_isSignUp && !_isForgotPassword) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(() => _isForgotPassword = true),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryStart,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Error message
                          if (authState.hasError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                authState.error.toString(),
                                style: const TextStyle(color: AppColors.red, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Submit button
                          GradientButton(
                            onPressed: isLoading ? null : _submit,
                            isLoading: isLoading,
                            label: _isForgotPassword
                                ? 'Send Reset Link'
                                : _isSignUp
                                    ? 'Create Account'
                                    : 'Sign In',
                          ),

                          if (_isForgotPassword) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => setState(() => _isForgotPassword = false),
                              child: const Text('Back to sign in'),
                            ),
                          ],

                          // OAuth divider + buttons
                          if (!_isForgotPassword) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or continue with',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _OAuthButton(
                                    label: 'Google',
                                    icon: Icons.mail_outline,
                                    onPressed: isLoading ? null : _googleSignIn,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _OAuthButton(
                                    label: 'GitHub',
                                    icon: Icons.code,
                                    onPressed: isLoading ? null : _githubSignIn,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.isSignUp, required this.onChanged});
  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab('Sign In', !isSignUp, () => onChanged(false)),
          _tab('Sign Up', isSignUp, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: active ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({required this.label, required this.icon, this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        side: BorderSide(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
