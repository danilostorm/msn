# Tests the LEGACY Trident/IE WebBrowser control against the public Storm MSN
# game directory. This is a separate test window, NOT the Microsoft MSN UI.
# No screenshots, cookies, URLs from private sessions, credentials or game launch.
[CmdletBinding()]
param(
    [string]$OutputPath = 'E:\StormMSN-Research\lab-native-2009\Trident-GamesBrowser-Result.json',
    [int]$TimeoutSeconds = 18
)
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Execute with powershell.exe -STA (WebBrowser COM requires STA)'
}
if ($TimeoutSeconds -lt 3 -or $TimeoutSeconds -gt 30) {
    throw 'TimeoutSeconds must be from 3 to 30'
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$target = [Uri]'https://msn.hoststorm.com.br/AppDirectory/Directory.aspx?from=wlm2009'
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Storm MSN read-only Trident compatibility test'
$form.Width = 900
$form.Height = 760
$form.ShowInTaskbar = $false
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point(-30000,-30000)
$form.Opacity = 0
$browser = New-Object System.Windows.Forms.WebBrowser
$browser.Dock = 'Fill'
$browser.ScriptErrorsSuppressed = $true
$browser.AllowWebBrowserDrop = $false
$browser.WebBrowserShortcutsEnabled = $false
$browser.IsWebBrowserContextMenuEnabled = $false
$browser.ScrollBarsEnabled = $true
$form.Controls.Add($browser)
$state = [hashtable]::Synchronized(@{
    completed = $false
    error = $null
    documentCompletedCount = 0
})
$browser.add_DocumentCompleted({
    $state.documentCompletedCount += 1
    if ($browser.ReadyState -eq [Windows.Forms.WebBrowserReadyState]::Complete -and
       $null -ne $browser.Url -and $browser.Url.Host -eq $target.Host) {
        $state.completed = $true
    }
})
$browser.add_NewWindow({ param($sender,$e) $e.Cancel=$true })
$start = [Diagnostics.Stopwatch]::StartNew()
try {
    $form.Show()
    $browser.Navigate($target)
    while (-not $state.completed -and $start.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 80
    }
    $isPlaystor = $false
    $gameLinkCount = 0
    $documentExists = $null -ne $browser.Document
    if ($documentExists) {
        $doc = $browser.Document
        try {
            $body = $doc.Body
            $content = if ($null -ne $body) { [string]$body.InnerText } else { '' }
            $isPlaystor = $content.IndexOf('PlayStor', [StringComparison]::OrdinalIgnoreCase) -ge 0
            foreach ($item in $doc.GetElementsByTagName('a')) {
                $href = [string]$item.GetAttribute('href')
                if ($href.StartsWith('https://playstor.hoststorm.cloud/', [StringComparison]::OrdinalIgnoreCase)) {
                    $gameLinkCount++
                }
            }
        } catch {
            $state.error = 'DOM_ACCESS_' + $_.Exception.GetType().Name
        }
    }
    $runtimeFeatures = [ordered]@{
        WebAssembly = 'unknown'
        WebSocket = 'unknown'
        fetch = 'unknown'
        canvas = 'unknown'
    }
    if ($documentExists) {
        foreach ($feature in @('WebAssembly','WebSocket','fetch')) {
            try {
                $value = $browser.Document.InvokeScript('eval', @('typeof ' + $feature))
                $runtimeFeatures[$feature] = [string]$value
            } catch {
                $runtimeFeatures[$feature] = 'unavailable'
            }
        }
        try {
            $value = $browser.Document.InvokeScript('eval', @("typeof document.createElement('canvas').getContext"))
            $runtimeFeatures.canvas = [string]$value
        } catch {
            $runtimeFeatures.canvas = 'unavailable'
        }
    }
    $result = [ordered]@{
        test = 'Windows WebBrowser/Trident - public GamesBrowserURL'
        browserEngineFeatures = $runtimeFeatures
        executionSession = [Diagnostics.Process]::GetCurrentProcess().SessionId
        documentCompleted = [bool]$state.completed
        readyState = [string]$browser.ReadyState
        documentExists = [bool]$documentExists
        playstorContentVisibleInDOM = [bool]$isPlaystor
        playstorGameLinkCount = [int]$gameLinkCount
        documentCompletedEvents = [int]$state.documentCompletedCount
        elapsedMilliseconds = [int]$start.Elapsed.TotalMilliseconds
        errorClass = $state.error
        actualWLMWindowUsed = $false
        gameLaunched = $false
        cookiesOrPageContentsStored = $false
    }
    $json=$result|ConvertTo-Json -Depth 5
    $dir=Split-Path -Parent $OutputPath
    if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    [IO.File]::WriteAllText($OutputPath,$json,[Text.UTF8Encoding]::new($false))
    Write-Output $json
}finally{
    $browser.Stop()
    $browser.Dispose()
    $form.Close()
    $form.Dispose()
}
