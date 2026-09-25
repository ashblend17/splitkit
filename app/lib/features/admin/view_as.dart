import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../common/common.dart';
import 'admin_providers.dart';

/// Opens the app as [target] (screen 18, "View as user"). [mode] is `read_only` (the default
/// everywhere in the admin area) or `edit`.
typedef ViewAsLauncher = Future<void> Function(BuildContext context, AdminUserOut target, {String mode});

/// SEAM for screen 18. Every "View as" / "Open as" button in the admin area calls this and
/// nothing else, so the real switch plugs in here without touching the admin pages.
///
/// The default only starts the admin session on the server (`POST /admin/sessions`, which is
/// audited) and says so. The replacement, once the data layer is rewritten, should:
///   1. keep the admin's own session aside and switch the app to `out.accessToken` for
///      `out.user` (every request then runs as the target; the server enforces read-only);
///   2. show AdminBanner and AdminFrame on every screen while it lasts (`out.session.mode`
///      says read-only or edit; "Allow edits" is `PATCH /admin/sessions/{id}` on the admin's
///      own token, and takes effect on the same view-as token);
///   3. on Exit, call `POST /admin/sessions/{id}/end` and go back to the admin's session.
/// Override it with `viewAsLauncherProvider.overrideWithValue(...)`.
final viewAsLauncherProvider = Provider<ViewAsLauncher>((ref) {
  return (context, target, {mode = 'read_only'}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final out = await ref
          .read(adminApiProvider)
          .startAdminSession(
            AdminSessionIn(
              targetUserId: target.id,
              mode: AdminSessionInModeEnum.fromJson(mode) ?? AdminSessionInModeEnum.readOnly,
            ),
          );
      if (out == null) throw ApiException(500, 'Empty response');
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('View-as will open here')));
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, apiErrorMessage(e));
    }
  };
});
