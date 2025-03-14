part of 'isp_page_bloc.dart';

@freezed
class IspPageState with _$IspPageState {
  const factory IspPageState.initial() = _Initial;

  const factory IspPageState.loadInProgress() = _LoadInProgress;

  const factory IspPageState.loadFailure() = _LoadFailure;

  const factory IspPageState.loadSuccess(List<Server> bestServers) =
      _LoadSuccess;
}
