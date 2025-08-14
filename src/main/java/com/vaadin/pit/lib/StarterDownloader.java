package com.vaadin.pit.lib;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.util.zip.ZipInputStream;

public class StarterDownloader {
    public static void downloadAndUnzipStarter(String preset, File targetDir, boolean verbose) throws IOException {
        String[] presets = preset.split("_");
        StringBuilder presetParams = new StringBuilder();
        for (String p : presets) {
            presetParams.append("&preset=").append(p);
        }
        String url = "https://start.vaadin.com/dl?" + presetParams + "&projectName=" + preset;
        File zipFile = new File(targetDir, preset + ".zip");
        if (verbose) {
            System.out.println("Downloading: " + url);
        }
        downloadFile(url, zipFile);
        unzip(zipFile, targetDir);
        Files.deleteIfExists(zipFile.toPath());
    }

    private static void downloadFile(String urlStr, File dest) throws IOException {
        HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
        conn.setRequestProperty("User-Agent", "Java");
        try (FileOutputStream out = new FileOutputStream(dest)) {
            conn.getInputStream().transferTo(out);
        }
    }

    private static void unzip(File zipFile, File destDir) throws IOException {
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(zipFile.toPath()))) {
            java.util.zip.ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                File newFile = new File(destDir, entry.getName());
                if (entry.isDirectory()) {
                    newFile.mkdirs();
                } else {
                    newFile.getParentFile().mkdirs();
                    try (FileOutputStream fos = new FileOutputStream(newFile)) {
                        zis.transferTo(fos);
                    }
                }
            }
        }
    }
}
