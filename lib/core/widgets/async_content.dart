import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/widgets/app_states.dart';

/// Keeps successfully loaded content visible when a refresh fails.
class AsyncContent<T extends Object> extends StatefulWidget {
  const AsyncContent({required this.load, required this.builder, super.key});
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() refresh,
  )
  builder;
  @override
  State<AsyncContent<T>> createState() => _AsyncContentState<T>();
}

class _AsyncContentState<T extends Object> extends State<AsyncContent<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (mounted && generation == _generation) setState(() => _data = data);
    } on Object catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return _loading
          ? const AppLoadingView()
          : AppErrorView(
              title: 'Could not load this page',
              message: _error is ApiException
                  ? (_error as ApiException).message
                  : 'Check your connection and try again.',
              onRetry: _refresh,
            );
    }
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: const AppText(
              'Refresh failed. Showing the last loaded information.',
            ),
            actions: [
              TextButton(onPressed: _refresh, child: const AppText('Retry')),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: widget.builder(context, _data!, _refresh),
          ),
        ),
      ],
    );
  }
}
