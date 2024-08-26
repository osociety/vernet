part of 'host_scan_bloc.dart';

@freezed
class HostScanEvent with _$HostScanEvent {
  const factory HostScanEvent.initialized() = Initialized;

  const factory HostScanEvent.startNewScan() = StartNewScan;
  const factory HostScanEvent.loadScan() = LoadScan;
}
