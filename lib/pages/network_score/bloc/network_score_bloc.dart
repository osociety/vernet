import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:vernet/models/network_connection_status.dart';
import 'package:vernet/models/network_score.dart';
import 'package:vernet/models/wifi_info.dart';
import 'package:vernet/repository/network_score_repository.dart';
import 'package:vernet/services/network_score_service.dart';

part 'network_score_event.dart';
part 'network_score_state.dart';
part 'network_score_bloc.freezed.dart';

@singleton
class NetworkScoreBloc extends Bloc<NetworkScoreEvent, NetworkScoreState> {
  NetworkScoreBloc({
    required this.scoreService,
    required this.scoreRepository,
  }) : super(const _Initial()) {
    on<_LoadCached>(_loadCached);
    on<_Compute>(_compute);
    on<_Refresh>(_refresh);
    on<_UpdateCache>(_updateCache);
  }

  final NetworkScoreService scoreService;
  final NetworkScoreRepository scoreRepository;

  WifiInfo? _lastWifiInfo;
  NetworkConnectionStatus? _lastConnectivityStatus;

  Future<void> _loadCached(
    _LoadCached event,
    Emitter<NetworkScoreState> emit,
  ) async {
    final cached = await scoreRepository.loadLastScore();
    if (cached != null) {
      emit(NetworkScoreState.success(cached));
    }
  }

  Future<void> _compute(
    _Compute event,
    Emitter<NetworkScoreState> emit,
  ) async {
    // Always update cache first if data is provided
    if (event.wifiInfo != null) {
      _lastWifiInfo = event.wifiInfo;
    }
    if (event.connectivityStatus != null) {
      _lastConnectivityStatus = event.connectivityStatus;
    }

    emit(const NetworkScoreState.computing());
    try {
      final score = await scoreService.computeScore(
        liveWifiInfo: event.wifiInfo ?? _lastWifiInfo,
        liveConnectivityStatus: event.connectivityStatus ?? _lastConnectivityStatus,
      );
      emit(NetworkScoreState.success(score));
    } catch (e) {
      emit(NetworkScoreState.failure('Failed to compute score: $e'));
    }
  }

  Future<void> _refresh(
    _Refresh event,
    Emitter<NetworkScoreState> emit,
  ) async {
    if (event.wifiInfo != null) {
      _lastWifiInfo = event.wifiInfo;
    }
    if (event.connectivityStatus != null) {
      _lastConnectivityStatus = event.connectivityStatus;
    }

    emit(const NetworkScoreState.computing());
    try {
      final score = await scoreService.computeScore(
        liveWifiInfo: event.wifiInfo ?? _lastWifiInfo,
        liveConnectivityStatus: event.connectivityStatus ?? _lastConnectivityStatus,
      );
      emit(NetworkScoreState.success(score));
    } catch (e) {
      emit(NetworkScoreState.failure('Failed to refresh score: $e'));
    }
  }

  Future<void> _updateCache(
    _UpdateCache event,
    Emitter<NetworkScoreState> emit,
  ) async {
    _lastWifiInfo = event.wifiInfo;
    _lastConnectivityStatus = event.connectivityStatus;
    
    // Always recompute score with fresh data
    emit(const NetworkScoreState.computing());
    try {
      final score = await scoreService.computeScore(
        liveWifiInfo: event.wifiInfo,
        liveConnectivityStatus: event.connectivityStatus,
      );
      emit(NetworkScoreState.success(score));
    } catch (e) {
      emit(NetworkScoreState.failure('Failed to update score: $e'));
    }
  }
}
