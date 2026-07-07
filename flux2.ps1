# flux2.ps1
# Skript zur Messung von MTTD und MTTR mit Flux

# 1. Konfiguration
$deployment_name = "meine-test-app"
$app_namespace = "default"
$kustomization_name = "flux-thesis-clean"
$kustomization_namespace = "flux-thesis-clean"

# 2. Sync-Check: Warten, bis Flux bereit ist
Write-Host "Prüfe Flux-Status..."
$isReady = $false
while (-not $isReady) {
    $status = flux get kustomizations $kustomization_name -n $kustomization_namespace -o json | ConvertFrom-Json
    # Prüfe die 'ready' condition im JSON
    $readyCondition = $status.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }
    if ($readyCondition) {
        $isReady = $true
        Write-Host "Flux ist synchron und bereit."
    } else {
        Write-Host "Warte auf Synchronisation..."
        Start-Sleep -Seconds 2
    }
}

# 3. Startpunkt
Write-Host "--- Bereit zur Messung ---"
Write-Host "Führe jetzt deinen 'git push' aus."
$start_push = Get-Date

# 4. Alte Generation speichern
$old_gen = kubectl get deployment $deployment_name -n $app_namespace -o jsonpath='{.metadata.generation}'

# 5. Trigger für Flux (Reconciliation erzwingen)
Write-Host "Triggering Reconciliation..."
flux reconcile kustomization $kustomization_name -n $kustomization_namespace --with-source | Out-Null

# 6. MTTD (Detektion)
Write-Host "Warte auf Detektion..."
while ($true) {
    $new_gen = kubectl get deployment $deployment_name -n $app_namespace -o jsonpath='{.metadata.generation}'
    if ($new_gen -ne $old_gen) {
        $mttd_end = Get-Date
        Write-Host "Änderung erkannt!"
        break
    }
    Start-Sleep -Milliseconds 100
}

# 7. MTTR (Ready-Status)
Write-Host "Warte auf Ready-Status (MTTR)..."
kubectl rollout status deployment $deployment_name -n $app_namespace --timeout=300s | Out-Null
$mttr_end = Get-Date

# 8. Berechnung & Ausgabe
$mttd = $mttd_end - $start_push
$mttr = $mttr_end - $start_push

Write-Host "`n----------------------------"
Write-Host "ERGEBNISSE:"
Write-Host "MTTD: $($mttd.TotalSeconds.ToString("F3")) Sekunden"
Write-Host "MTTR: $($mttr.TotalSeconds.ToString("F3")) Sekunden"
Write-Host "----------------------------"