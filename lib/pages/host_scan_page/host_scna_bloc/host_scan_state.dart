part of 'host_scan_bloc.dart';

@freezed
class HostScanState with _$HostScanState {
  factory HostScanState.initial() = _Initial;

  const factory HostScanState.loadInProgress() = _LoadInProgress;

  const factory HostScanState.loadSuccess(String securityBearIp) = _LoadSuccess;

  const factory HostScanState.loadFailure() = _loadFailure;

  const factory HostScanState.error() = Error;
}
