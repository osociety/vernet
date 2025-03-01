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
  runScanOnStartup('runScanOnStartup'),
  rescanIconButton('rescanIconButton'),
  changeThemeTile('changeThemeTile'),
  inAppInternetSwitch('inAppInternetSwitch'),
  checkForUpdatesButton('checkForUpdatesButton'),
  pingSummarySent('pingSummarySent'),
  dnsLookupButton('dnsLookupButton'),
  portScanButton('portScanButton'),
  customSubnetTile('customSubnetTile'),
  firstSubnetTile('firstSubnetTile'),
  runOnAppStartupSwitch('runOnAppStartupSwitch'),
  lastSubnetTile('lastSubnetTile'),
  socketTimeoutTile('socketTimeoutTile'),
  pingCountTile('pingCountTile'),
  pingTimeoutTile('pingTimeoutTile'),
  settingsButton('settingsButton'),
  settingsTextField('settingsTextField'),
  settingsSubmitButton('settingsSubmitButton'),
  cloudflareChip('cloudflareChip'),
  knownPortChip('knownPortChip'),
  darkThemeRadioButton('darkThemeRadioButton'),
  lightThemeRadioButton('lightThemeRadioButton'),
  systemThemeRadioButton('systemThemeRadioButton'),
  shortPortChip('shortPortChip'),
  dnsResultTile('dnsResultTile'),
  fullPortChip('fullPortChip'),
  youtubeChip('youtubeChip'),
  localIpChip('localIpChip'),
  googleChip('googleChip'),
  amazonChip('amazonChip'),
  homeButton('homeButton'),
  appleChip('appleChip'),
  ping('ping');

  const WidgetKey(this.value);
  final String value;
  ValueKey get key => ValueKey(value);

  @override
  int compareTo(WidgetKey other) => value.compareTo(other.value);
}
