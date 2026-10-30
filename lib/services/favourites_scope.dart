import 'package:flutter/widgets.dart';
import 'favourites_store.dart';

/// Makes the one FavouritesStore available to any widget below it,
/// and rebuilds those widgets whenever favourites change.
class FavouritesScope extends InheritedNotifier<FavouritesStore> {
  const FavouritesScope({
    super.key,
    required FavouritesStore store,
    required super.child,
  }) : super(notifier: store);

  static FavouritesStore of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FavouritesScope>();
    assert(scope != null, 'FavouritesScope is missing above this widget');
    return scope!.notifier!;
  }
}