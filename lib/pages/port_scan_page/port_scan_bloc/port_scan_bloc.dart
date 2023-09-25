import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

part 'port_scan_bloc.freezed.dart';
part 'port_scan_event.dart';
part 'port_scan_state.dart';

@injectable
class PortScanBloc extends Bloc<PortScanEvent, PortScanState> {
  PortScanBloc() : super(PortScanState.initial()) {
    on<Initialized>(_initialized);
    on<StartNewScan>(_startNewScan);
    on<StopScan>(_stopScan);
  }

  Future<void> _initialized(Initialized event, Emitter<PortScanState> emit) {
    emit(const PortScanState.loadInProgress());
    return Future.delayed(const Duration(microseconds: 1));
  }

  Future<void> _startNewScan(StartNewScan event, Emitter<PortScanState> emit) {
    return Future.delayed(const Duration(microseconds: 1));
  }

  Future<void> _stopScan(StopScan event, Emitter<PortScanState> emit) {
    return Future.delayed(const Duration(microseconds: 1));
  }
}
