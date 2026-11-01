part of 'network_score_bloc.dart';

@freezed
class NetworkScoreState with _$NetworkScoreState {
  const factory NetworkScoreState.initial() = _Initial;

  const factory NetworkScoreState.computing() = _Computing;

  const factory NetworkScoreState.success(NetworkScore score) = _Success;

  const factory NetworkScoreState.failure(String message) = _Failure;
}
