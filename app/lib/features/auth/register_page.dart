import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _currency = 'INR';
  Map<String, String> _errors = {};
  String? _submitError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final errors = <String, String>{
      if (_name.text.trim().isEmpty) 'name': 'Tell us your name',
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) 'email': 'Enter a valid email',
      if (_password.text.length < 8) 'password': 'Use at least 8 characters',
    };
    setState(() {
      _errors = errors;
      _submitError = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(name: _name.text, email: _email.text, password: _password.text, currency: _currency);
    } catch (e) {
      final message = apiErrorMessage(e);
      if (mounted) {
        setState(() => message.contains('email') ? _errors = {'email': message} : _submitError = message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 440,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: const Offset(-10, 0),
                            child: HeaderIconButton(
                              glyph: 'back',
                              label: 'Back to log in',
                              onPressed: () => context.go('/login'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Semantics(header: true, child: Text('Create your account', style: SkText.display(32, 800))),
                        const SizedBox(height: 6),
                        Text(
                          'Takes a minute. You can change these later.',
                          style: SkText.body(15, 400, color: SkColors.ink2),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Avatar(
                              SkPerson(
                                id: _email.text,
                                name: name.isEmpty ? '?' : name,
                                colors: SkAvatarColors.pairs.first,
                              ),
                              size: 64,
                              fontSize: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SkTextField(
                          label: 'Full name',
                          controller: _name,
                          size: SkFieldSize.large,
                          autofillHints: const [AutofillHints.name],
                          textInputAction: TextInputAction.next,
                          errorText: _errors['name'],
                          errorIcon: true,
                        ),
                        const SizedBox(height: 14),
                        SkTextField(
                          label: 'Email',
                          controller: _email,
                          size: SkFieldSize.large,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          errorText: _errors['email'],
                          errorIcon: true,
                        ),
                        const SizedBox(height: 14),
                        SkTextField(
                          label: 'Password',
                          controller: _password,
                          size: SkFieldSize.large,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          errorText: _errors['password'],
                          errorIcon: true,
                        ),
                        const SizedBox(height: 14),
                        Text('Default currency', style: SkText.body(14, 600)),
                        const SizedBox(height: 6),
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: SkColors.surface,
                            borderRadius: BorderRadius.circular(SkRadius.button),
                            border: Border.all(color: SkColors.lineStrong, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _currency,
                              isExpanded: true,
                              icon: const SkIcon('down', size: 18),
                              style: SkText.body(16, 400),
                              items: [
                                for (final e in supportedCurrencies.entries)
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text('${e.key} — ${e.value} (${currencySymbol(e.key)})'),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _currency = v!),
                            ),
                          ),
                        ),
                        if (_submitError != null) ...[
                          const SizedBox(height: 14),
                          Text(_submitError!, style: SkText.body(13, 500, color: SkColors.owe)),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        SkButton(
                          _busy ? 'Creating account…' : 'Create account',
                          onPressed: _busy ? null : _submit,
                          size: SkButtonSize.large,
                          expand: true,
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
