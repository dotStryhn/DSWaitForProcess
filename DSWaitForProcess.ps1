<#
   .SYNOPSIS
    Script for checking for remotely checking for process start and stop
   .PARAMETER ComputerName
    Defines the size of the LogFile, if not set Default is 500mb
   .PARAMETER ProcessName
    Defines the name of the Process to find and monitor
   .PARAMETER TimeOutStart
    Defines the time to wait for the Process to start in minutes (Default 5min)
   .PARAMETER TimeOutStop
    Defines the time to wait for the Process to stop in minutes (Default 15min)
   .EXAMPLE
    ./DSWaitForProcess.ps1 -ComputerName SRV1 -ProcessName ccmsetup
    Will check for the ccmsetup process on SRV1, if not started, it will listen
    5 minutes for it to start and if started within 5 minutes it will listen for
    another 15 minutes for it to stop.
   .Notes
    Name:       DSWaitForProcess.ps1
    Author:     Tom Stryhn (@dotStryhn)
   .Link
    https://github.com/dotStryhn/DSWaitForProcess
    http://dotstryhn.dk
#>

param(
    [Parameter(Mandatory = $true)][string]$ComputerName,
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter()][int]$TimeOutStart = 5,
    [Parameter()][int]$TimeOutStop = 15
)

$WaitForStart = $TimeOutStart * 60
$WaitForStop = $TimeOutStop * 60
$TimeOut = $false

# Creates a PSSession to the target computer
$Session = New-PSSession -ComputerName $ComputerName -ErrorAction SilentlyContinue

# If the session exists it will continue
if($Session) {
    $AppGet = Invoke-Command -Session $Session -ScriptBlock { $App = Get-Process -ProcessName $using:AppName -ErrorAction SilentlyContinue; $App }
    if (!$AppGet) {
        Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Application [$ProcessName] on [$ComputerName]: Not started, listening for $TimeOutStart minute(s)"
        $Time = 0
        while ((-not $AppGet) -and ($TimeOut -eq $false)) {
            $AppGet = Invoke-Command -Session $Session -ScriptBlock { $App = Get-Process -ProcessName $using:AppName -ErrorAction SilentlyContinue; $App }
            Start-Sleep -Seconds 1
            $Time = $Time + 1
            if($Time -ge $WaitForStart) { $TimeOut = $true }
        }
        if ($TimeOut) { Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Application [$ProcessName] on [$ComputerName]: Not started within $TimeOutStart minute(s)" }
    }
    if($AppGet) {
        Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Application [$ProcessName] on [$ComputerName]: Running, listening for $TimeOutStop minute(s)"
        $Time = 0
        $AppExit = Invoke-Command -Session $Session -ScriptBlock { $App.Refresh();$App.HasExited }
        while (($AppExit -eq $false) -and ($TimeOut -eq $false)) {
            $AppExit = Invoke-Command -Session $Session -ScriptBlock { $App.Refresh();$App.HasExited }
            Start-Sleep -Seconds 1
            $Time = $Time + 1
            if($Time -ge $WaitForStop) { $TimeOut = $true }
        }
        if ($AppExit -eq $true) {
            Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Application [$ProcessName] on [$ComputerName]: Has Exited with ExitCode: [$(Invoke-Command -Session $Session -ScriptBlock { $App.ExitCode })]"
        }
        if ($TimeOut) { Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Application [$ProcessName] on [$ComputerName]: Not Exited within $TimeOutStop minute(s)" }
    }
    Remove-PSSession -Session $Session
} else {
    # If Session dont exists
    Write-Host "Unable to create session to [$ComputerName]"
}