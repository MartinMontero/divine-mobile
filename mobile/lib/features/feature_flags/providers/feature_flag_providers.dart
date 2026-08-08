// ABOUTME: Riverpod providers for feature flag service and state management
// ABOUTME: Provides dependency injection for feature flag system with proper lifecycle management

import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_flag_providers.g.dart';

/// Build configuration provider
@riverpod
BuildConfiguration buildConfiguration(Ref ref) {
  return const BuildConfiguration();
}

/// Feature flag service provider — kept alive so flag state survives navigation
@Riverpod(keepAlive: true)
FeatureFlagService featureFlagService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final buildConfig = ref.watch(buildConfigurationProvider);
  final environmentService = ref.watch(environmentServiceProvider);

  final service = FeatureFlagService(
    prefs,
    buildConfig,
    canOverrideInternalFlags: () => environmentService.isDeveloperModeEnabled,
  );
  // Load persisted overrides from SharedPreferences
  service.initialize();

  // Re-resolve every flag when developer mode flips, rather than watching it
  // and rebuilding: this provider's instance is captured by ref.read in
  // SettingsScreen.initState, and a new identity here would strand that
  // capture on an orphaned service.
  void onEnvironmentChanged() => service.initialize();
  environmentService.addListener(onEnvironmentChanged);
  ref.onDispose(() => environmentService.removeListener(onEnvironmentChanged));

  return service;
}

/// Feature flag state provider (reactive to service changes)
@riverpod
Map<FeatureFlag, bool> featureFlagState(Ref ref) {
  final service = ref.watch(featureFlagServiceProvider);

  // Set up listener to invalidate provider when service changes
  void listener() {
    ref.invalidateSelf();
  }

  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
  });

  return service.currentState.allFlags;
}

/// Individual feature flag check provider family
@riverpod
bool isFeatureEnabled(Ref ref, FeatureFlag flag) {
  final state = ref.watch(featureFlagStateProvider);
  return state[flag] ?? false;
}

/// Whether client-side seen-video filtering is on.
///
/// Watches [featureFlagStateProvider] rather than the service: the service
/// keeps one identity for the process and only notifies listeners, so watching
/// it would freeze this on whatever the flag read at first build — including
/// the build default, when that first read beats the unawaited load of
/// persisted overrides. The kill switch has to work without a restart.
///
/// Resolving the flag needs the whole chain, including
/// `sharedPreferencesProvider`, which many widget tests do not override. Those
/// tests should keep the shipped default rather than fail, so a failure to
/// resolve falls back to on.
@Riverpod(keepAlive: true)
bool clientSeenFilteringEnabled(Ref ref) {
  try {
    return ref.watch(
          featureFlagStateProvider,
        )[FeatureFlag.clientSeenFiltering] ??
        true;
  } on Object {
    return true;
  }
}
