import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopToolbarSettings 聚合按钮 serialization', () {
    test('round-trips groups with ordered children, label and icon', () {
      const settings = TopToolbarSettings(
        positions: [
          TopToolbarComponentPosition(
            component: TopToolbarComponent.menuButton,
            x: 10,
            y: 50,
          ),
        ],
        groups: [
          TopToolbarGroup(
            id: 'g1',
            x: 80,
            y: 50,
            label: '常用',
            icon: TopToolbarGroupIcon.layers,
            children: [
              TopToolbarComponent.searchButton,
              TopToolbarComponent.newTopicButton,
              TopToolbarComponent.settingsButton,
            ],
          ),
        ],
      );

      final restored = TopToolbarSettings.fromJson(settings.toJson());

      expect(restored, settings);
      // Child order is a user-facing fact, so it must survive verbatim.
      expect(restored.groups.single.children, [
        TopToolbarComponent.searchButton,
        TopToolbarComponent.newTopicButton,
        TopToolbarComponent.settingsButton,
      ]);
    });

    test('old configs without a groups field decode to an empty list', () {
      final json = {
        'positions': [
          {'component': 'menuButton', 'x': 10.0, 'y': 50.0},
        ],
        'modelSelectorDisplayStyle': 'icon',
      };

      final settings = TopToolbarSettings.fromJson(json);

      expect(settings.groups, isEmpty);
      expect(settings.positions, hasLength(1));
    });

    test('a group falls back to defaults when optional fields are absent', () {
      final group = TopToolbarGroup.fromJson({'id': 'g1', 'x': 0.0, 'y': 0.0});

      expect(group.label, '聚合');
      expect(group.icon, TopToolbarGroupIcon.more);
      expect(group.children, isEmpty);
    });
  });

  group('TopToolbarGroupIcon.fromId', () {
    test('resolves a known id', () {
      expect(TopToolbarGroupIcon.fromId('star'), TopToolbarGroupIcon.star);
    });

    test('falls back to more for unknown or null ids', () {
      expect(TopToolbarGroupIcon.fromId('nope'), TopToolbarGroupIcon.more);
      expect(TopToolbarGroupIcon.fromId(null), TopToolbarGroupIcon.more);
    });
  });
}
