package com.example.chafon_h103_rfid;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.cf.beans.AllParamBean;
import com.cf.beans.BatteryCapacityBean;
import com.cf.beans.CmdData;
import com.cf.beans.TagInfoBean;
import com.cf.beans.TagOperationBean;
import com.cf.ble.interfaces.IBtScanCallback;
import com.cf.ble.interfaces.IConnectDoneCallback;
import com.cf.ble.interfaces.IOnNotifyCallback;
import com.cf.zsdk.BleCore;
import com.cf.zsdk.CfSdk;
import com.cf.zsdk.SdkC;
import com.cf.zsdk.cmd.CmdBuilder;
import com.cf.zsdk.cmd.CmdType;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ChafonH103RfidPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;
    private BleCore bleCore;
    private final Map<String, BluetoothDevice> discoveredDevices = new HashMap<>();
    private IBtScanCallback scanCallback;
    private boolean isScanning = false;

    private MethodChannel.Result pendingGetConfigResult;
    private MethodChannel.Result pendingSaveFlashResult;

    private String radarEpc = null;
    private boolean radarActive = false;

    private Handler batteryTimeoutHandler = new Handler(Looper.getMainLooper());
    private Runnable batteryTimeoutRunnable;

    private Handler flashTimeoutHandler = new Handler(Looper.getMainLooper());
    private Runnable flashTimeoutRunnable;

    private AllParamBean latestAllParam = null;

    // BLE ready/notify active flag and operation lock
    private volatile boolean bleReady = false;
    private final AtomicBoolean opInProgress = new AtomicBoolean(false);

    // Flag to track inventory status
    private volatile boolean inventoryRunning = false;

    // Power range
    private static final int POWER_MIN = 5;
    private static final int POWER_MAX = 33; // slider up to 33

    private static final UUID SERVICE_UUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb");
    private static final UUID WRITE_UUID   = UUID.fromString("0000ffe3-0000-1000-8000-00805f9b34fb");
    private static final UUID NOTIFY_UUID  = UUID.fromString("0000ffe4-0000-1000-8000-00805f9b34fb");

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "chafon_h103_rfid");
        channel.setMethodCallHandler(this);

        CfSdk.load();
        bleCore = (BleCore) CfSdk.get(SdkC.BLE);
        bleCore.init(context);
        bleCore.setOnNotifyCallback(universalNotifyCallback);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            Log.d("CHAFON_PLUGIN", "📞 Method called: " + call.method);
            switch (call.method) {
                case "getPlatformVersion":
                    result.success("Android " + android.os.Build.VERSION.RELEASE);
                    break;

                case "getBatteryLevel":
                    getBatteryLevel(result);
                    break;

                case "startScan":
                    startScan(result);
                    break;

                case "stopScan":
                    stopScan(result);
                    break;

                case "connect": {
                    String address = call.argument("address");
                    if (address != null && !address.isEmpty()) {
                        connect(address, result);
                    } else {
                        result.error("INVALID_ARGUMENT", "Address is null or empty", null);
                    }
                    break;
                }

                case "isConnected":
                    result.success(bleCore != null && bleCore.isConnect());
                    break;

                case "disconnect":
                    disconnect(result);
                    break;

                case "getAllDeviceConfig":
                    getAllDeviceConfig(result);
                    break;

                case "sendAndSaveAllParams": {
                    Integer power   = call.argument("power");
                    Integer region  = call.argument("region");
                    Integer qValue  = call.argument("qValue");
                    Integer session = call.argument("session");

                    int pwr = power   != null ? power   : 17;
                    int reg = region  != null ? region  : 2;
                    int q   = qValue  != null ? qValue  : 4;
                    int ses = session != null ? session : 0;
                    sendAndSaveAllParams(pwr, reg, q, ses, result);
                    break;
                }

                // NEW: simple API that only writes power
                case "setOnlyOutputPower": {
                    Integer power = call.argument("power");
                    Boolean saveToFlash = call.argument("saveToFlash"); // default true
                    Boolean resumeInventory = call.argument("resumeInventory"); // default false
                    Integer region = call.argument("region"); // <-- NEW

                    int pwr = power != null ? power : 17;
                    boolean save = (saveToFlash == null) ? true : saveToFlash;
                    boolean resume = (resumeInventory == null) ? false : resumeInventory;
                    int reg = (region == null) ? -1 : region; // -1 => don't change region

                    setOnlyOutputPower(pwr, save, resume, reg, result); // <-- signature changed
                    break;
                }


                case "startInventory":
                    startInventory(result);
                    break;

                case "stopInventory":
                    stopInventory(result);
                    break;

                case "readSingleTag": {
                    Integer memoryBank = call.argument("memoryBank");
                    if (memoryBank == null) {
                        result.error("INVALID_ARGUMENT", "Missing 'memoryBank'", null);
                        return;
                    }
                    readTagByMemoryBank(memoryBank.byteValue(), result);
                    break;
                }

                case "startRadarTracking": {
                    String radarEpcValue = call.argument("epc");
                    if (radarEpcValue == null || radarEpcValue.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "EPC cannot be empty", null);
                    } else {
                        startRadarTracking(radarEpcValue, result);
                    }
                    break;
                }

                case "stopRadarTracking":
                    stopRadarTracking(result);
                    break;

                default:
                    result.error("UNSUPPORTED_METHOD",
                            "Method " + call.method + " not supported",
                            Arrays.asList("startScan", "stopScan", "setOnlyOutputPower", "sendAndSaveAllParams"));
            }
        } catch (Exception e) {
            result.error("UNEXPECTED_ERROR", e.getMessage(), null);
        }
    }

    // ==== NOTIFY CALLBACK ====
    private final IOnNotifyCallback universalNotifyCallback = new IOnNotifyCallback() {
        @Override
        public void onNotify(int cmdType, CmdData cmdData) {
            try {
                Object obj = cmdData.getData();

                switch (cmdType) {
                    case CmdType.TYPE_GET_BATTERY_CAPACITY: {
                        Log.d("CHAFON_PLUGIN", "📩 TYPE_BATTERY response received");
                        if (obj instanceof BatteryCapacityBean) {
                            int battery = ((BatteryCapacityBean) obj).mBatteryCapacity;

                            if (batteryTimeoutRunnable != null) {
                                batteryTimeoutHandler.removeCallbacks(batteryTimeoutRunnable);
                                batteryTimeoutRunnable = null;
                            }

                            Map<String, Object> batteryMap = new HashMap<>();
                            batteryMap.put("level", battery);

                            new Handler(Looper.getMainLooper()).post(() -> {
                                channel.invokeMethod("onBatteryLevel", batteryMap);
                            });
                        }
                        break;
                    }

                    case CmdType.TYPE_OUT_MODE:
                        Log.d("CHAFON_PLUGIN", "📤 Output mode changed");
                        break;

                    case CmdType.TYPE_KEY_STATE:
                        Log.d("CHAFON_PLUGIN", "🔘 Button status received");
                        break;

                    case CmdType.TYPE_GET_DEVICE_INFO:
                        Log.d("CHAFON_PLUGIN", "📡 Device info received");
                        break;

                    case CmdType.TYPE_GET_ALL_PARAM: {
                        if (obj instanceof AllParamBean) {
                            AllParamBean param = (AllParamBean) obj;
                            latestAllParam = param;

                            if (pendingGetConfigResult != null) {
                                Map<String, Object> config = new HashMap<>();
                                config.put("power",   (int) param.mRfidPower);
                                config.put("region",  (int) param.mRfidFreq.mREGION);
                                config.put("qValue",  (int) param.mQValue);
                                config.put("session", (int) param.mSession);

                                MethodChannel.Result callback = pendingGetConfigResult;
                                pendingGetConfigResult = null;
                                callback.success(config);
                            }
                        }
                        break;
                    }

                    case CmdType.TYPE_SET_ALL_PARAM:
                        Log.d("CHAFON_PLUGIN", "✅ Parameters written to RAM (notify)");
                        break;

                    case CmdType.TYPE_INVENTORY: {
                        if (obj instanceof TagInfoBean) {
                            TagInfoBean tag = (TagInfoBean) obj;
                            if (tag.mEPCNum == null || tag.mEPCNum.length == 0) return;

                            String epc = bytesToHexString(tag.mEPCNum);
                            int rssi = tag.mRSSI;

                            if (radarActive && radarEpc != null && epc.equalsIgnoreCase(radarEpc)) {
                                Log.d("CHAFON_PLUGIN", "🎯 RADAR FOUND: EPC=" + epc + ", RSSI=" + rssi);

                                Map<String, Object> radarMap = new HashMap<>();
                                radarMap.put("epc", epc);
                                radarMap.put("rssi", rssi);

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onRadarSignal", radarMap);
                                });
                            } else {
                                Map<String, Object> tagMap = new HashMap<>();
                                tagMap.put("epc", epc);
                                tagMap.put("rssi", rssi);
                                tagMap.put("antenna", tag.mAntenna);
                                tagMap.put("timestamp", System.currentTimeMillis());

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onTagRead", tagMap);
                                });
                            }
                        }
                        break;
                    }

                    case CmdType.TYPE_READ_TAG: {
                        if (obj instanceof TagOperationBean) {
                            TagOperationBean tagOp = (TagOperationBean) obj;

                            int status = tagOp.mTagStatus;
                            Log.d("CHAFON_PLUGIN", "📛 TagOperationBean status: " + status);

                            String epc = bytesToHexString(tagOp.mEPCNum);
                            String data = bytesToHexString(tagOp.mData);
                            if (epc == null) epc = "";
                            if (data == null) data = "";

                            if (!epc.trim().isEmpty() || !data.trim().isEmpty()) {
                                Map<String, Object> tagMap = new HashMap<>();
                                tagMap.put("epc", epc.isEmpty() ? "<empty>" : epc);
                                tagMap.put("data", data);
                                tagMap.put("status", status);
                                tagMap.put("timestamp", System.currentTimeMillis());

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onTagReadSingle", tagMap);
                                });
                            } else {
                                Log.w("CHAFON_PLUGIN", "❌ READ_TAG response is invalid – no EPC or DATA");
                            }
                        }
                        break;
                    }

                    default: {
                        // Some firmware may send TagInfoBean with different cmdType – fallback
                        Object any = cmdData.getData();
                        if (any instanceof TagInfoBean) {
                            TagInfoBean tag = (TagInfoBean) any;
                            if (tag.mEPCNum != null && tag.mEPCNum.length > 0) {
                                String epc = bytesToHexString(tag.mEPCNum);
                                int rssi = tag.mRSSI;

                                Map<String, Object> tagMap = new HashMap<>();
                                tagMap.put("epc", epc);
                                tagMap.put("rssi", rssi);
                                tagMap.put("antenna", tag.mAntenna);
                                tagMap.put("timestamp", System.currentTimeMillis());

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onTagRead", tagMap);
                                });
                            }
                        } else {
                            Log.d("CHAFON_PLUGIN", "⚠️ Fallback: unknown cmdType=" + cmdType + " obj=" + any);
                        }
                        break;
                    }
                }
            } catch (Exception e) {
                Log.e("NOTIFY_ERROR", "Callback processing error", e);
                Map<String, Object> errorMap = new HashMap<>();
                errorMap.put("error", e.getMessage());
                channel.invokeMethod("onReadError", errorMap);
            }
        }

        @Override
        public void onNotify(byte[] bytes) {
            if (bytes == null || bytes.length < 5) return;

            int cmd = bytes[3] & 0xFF;   // CMD
            int len = bytes[4] & 0xFF;   // LEN
            Log.d("CHAFON_PLUGIN", "🔍 CMD Header: " + cmd);

            // FLASH ack (0x79)
            if (cmd == 0x79) {
                Log.d("CHAFON_PLUGIN", "💾 FLASH command successfully acknowledged");

                if (flashTimeoutRunnable != null) {
                    flashTimeoutHandler.removeCallbacks(flashTimeoutRunnable);
                    flashTimeoutRunnable = null;
                }
                if (pendingSaveFlashResult != null) {
                    pendingSaveFlashResult.success("flash_saved");
                    pendingSaveFlashResult = null;
                }
                // Note: We don't resend 0x88/0x8E here.
                return;
            }

            // START INVENTORY ack (0x01, len=0x01, status byte)
            if (cmd == 0x01 && len == 0x01 && bytes.length >= 6) {
                int status = bytes[5] & 0xFF; // 0x00=OK
                if (status == 0x00) {
                    Log.d("CHAFON_PLUGIN", "✅ Inventory START ack (OK)");
                    inventoryRunning = true;
                } else {
                    Log.w("CHAFON_PLUGIN", "❌ Inventory START ack status=0x" + Integer.toHexString(status));
                    inventoryRunning = false;
                }
                return;
            }

            // STOP INVENTORY ack (0x02, len=0x01, status byte)
            if (cmd == 0x02 && len == 0x01 && bytes.length >= 6) {
                int status = bytes[5] & 0xFF;
                Log.d("CHAFON_PLUGIN", "↩️ STOP ack status=0x" + Integer.toHexString(status));
                inventoryRunning = false;
                return;
            }

            // No need for remaining raw frames (e.g. tag stream 0x01 len>1) – we handle with TagInfoBean.
        }
    };

    // ==== BLE commands ====

    private void getBatteryLevel(MethodChannel.Result result) {
        if (bleCore == null || !bleCore.isConnect()) {
            result.error("DISCONNECTED", "Device not connected", null);
            return;
        }

        byte[] cmd = CmdBuilder.buildGetBatteryCapacityCmd();
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            Log.d("CHAFON_PLUGIN", "🔋 Battery level command sent.");
            result.success("battery_request_sent");

            batteryTimeoutRunnable = () -> {
                Log.w("CHAFON_PLUGIN", "⏰ Battery response not received (timeout)");
                channel.invokeMethod("onBatteryTimeout", null);
            };
            batteryTimeoutHandler.postDelayed(batteryTimeoutRunnable, 5000);

        } else {
            result.error("BATTERY_FAILED", "Unable to send battery command", null);
        }
    }

    private void startScan(MethodChannel.Result result) {
        Log.d("CHAFON_PLUGIN", "▶️ startScan method called");

        if (isScanning) {
            Log.d("CHAFON_PLUGIN", "⚠️ Scan is already running");
            result.success("scan_already_running");
            return;
        }

        try {
            scanCallback = new IBtScanCallback() {
                @Override
                public void onBtScanResult(ScanResult pResult) {
                    BluetoothDevice device = pResult.getDevice();
                    if (device != null && device.getAddress() != null) {
                        if (!discoveredDevices.containsKey(device.getAddress())) {
                            discoveredDevices.put(device.getAddress(), device);
                            Map<String, Object> deviceInfo = new HashMap<>();
                            deviceInfo.put("name", device.getName() != null ? device.getName() : "Unknown");
                            deviceInfo.put("address", device.getAddress());
                            deviceInfo.put("rssi", pResult.getRssi());

                            new Handler(Looper.getMainLooper()).post(() -> {
                                channel.invokeMethod("onDeviceFound", deviceInfo);
                            });
                        }
                    }
                }

                @Override
                public void onBtScanFail(int pErrorCode) {
                    Log.e("CHAFON_PLUGIN", "❌ Scan failed. Code: " + pErrorCode);
                    new Handler(Looper.getMainLooper()).post(() -> {
                        channel.invokeMethod("onScanError", "Scan error: " + pErrorCode);
                    });
                }
            };

            bleCore.startScan(scanCallback);
            isScanning = true;
            Log.d("CHAFON_PLUGIN", "🚀 Scan started!");
            result.success("scan_started");
        } catch (Exception e) {
            Log.e("CHAFON_PLUGIN", "🔥 startScan error: " + e.getMessage());
            result.error("SCAN_ERROR", "Scan not started: " + e.getMessage(), null);
        }
    }

    private void stopScan(@Nullable MethodChannel.Result result) {
        if (!isScanning) {
            if (result != null) result.success("scan_already_stopped");
            return;
        }

        try {
            bleCore.stopScan();
            isScanning = false;
            if (result != null) result.success("scan_stopped");
        } catch (Exception e) {
            if (result != null) {
                result.error("STOP_SCAN_ERROR", "Scan not stopped: " + e.getMessage(), null);
            }
        }
    }

    private void connect(String address, MethodChannel.Result result) {
        if (isScanning) {
            stopScan(null);
        }

        BluetoothDevice device = discoveredDevices.get(address);
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found: " + address, null);
            return;
        }

        bleCore.setIConnectDoneCallback(new IConnectDoneCallback() {
            @Override
            public void onConnectDone(boolean success) {
                if (success) {
                    bleReady = false;
                    boolean notifySet = bleCore.setNotifyState(SERVICE_UUID, NOTIFY_UUID, true);
                    if (notifySet) {
                        new Handler(Looper.getMainLooper()).postDelayed(() -> {
                            bleReady = true;
                            configureAfterConnection(result);
                        }, 200);
                    } else {
                        result.error("NOTIFY_FAILED", "Failed to enable notifications", null);
                    }
                } else {
                    result.error("CONNECTION_FAILED", "Connection failed", null);
                }
            }
        });

        try {
            bleCore.connectDevice(device, context, true);
        } catch (Exception e) {
            result.error("CONNECTION_EXCEPTION", "Connection error: " + e.getMessage(), null);
        }
    }

    private void configureAfterConnection(MethodChannel.Result result) {
        try {
            // Like official app: we don't send special 0x88/0x8E after connection
            bleReady = true;
            result.success(true);
        } catch (Exception e) {
            result.error("CONFIGURATION_FAILED", "Config error: " + e.getMessage(), null);
        }
    }

    private void disconnect(MethodChannel.Result result) {
        try {
            bleCore.setIConnectDoneCallback(null);
            bleCore.setOnNotifyCallback(null);
            bleCore.disconnectedDevice();

            bleReady = false;
            latestAllParam = null;
            inventoryRunning = false;

            result.success(true);

            new Handler(Looper.getMainLooper()).post(() -> {
                channel.invokeMethod("onDisconnected", null);
            });
        } catch (Exception e) {
            result.error("DISCONNECT_FAILED", "Connection not disconnected: " + e.getMessage(), null);
        }
    }

    private void getAllDeviceConfig(MethodChannel.Result result) {
        try {
            if (!waitBleReady(1000)) {
                result.error("BLE_NOT_READY", "Notify not ready", null);
                return;
            }
            byte[] cmd = CmdBuilder.buildGetAllParamCmd();
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

            if (sent) {
                pendingGetConfigResult = result; // response will come from notify
            } else {
                result.error("READ_CONFIG_FAILED", "BLE read command not sent", null);
            }
        } catch (Exception e) {
            result.error("READ_CONFIG_EXCEPTION", "Error: " + e.getMessage(), null);
        }
    }

    private void saveParamsToFlash(MethodChannel.Result result) {
        try {
            Log.d("CHAFON_PLUGIN", "💾 FLASH write command being sent...");

            pendingSaveFlashResult = result;

            byte[] cmd = new byte[]{ (byte) 0xCF, (byte) 0xFF, 0x00, (byte) 0x79, 0x00, 0x00, 0x00 };
            int crc = calculateCRC16(cmd, 5);
            cmd[5] = (byte) ((crc >> 8) & 0xFF);
            cmd[6] = (byte) (crc & 0xFF);

            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);
            if (!sent) {
                pendingSaveFlashResult = null;
                result.error("FLASH_WRITE_FAILED", "FLASH command could not be sent", null);
                return;
            }

            // Timeout: if 0x79 ack not received within 2s, error
            flashTimeoutRunnable = () -> {
                if (pendingSaveFlashResult != null) {
                    MethodChannel.Result r = pendingSaveFlashResult;
                    pendingSaveFlashResult = null;
                    r.error("FLASH_TIMEOUT", "FLASH response not received", null);
                }
            };
            flashTimeoutHandler.postDelayed(flashTimeoutRunnable, 2000);

        } catch (Exception e) {
            result.error("FLASH_EXCEPTION", "Error occurred: " + e.getMessage(), null);
        }
    }

    // ==== NEW: Simple API that only writes power ====
    private void setOnlyOutputPower(int power,
                                    boolean saveToFlash,
                                    boolean resumeInventory,
                                    int regionOrMinus1, // -1 if region should not be touched
                                    MethodChannel.Result result) {
        Log.d("CHAFON_PLUGIN", "⚙️ setOnlyOutputPower(power=" + power + ", save=" + saveToFlash +
                ", resume=" + resumeInventory + ", region=" + regionOrMinus1 + ")");

        if (!opInProgress.compareAndSet(false, true)) {
            result.error("BUSY", "Another operation is in progress", null);
            return;
        }

        boolean wasRunning = inventoryRunning;

        try {
            if (!waitBleReady(1000) || bleCore == null || !bleCore.isConnect()) {
                opInProgress.set(false);
                result.error("BLE_NOT_READY", "Device not connected or notify not ready", null);
                return;
            }

            if (wasRunning) {
                internalStopInventory();
                try { Thread.sleep(150); } catch (InterruptedException ignored) {}
            }

            if (latestAllParam == null) {
                // if latestAllParam doesn't exist: use provided region, otherwise default ETSI(2)
                int effectiveRegion = (regionOrMinus1 == -1) ? 2 : regionOrMinus1;
                latestAllParam = makeAllParamsFromDefaults(power, effectiveRegion, /*q*/4, /*session*/0);
            } else {
                int p = Math.max(POWER_MIN, Math.min(POWER_MAX, power));
                latestAllParam.mRfidPower = (byte) p;

                // if region param is provided, also update frequency table
                if (regionOrMinus1 != -1) {
                    latestAllParam.mRfidFreq = buildFreqByRegion(regionOrMinus1);
                }
            }

            // Write to RAM
            byte[] cmd = CmdBuilder.buildSetAllParamCmd(latestAllParam);
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);
            if (!sent) {
                if (resumeInventory && wasRunning) internalStartInventory();
                opInProgress.set(false);
                result.error("WRITE_FAILED", "Parameters not written to RAM", null);
                return;
            }

            if (saveToFlash) {
                saveParamsToFlash(new MethodChannel.Result() {
                    @Override public void success(Object res) {
                        if (resumeInventory && wasRunning) internalStartInventory();
                        opInProgress.set(false);
                        result.success(res); // "flash_saved"
                    }
                    @Override public void error(String code, String msg, Object details) {
                        if (resumeInventory && wasRunning) internalStartInventory();
                        opInProgress.set(false);
                        result.error(code, msg, details);
                    }
                    @Override public void notImplemented() {
                        if (resumeInventory && wasRunning) internalStartInventory();
                        opInProgress.set(false);
                        result.notImplemented();
                    }
                });
            } else {
                if (resumeInventory && wasRunning) internalStartInventory();
                opInProgress.set(false);
                result.success("ok");
            }

        } catch (Exception e) {
            if (resumeInventory && wasRunning) internalStartInventory();
            opInProgress.set(false);
            result.error("SET_POWER_EXCEPTION", e.getMessage(), null);
        }
    }


    // ==== MAIN CHANGE: Version that works without getAllDeviceConfig ====
    private void sendAndSaveAllParams(int power, int region, int qValue, int session, MethodChannel.Result result) {
        Log.d("CHAFON_PLUGIN", "📦 sendAndSaveAllParams(power=" + power + ", region=" + region + ", q=" + qValue + ", s=" + session + ")");

        if (!opInProgress.compareAndSet(false, true)) {
            result.error("BUSY", "Another parameters operation is in progress", null);
            return;
        }

        boolean wasRunning = inventoryRunning;

        try {
            if (!waitBleReady(1000) || bleCore == null || !bleCore.isConnect()) {
                opInProgress.set(false);
                result.error("BLE_NOT_READY", "Notify/CCCD not ready or device not connected", null);
                return;
            }

            // If inventory is running, stop it
            if (wasRunning) {
                internalStopInventory();
                try { Thread.sleep(150); } catch (InterruptedException ignored) {}
            }

            if (latestAllParam == null) {
                latestAllParam = makeAllParamsFromDefaults(power, region, qValue, session); // <<< region used here
            } else {
                int p = Math.max(POWER_MIN, Math.min(POWER_MAX, power));
                latestAllParam.mRfidPower = (byte) p;
                latestAllParam.mQValue    = (byte) qValue;
                latestAllParam.mSession   = (byte) session;
                latestAllParam.mRfidFreq  = buildFreqByRegion(region); // <<< here too!
            }

            // Write to RAM
            byte[] cmd = CmdBuilder.buildSetAllParamCmd(latestAllParam);
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);
            if (!sent) {
                if (wasRunning) internalStartInventory();
                opInProgress.set(false);
                result.error("WRITE_FAILED", "Parameters could not be written to RAM", null);
                return;
            }

            // Save to FLASH
            saveParamsToFlash(new MethodChannel.Result() {
                @Override public void success(Object res) {
                    if (wasRunning) internalStartInventory();
                    opInProgress.set(false);
                    result.success(res); // "flash_saved"
                }
                @Override public void error(String code, String msg, Object details) {
                    if (wasRunning) internalStartInventory();
                    opInProgress.set(false);
                    result.error(code, msg, details);
                }
                @Override public void notImplemented() {
                    if (wasRunning) internalStartInventory();
                    opInProgress.set(false);
                    result.notImplemented();
                }
            });

        } catch (Exception e) {
            if (wasRunning) internalStartInventory();
            opInProgress.set(false);
            result.error("WRITE_EXCEPTION", "Error occurred: " + e.getMessage(), null);
        }
    }

    // ==== Helpers ====

    private boolean waitBleReady(long timeoutMs) {
        long end = System.currentTimeMillis() + timeoutMs;
        while (!bleReady && System.currentTimeMillis() < end) {
            try { Thread.sleep(50); } catch (InterruptedException ignored) {}
        }
        return bleReady;
    }

    private boolean writeWithRetry(UUID service, UUID write, byte[] data) {
        for (int i = 0; i < 3; i++) {
            boolean ok = bleCore.writeData(service, write, data);
            if (ok) return true;
            try { Thread.sleep(120L * (i + 1)); } catch (InterruptedException ignored) {}
        }
        return false;
    }

    private AllParamBean.RfidFreq buildFreqByRegion(int region) {
        AllParamBean.RfidFreq freq = new AllParamBean.RfidFreq();
        freq.mSTRATFREI = new byte[2];
        freq.mSTRATFRED = new byte[2];
        freq.mSTEPFRE   = new byte[2];

        if (region == 1) { // FCC
            freq.mREGION = 0x01;
            freq.mSTRATFREI[0] = 0x03; freq.mSTRATFREI[1] = (byte) 0x86;
            freq.mSTRATFRED[0] = 0x02; freq.mSTRATFRED[1] = (byte) 0xEE;
            freq.mSTEPFRE[0]   = 0x01; freq.mSTEPFRE[1]   = (byte) 0xF4;
            freq.mCN = 0x32;
        } else {           // ETSI (default)
            freq.mREGION = 0x03;
            freq.mSTRATFREI[0] = 0x03; freq.mSTRATFREI[1] = (byte) 0x61;
            freq.mSTRATFRED[0] = 0x00; freq.mSTRATFRED[1] = (byte) 0x64;
            freq.mSTEPFRE[0]   = 0x00; freq.mSTEPFRE[1]   = (byte) 0xC8;
            freq.mCN = 0x0F;
        }
        return freq;
    }

    private AllParamBean makeAllParamsFromDefaults(int power, int region, int qValue, int session) {
        AllParamBean b = new AllParamBean();
        int p = Math.max(POWER_MIN, Math.min(POWER_MAX, power));
        b.mRfidPower = (byte) p;
        b.mQValue    = (byte) qValue;   // default 4
        b.mSession   = (byte) session;  // default 0 (S0)
        b.mRfidFreq  = buildFreqByRegion(region);
        return b;
    }

    private int calculateCRC16(byte[] data, int length) {
        int crc = 0xFFFF;
        for (int i = 0; i < length; i++) {
            crc ^= data[i] & 0xFF;
            for (int j = 0; j < 8; j++) {
                if ((crc & 0x0001) != 0) {
                    crc = (crc >> 1) ^ 0x8408;
                } else {
                    crc >>= 1;
                }
            }
        }
        return crc;
    }

    private void startInventory(MethodChannel.Result result) {
        if (!bleReady || bleCore == null || !bleCore.isConnect()) {
            result.error("BLE_NOT_READY", "Notify/connection not ready", null);
            return;
        }
        if (!opInProgress.compareAndSet(false, true)) {
            result.error("BUSY", "Another operation is in progress", null);
            return;
        }

        new Thread(() -> {
            try {
                // 1) STOP as precaution (0x02)
                writeWithRetry(SERVICE_UUID, WRITE_UUID, CmdBuilder.buildStopInventoryCmd());
                try { Thread.sleep(120); } catch (InterruptedException ignored) {}

                // 2) START (0x01) – like official app, we don't change read-mode/out-mode
                byte[] invCmd = CmdBuilder.buildInventoryISOContinueCmd((byte) 0x00, 0);
                boolean ok = writeWithRetry(SERVICE_UUID, WRITE_UUID, invCmd);
                if (ok) inventoryRunning = true;

                final boolean okFinal = ok;
                new Handler(Looper.getMainLooper()).post(() -> {
                    if (okFinal) result.success("inventory_started");
                    else         result.error("INVENTORY_FAILED", "start cmd not sent", null);
                });
            } catch (Exception e) {
                inventoryRunning = false;
                new Handler(Looper.getMainLooper()).post(
                        () -> result.error("INVENTORY_EXCEPTION", e.getMessage(), null)
                );
            } finally {
                opInProgress.set(false);
            }
        }).start();
    }

    private void stopInventory(MethodChannel.Result result) {
        try {
            byte[] stopCmd = CmdBuilder.buildStopInventoryCmd();
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, stopCmd);
            if (sent) {
                inventoryRunning = false;
                result.success("inventory_stopped");
            } else {
                result.error("INVENTORY_STOP_FAILED", "stop cmd not sent", null);
            }
        } catch (Exception e) {
            result.error("INVENTORY_STOP_EXCEPTION", e.getMessage(), null);
        }
    }

    // Internal start/stop (doesn't return result)
    private void internalStartInventory() {
        try {
            byte[] invCmd = CmdBuilder.buildInventoryISOContinueCmd((byte) 0x00, 0);
            if (writeWithRetry(SERVICE_UUID, WRITE_UUID, invCmd)) {
                inventoryRunning = true;
            }
        } catch (Exception ignore) {}
    }

    private void internalStopInventory() {
        try {
            byte[] stopCmd = CmdBuilder.buildStopInventoryCmd();
            if (writeWithRetry(SERVICE_UUID, WRITE_UUID, stopCmd)) {
                inventoryRunning = false;
            }
        } catch (Exception ignore) {}
    }

    private void readTagByMemoryBank(byte memBank, MethodChannel.Result result) {
        byte[] accPwd = new byte[]{0x00, 0x00, 0x00, 0x00}; // Default password
        byte[] wordPtr;

        if (memBank == 0x01) { // EPC
            wordPtr = new byte[]{0x00, 0x02};
        } else {               // TID/USER
            wordPtr = new byte[]{0x00, 0x00};
        }
        byte wordCount = 6;

        byte[] cmd = CmdBuilder.buildReadISOTagCmd(accPwd, memBank, wordPtr, wordCount);
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            result.success("read_tag_command_sent");
        } else {
            result.error("SEND_FAIL", "Unable to send readTag command", null);
        }
    }

    private String bytesToHex(byte[] bytes) {
        if (bytes == null) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    public String bytesToHexString(byte[] bytes) {
        if (bytes == null || bytes.length == 0) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    private void startRadarTracking(String epc, MethodChannel.Result result) {
        radarEpc = epc;
        radarActive = true;

        byte[] cmd = CmdBuilder.buildInventoryISOContinueCmd((byte) 0x00, 0); // time-based
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            inventoryRunning = true;
            result.success("radar_started");
        } else {
            result.error("RADAR_START_FAIL", "Radar tracking not started", null);
        }
    }

    private void stopRadarTracking(MethodChannel.Result result) {
        radarEpc = null;
        radarActive = false;

        byte[] stopCmd = CmdBuilder.buildStopInventoryCmd();
        writeWithRetry(SERVICE_UUID, WRITE_UUID, stopCmd);

        inventoryRunning = false;
        result.success("radar_stopped");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (bleCore != null) {
            bleCore.disconnectedDevice();
            bleCore.setOnNotifyCallback(null);
            bleCore.setIConnectDoneCallback(null);
            bleCore.setIBleDisConnectCallback(null);
        }
        discoveredDevices.clear();
        channel.setMethodCallHandler(null);

        bleReady = false;
        latestAllParam = null;
        inventoryRunning = false;
    }
}
