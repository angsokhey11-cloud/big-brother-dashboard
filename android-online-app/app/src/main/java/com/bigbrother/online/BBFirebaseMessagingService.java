package com.bigbrother.online;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

/** Online APK only. Never receives or sends Local Brain data. */
public final class BBFirebaseMessagingService extends FirebaseMessagingService {
    public static final String CHANNEL = "bb_business_updates_v1";
    private static final int MAX_BODY_LENGTH = 160;

    @Override public void onNewToken(String token) {
        super.onNewToken(token);
        // No background API polling or auth-token access from the service.
        // MainActivity will resync the token with the signed-in account when
        // the user next opens the app and has opted into notifications.
        getSharedPreferences("bb_online_native_push_v1", MODE_PRIVATE)
            .edit().putString("latest_token", token).apply();
    }

    @Override public void onMessageReceived(RemoteMessage message) {
        super.onMessageReceived(message);
        // FCM automatically displays a notification payload in background.
        // Foreground/data-only messages are shown here using native Android.
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) return;
        Map<String, String> data = message.getData();
        String route = safeRoute(data.get("route"));
        String eventKey = safeData(data.get("eventKey"), 180);
        String entityId = safeData(data.get("entityId"), 120);
        String body = message.getNotification() != null
            ? message.getNotification().getBody()
            : data.get("body");
        if (body == null || body.trim().isEmpty())
            body = "An important BIG BROTHER update is available.";
        if (body.length() > MAX_BODY_LENGTH)
            body = body.substring(0, MAX_BODY_LENGTH);
        createChannel();
        Intent target = new Intent(this, MainActivity.class);
        target.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        target.putExtra("bb_notification_route", route);
        target.putExtra("bb_notification_event", eventKey);
        target.putExtra("bb_notification_entity", entityId);
        int requestCode = (eventKey.isEmpty() ? System.nanoTime() + "" : eventKey).hashCode() & 0x7fffffff;
        PendingIntent action = PendingIntent.getActivity(this, requestCode, target,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notice = new Notification.Builder(this, CHANNEL)
            .setContentTitle("BIG BROTHER")
            .setContentText(body)
            .setSmallIcon(R.drawable.launcher)
            .setAutoCancel(true)
            .setContentIntent(action)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .build();
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) manager.notify(requestCode, notice);
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationChannel channel = new NotificationChannel(CHANNEL,
            "BIG BROTHER business alerts", NotificationManager.IMPORTANCE_DEFAULT);
        channel.setDescription("Important company requests, collections and staff updates");
        NotificationManager nm = getSystemService(NotificationManager.class);
        if (nm != null) nm.createNotificationChannel(channel);
    }
    private static String safeRoute(String value) {
        return value != null && value.matches("[a-z0-9-]{2,70}")
            ? value : "notification-center";
    }
    private static String safeData(String value, int size) {
        if (value == null) return "";
        value = value.replaceAll("[^a-zA-Z0-9_./:-]", "");
        return value.length() <= size ? value : value.substring(0, size);
    }
}
