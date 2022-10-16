part of 'ping_bloc.dart';

@freezed
class PingState with _$PingState {
  const factory PingState.initial() = _Initial;
  const factory PingState.pingRunning() = _PingRunning;
  const factory PingState.pingStopped() = _PingStopped;
  const factory PingState.pingCompleted() = _PingCompleted;
}
