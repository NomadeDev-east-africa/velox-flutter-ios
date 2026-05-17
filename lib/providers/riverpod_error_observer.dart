import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Observateur Riverpod — capture les erreurs dans les providers
/// et les envoie à Crashlytics en production.
class RiverpodErrorObserver extends ProviderObserver {
  const RiverpodErrorObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    // Identifier le provider en erreur
    final providerName = provider.name ?? provider.runtimeType.toString();

    debugPrint('❌ [Riverpod] Provider "$providerName" a échoué: $error');
    debugPrint('   Stacktrace: $stackTrace');

    // En production uniquement : envoyer à Crashlytics
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Riverpod provider failed: $providerName',
        fatal: false,
      );
    }
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Optionnel : logger les mises à jour en debug seulement
    // Commenter si trop verbeux
    // debugPrint('[Riverpod] ${provider.name} updated');
  }
}
