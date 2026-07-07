# 1. Zeitstempel VOR dem Push nehmen
$start_push = Get-Date

# 2. Git Befehle
git add .
git commit -m "Messung: $(Get-Date)"
git push origin main

# 3. Mess-Skript mit dem Start-Zeitpunkt starten
.\argo2.ps1 -start_push $start_push

# 1. Startpunkt: Deine lokale Zeit beim Ausfuehren (nach dem git push) 
Write-Host "Starte Messung. Führe jetzt git push aus..." 
$start_push = Get-Date 
# 2. Speichere die alte Cluster-Generation $old_gen = kubectl get deployment meine-test-app -n default -o jsonpath='{.metadata.generation}' 
# 3. Warten auf MTTD: Wann erkennt Argo CD die Aenderung? Write-Host "Warte auf Detektion durch ArgoCD..." while ($true) { # Wir schauen, ob die Generation im Cluster aktualisiert wurde $new_gen = kubectl get deployment meine-test-app -n default -o jsonpath='{.metadata.generation}' if ($new_gen -ne $old_gen) { $mttd_end = Get-Date Write-Host "Aenderung erkannt!" break } Start-Sleep -Seconds 0.5 } 
# 4. Warten auf MTTR: Wann ist der Pod fertig? Write-Host "Warte auf Ready-Status (MTTR)..." kubectl rollout status deployment meine-test-app -n default --timeout=300s | Out-Null $mttr_end = Get-Date 
# 5. Berechnung $mttd = $mttd_end - $start_push $mttr = $mttr_end - $start_push Write-Host "----------------------------" Write-Host "MTTD (Detektion): $($mttd.TotalSeconds) Sekunden" Write-Host "MTTR (Gesamtdauer): $($mttr.TotalSeconds) Sekunden" Write-Host "----------------------------"