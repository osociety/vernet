import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ping_event.dart';
part 'ping_state.dart';
part 'ping_bloc.freezed.dart';

class PingBloc extends Bloc<PingEvent, PingState> {
  PingBloc() : super(PingState.initial()) {
    on<StartPing>(_startPing);
    on<StopPing>(_stopPing);
  }

  _startPing(StartPing event, Emitter<PingState> emit) {}

  _stopPing(StopPing event, Emitter<PingState> emit) {}
}
