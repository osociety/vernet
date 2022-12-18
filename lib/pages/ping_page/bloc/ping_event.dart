part of 'ping_bloc.dart';

@freezed
class PingEvent with _$PingEvent {
  const factory PingEvent.startPing() = StartPing;
  const factory PingEvent.stopPing() = StopPing;
}
