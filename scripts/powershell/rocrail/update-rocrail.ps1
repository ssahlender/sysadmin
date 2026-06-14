$Url = "https://www.rocrail.online/rocrail-snapshot/Rocrail-Windows-WIN64.zip"
$ZipFile = "$env:TEMP\Rocrail-Windows-WIN64.zip"
$TargetFolder = "C:\data\rocrail"

Write-Host "Stopping Rocrail if running..."
Get-Process -Name "rocrail" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "Downloading latest Rocrail snapshot..."
Start-BitsTransfer -Source $Url -Destination $ZipFile

Write-Host "Extracting files..."
Expand-Archive -Path $ZipFile -DestinationPath $TargetFolder -Force

Remove-Item $ZipFile
Write-Host "Update complete."