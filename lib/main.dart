import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/constants/app_colors.dart';
import 'core/network/error_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  if (kReleaseMode) {
    final reporter = container.read(errorReporterProvider);
    FlutterError.onError = (details) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      reporter.report(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      reporter.report(error, stack);
      return true;
    };
    ErrorWidget.builder = (_) => const _FallbackErrorWidget();
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const VoxlabApp()),
  );
}

class _FallbackErrorWidget extends StatelessWidget {
  const _FallbackErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: const Icon(
        Icons.error_outline_rounded,
        color: AppColors.error,
        size: 32,
      ),
    );
  }
}
