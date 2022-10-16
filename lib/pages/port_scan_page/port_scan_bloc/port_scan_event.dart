part of 'port_scan_bloc.dart';

@freezed
class PortScanEvent with _$PortScanEvent {
  const factory PortScanEvent.initialized() = Initialized;
  const factory PortScanEvent.startNewScan() = StartNewScan;
  const factory PortScanEvent.stopScan() = StopScan;
}
