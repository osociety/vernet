package org.fsociety.vernet;

import android.content.Context;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String WIFI_SIGNAL_CHANNEL = "org.fsociety.vernet/wifi_signal";

    /** WifiInfo's sentinel for "not associated"; the SDK keeps it hidden. */
    private static final int NO_ASSOCIATION_RSSI = -127;

    /**
     * Only Android answers. iOS exposes no public Wi-Fi RSSI, which is why the
     * dependency this replaces returned nothing there.
     */
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                WIFI_SIGNAL_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (!"getSignalStrength".equals(call.method)) {
                        result.notImplemented();
                        return;
                    }
                    result.success(currentSignalDbm());
                });
    }

    /** Live signal level in dBm, or null when there is no association to read. */
    @SuppressWarnings("deprecation")
    private Integer currentSignalDbm() {
        Object service = getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (!(service instanceof WifiManager)) {
            return null;
        }
        // getConnectionInfo() is deprecated on API 31+, but it stays the only
        // route to a live dBm that needs nothing beyond the location
        // permission the caller already holds.
        WifiInfo info = ((WifiManager) service).getConnectionInfo();
        if (info == null || info.getRssi() == NO_ASSOCIATION_RSSI) {
            return null;
        }
        return info.getRssi();
    }
}
