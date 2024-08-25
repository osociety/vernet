part of 'host_scan_bloc.dart';

@freezed
class HostScanState with _$HostScanState {
  factory HostScanState.initial() = _Initial;

  const factory HostScanState.loadInProgress() = _LoadInProgress;

  const factory HostScanState.foundNewDevice(
    List<Device> activeHostList,
  ) = FoundNewDevice;

  const factory HostScanState.loadSuccess(
    List<Device> activeHostList,
  ) = LoadSuccess;

  const factory HostScanState.loadFailure() = _loadFailure;

  const factory HostScanState.error() = Error;
}
