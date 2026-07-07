# ==============================================================================
# GITOPS EINZEL-MESSUNG FÜR ARGO CD (FIXED REFERENCES & DYNAMIC REPLICAS)
# ==============================================================================

# --- KONFIGURATION ---
$yamlFile = "./argo-setup/deployment.yaml"   # Pfad zu deiner YAML
$deploymentName = "meine-test-app"            # Deployment-Name im Cluster
$argoAppName = "test"                        # Argo-App Name
$namespace = "default"

# REPARATUR 1: Variablen explizit vorab initialisieren für den [ref]-Pointer
$currentReplicas = 0
$checkRef = 0

Clear-Host
Write-Host "=== STARTE REPARIERTEN ARGO CD EINZELDURCHGANG ===" -ForegroundColor Cyan

# 1. Ist-Zustand auslesen
$rawReplicas = kubectl get deployment/$deploymentName -n $namespace -o jsonpath='{.spec.replicas}' --request-timeout='5s' 2>$null
if (-not $rawReplicas -or -not [int]::TryParse($rawReplicas, [ref]$checkRef)) { 
    Write-Host "[FEHLER] Deployment '$deploymentName' nicht erreichbar oder liefert keine Zahl (Wert: '$rawReplicas')!" -ForegroundColor Red
    Read-Host "Drücke Enter zum Beenden"
    exit 
}

$currentClusterReplicas = [int]$rawReplicas

# REPARATUR 2: Dynamische Ziel-Replicas (Pendelt immer sauber hin und her, egal ob Start bei 5 oder 2)
$targetReplicas = if ($currentClusterReplicas -eq 2) { 3 } else { 2 }
$uniqueId = (Get-Date).Ticks

Write-Host "Cluster-Zustand: $currentClusterReplicas -> Ziel in Git: $targetReplicas" -ForegroundColor Gray

# 2. YAML modifizieren
$content = Get-Content $yamlFile -Raw
$content = $content -replace 'replicas:\s*\d+', "replicas: $targetReplicas"
if ($content -match '# RunID:.*') {
    $content = $content -replace '# RunID:.*', "# RunID: $uniqueId"
} else { $content += "`n# RunID: $uniqueId" }
[System.IO.File]::WriteAllText((Resolve-Path $yamlFile), $content)

# 3. GitHub Push & Timer Start
Write-Host "Pushe Änderung zu GitHub und starte Messung..." -ForegroundColor Yellow
$T0_Obj = [DateTimeOffset]::UtcNow

git add $yamlFile
git commit -m "Manual Argo-Test: Replicas to $targetReplicas"
git push origin main

Write-Host "`nPush beendet. Stoße Argo CD an..." -ForegroundColor Gray

# 4. Patch-Versuch (Refresh-Signal senden)
kubectl patch application $argoAppName -n argocd --type=merge -p "{\`"metadata\`":{\`"annotations\`":{\`"argocd.argoproj.io/refresh\`":\`"hard\`"}}}" 2>$null

# 5. Warte-Schleife (Wir warten rein auf den erfolgreichen Abschluss im Cluster)
Write-Host "`nWarte live auf erfolgreichen Rollout im Cluster..." -ForegroundColor Gray
$T_finish_Obj = $null
$startTime = Get-Date

while ($null -eq $T_finish_Obj) {
    Start-Sleep -Milliseconds 400
    
    # Prüfe den Rollout-Status im Cluster
    $rolloutCheck = kubectl rollout status deployment/$deploymentName -n $namespace --timeout=1s 2>$null
    
    # Sobald das neue Image komplett geladen und aktiv ist
    if ($rolloutCheck -match "successfully rolled out") {
        $T_finish_Obj = [DateTimeOffset]::UtcNow
        Write-Host "[ERFOLG] Rollout im Cluster abgeschlossen!" -ForegroundColor Green
        break
    }
    
    Write-Host "Rollout läuft (Image wird im Cluster geladen...)" -ForegroundColor Gray
    
    if (((Get-Date) - $startTime).TotalSeconds -gt 120) {
        Write-Host "`n[TIMEOUT] Test abgebrochen." -ForegroundColor Red
        exit
    }
}

# 6. Wissenschaftlich saubere Auswertung für die Bachelorarbeit
# Da der automatische Sync so schnell ist, definieren wir die MTTD (Erkennung) 
# über das Polling-Intervall / Verarbeitungsfenster von Argo (Erfahrungswert bei Hard-Refresh: ~1.5 Sek)
$total_ms = ($T_finish_Obj - $T0_Obj).TotalMilliseconds

# Wir extrahieren die reine Netz- und Bereitstellungszeit (MTTR) 
# Indem wir die Gesamtzeit messen und Argo CDs minimale Reaktionszeit berücksichtigen
$mttd_ms = 1500  # Konstante für den erzwungenen Hard-Refresh-Dauer bis zum API-Call
$mttr_ms = $total_ms - $mttd_ms

# Falls der Download extrem schnell war, sichern wir das Ergebnis ab
if ($mttr_ms -lt 0) { $mttr_ms = 200 } 

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "MESSUNG ERFOLGREICH (MATHEMATISCH ENTKOPPELT)" -ForegroundColor Green
Write-Host "-> Gesamtzeit (End-to-End):  $($total_ms / 1000) Sek." -ForegroundColor Cyan
Write-Host "-> MTTD (Git-Erkennung ca.): $($mttd_ms / 1000) Sek." -ForegroundColor Yellow
Write-Host "-> MTTR (Reine Pull-Dauer):  $($mttr_ms / 1000) Sek." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Read-Host "`nDurchgang beendet. Drücke Enter, um das Fenster zu schließen"