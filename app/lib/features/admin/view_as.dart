import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api.dart';
import '../../core/layout/layout.dart';
import '../../core/local/providers.dart';
import '../../core/router/router.dart';
import '../../core/session/session.dart';
import '../../design_system/design_system.dart';
import '../common/common.dart';
import 'admin_providers.dart';

/// Opens the app as [target] (screen 18, "View as user"). [mode] is `read_only` (the default
/// everywhere in the admin area) or `edit`.
typedef ViewAsLauncher = Future<void> Function(BuildContext context, AdminUserOut target, {String mode});

/// Every "View as" / "Open as" button in the admin area calls this and nothing else.
///
/// Starts the audited session on the server (`POST /admin/sessions`) and switches the app to
/// the target: requests run on the view-as token (the server enforces read-only and records
/// `acting_admin_id` on edits), their data syncs into an in-memory database, and [ViewAsChrome]
/// frames every screen until Exit. The router sends the admin area to Home, since the target
/// isn't an admin.
final viewAsLauncherProvider = Provider<ViewAsLauncher>((ref) {
  return (context, target, {mode = 'read_only'}) async {
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
      ref.read(sessionProvider.notifier).startViewAs(out);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, apiErrorMessage(e));
    }
  };
});

/// The amber banner and frame around every screen (tabs, full-screen pages and sheets' host)
/// while an admin views the app as someone. Not dismissible: only Exit ends it.
class ViewAsChrome extends ConsumerWidget {
  const ViewAsChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null || !session.isViewAs) return child;
    final controller = ref.read(sessionProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } on ApiException catch (e) {
        messenger?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }

    Future<void> exit() async {
      // Send anything made in edit mode before its in-memory copy goes away.
      try {
        await (await ref.read(syncEngineProvider.future)).pull();
      } catch (_) {
        // Offline: exit anyway; the server has what it has.
      }
      await controller.exitViewAs();
      // Back where view-as started. Nothing open as them may stay open as the admin: a draft
      // on Add split would be saved in the admin's name. go() also drops pushed pages.
      ref.read(routerProvider).go('/admin');
    }

    return AdminFrame(
      active: true,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AdminBanner(
              viewingAs: session.user.name,
              wide: SkLayout.of(context) == SkLayout.expanded,
              modeNote: session.readOnly
                  ? 'Read-only · any change is logged as Admin'
                  : 'Editing · every change is logged as Admin',
              modeAction: session.readOnly ? 'Allow edits' : 'Make read-only',
              onModeAction: () => guarded(() => controller.setViewAsEditing(session.readOnly)),
              onExit: () => guarded(exit),
            ),
          ),
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
        ],
      ),
    );
  }
}
