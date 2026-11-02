import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'gradient_header.dart';

/// Kerangka halaman modul: header gradien + loader otomatis
/// (loading / error / retry / pull-to-refresh).
///
/// Gunakan [AsyncPageState.reload] lewat GlobalKey untuk memuat ulang
/// dari luar (misal setelah ganti periode).
class AsyncPage<T> extends StatefulWidget {
  const AsyncPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.load,
    required this.builder,
    this.headerActions,
    this.headerExtras,
    this.fab,
  });

  final String title;
  final String? subtitle;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final List<Widget>? headerActions;
  final Widget? headerExtras;
  final Widget? fab;

  @override
  State<AsyncPage<T>> createState() => AsyncPageState<T>();
}

class AsyncPageState<T> extends State<AsyncPage<T>> {
  late Future<T> _future;
  T? _data;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    _future = widget.load();
  }

  /// Muat ulang data dari luar widget.
  void reload() {
    if (!mounted) return;
    setState(_run);
  }

  Future<void> refresh() async {
    _run();
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: widget.fab,
      body: Column(
        children: [
          GradientHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            actions: widget.headerActions,
            leading:
                Navigator.of(context).canPop() ? const HeaderBackButton() : null,
            bottom: widget.headerExtras,
          ),
          Expanded(
            child: FutureBuilder<T>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  final msg = snap.error is ApiException
                      ? (snap.error as ApiException).message
                      : snap.error.toString();
                  return ErrorRetry(message: msg, onRetry: reload);
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  if (!_hasData) return const LoadingView();
                }
                if (snap.hasData) {
                  _data = snap.data;
                  _hasData = true;
                }
                if (_data == null) {
                  return const EmptyView();
                }
                return RefreshIndicator(
                  color: AppColors.primaryYellow,
                  backgroundColor: context.card,
                  onRefresh: refresh,
                  child: widget.builder(context, _data as T),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
