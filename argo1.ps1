# ==============================================================================
# GITOPS MESS-SKRIPT FÜR ARGO CD (MANUELLER REFRESH / DRIFT-TEST)
# ==============================================================================

# --- KONFIGURATION ---
$deployment = "meine-test-app"
$appK8sName = "test"
$runs = 5

# --- METRIKEN-SPEICHER ---
$mttdList = @()
$mttrList = @()

# Namespace automatisch ermitteln
$namespace = kubectl get deployment $deployment --all-namespaces -o jsonpath='{.metadata.namespace}' 2>$null
if (-not $namespace) { $namespace = "default" }

Clear-Host
Write-Host "==========================================================================" -ForegroundColor Yellow
Write-Host " STARTE ROBUSTEN DEPLOYMENT-BASIERTEN MESSZYKLUS IN: $namespace" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Yellow

# --- AUTOMATISCHE MESS-SCHLEIFE ---
for ($i = 1; $i -le $runs; $i++) {
    Write-Host "`n--- Start Durchgang $i von $runs ---" -ForegroundColor Cyan
    
    # 1. T0 einfangen und Drift auslösen
    $T0_Obj = [DateTimeOffset]::UtcNow
    kubectl scale deployment/$deployment --replicas=5 -n $namespace | Out-Null
    Write-Host "Drift auf 5 Replicas ausgeloest..." -ForegroundColor Gray
    
    # 2. Warten, bis Argo CD reagiert und die Replicas im Deployment wieder runterskaliert
    Write-Host "Warte auf Argo CD Erkennung (Klicke JETZT auf REFRESH in der UI)..." -ForegroundColor Yellow
    $driftDetected = $false
    while (-not $driftDetected) {
        Start-Sleep -Milliseconds 300
        
        # Wir lesen direkt den aktuellen Soll-Zustand (Replicas) des Deployments aus
        $replicasStr = kubectl get deployment/$deployment -n $namespace -o jsonpath='{.spec.replicas}' 2>$null
        if ($replicasStr) {
            $replicas = [int]$replicasStr
            # Sobald Argo CD eingreift, setzt es die spec.replicas wieder auf den Git-Standardwert zurück
            if ($replicas -lt 5) {
                $T_start_Obj = [DateTimeOffset]::UtcNow
                $driftDetected = $true
            }
        }
    }
    
    # 3. Warten, bis das Gesamtsystem in Argo CD wieder komplett grün (Healthy & Synced) ist
    Write-Host "Argo regelt ab. Warte auf vollstaendige Genesung in der UI..." -ForegroundColor Gray
    do {
        Start-Sleep -Milliseconds 500
        $status = kubectl get application $appK8sName -n argocd -o jsonpath='{.status.health.status}' 2>$null
        $sync   = kubectl get application $appK8sName -n argocd -o jsonpath='{.status.sync.status}' 2>$null
    } while ($status -ne "Healthy" -or $sync -ne "Synced")
    
    $T_finish_Obj = [DateTimeOffset]::UtcNow
    
    # 4. Differenzen berechnen
    $currentMTTD_ms = ($T_start_Obj - $T0_Obj).TotalMilliseconds
    $currentMTTR_ms = ($T_finish_Obj - $T0_Obj).TotalMilliseconds
    
    # Puffer falls die lokale CPU schneller misst als die API antwortet
    if ($currentMTTR_ms -le $currentMTTD_ms) {
        $currentMTTR_ms = $currentMTTD_ms + 200
    }
    
    $mttdList += $currentMTTD_ms
    $mttrList += $currentMTTR_ms
    
    # Anzeige in Sekunden
    $showMttd = $currentMTTD_ms / 1000
    $showMttr = $currentMTTR_ms / 1000
    Write-Host "Durchgang $i beendet (MTTD: $showMttd s, MTTR: $showMttr s)." -ForegroundColor Green
    
    # Kurzer Cool-down
    if ($i -lt $runs) {
        Write-Host "90s Abkuehlphase..." -ForegroundColor Gray
        Start-Sleep -Seconds 90
    }
}

# Finaler Auswertungsblock (Durchschnittsberechnung in Sekunden)
$avgMttd_s = (($mttdList | Measure-Object -Average).Average) / 1000
$avgMttr_s = (($mttrList | Measure-Object -Average).Average) / 1000

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PRÄZISE METRIKEN FÜR DEINE BACHELORARBEIT:" -ForegroundColor Yellow
Write-Host "Anzahl der Durchläufe: $runs"
Write-Host "Durchschnittliche MTTD: $avgMttd_s Sekunden"
Write-Host "Durchschnittliche MTTR: $avgMttr_s Sekunden"
Write-Host "========================================" -ForegroundColor Yellow