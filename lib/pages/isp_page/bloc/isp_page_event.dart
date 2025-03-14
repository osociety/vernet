part of 'isp_page_bloc.dart';

@freezed
class IspPageEvent with _$IspPageEvent {
  const factory IspPageEvent.started(SpeedTestDart tester, Settings settings) =
      _Started;
  const factory IspPageEvent.completed() = _Completed;
  const factory IspPageEvent.failed() = _Failed;
}
