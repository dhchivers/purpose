import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purpose/core/models/user_strategy.dart';
import 'package:purpose/core/services/strategy_provider.dart';
import 'package:purpose/core/services/auth_provider.dart';

/// State for the currently selected strategy context
class StrategyContext {
  final UserStrategy? selectedStrategy;
  final bool isLoading;
  final String? error;

  const StrategyContext({
    this.selectedStrategy,
    this.isLoading = false,
    this.error,
  });

  StrategyContext copyWith({
    UserStrategy? selectedStrategy,
    bool? isLoading,
    String? error,
  }) {
    return StrategyContext(
      selectedStrategy: selectedStrategy ?? this.selectedStrategy,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing the currently selected strategy
class StrategyContextNotifier extends StateNotifier<StrategyContext> {
  StrategyContextNotifier() : super(const StrategyContext());

  /// Set the selected strategy
  void setStrategy(UserStrategy? strategy) {
    state = state.copyWith(selectedStrategy: strategy, error: null);
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

/// Provider for the currently selected strategy (convenience)
final currentStrategyProvider = Provider<UserStrategy?>((ref) {
  return ref.watch(strategyContextProvider).selectedStrategy;
});

/// Provider that automatically selects the default strategy if none is selected
/// This is the main provider UI components should use
final activeStrategyProvider = Provider<UserStrategy?>((ref) {
  final strategyContext = ref.watch(strategyContextProvider);
  
  // If a strategy is explicitly selected, use it
  if (strategyContext.selectedStrategy != null) {
    return strategyContext.selectedStrategy;
  }
  
  // Otherwise, try to use the default strategy
  final defaultStrategyAsync = ref.watch(currentUserDefaultStrategyProvider);
  return defaultStrategyAsync.value;
});

/// Provider that ensures a strategy is selected by auto-selecting default if needed
/// Returns AsyncValue to handle loading and error states
final activeStrategyAsyncProvider = Provider<AsyncValue<UserStrategy?>>((ref) {
  final strategyContext = ref.watch(strategyContextProvider);
  
  // If a strategy is explicitly selected, wrap it in AsyncValue
  if (strategyContext.selectedStrategy != null) {
    return AsyncValue.data(strategyContext.selectedStrategy);
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
      ref.read(strategyContextProvider.notifier).setStrategy(defaultStrategy);
    } else {
      ref.read(strategyContextProvider.notifier).setLoading(false);
    }
  } catch (e, stackTrace) {
    print('❌ Error initializing strategy context: $e');
    print('Stack trace: $stackTrace');
    ref.read(strategyContextProvider.notifier).setError('Failed to load default strategy: $e');
  }
}
