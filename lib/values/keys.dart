import 'package:flutter/material.dart';

enum WidgetKey implements Comparable<WidgetKey> {
  thisDeviceTileIconButton('thisDeviceTileIconButton'),
  rangePortScanRadioButton('rangePortScanRadioButton'),
  singlePortScanRadioButton('singlePortScanRadioButton'),
  scanForOpenPortsButton('scanForOpenPortsButton'),
  reverseDnsLookupButton('reverseDnsLookupButton'),
  pingSummaryTotalTime('pingSummaryTotalTime'),
  scanForDevicesButton('scanForDevicesButton'),
  basePageSubmitButton('basePageSubmitButton'),
  pingSummaryReceived('pingSummaryReceived'),
  enterPortTextField('enterPortTextField'),
  veryShortPortChip('veryShortPortChip'),
  rescanIconButton('rescanIconButton'),
  pingSummarySent('pingSummarySent'),
  dnsLookupButton('dnsLookupButton'),
  portScanButton('portScanButton'),
  cloudflareChip('cloudflareChip'),
  knownPortChip('knownPortChip'),
  shortPortChip('shortPortChip'),
  fullPortChip('fullPortChip'),
  youtubeChip('youtubeChip'),
  localIpChip('localIpChip'),
  googleChip('googleChip'),
  amazonChip('amazonChip'),
  appleChip('appleChip'),
  ping('ping');

  const WidgetKey(this.value);
  final String value;
  ValueKey get key => ValueKey(value);

  @override
  int compareTo(WidgetKey other) => value.compareTo(other.value);
}
