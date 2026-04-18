import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import 'auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    await ref.read(authControllerProvider.notifier).resendVerificationEmail();
    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent!')),
      );
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final verified = await ref.read(authControllerProvider.notifier).checkEmailVerified();
    if (mounted) {
      setState(() => _checking = false);
      if (verified) {
        await ref.read(authControllerProvider.notifier).fetchCurrentUser();
        if (mounted) context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not yet verified. Please check your inbox.')),
        );
      }
    }
  }

  Future<void> _backToSignIn() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We\'ve sent a verification link to your email. Please check your inbox and click the link, then come back here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      onPressed: _checking ? null : _checkVerified,
                      isLoading: _checking,
                      label: 'I\'ve Verified',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _sending ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0x33000000),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Resend Email'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _backToSignIn,
                      child: const Text('Back to sign in'),
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
