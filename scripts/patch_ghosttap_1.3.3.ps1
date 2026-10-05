param(
    [Parameter(Mandatory = $true)]
    [string]$Root
)

$ErrorActionPreference = "Stop"

function Replace-Exact([string]$Path, [string]$Old, [string]$New) {
    $text = Get-Content -Raw -LiteralPath $Path
    if (-not $text.Contains($Old)) {
        throw "Expected source text not found in $Path"
    }
    Set-Content -LiteralPath $Path -Value $text.Replace($Old, $New) -Encoding utf8NoBOM
}

Replace-Exact (Join-Path $Root "Services\DatabaseService.cs") "await using var transaction = await connection.BeginTransactionAsync().ConfigureAwait(false);" "await using var transaction = (SqliteTransaction)await connection.BeginTransactionAsync().ConfigureAwait(false);"
Replace-Exact (Join-Path $Root "Services\WhatsAppParser.cs") "var now = createdAt.ToLocalTime();" "var now = createdAt.ToLocalTime().DateTime;"

$main = Join-Path $Root "UI\MainForm.cs"
$mainText = Get-Content -Raw -LiteralPath $main
if ($mainText -notmatch "private static void OpenFolder\(") {
    $openFolder = @'
    private static void OpenFolder(string path)
    {
        try
        {
            if (!Directory.Exists(path)) Directory.CreateDirectory(path);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("explorer.exe", $"\"{path}\"")
            {
                UseShellExecute = true
            });
        }
        catch { }
    }

'@
    $pattern = "(?m)^\s*private static void OpenUri\(string uri\)"
    if ($mainText -notmatch $pattern) {
        throw "OpenUri method not found in MainForm.cs"
    }
    $mainText = [regex]::Replace($mainText, $pattern, $openFolder + "    private static void OpenUri(string uri)", 1)
    Set-Content -LiteralPath $main -Value $mainText -Encoding utf8NoBOM
}

$testProject = Join-Path $Root "tests\GhostTap.Unified.SmokeTests.csproj"
$testText = Get-Content -Raw -LiteralPath $testProject
if ($testText -notmatch "<Platforms>x64</Platforms>") {
    $nl = [Environment]::NewLine
    $testText = $testText.Replace("    <EnableWindowsTargeting>true</EnableWindowsTargeting>", "    <EnableWindowsTargeting>true</EnableWindowsTargeting>" + $nl + "    <Platforms>x64</Platforms>" + $nl + "    <PlatformTarget>x64</PlatformTarget>")
    Set-Content -LiteralPath $testProject -Value $testText -Encoding utf8NoBOM
}

$program = Join-Path $Root "Program.cs"
$programText = Get-Content -Raw -LiteralPath $program
if ($programText -notmatch "Application\.SetHighDpiMode") {
    $nl = [Environment]::NewLine
    $programText = $programText.Replace("        ApplicationConfiguration.Initialize();", "        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);" + $nl + "        ApplicationConfiguration.Initialize();")
    Set-Content -LiteralPath $program -Value $programText -Encoding utf8NoBOM
}

$manifest = Join-Path $Root "app.manifest"
$manifestText = Get-Content -Raw -LiteralPath $manifest
$manifestText = [regex]::Replace($manifestText, "\s*<dpiAware[^>]*>true/pm</dpiAware>\s*", [Environment]::NewLine)
$manifestText = [regex]::Replace($manifestText, "\s*<dpiAwareness[^>]*>PerMonitorV2</dpiAwareness>\s*", [Environment]::NewLine)
Set-Content -LiteralPath $manifest -Value $manifestText -Encoding utf8NoBOM

# Final release metadata and regression fixes.
Replace-Exact (Join-Path $Root "GhostTap.Unified.csproj") "<Version>1.3.2</Version>" "<Version>1.3.3</Version>"
Replace-Exact (Join-Path $Root "GhostTap.Unified.csproj") "<AssemblyVersion>1.3.2.0</AssemblyVersion>" "<AssemblyVersion>1.3.3.0</AssemblyVersion>"
Replace-Exact (Join-Path $Root "GhostTap.Unified.csproj") "<FileVersion>1.3.2.0</FileVersion>" "<FileVersion>1.3.3.0</FileVersion>"
Replace-Exact (Join-Path $Root "packaging\Package.appxmanifest") "Version="1.3.2.0"" "Version="1.3.3.0""
Replace-Exact (Join-Path $Root "scripts\Verify.ps1") "release 1.3.2" "release 1.3.3"
Replace-Exact (Join-Path $Root "scripts\static_verify.py") "<Version>1.3.2</Version>" "<Version>1.3.3</Version>"
Replace-Exact (Join-Path $Root "scripts\static_verify.py") "Project version is not 1.3.2." "Project version is not 1.3.3."
Replace-Exact (Join-Path $Root "scripts\static_verify.py") "Version="1.3.2.0"" "Version="1.3.3.0""
Replace-Exact (Join-Path $Root "scripts\static_verify.py") "MSIX manifest version is not 1.3.2.0." "MSIX manifest version is not 1.3.3.0."

$smoke = Join-Path $Root "tests\Program.cs"
$smokeText = Get-Content -Raw -LiteralPath $smoke
$smokeText = $smokeText.Replace('Assert(parsed!.ToString().Equals(uri, StringComparison.OrdinalIgnoreCase), "Recovered URI did not match the original.");', 'Assert(parsed!.AbsoluteUri.Equals(valid!.AbsoluteUri, StringComparison.OrdinalIgnoreCase), "Recovered URI did not match the canonical original URI.");')
Set-Content -LiteralPath $smoke -Value $smokeText -Encoding utf8NoBOM

$watcher = Join-Path $Root "Services\WhatsAppWatcherService.cs"
$watcherText = Get-Content -Raw -LiteralPath $watcher
$watcherText = $watcherText.Replace("    private bool _enabled;" + [Environment]::NewLine, "")
Set-Content -LiteralPath $watcher -Value $watcherText -Encoding utf8NoBOM

Get-ChildItem -Path $Root -Directory -Filter bin -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $Root -Directory -Filter obj -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "GhostTap 1.3.3 source fixes applied successfully."
