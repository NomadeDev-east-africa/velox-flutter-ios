import 'package:flutter/foundation.dart';

/// Utilitaire de retry avec backoff exponentiel
/// Délais : 1s → 2s → 4s → 8s → 16s (plafonné)
class RetryHelper {
  static Future<T> withExponentialBackoff<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 16),
    String? label,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;

        final delay = initialDelay * (1 << (attempt - 1));
        final effectiveDelay = delay > maxDelay ? maxDelay : delay;

        debugPrint(
          '⚠️ [RetryHelper${label != null ? " $label" : ""}] '
          'Tentative $attempt échouée ($e), retry dans $effectiveDelay',
        );
        await Future.delayed(effectiveDelay);
      }
    }
  }
}
