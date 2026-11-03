# Re-habilita paquetes desactivados por el afinado LLM (2026-10-31).
param([string]$Serial = $env:GT2_ADB_SERIAL)

$packages = @(
  "com.heytap.pictorial",
  "com.coloros.assistantscreen",
  "com.heytap.music",
  "com.oplus.games",
  "com.google.android.apps.podcasts",
  "com.google.android.apps.chromecast.app",
  "com.amazon.appmanager",
  "com.coloros.video",
  "com.coloros.karaoke",
  "com.coloros.childrenspace",
  "com.google.android.apps.youtube.music",
  "com.google.android.apps.docs",
  "com.google.android.apps.subscriptions.red",
  "com.google.android.apps.tachyon",
  "andes.oplus.documentsreader",
  "com.oneplus.brickmode",
  "com.coloros.backuprestore",
  "com.coloros.note"
)

foreach ($pkg in $packages) {
  Write-Host "enable $pkg"
  adb -s $Serial shell "pm enable $pkg" 2>&1 | Out-Null
}
Write-Host "Listo. Reinicia apps deseadas desde el launcher."
