# messung.ps1
$deploymentName = "meine-test-app" 
$namespace = "default"

# 1. Aktuelle ResourceVersion ermitteln (Das ist der absolut eindeutige ID-String)
$dep = kubectl get deployment $deploymentName -n $namespace -o json | ConvertFrom-Json
$old_rv = $dep.metadata.resourceVersion

Write-Host "Warte auf Detektion durch Flux..." -ForegroundColor Cyan

# 2. Warten, bis sich die ResourceVersion aendert
while ($true) {
    $currentDep = kubectl get deployment $deploymentName -n $namespace -o json | ConvertFrom-Json
    if ($currentDep.metadata.resourceVersion -ne $old_rv) {
        $mttd_end = Get-Date
        Write-Host "Aenderung erkannt! (MTTD erreicht)" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 0.5
}

# 3. Warten auf Ready
Write-Host "Warte auf Ready-Status (MTTR)..." -ForegroundColor Yellow
kubectl rollout status deployment $deploymentName -n $namespace --timeout=600s | Out-Null
$mttr_end = Get-Date

# 5. Berechnung und Ausgabe
$mttd = $mttd_end - $start_push
$mttr = $mttr_end - $start_push

Write-Host "--------------------------------------------"
Write-Host "ERGEBNISSE:"
Write-Host "MTTD (Detektion):   $($mttd.TotalSeconds) Sekunden"
Write-Host "MTTR (Gesamtdauer): $($mttr.TotalSeconds) Sekunden"
Write-Host "--------------------------------------------"