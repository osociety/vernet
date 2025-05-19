import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speed_test_dart/classes/classes.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:vernet/injection.dart';
import 'package:vernet/pages/isp_page/bloc/isp_page_bloc.dart';
import 'package:vernet/pages/isp_page/isp_page_widget.dart';
import 'package:vernet/values/strings.dart';

class IspPage extends StatelessWidget {
  const IspPage({super.key, required this.tester, required this.settings});
  final SpeedTestDart tester;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(StringValue.ispPageTitle),
      ),
      body: BlocProvider(
        create: (context) =>
            getIt<IspPageBloc>()..add(IspPageEvent.started(tester, settings)),
        child: IspPageWidget(
          client: settings.client,
        ),
      ),
    );
  }
}
