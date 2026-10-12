import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the app's two halves, Split and Personal, work with each other. Every link between
/// them is one flag here, so a link can be tuned or cut without touching the screens; with
/// every flag off the two share nothing but your account.
///
/// The server never reads these: it stores and returns everything, and the app decides what
/// to show. Tests override [integrationsProvider] to check each flag.
class Integrations {
  const Integrations({this.groupShareInPersonal = true});

  /// Personal shows your share of group expenses next to your own spending: a line on
  /// Overview and the "Personal vs group" card in Insights.
  final bool groupShareInPersonal;
}

final integrationsProvider = Provider<Integrations>((_) => const Integrations());
