import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    setState(() {
      _emailError = email.contains('@') ? null : 'Enter the email you signed up with';
      _error = null;
    });
    if (_emailError != null || _password.text.isEmpty) {
      if (_password.text.isEmpty) setState(() => _error = 'Enter your password');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(email, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 440,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: SkColors.ink, borderRadius: BorderRadius.circular(16)),
                            child: const Center(child: SkIcon('settle', size: 28, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          header: true,
                          child: Text('Spend together.\nSettle simply.', style: SkText.display(36, 800, height: 1.05)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log in to see who paid, who owes, and how much.',
                          style: SkText.body(16, 400, color: SkColors.ink2, height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        SkTextField(
                          label: 'Email',
                          controller: _email,
                          size: SkFieldSize.large,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          errorText: _emailError,
                        ),
                        const SizedBox(height: 16),
                        SkTextField(
                          label: 'Password',
                          controller: _password,
                          size: SkFieldSize.large,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          errorText: _error,
                        ),
                        const SizedBox(height: 16),
                        SkButton(
                          _busy ? 'Logging in…' : 'Log in',
                          onPressed: _busy ? null : _submit,
                          size: SkButtonSize.large,
                          expand: true,
                        ),
                        const Spacer(),
                        const SizedBox(height: 32),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('New here? ', style: SkText.body(15, 400, color: SkColors.ink2)),
                            InkWell(
                              onTap: () => context.go('/register'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('Create an account', style: SkText.body(15, 700, color: SkColors.brandInk)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Coming from Tricount? Import your groups after you sign up.',
                          textAlign: TextAlign.center,
                          style: SkText.body(13, 400, color: SkColors.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
