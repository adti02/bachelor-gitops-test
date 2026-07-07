# 1. Zeitstempel VOR dem Push nehmen
$start_push = Get-Date

# 2. Git Befehle
git add .
git commit -m "Messung: $(Get-Date)"
git push origin main

# 3. Mess-Skript mit dem Start-Zeitpunkt starten
.\MessungTest2.ps1 -start_push $start_push