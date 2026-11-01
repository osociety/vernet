part of 'network_score_bloc.dart';

@freezed
class NetworkScoreEvent with _$NetworkScoreEvent {
  const factory NetworkScoreEvent.loadCached() = _LoadCached;

  const factory NetworkScoreEvent.compute({
    WifiInfo? wifiInfo,
    NetworkConnectionStatus? connectivityStatus,
  }) = _Compute;

  const factory NetworkScoreEvent.refresh({
    WifiInfo? wifiInfo,
    NetworkConnectionStatus? connectivityStatus,
  }) = _Refresh;

  const factory NetworkScoreEvent.updateCache({
    required WifiInfo wifiInfo,
    required NetworkConnectionStatus connectivityStatus,
  }) = _UpdateCache;
}
