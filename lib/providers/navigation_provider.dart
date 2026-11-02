import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The main navigation's tabs, in display order.
enum AppTab { home, build, saved, profile }

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, AppTab>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}
