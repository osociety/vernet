part of 'speed_test_bloc.dart';

@freezed
class SpeedTestEvent with _$SpeedTestEvent {
  const factory SpeedTestEvent.init({List<Ndt7Server>? preloadedServers}) =
      _Init;
  const factory SpeedTestEvent.loadServers() = _LoadServers;
  const factory SpeedTestEvent.startTest() = _StartTest;
  const factory SpeedTestEvent.toggleServerInfo() = _ToggleServerInfo;
  const factory SpeedTestEvent.reset() = _Reset;
}
