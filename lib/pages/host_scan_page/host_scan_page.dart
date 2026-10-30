import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/host_scan_page/host_scan_bloc/host_scan_bloc.dart';
import 'package:vernet/pages/host_scan_page/scan_history/scan_history_page.dart';
import 'package:vernet/pages/host_scan_page/widgets/host_scan_widget.dart';
import 'package:vernet/values/keys.dart';
import 'package:vernet/values/strings.dart';

class HostScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.hostScanPageTitle),
        actions: [
          IconButton(
            key: WidgetKey.scanHistoryIconButton.key,
            tooltip: StringValue.previousScansTitle,
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const ScanHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocProvider(
        create: (context) => getIt<HostScanBloc>(),
        child: _ScanStartGate(child: HostScanWidget()),
      ),
    );
  }
}

/// Starts the scan once the page transition has finished.
///
/// Scan startup (database write, network tools isolate, mDNS) costs several
/// frames; running it while the route animates makes the push stutter.
class _ScanStartGate extends StatefulWidget {
  const _ScanStartGate({required this.child});

  final Widget child;

  @override
  State<_ScanStartGate> createState() => _ScanStartGateState();
}

class _ScanStartGateState extends State<_ScanStartGate> {
  Animation<double>? _animation;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _start();
      return;
    }
    if (animation != _animation) {
      _animation?.removeStatusListener(_handleStatus);
      _animation = animation..addStatusListener(_handleStatus);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _start();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _animation?.removeStatusListener(_handleStatus);
    _animation = null;
    // Post-frame, so the last transition frame is not competing with setup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HostScanBloc>().add(const HostScanEvent.initialized());
    });
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_handleStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
