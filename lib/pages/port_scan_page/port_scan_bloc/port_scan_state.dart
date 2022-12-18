part of 'port_scan_bloc.dart';

@freezed
class PortScanState with _$PortScanState {
  factory PortScanState.initial() = _Initial;
  const factory PortScanState.loadInProgress() = _LoadInProgress;
  const factory PortScanState.foundOpenPort(List<OpenPort> openPortList) =
      FoundOpenPort;
  const factory PortScanState.loadFailure() = _LoadFailure;
  const factory PortScanState.noPortFound() = _NoPortFound;
  const factory PortScanState.error() = Error;
}
