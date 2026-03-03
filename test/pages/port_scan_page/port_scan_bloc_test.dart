import 'package:flutter_test/flutter_test.dart';
import 'package:vernet/pages/port_scan_page/port_scan_bloc/port_scan_bloc.dart';

void main() {
  group('PortScanBloc', () {
    test('initial state is PortScanState.initial', () {
      final bloc = PortScanBloc();

      expect(bloc.state, PortScanState.initial());
    });

    test('handles events without throwing', () async {
      final bloc = PortScanBloc();

      bloc.add(const PortScanEvent.initialized());
      bloc.add(const PortScanEvent.startNewScan());
      bloc.add(const PortScanEvent.stopScan());

      await bloc.close();
    });
  });
}
