package com.gamelauncher.nativebridge;

import android.app.ActivityManager;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.StatFs;
import android.provider.Settings;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Pont Android du Game Launcher.
 *
 * Ce plugin s'enregistre tout seul (GeneratedPluginRegistrant) : aucune
 * modification de MainActivity n'est nécessaire. Le nom du canal doit rester
 * identique à celui de lib/core/native_bridge.dart.
 */
public class GameLauncherNativePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {

    private static final String CHANNEL = "gamelauncher/native";
    private static final String BRIDGE_VERSION = "2.0.0";
    private static final int ICON_SIZE_GAME_PX = 192;
    private static final int ICON_SIZE_APP_PX = 96;

    private MethodChannel channel;
    private Context context;
    private ExecutorService executor;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // ------------------------------------------------------------ cycle de vie

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        executor = Executors.newSingleThreadExecutor();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        if (executor != null) {
            executor.shutdown();
            executor = null;
        }
        context = null;
    }

    // --------------------------------------------------------------- appels

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "ping":
                    result.success(BRIDGE_VERSION);
                    break;
                case "getGames": {
                    final boolean includeAll = Boolean.TRUE.equals(call.argument("includeAll"));
                    runInBackground(result, () -> listGames(includeAll));
                    break;
                }
                case "launchGame": {
                    final String pkg = call.argument("package");
                    result.success(launchGame(pkg));
                    break;
                }
                case "openAppInfo": {
                    final String pkg = call.argument("package");
                    result.success(openAppInfo(pkg));
                    break;
                }
                case "getBattery":
                    result.success(batteryInfo());
                    break;
                case "getMemory":
                    result.success(memoryInfo());
                    break;
                case "getStorage":
                    result.success(storageInfo());
                    break;
                case "getDeviceInfo":
                    result.success(deviceInfo());
                    break;
                case "cleanRam": {
                    final String keep = call.argument("keep");
                    runInBackground(result, () -> cleanRam(keep));
                    break;
                }
                case "dndStatus":
                    result.success(dndStatus());
                    break;
                case "openDndSettings":
                    openDndSettings();
                    result.success(null);
                    break;
                case "setDnd": {
                    final boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
                    result.success(setDnd(enabled));
                    break;
                }
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Throwable t) {
            result.error("native_error", String.valueOf(t.getMessage()), null);
        }
    }

    /** Exécute [job] sur un thread de fond, puis répond sur le thread principal. */
    private void runInBackground(final MethodChannel.Result result, final Callable<Object> job) {
        final ExecutorService exec = executor;
        if (exec == null) {
            result.error("native_error", "Plugin détaché du moteur Flutter.", null);
            return;
        }
        exec.execute(() -> {
            try {
                final Object value = job.call();
                mainHandler.post(() -> result.success(value));
            } catch (final Throwable t) {
                final String message = String.valueOf(t.getMessage());
                mainHandler.post(() -> result.error("native_error", message, null));
            }
        });
    }

    // ------------------------------------------------------------------ jeux

    @SuppressWarnings("deprecation")
    private boolean isGame(ApplicationInfo info) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && info.category == ApplicationInfo.CATEGORY_GAME) {
            return true;
        }
        return (info.flags & ApplicationInfo.FLAG_IS_GAME) != 0;
    }

    @SuppressWarnings("deprecation")
    private List<Map<String, Object>> listGames(boolean includeAll) {
        final PackageManager pm = context.getPackageManager();
        final Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        final String self = context.getPackageName();
        final Set<String> seen = new HashSet<>();
        final List<Map<String, Object>> out = new ArrayList<>();

        for (ResolveInfo ri : pm.queryIntentActivities(intent, 0)) {
            final String pkg = ri.activityInfo.packageName;
            if (pkg.equals(self) || !seen.add(pkg)) {
                continue;
            }
            final boolean game = isGame(ri.activityInfo.applicationInfo);
            if (!includeAll && !game) {
                continue;
            }
            final CharSequence label = ri.loadLabel(pm);
            final Map<String, Object> m = new HashMap<>();
            m.put("name", label == null ? pkg : label.toString());
            m.put("package", pkg);
            m.put("isGame", game);
            m.put("icon", iconPng(ri.loadIcon(pm), game ? ICON_SIZE_GAME_PX : ICON_SIZE_APP_PX));
            out.add(m);
        }

        // Les jeux d'abord, puis l'ordre alphabétique.
        Collections.sort(out, (a, b) -> {
            final boolean ga = Boolean.TRUE.equals(a.get("isGame"));
            final boolean gb = Boolean.TRUE.equals(b.get("isGame"));
            if (ga != gb) {
                return ga ? -1 : 1;
            }
            final String na = String.valueOf(a.get("name")).toLowerCase(Locale.ROOT);
            final String nb = String.valueOf(b.get("name")).toLowerCase(Locale.ROOT);
            return na.compareTo(nb);
        });
        return out;
    }

    private byte[] iconPng(Drawable drawable, int sizePx) {
        try {
            final Bitmap bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888);
            final Canvas canvas = new Canvas(bmp);
            drawable.setBounds(0, 0, sizePx, sizePx);
            drawable.draw(canvas);
            final ByteArrayOutputStream stream = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.PNG, 100, stream);
            bmp.recycle();
            return stream.toByteArray();
        } catch (Throwable t) {
            return null;
        }
    }

    private boolean launchGame(String pkg) {
        if (pkg == null || pkg.isEmpty()) {
            return false;
        }
        try {
            final Intent intent = context.getPackageManager().getLaunchIntentForPackage(pkg);
            if (intent == null) {
                return false;
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    /** Ouvre la fiche Android de l'appli (désinstaller, vider le cache, permissions…). */
    private boolean openAppInfo(String pkg) {
        if (pkg == null || pkg.isEmpty()) {
            return false;
        }
        try {
            final Intent intent = new Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", pkg, null));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    // -------------------------------------------------- batterie / appareil

    private Map<String, Object> batteryInfo() {
        final Intent i = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        int level = -1;
        int scale = -1;
        int tenths = 0;
        int status = -1;
        int health = 1;
        int plugged = 0;
        int voltage = 0;
        String technology = "";
        if (i != null) {
            level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            scale = i.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            // Android donne la température en dixièmes de °C (352 = 35,2 °C).
            tenths = i.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0);
            status = i.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            health = i.getIntExtra(BatteryManager.EXTRA_HEALTH, 1);
            plugged = i.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0);
            voltage = i.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0);
            final String t = i.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY);
            if (t != null) {
                technology = t;
            }
        }
        final int percent = (level >= 0 && scale > 0) ? (level * 100 / scale) : -1;
        final boolean charging = status == BatteryManager.BATTERY_STATUS_CHARGING
                || status == BatteryManager.BATTERY_STATUS_FULL;

        int thermal = -1;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            final PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                thermal = pm.getCurrentThermalStatus();
            }
        }

        final Map<String, Object> m = new HashMap<>();
        m.put("level", percent);
        m.put("tempC", tenths / 10.0);
        m.put("charging", charging);
        m.put("thermal", thermal);
        m.put("voltage", voltage / 1000.0);
        m.put("health", health);
        m.put("plugged", plugged);
        m.put("technology", technology);
        return m;
    }

    private Map<String, Object> deviceInfo() {
        final Map<String, Object> m = new HashMap<>();
        m.put("model", String.valueOf(Build.MODEL));
        m.put("manufacturer", String.valueOf(Build.MANUFACTURER));
        m.put("brand", String.valueOf(Build.BRAND));
        m.put("androidVersion", String.valueOf(Build.VERSION.RELEASE));
        m.put("sdk", Build.VERSION.SDK_INT);
        m.put("cores", Runtime.getRuntime().availableProcessors());
        return m;
    }

    // ------------------------------------------------------- mémoire / stockage

    private long availMb(ActivityManager am) {
        final ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        return mi.availMem / 1048576L;
    }

    private Map<String, Object> memoryInfo() {
        final ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        final ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        final Map<String, Object> m = new HashMap<>();
        m.put("availMb", mi.availMem / 1048576L);
        m.put("totalMb", mi.totalMem / 1048576L);
        return m;
    }

    private Map<String, Object> storageInfo() {
        final StatFs fs = new StatFs(Environment.getDataDirectory().getPath());
        final Map<String, Object> m = new HashMap<>();
        m.put("totalMb", fs.getTotalBytes() / 1048576L);
        m.put("freeMb", fs.getAvailableBytes() / 1048576L);
        return m;
    }

    /**
     * Ferme les processus d'ARRIÈRE-PLAN des applis installées. Android refuse
     * de fermer l'appli au premier plan et les applis système ; certaines
     * applis seront relancées par le système, donc le gain est souvent partiel.
     * [keep] = le jeu qu'on va lancer : on ne le ferme jamais.
     */
    @SuppressWarnings("deprecation")
    private Map<String, Object> cleanRam(String keep) throws InterruptedException {
        final ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        final PackageManager pm = context.getPackageManager();
        final long before = availMb(am);

        final Set<String> protectedPkgs = new HashSet<>();
        protectedPkgs.add(context.getPackageName());
        if (keep != null && !keep.isEmpty()) {
            protectedPkgs.add(keep);
        }
        final Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        for (ResolveInfo ri : pm.queryIntentActivities(home, 0)) {
            protectedPkgs.add(ri.activityInfo.packageName);
        }

        int processed = 0;
        final Intent launcher = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        for (ResolveInfo ri : pm.queryIntentActivities(launcher, 0)) {
            final String pkg = ri.activityInfo.packageName;
            if (protectedPkgs.contains(pkg)) {
                continue;
            }
            final int flags = ri.activityInfo.applicationInfo.flags;
            final boolean pureSystem = (flags & ApplicationInfo.FLAG_SYSTEM) != 0
                    && (flags & ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0;
            if (pureSystem) {
                continue;
            }
            am.killBackgroundProcesses(pkg);
            processed++;
        }

        // Laisse au système le temps de récupérer la mémoire avant de re-mesurer.
        Thread.sleep(900);

        final ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        final Map<String, Object> m = new HashMap<>();
        m.put("availBeforeMb", before);
        m.put("availAfterMb", mi.availMem / 1048576L);
        m.put("totalMb", mi.totalMem / 1048576L);
        m.put("processed", processed);
        return m;
    }

    // ---------------------------------------------------------- Ne pas déranger

    private Map<String, Object> dndStatus() {
        boolean granted = false;
        boolean active = false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            final NotificationManager nm =
                    (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) {
                granted = nm.isNotificationPolicyAccessGranted();
                final int f = nm.getCurrentInterruptionFilter();
                active = f == NotificationManager.INTERRUPTION_FILTER_PRIORITY
                        || f == NotificationManager.INTERRUPTION_FILTER_ALARMS
                        || f == NotificationManager.INTERRUPTION_FILTER_NONE;
            }
        }
        final Map<String, Object> m = new HashMap<>();
        m.put("granted", granted);
        m.put("active", active);
        return m;
    }

    private void openDndSettings() {
        try {
            final Intent intent = new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Throwable t) {
            // Écran introuvable sur certains appareils : on ignore.
        }
    }

    /**
     * PRIORITY = le « Ne pas déranger » habituel (appels de favoris et alarmes
     * restent autorisés selon les réglages du téléphone). ALL = tout rétabli.
     */
    private boolean setDnd(boolean enabled) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false;
        }
        final NotificationManager nm =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || !nm.isNotificationPolicyAccessGranted()) {
            return false;
        }
        nm.setInterruptionFilter(enabled
                ? NotificationManager.INTERRUPTION_FILTER_PRIORITY
                : NotificationManager.INTERRUPTION_FILTER_ALL);
        return true;
    }
}
