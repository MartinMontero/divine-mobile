// ABOUTME: Pins the seen-filtering kill switch to live flag state.
// ABOUTME: A frozen value would leave feeds filtering after an operator toggle.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('clientSeenFilteringEnabledProvider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to enabled', () {
      final container = buildContainer();

      expect(
        container.read(clientSeenFilteringEnabledProvider),
        isTrue,
      );
    });

    test('follows a runtime flag toggle', () async {
      final container = buildContainer();

      // Read once first: a provider that watched the flag *service* rather
      // than its state would freeze on this value for the process, and the
      // kill switch would stop working.
      expect(container.read(clientSeenFilteringEnabledProvider), isTrue);

      await container
          .read(featureFlagServiceProvider)
          .setFlag(FeatureFlag.clientSeenFiltering, false);

      expect(
        container.read(clientSeenFilteringEnabledProvider),
        isFalse,
        reason: 'the kill switch must take effect without a restart',
      );
    });
  });
}
