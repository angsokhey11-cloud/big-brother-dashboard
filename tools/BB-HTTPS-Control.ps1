<#
BIG BROTHER Control Center V3.4 HTTPS Caddy helper.
Use -Action Doctor, Start, Status, Stop.
Run Start after V6 starts, and Stop before V6 closes.
This file does not alter Docker, V5, V6, firewall or certificates.
#>
[CmdletBinding()]
param([ValidateSet('Doctor','Start','Stop','Status')][string]$Action='Status')
$ErrorActionPreference='Stop'
$folder=Join-Path $env:USERPROFILE 'BIG_BROTHER_HTTPS'
$config=Join-Path $folder 'Caddyfile'
$pidPath=Join-Path $folder '.bigbrother-caddy.pid'
function Get-Caddy {
    $cmd=Get-Command caddy.exe -ErrorAction SilentlyContinue
    if(-not $cmd){throw 'caddy.exe not found in PATH'}
    return $cmd.Source
}
function Is-Listening([int]$port) {
    return @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue).Count -gt 0
}
function Get-ManagedProcess {
    if(-not (Test-Path -LiteralPath $pidPath)){return $null}
    [int]$managedPid=0
    $saved=(Get-Content -LiteralPath $pidPath -ErrorAction SilentlyContinue | Select-Object -First 1)
    if(-not [int]::TryParse([string]$saved,[ref]$managedPid)){return $null}
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$managedPid" -ErrorAction SilentlyContinue
    if(-not $p -or $p.Name -notmatch '^caddy(\.exe)?$'){return $null}
    if($p.CommandLine -notlike '*BIG_BROTHER_HTTPS*Caddyfile*'){return $null}
    return $p
}
function Show-Status {
    $managed=Get-ManagedProcess
    Write-Host ('Local V6 HTTP 8083: '+$(if(Is-Listening 8083){'LISTENING'}else{'NOT LISTENING'}))
    Write-Host ('Caddy HTTPS 8443: '+$(if(Is-Listening 8443){'LISTENING'}else{'NOT LISTENING'}))
    Write-Host ('Controller-managed Caddy: '+$(if($managed){'YES PID '+$managed.ProcessId}else{'NO / manually started'}))
}
switch($Action){
    Doctor {
        Write-Host ('Caddy executable: '+$(try{Get-Caddy}catch{$_.Exception.Message}))
        Write-Host ('Caddyfile exists: '+(Test-Path -LiteralPath $config))
        Write-Host ('Local public CA exists: '+(Test-Path (Join-Path $env:APPDATA 'Caddy\pki\authorities\local\root.crt')))
        Show-Status
        break
    }
    Status {Show-Status;break}
    Start {
        if(Is-Listening 8443){
            Write-Host 'HTTPS already listening. Leaving its existing process untouched.'
            Show-Status
            break
        }
        if(-not (Test-Path -LiteralPath $config)){throw "Missing Caddyfile: $config"}
        $caddy=Get-Caddy
        & $caddy validate --config $config --adapter caddyfile
        if($LASTEXITCODE -ne 0){throw 'Caddyfile validation failed, HTTPS NOT started'}
        $arguments=@('run','--config',('"'+$config+'"'),'--adapter','caddyfile')
        $process=Start-Process -FilePath $caddy -ArgumentList $arguments -WorkingDirectory $folder -PassThru -WindowStyle Hidden
        Set-Content -LiteralPath $pidPath -Value $process.Id -Encoding ascii
        $ready=$false
        for($i=0;$i -lt 30;$i++){
            Start-Sleep -Milliseconds 200
            if(Is-Listening 8443){$ready=$true;break}
            if($process.HasExited){break}
        }
        if(-not $ready){throw 'Caddy did not listen on HTTPS 8443; check logs; no V6 changes made'}
        Write-Host ('BIG BROTHER HTTPS started: PID '+$process.Id)
        Show-Status
        break
    }
    Stop {
        $managed=Get-ManagedProcess
        if(-not $managed){
            Write-Host 'No controller-managed Caddy process. Refusing to stop a manually started instance.'
            Show-Status
            break
        }
        Stop-Process -Id $managed.ProcessId -ErrorAction Stop
        Remove-Item -LiteralPath $pidPath -ErrorAction SilentlyContinue
        Write-Host 'Controller-managed BIG BROTHER HTTPS stopped.'
        Show-Status
        break
    }
}
