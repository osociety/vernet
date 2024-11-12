import 'package:flutter/material.dart';

enum WidgetKey implements Comparable<WidgetKey> {
  routerOrGatewayTileIconButton('routerOrGatewayTileIconButton'),
  rangePortScanRadioButton('rangePortScanRadioButton'),
  scanForOpenPortsButton('scanForOpenPortsButton'),
  scanForDevicesButton('scanForDevicesButton'),
  veryShortPortChip('veryShortPortChip'),
  rescanIconButton('rescanIconButton'),
  portScanButton('portScanButton'),
  cloudflareChip('cloudflareChip'),
  knownPortChip('knownPortChip'),
  shortPortChip('shortPortChip'),
  fullPortChip('fullPortChip'),
  youtubeChip('youtubeChip'),
  localIpChip('localIpChip'),
  googleChip('googleChip'),
  amazonChip('amazonChip'),
  appleChip('appleChip');

  const WidgetKey(this.value);
  final String value;
  ValueKey get key => ValueKey(value);

  @override
  int compareTo(WidgetKey other) => value.compareTo(other.value);
}
