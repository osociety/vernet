part of 'host_scan_bloc.dart';

@freezed
abstract class HostScanEvent with _$HostScanEvent {
  const factory HostScanEvent.initialized() = Initialized;

  const factory HostScanEvent.startNewScan() = StartNewScan;
  const factory HostScanEvent.loadScan() = LoadScan;
}
