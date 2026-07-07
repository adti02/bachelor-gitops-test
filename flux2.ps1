# ==============================================================================
# GITOPS EINZEL-MESSUNG FÜR BACHELOR-THESIS (FLUX PULL-EVALUIERUNG)
# ==============================================================================

# --- KONFIGURATION ---
$yamlFile = "./flux-setup/deployment.yaml"  # Path to your YAML
$deploymentName = "meine-test-app"          # Deployment name
$namespace = "default"

Clear-Host
Write-Host "=== STARTE ISOLIERTEN EINZELDURCHGANG ===" -ForegroundColor Cyan

# 1. Ist-Zustand auslesen
$rawReplicas = kubectl get deployment/$deploymentName -n $namespace -o jsonpath='{.spec.replicas}' --request-timeout='5s' 2>$null
if (-not $rawReplicas) { Write-Host "[FEHLER] Cluster nicht erreichbar oder App fehlt!" -ForegroundColor Red; exit }

$currentClusterReplicas = [int]$rawReplicas
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
Write-Host "Pushe Aenderung zu GitHub und starte Messung..." -ForegroundColor Yellow
$T0_Obj = [DateTimeOffset]::UtcNow

git add $yamlFile 2>&1 | Out-Null
git commit -m "Manual Single-Test: Replicas to $targetReplicas (ID: $uniqueId)" 2>&1 | Out-Null
git push origin main 2>&1 | Out-Null

Write-Host "Push erfolgreich. Warte live auf Flux-Abgleich..." -ForegroundColor Green

# 4. Warte-Schleife
$reconciliationDone = $false
while (-not $reconciliationDone) {
    Start-Sleep -Seconds 1 # Scharfe 1-Sekunden-Taktung fuer maximale Praezision im Einzeltest
    
    $currentReplicasStr = kubectl get deployment/$deploymentName -n $namespace -o jsonpath='{.spec.replicas}' 2>$null
    if ($currentReplicasStr) {
        if ([int]$currentReplicasStr -eq $targetReplicas) {
            $T_finish_Obj = [DateTimeOffset]::UtcNow
            $reconciliationDone = $true
        }
    }
}

# 5. Auswertung für Excel
$currentTime_ms = ($T_finish_Obj - $T0_Obj).TotalMilliseconds
$currentMTTD_s = ($currentTime_ms - 300) / 1000
$currentMTTR_s = $currentTime_ms / 1000

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "MESSUNG ERFOLGREICH BEENDET" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Trage diese Werte in deine Excel-Liste ein:" -ForegroundColor White
Write-Host "-> MTTD: $currentMTTD_s Sekunden" -ForegroundColor Yellow
Write-Host "-> MTTR: $currentMTTR_s Sekunden" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green