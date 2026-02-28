import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/user_strategy.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';

/// State for the currently selected strategy context
class StrategyContext {
  final String? selectedStrategyId; // Store ID instead of full object
  final bool isLoading;
  final String? error;

  const StrategyContext({
    this.selectedStrategyId,
    this.isLoading = false,
    this.error,
  });

  StrategyContext copyWith({
    String? selectedStrategyId,
    bool? isLoading,
    String? error,
  }) {
    return StrategyContext(
      selectedStrategyId: selectedStrategyId ?? this.selectedStrategyId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing the currently selected strategy
class StrategyContextNotifier extends StateNotifier<StrategyContext> {
  StrategyContextNotifier() : super(const StrategyContext());

  /// Set the selected strategy by ID
  void setStrategyId(String? strategyId) {
    state = state.copyWith(selectedStrategyId: strategyId, error: null);
  }

  /// Set the selected strategy (extracts ID)
  void setStrategy(UserStrategy? strategy) {
    state = state.copyWith(selectedStrategyId: strategy?.id, error: null);
  }

  /// Set loading state
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Set error state
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Clear the selected strategy
  void clearStrategy() {
    state = const StrategyContext();
  }
}

/// Provider for the strategy context notifier
final strategyContextProvider = StateNotifierProvider<StrategyContextNotifier, StrategyContext>((ref) {
  return StrategyContextNotifier();
});

/// Provider for the currently selected strategy ID (convenience)
final currentStrategyIdProvider = Provider<String?>((ref) {
  return ref.watch(strategyContextProvider).selectedStrategyId;
});

/// Stream provider for the currently selected strategy with real-time updates
final currentStrategyStreamProvider = StreamProvider<UserStrategy?>((ref) {
  final strategyId = ref.watch(currentStrategyIdProvider);
  
  if (strategyId == null) {
    return Stream.value(null);
  }
  
  // Watch the strategy stream to get real-time updates
  return ref.watch(strategyStreamProvider(strategyId).stream);
});

/// Provider that automatically selects the default strategy if none is selected
/// This is the main provider UI components should use - returns the latest data via stream
final activeStrategyProvider = Provider<UserStrategy?>((ref) {
  final strategyId = ref.watch(currentStrategyIdProvider);
  
  // If a strategy is explicitly selected, get it from the stream
  if (strategyId != null) {
    final strategyAsync = ref.watch(strategyStreamProvider(strategyId));
    return strategyAsync.value;
  }
  
  // Otherwise, use the default strategy stream
  final defaultStrategyAsync = ref.watch(currentUserDefaultStrategyProvider);
  return defaultStrategyAsync.value;
});

/// Provider that ensures a strategy is selected by auto-selecting default if needed
/// Returns AsyncValue to handle loading and error states
final activeStrategyAsyncProvider = Provider<AsyncValue<UserStrategy?>>((ref) {
  final strategyId = ref.watch(currentStrategyIdProvider);
  
  // If a strategy is explicitly selected, get it from the stream
  if (strategyId != null) {
    return ref.watch(strategyStreamProvider(strategyId));
  }
  
  // Otherwise, return the default strategy async state
  return ref.watch(currentUserDefaultStrategyProvider);
});

/// Initialize strategy context with user's default strategy
/// Call this when the app starts or user logs in
Future<void> initializeStrategyContext(WidgetRef ref) async {
  final user = ref.read(currentUserProvider).value;
  if (user == null) {
    ref.read(strategyContextProvider.notifier).clearStrategy();
    return;
  }

  try {
    ref.read(strategyContextProvider.notifier).setLoading(true);
    
    // Get the default strategy
    final defaultStrategy = await ref.read(defaultStrategyProvider(user.uid).future);
    
    if (defaultStrategy != null) {
      ref.read(strategyContextProvider.notifier).setStrategyId(defaultStrategy.id);
    } else {
      ref.read(strategyContextProvider.notifier).setLoading(false);
    }
  } catch (e, stackTrace) {
    print('❌ Error initializing strategy context: $e');
    print('Stack trace: $stackTrace');
    ref.read(strategyContextProvider.notifier).setError('Failed to load default strategy: $e');
  }
}
