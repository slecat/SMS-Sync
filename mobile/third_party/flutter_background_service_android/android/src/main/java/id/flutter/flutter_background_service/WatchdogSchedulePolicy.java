package id.flutter.flutter_background_service;

public final class WatchdogSchedulePolicy {
    private static final int LOW_FREQUENCY_INTERVAL_MILLIS = 60000;

    private WatchdogSchedulePolicy() {}

    public static int nextCheckIntervalMillis() {
        return LOW_FREQUENCY_INTERVAL_MILLIS;
    }

    public static boolean shouldSchedule(boolean manuallyStopped, long backgroundHandle) {
        return !manuallyStopped && backgroundHandle > 0;
    }
}
