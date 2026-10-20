package dev.local.aicorecheck;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import com.google.mlkit.genai.common.FeatureStatus;
import com.google.mlkit.genai.prompt.*;
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class MainActivity extends Activity {
    private TextView output;
    private volatile GenerativeModelFutures selectedModel;
    private void report(String text) {
        Log.i("AICoreCheck", text);
        try (FileOutputStream file = openFileOutput("results.txt", MODE_APPEND)) {
            file.write((text + "\n").getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) { Log.e("AICoreCheck", "Cannot save result", e); }
        runOnUiThread(() -> output.append(text + "\n\n"));
    }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        output = new TextView(this);
        output.setTextSize(18);
        output.setPadding(32,64,32,32);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        Button offline = new Button(this);
        offline.setText("Run offline test");
        offline.setOnClickListener(v -> {
            offline.setEnabled(false);
            Executors.newSingleThreadExecutor().execute(() -> {
                try {
                    ConnectivityManager connectivity = getSystemService(ConnectivityManager.class);
                    int internetNetworks = 0;
                    for (Network network : connectivity.getAllNetworks()) {
                        NetworkCapabilities capabilities = connectivity.getNetworkCapabilities(network);
                        if (capabilities != null && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) internetNetworks++;
                    }
                    report("OFFLINE_TEST_INTERNET_NETWORKS=" + internetNetworks);
                    if (internetNetworks != 0) {
                        report("Turn on airplane mode, turn Wi-Fi off, then tap Run offline test again.");
                        return;
                    }
                    String prompt = "What is " + (System.currentTimeMillis() % 40 + 10) + " plus 25? Answer with just the number.";
                    report("OFFLINE_PROMPT=" + prompt);
                    GenerativeModelFutures model = selectedModel != null ? selectedModel : GenerativeModelFutures.from(Generation.INSTANCE.getClient());
                    Object response = model.generateContent(prompt).get(120, TimeUnit.SECONDS);
                    report("OFFLINE_RESPONSE=" + response);
                    report("OFFLINE_TEST_PASSED");
                } catch (Throwable e) {
                    report("OFFLINE_ERROR=" + e);
                    if (e.getCause() != null) report("OFFLINE_CAUSE=" + e.getCause());
                } finally { runOnUiThread(() -> offline.setEnabled(true)); }
            });
        });
        layout.addView(offline);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(output);
        layout.addView(scroll);
        setContentView(layout);
        report("Checking Gemini Nano through Google ML Kit…");
        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                GenerativeModelFutures model = GenerativeModelFutures.from(Generation.INSTANCE.getClient());
                int status = model.checkStatus().get(90, TimeUnit.SECONDS);
                String label = status == FeatureStatus.AVAILABLE ? "AVAILABLE" : status == FeatureStatus.DOWNLOADABLE ? "DOWNLOADABLE" : status == FeatureStatus.DOWNLOADING ? "DOWNLOADING" : "UNAVAILABLE";
                report("STATUS=" + label + " (" + status + ")");
                if (status == FeatureStatus.AVAILABLE) {
                    report("MODEL=" + model.getBaseModelName().get(30, TimeUnit.SECONDS));
                    report("PROMPT=What is 17 plus 25? Answer with just the number.");
                    long start = System.currentTimeMillis();
                    Object response = model.generateContent("What is 17 plus 25? Answer with just the number.").get(120, TimeUnit.SECONDS);
                    report("RESPONSE=" + response);
                    report("ELAPSED_MS=" + (System.currentTimeMillis() - start));
                }
                int[] stages = {ModelReleaseStage.STABLE, ModelReleaseStage.PREVIEW};
                int[] preferences = {ModelPreference.FULL, ModelPreference.FAST};
                for (int stage : stages) {
                    for (int preference : preferences) {
                        String variant = (stage == ModelReleaseStage.STABLE ? "STABLE" : "PREVIEW") + "/" + (preference == ModelPreference.FULL ? "FULL" : "FAST");
                        try {
                            ModelConfig.Builder modelBuilder = new ModelConfig.Builder();
                            modelBuilder.setReleaseStage(stage);
                            modelBuilder.setPreference(preference);
                            GenerationConfig.Builder generationBuilder = new GenerationConfig.Builder();
                            generationBuilder.setModelConfig(modelBuilder.build());
                            GenerationConfig config = generationBuilder.build();
                            GenerativeModelFutures candidate = GenerativeModelFutures.from(Generation.INSTANCE.getClient(config));
                            int variantStatus = candidate.checkStatus().get(30, TimeUnit.SECONDS);
                            String variantLabel = variantStatus == FeatureStatus.AVAILABLE ? "AVAILABLE" : variantStatus == FeatureStatus.DOWNLOADABLE ? "DOWNLOADABLE" : variantStatus == FeatureStatus.DOWNLOADING ? "DOWNLOADING" : "UNAVAILABLE";
                            report("VARIANT=" + variant + " STATUS=" + variantLabel);
                            if (variantStatus == FeatureStatus.AVAILABLE && selectedModel == null) {
                                selectedModel = candidate;
                                report("SELECTED_VARIANT=" + variant);
                                report("SELECTED_MODEL=" + candidate.getBaseModelName().get(30, TimeUnit.SECONDS));
                            }
                        } catch (Throwable variantError) { report("VARIANT=" + variant + " ERROR=" + variantError); }
                    }
                }
                report("DONE");
            } catch (Throwable e) {
                Log.e("AICoreCheck", "Diagnostic failed", e);
                report("ERROR=" + e);
                if (e.getCause() != null) report("CAUSE=" + e.getCause());
            }
        });
    }
}
