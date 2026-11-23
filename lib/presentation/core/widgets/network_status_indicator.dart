import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/connectivity_service.dart';
import '../app_ui_constants.dart';

/// Widget that displays network connectivity status.
/// Shows a banner when device is offline.
class NetworkStatusIndicator extends StatefulWidget {
  const NetworkStatusIndicator({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  final _connectivityService = sl<ConnectivityService>();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivityService.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await _connectivityService.isConnected();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (w, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: w,
                ),
              ),
              child: _isConnected
                  ? const SizedBox.shrink(key: ValueKey('online'))
                  : Padding(
                      key: const ValueKey('offline'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: AppUIConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppUIConstants.radiusFull,
                            ),
                            border: Border.all(color: AppUIConstants.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: AppUIConstants.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "You're offline",
                                  style: TextStyle(
                                    color: AppUIConstants.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _checkConnectivity,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppUIConstants.primaryLight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
