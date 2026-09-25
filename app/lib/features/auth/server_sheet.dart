import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/session/session.dart';
import '../../core/theme/theme.dart';
import '../../design_system/design_system.dart';

/// Developer settings: which API server the app talks to. Only shown when [AppConfig.devTools].
Future<void> showServerSheet(BuildContext context) =>
    showAppBottomSheet<void>(context, title: 'Server', child: const _ServerSheet());

/// "Server: http://10.0.2.2:8000" under the login form; opens [showServerSheet].
class ServerLink extends ConsumerWidget {
  const ServerLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(apiOriginProvider);
    return InkWell(
      onTap: () => showServerSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Server: ${_describe(origin)}',
          textAlign: TextAlign.center,
          style: SkText.body(13, 600, color: SkColors.ink3),
        ),
      ),
    );
  }
}

String _describe(String origin) => origin.isEmpty ? 'this site' : origin;

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final _url = TextEditingController(text: ref.read(apiOriginProvider));
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final origin = normalizeApiOrigin(_url.text);
    if (origin == null) {
      setState(() => _error = 'Enter a URL like http://192.168.1.20:8000');
      return;
    }
    await _apply(origin);
  }

  Future<void> _apply(String? origin) async {
    await ref.read(apiOriginProvider.notifier).set(origin);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final overridden = ref.watch(apiOriginProvider.notifier).isOverridden;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The API this app talks to. Changing it logs you out. '
            'From an emulator, your computer is http://10.0.2.2:8000.',
            style: SkText.body(14, 400, color: SkColors.ink2, height: 1.45),
          ),
          const SizedBox(height: 14),
          SkTextField(
            label: 'Server URL',
            controller: _url,
            hint: 'http://192.168.1.20:8000',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            errorText: _error,
          ),
          const SizedBox(height: 14),
          SkButton('Save', onPressed: _save, expand: true),
          if (overridden) ...[
            const SizedBox(height: 8),
            SkButton(
              'Use the build default (${_describe(AppConfig.apiOrigin)})',
              variant: SkButtonVariant.ghost,
              onPressed: () => _apply(null),
              expand: true,
            ),
          ],
        ],
      ),
    );
  }
}
