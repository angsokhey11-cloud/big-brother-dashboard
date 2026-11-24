package com.bigbrother.nativev2;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.ScrollView;
import android.widget.Button;
import android.content.Intent;
import android.provider.Settings;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;

public final class MainActivity extends Activity {
    private TextView status;
    private int dp(int n) { return Math.round(n * getResources().getDisplayMetrics().density); }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24),dp(40),dp(24),dp(24));
        root.setBackgroundColor(Color.WHITE);
        scroll.addView(root);
        setContentView(scroll);
        addText(root, "BIG BROTHER", 28, Color.rgb(23,74,145));
        addText(root, getString(R.string.app_name), 18, Color.DKGRAY);
        addText(root, "Native development build — no live accounting access yet.", 15, Color.DKGRAY);
        status = addText(root, "", 16, Color.DKGRAY);
        addText(root, "Configured server: " + BuildConfig.ENDPOINT, 14, Color.DKGRAY);
        Button refresh = new Button(this);
        refresh.setText("Refresh connection status");
        refresh.setOnClickListener(v -> refreshStatus());
        root.addView(refresh);
        Button settings = new Button(this);
        settings.setText("Network settings");
        settings.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_WIRELESS_SETTINGS)));
        root.addView(settings);
        refreshStatus();
    }
    private TextView addText(LinearLayout root, String value, int sp, int color) {
        TextView text = new TextView(this);
        text.setText(value); text.setTextSize(sp); text.setTextColor(color);
        text.setPadding(0,dp(8),0,dp(8));
        root.addView(text,new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,ViewGroup.LayoutParams.WRAP_CONTENT));
        return text;
    }
    @Override protected void onResume() { super.onResume(); if(status != null) refreshStatus(); }
    private void refreshStatus() {
        ConnectivityManager manager = getSystemService(ConnectivityManager.class);
        NetworkCapabilities caps = manager == null ? null : manager.getNetworkCapabilities(manager.getActiveNetwork());
        status.setText(caps == null ? "Device network: disconnected" : "Device network: connected (server not verified)");
    }
}
