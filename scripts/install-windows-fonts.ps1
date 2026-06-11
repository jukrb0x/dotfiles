#Requires -Version 7.1
$ErrorActionPreference = "Stop"

$nerdFonts = @(
    "Meslo"
)

$officialFonts = @(
    @{
        Name = "JetBrains Mono"
        GitHubRepo = "JetBrains/JetBrainsMono"
        AssetPattern = "JetBrainsMono-*.zip"
        Include = @("fonts/ttf/JetBrainsMono-*.ttf")
    },
    @{
        Name = "Monaspace Static"
        GitHubRepo = "githubnext/monaspace"
        AssetPattern = "monaspace-static-*.zip"
        Include = @("*.otf", "*.ttf")
        Recurse = $true
    },
    @{
        Name = "Monaspace Variable"
        GitHubRepo = "githubnext/monaspace"
        AssetPattern = "monaspace-variable-*.zip"
        Include = @("*.otf", "*.ttf")
        Recurse = $true
    },
    @{
        Name = "Monaspace Frozen"
        GitHubRepo = "githubnext/monaspace"
        AssetPattern = "monaspace-frozen-*.zip"
        Include = @("*.otf", "*.ttf")
        Recurse = $true
    },
    @{
        Name = "Monaspace Nerd Fonts"
        GitHubRepo = "githubnext/monaspace"
        AssetPattern = "monaspace-nerdfonts-*.zip"
        Include = @("*.otf", "*.ttf")
        Recurse = $true
    }
)

$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$tempDir = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-fonts"

New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class FontInstall {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResource(string lpFileName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        IntPtr lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult);
}
"@
Add-Type -AssemblyName PresentationCore

function Get-LatestGitHubReleaseAssetUrl {
    param(
        [Parameter(Mandatory)] [string] $Repo,
        [Parameter(Mandatory)] [string] $AssetPattern
    )

    try {
        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$Repo/releases/latest" `
            -Headers @{ "User-Agent" = "install-windows-fonts.ps1" }
        $asset = $release.assets |
            Where-Object { $_.name -like $AssetPattern } |
            Select-Object -First 1

        if ($asset) {
            return $asset.browser_download_url
        }
    } catch {
        Write-Warning "GitHub API lookup failed for $Repo. Falling back to release page parsing."
    }

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    try {
        $client.DefaultRequestHeaders.UserAgent.ParseAdd("install-windows-fonts.ps1")
        $latest = $client.GetAsync("https://github.com/$Repo/releases/latest").GetAwaiter().GetResult()
        $location = $latest.Headers.Location
        $tag = [IO.Path]::GetFileName($location.AbsolutePath)
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }

    $assetsPage = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/expanded_assets/$tag"
    $assetPath = $assetsPage.Links |
        Where-Object { [IO.Path]::GetFileName($_.href) -like $AssetPattern } |
        Select-Object -First 1 -ExpandProperty href

    if (-not $assetPath) {
        throw "Could not find release asset matching '$AssetPattern' in $Repo latest release."
    }

    "https://github.com$assetPath"
}

function Install-FontFile {
    param([Parameter(Mandatory)] [string] $Path)

    $destination = Join-Path $fontDir (Split-Path $Path -Leaf)
    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    $fontType = if ($extension -eq ".otf") { "OpenType" } else { "TrueType" }
    # Windows persists fonts through registry entries named after the font's
    # internal Win32 family/face metadata, not the filename.
    $glyphTypeface = [System.Windows.Media.GlyphTypeface]::new([Uri]$Path)
    $familyName = if ($glyphTypeface.Win32FamilyNames.ContainsKey([Globalization.CultureInfo]"en-US")) {
        $glyphTypeface.Win32FamilyNames[[Globalization.CultureInfo]"en-US"]
    } else {
        $glyphTypeface.Win32FamilyNames.Values | Select-Object -First 1
    }
    $faceName = if ($glyphTypeface.Win32FaceNames.ContainsKey([Globalization.CultureInfo]"en-US")) {
        $glyphTypeface.Win32FaceNames[[Globalization.CultureInfo]"en-US"]
    } else {
        $glyphTypeface.Win32FaceNames.Values | Select-Object -First 1
    }
    $registryName = "$familyName $faceName ($fontType)"
    $registryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    if (Test-Path $destination) {
        $sourceHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash

        if ($sourceHash -ne $destinationHash) {
            throw "Font file already exists with different content: $destination. Close apps or remove it manually before rerunning."
        }
    } else {
        Copy-Item -LiteralPath $Path -Destination $destination
    }

    New-ItemProperty `
        -Path $registryPath `
        -Name $registryName `
        -Value $destination `
        -PropertyType String `
        -Force | Out-Null

    $added = [FontInstall]::AddFontResource($destination)
    if ($added -eq 0) {
        throw "Windows did not load font resource: $destination"
    }
}

foreach ($font in $officialFonts) {
    $archive = Join-Path $tempDir "$($font.Name).zip"
    $extractDir = Join-Path $tempDir $font.Name
    $url = Get-LatestGitHubReleaseAssetUrl `
        -Repo $font.GitHubRepo `
        -AssetPattern $font.AssetPattern

    Write-Host "Downloading $($font.Name)..."
    Invoke-WebRequest -Uri $url -OutFile $archive

    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force

    foreach ($include in $font.Include) {
        Get-ChildItem -Path (Join-Path $extractDir $include) -File -Recurse:$font.Recurse |
            ForEach-Object { Install-FontFile $_.FullName }
    }
}

foreach ($font in $nerdFonts) {
    $archive = Join-Path $tempDir "$font.tar.xz"
    $extractDir = Join-Path $tempDir $font
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.tar.xz"

    Write-Host "Downloading $font Nerd Font..."
    Invoke-WebRequest -Uri $url -OutFile $archive

    Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    tar -xf $archive -C $extractDir

    Get-ChildItem -Path $extractDir -Recurse -Include *.ttf,*.otf |
        ForEach-Object { Install-FontFile $_.FullName }
}

$result = [UIntPtr]::Zero
$messageResult = [FontInstall]::SendMessageTimeout(
    [IntPtr]0xffff,
    0x001d,
    [UIntPtr]::Zero,
    [IntPtr]::Zero,
    0x0002,
    1000,
    [ref]$result)

if ($messageResult -eq [IntPtr]::Zero) {
    Write-Warning "Windows did not confirm WM_FONTCHANGE broadcast. Restart terminals/editors, or sign out and back in."
}

Write-Host "Fonts installed for current user. Restart terminals/editors to pick them up."
