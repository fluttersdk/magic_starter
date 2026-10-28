import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterNavItem', () {
    test('stays a compile-time constant without a badge', () {
      const item = MagicStarterNavItem(
        icon: Icons.home,
        labelKey: 'nav.home',
        path: '/',
      );

      expect(item.badgeCount, isNull);
      expect(item.badgeLabelKey, 'nav.badge_count');
    });

    test('holds the notifier it is given, not a copy of its value', () {
      final count = ValueNotifier<int?>(2);
      addTearDown(count.dispose);

      final item = MagicStarterNavItem(
        icon: Icons.shopping_cart,
        labelKey: 'nav.shopping',
        path: '/shopping',
        badgeCount: count,
      );

      expect(item.badgeCount, same(count));

      count.value = 9;

      expect(item.badgeCount!.value, 9);
    });

    test('takes a ValueNotifier<int> without a cast', () {
      final count = ValueNotifier<int>(0);
      addTearDown(count.dispose);

      final item = MagicStarterNavItem(
        icon: Icons.shopping_cart,
        labelKey: 'nav.shopping',
        path: '/shopping',
        badgeCount: count,
        badgeLabelKey: 'nav.shopping_open',
      );

      expect(item.badgeCount, same(count));
      expect(item.badgeLabelKey, 'nav.shopping_open');
    });
  });
}
