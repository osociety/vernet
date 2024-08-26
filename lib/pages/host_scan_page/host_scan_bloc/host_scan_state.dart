part of 'host_scan_bloc.dart';

@freezed
class HostScanState with _$HostScanState {
  factory HostScanState.initial() = _Initial;

  const factory HostScanState.loadInProgress() = _LoadInProgress;

  const factory HostScanState.foundNewDevice(
    Set<Device> activeHosts,
  ) = FoundNewDevice;

  const factory HostScanState.loadSuccess(
    Set<Device> activeHosts,
  ) = LoadSuccess;

  const factory HostScanState.loadFailure() = _loadFailure;

  const factory HostScanState.error() = Error;
}
