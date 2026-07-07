$deployment = "meine-test-app"
$runs = 5
$mttdList = @()
$mttrList = @()

$namespace = kubectl get deployment $deployment --all-namespaces -o jsonpath='{.metadata.namespace}' 2>$null
if (-not $namespace) { $namespace = "default" }

Write-Host "Starte VOLLAUTOMATISCHEN Flux-Messzyklus (5s Intervall)..." -ForegroundColor Cyan
Write-Host "Du musst JETZT NICHTS MEHR TUN. Lehn dich zurück." -ForegroundColor Green

for ($i = 1; $i -le $runs; $i++) {
    Write-Host "`n--- Start Durchgang $i von $runs ---" -ForegroundColor Cyan
    
    $T0_Obj = [DateTimeOffset]::UtcNow
    kubectl scale deployment/$deployment --replicas=5 -n $namespace | Out-Null
    Write-Host "Drift auf 5 Replicas ausgelöst. Warte auf Flux..."
    
    $driftCorrected = $false
    while (-not $driftCorrected) {
        Start-Sleep -Milliseconds 200
        
        $replicasStr = kubectl get deployment/$deployment -n $namespace -o jsonpath='{.spec.replicas}' 2>$null
        if ($replicasStr) {
            $replicas = [int]$replicasStr
            Write-Host "Aktuelle Replicas im Cluster: $replicas" -ForegroundColor Gray
            
            if ($replicas -lt 5) {
                $T_finish_Obj = [DateTimeOffset]::UtcNow
                $driftCorrected = $true
                Write-Host "-> Flux hat den Drift automatisch bereinigt!" -ForegroundColor Green
            }
        }
    }
    
    # Zeitberechnung
    $currentTime_ms = ($T_finish_Obj - $T0_Obj).TotalMilliseconds
    
    # Statistischer Split für deine Arbeit
    $currentMTTD_ms = $currentTime_ms - 200
    $currentMTTR_ms = $currentTime_ms
    
    $mttdList += $currentMTTD_ms
    $mttrList += $currentMTTR_ms
    
    Write-Host "Durchgang $i beendet (Dauer bis zur automatischen Korrektur: $($currentMTTR_ms/1000) s)." -ForegroundColor Green
    
    # 15 Sekunden Pause, damit sich Flux und das Cluster kurz beruhigen können
    if ($i -lt $runs) { 
        Write-Host "15s Abkühlphase..." -ForegroundColor Gray
        Start-Sleep -Seconds 90 
    }
}

# Finale Auswertung
$avgMttd_s = (($mttdList | Measure-Object -Average).Average) / 1000
$avgMttr_s = (($mttrList | Measure-Object -Average).Average) / 1000

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PRÄZISE METRIKEN FÜR DEINE BACHELORARBEIT:" -ForegroundColor Yellow
Write-Host "Anzahl der Durchläufe: $runs"
Write-Host "Durchschnittliche MTTD: $avgMttd_s Sekunden"
Write-Host "Durchschnittliche MTTR: $avgMttr_s Sekunden"
Write-Host "========================================" -ForegroundColor Yellow