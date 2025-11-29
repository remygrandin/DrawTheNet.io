param(
    [PSObject[]] $steps = @("InitCleanup", "DownloadIcons", "GenContactSheets", "CopySrc", "SetBuildDate", "AllLowercase", "CopyDist", "EndCleanup")
)

$startTime = Get-Date

$distRootPath = Join-Path $PSScriptRoot ..
$distPath = Join-Path $distRootPath "dist"
$srcPath = Join-Path $PSScriptRoot .. "src"

$rootTempPath = Join-Path ([system.io.path]::GetTempPath()) "drawthenet.io-build"
$tempPath = Join-Path $rootTempPath "tmp"
$buildPath = Join-Path $rootTempPath "dist"
$samplesPath = Join-Path $buildPath "samples"
$iconsPath = Join-Path $buildPath "res" "icons"
$samplesJSONPath = Join-Path $samplesPath "samples.json"
$iconsJSONPath = Join-Path $iconsPath "icons.json"


$vssConvInstalled = $null -ne (Get-Command "vss2svg-conv" -ErrorAction SilentlyContinue)

function DownloadIcons {
    Write-Output "====== Downloading & processing icons ======"
    New-Item -Type Directory -Path $tempPath -Force | Out-Null
    
    DownloadAWSIcons
    DownloadAzureIcons
    DownloadM365Icons
    DownloadD365Icons
    DownloadPowerPlatformIcons
    DownloadGCPIcons
    DownloadCiscoIcons
    DownloadFortinetIcons
    DownloadMerakiIcons    
}

function DownloadAWSIcons {
    Write-Output "------ AWS ------"
    $zipPath = Join-Path $tempPath "AWS.zip"
    $extractPath = Join-Path $tempPath "AWS"
    $destPath = Join-Path $iconsPath "AWS"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://d1.awsstatic.com/webteam/architecture-icons/q3-2022/Asset-Package_07312022.e9f969935ef6aa73b775f3a4cd8c67af2a4cf51e.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") -and -not $_.Contains("\.") -and -not $_.Contains("__MACOSX") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        if ($obj.FullName.Contains("Architecture-Service-Icons")) {
            $obj.FullName -match "[\\/]Arch_([\da-zA-Z-_]*)[\\/](?:Arch_)?\d\d[\\/](?:Arch_ ?(?:Amazon|AWS)?-?)([\da-zA-Z-&_]*) ?_(\d\d)_?.svg" | Out-Null

            $obj | Add-Member -MemberType NoteProperty -Name "Size" -Value ([int]($Matches[3]))
            $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])_$($Matches[2])"
            
            $obj | Add-Member -MemberType NoteProperty -Name "DestName" -Value "$($obj.BaseName).svg"
        }
        elseif ($obj.FullName.Contains("Category-Icons")) {
            $obj.FullName -match "[\\/]Arch-Category_\d\d[\\/]Arch-([\da-zA-Z-_]*)_(\d\d).svg" | Out-Null

            $obj | Add-Member -MemberType NoteProperty -Name "Size" -Value ([int]($Matches[2]))
            $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
            
            $obj | Add-Member -MemberType NoteProperty -Name "DestName" -Value "$($obj.BaseName).svg"
        }
        elseif ($obj.FullName.Contains("Res_")) {
            $obj.FullName -match "[\\/]Res_([\dA-Za-z-_]*)[\\/][\dA-Za-z-_]*[\\/]Res_(?:AWS|Amazon)?-?([\dA-Za-z-_\.]*) ?_(\d\d)_(Light|Dark).svg" | Out-Null

            $obj | Add-Member -MemberType NoteProperty -Name "Size" -Value ([int]($Matches[3]))
            $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])_$($Matches[2])_$($Matches[4])"
            
            $obj | Add-Member -MemberType NoteProperty -Name "DestName" -Value "$($obj.BaseName).svg"
        }

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | Group-Object -Property BaseName | ForEach-Object {
        if ($_.Count -eq 1) {
            Write-Output "    Copy $($_.Group[0].FullName) as $($_.Group[0].DestName)  ..."
            Copy-Item -Path $_.Group[0].FullName -Destination (Join-Path $destPath $_.Group[0].DestName) -Force
        }
        else {
            $maxSize = $_.Group | Measure-Object -Property Size -Maximum | Select-Object -ExpandProperty Maximum

            $obj = $_.Group | Where-Object { $_.Size -eq $maxSize }

            Write-Output "    Copy $($obj.FullName) as $($obj.DestName)  ..."
            Copy-Item -Path $obj.FullName -Destination (Join-Path $destPath $obj.DestName) -Force
        }
        $copiedFiles += $_.Name
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "AWS" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadAzureIcons {


    Write-Output "------ Azure ------"
    $zipPath = Join-Path $tempPath "Azure.zip"
    $extractPath = Join-Path $tempPath "Azure"
    $destPath = Join-Path $iconsPath "Azure"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V11.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(?:\d{5}-icon-service-)(.*).svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | Group-Object -Property BaseName | ForEach-Object {
        if ($_.Count -eq 1) {
            Write-Output "    Copy $($_.Group[0].FullName) as $($_.Group[0].Name)  ..."
            Copy-Item -Path $_.Group[0].FullName -Destination (Join-Path $destPath $_.Group[0].Name) -Force
        }
        else {
            $obj = $_.Group | Select-Object -First 1

            Write-Output "    Copy $($obj.FullName) as $($obj.Name)  ..."
            Copy-Item -Path $obj.FullName -Destination (Join-Path $destPath $obj.Name) -Force
        }
        $copiedFiles += $_.Name
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "Azure" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadM365Icons {
    Write-Output "------ M365 ------"
    $zipPath = Join-Path $tempPath "M365.zip"
    $extractPath = Join-Path $tempPath "M365"
    $destPath = Join-Path $iconsPath "M365"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=869455" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit..."
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null    

    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {        
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj | Add-Member -MemberType NoteProperty -Name "LocalPath" -Value $obj.FullName.Replace($extractPath, "")

        Write-Output "    Parsing  $($obj.LocalPath)..."

        if ($obj.LocalPath -match "[\\/](.*)[\\/]\d{2}x\d{2} (.*) Icon[\\/](.*)\.svg") {
            $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[3].Replace(" ", "-"))_$($Matches[2].Replace(" ", "-").Replace("&","and"))_$($Matches[1].Replace(" ", "-"))"
        }
        else {
            $obj.LocalPath -match "[\\/](.*)[\\/]\d{2}x\d{2} SVG Icons[\\/](.*)\.svg" | Out-Null
            $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[2].Replace(" ", "-"))_$($Matches[1].Replace(" ", "-"))"
        }

        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg") 

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | Group-Object -Property BaseName | ForEach-Object {
        if ($_.Count -eq 1) {
            Write-Output "    Copy $($_.Group[0].FullName) as $($_.Group[0].Name)  ..."
            Copy-Item -Path $_.Group[0].FullName -Destination (Join-Path $destPath $_.Group[0].Name) -Force
        }
        else {
            $obj = $_.Group | Select-Object -First 1

            Write-Output "    Copy $($obj.FullName) as $($obj.Name)  ..."
            Copy-Item -Path $obj.FullName -Destination (Join-Path $destPath $obj.Name) -Force
        }
        $copiedFiles += $_.Name
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "M365" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadD365Icons {
    Write-Output "------ Dynamics 365 ------"
    $zipPath = Join-Path $tempPath "D365.zip"
    $extractPath = Join-Path $tempPath "D365"
    $destPath = Join-Path $iconsPath "D365"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/3/e/a/3eaa9444-906f-468d-92cb-ada53e87b977/Dynamics_365_Icons_scalable_2024.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit..."
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    foreach ($icon in $svgFilesRaw) {
        Write-Output "    Editing  $($icon) ..."

        $iconSVG = Get-Content -Path $icon -Raw

        $title = [System.IO.Path]::GetFileNameWithoutExtension($icon)

        $iconSVG = $iconSVG -replace "(clip\d)", "`$1-$title"
        $iconSVG = $iconSVG -replace "(mask\d)", "`$1-$title"
        $iconSVG = $iconSVG -replace "(filter\d_f)", "`$1-$title"
        $iconSVG = $iconSVG -replace "(paint\d_linear)", "`$1-$title"
        
        $iconSVG | Set-Content -Path $icon -Force
    }
    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*)_?_scalable.svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | Group-Object -Property BaseName | ForEach-Object {
        if ($_.Count -eq 1) {
            Write-Output "    Copy $($_.Group[0].FullName) as $($_.Group[0].Name)  ..."
            Copy-Item -Path $_.Group[0].FullName -Destination (Join-Path $destPath $_.Group[0].Name) -Force
        }
        else {
            $obj = $_.Group | Select-Object -First 1

            Write-Output "    Copy $($obj.FullName) as $($obj.Name)  ..."
            Copy-Item -Path $obj.FullName -Destination (Join-Path $destPath $obj.Name) -Force
        }
        $copiedFiles += $_.Name
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "D365" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadPowerPlatformIcons {
    Write-Output "------ Power Platform ------"
    $zipPath = Join-Path $tempPath "PowerPlatform.zip"
    $extractPath = Join-Path $tempPath "PowerPlatform"
    $destPath = Join-Path $iconsPath "PowerPlatform"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/e/f/4/ef434e60-8cdc-4dd1-9d9f-e58670e57ec1/Power_Platform_scalable.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"
    
    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit..."
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    foreach ($icon in $svgFilesRaw) {
        Write-Output "    Editing  $($icon) ..."

        $iconSVG = Get-Content -Path $icon -Raw

        $title = [System.IO.Path]::GetFileNameWithoutExtension($icon)

        $iconSVG = $iconSVG -replace "(clip\d)", "`$1-$title"
        $iconSVG = $iconSVG -replace "(mask\d(?:[_\d]*))", "`$1-$title"
        $iconSVG = $iconSVG -replace "(filter\d_f(?:[_\d]*))", "`$1-$title"
        $iconSVG = $iconSVG -replace "(paint\d_linear(?:[_\d]*))", "`$1-$title"
        
        $iconSVG | Set-Content -Path $icon -Force
    }
    Write-Output "Done"
    
    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*)_scalable.svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | Group-Object -Property BaseName | ForEach-Object {
        if ($_.Count -eq 1) {
            Write-Output "    Copy $($_.Group[0].FullName) as $($_.Group[0].Name)  ..."
            Copy-Item -Path $_.Group[0].FullName -Destination (Join-Path $destPath $_.Group[0].Name) -Force
        }
        else {
            $obj = $_.Group | Select-Object -First 1

            Write-Output "    Copy $($obj.FullName) as $($obj.Name)  ..."
            Copy-Item -Path $obj.FullName -Destination (Join-Path $destPath $obj.Name) -Force
        }
        $copiedFiles += $_.Name
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "PowerPlatform" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadGCPIcons {
    Write-Output "------ GCP ------"
    $zipPath = Join-Path $tempPath "GCP.zip"
    $extractPath = Join-Path $tempPath "GCP"
    $destPath = Join-Path $iconsPath "GCP"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://cloud.google.com/static/icons/files/google-cloud-icons.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit Icons..."
    $icons = Get-ChildItem -Recurse -Path $extractPath | `
        Where-Object { $_.Name.EndsWith(".svg") } 
    
    foreach ($icon in $icons) {
        Write-Output "    Editing  $($icon.FullName) ..."

        $iconSVG = Get-Content -Path $icon.FullName -Raw

        $title = [System.IO.Path]::GetFileNameWithoutExtension($icon)

        $iconSVG = $iconSVG -replace "cls-", "cls-$title-"
        $iconSVG = $iconSVG -replace "clip-", "clip-$title-"

        $iconSVG | Set-Content -Path $icon.FullName -Force
    }

    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*).svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    foreach ($svgFileParsed in $svgFilesParsed) {
        Write-Output "    Copy $($svgFileParsed.FullName) as $($svgFileParsed.Name) ..."
        Copy-Item -Path $svgFileParsed.FullName -Destination (Join-Path $destPath $svgFileParsed.Name) -Force

        $copiedFiles += $svgFileParsed.BaseName
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "GCP" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadCiscoIcons {
    Write-Output "------ Cisco ------"

    if (-not $vssConvInstalled) {
        Write-Output "vss2svg-conv not installed, skipping Cisco icons download & format"
        return
    }

    $zipPath = Join-Path $tempPath "Cisco.zip"
    $extractPath = Join-Path $tempPath "Cisco"
    $destPath = Join-Path $iconsPath "Cisco"


    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://www.cisco.com/c/dam/en_us/about/ac50/ac47/3015VSS.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Convert..."
    $vssFiles = Get-ChildItem -Recurse -Path $extractPath | Where-Object { $_.Name.EndsWith(".vss") }
    foreach ($vss in $vssFiles) {
        Write-Output "    Converting $($vss.FullName) ..."
        vss2svg-conv -i $vss -o $extractPath
    }
    Write-Output "Done"

    Write-Output "Edit Icons..."
    $icons = Get-ChildItem -Recurse -Path $extractPath | `
        Where-Object { $_.Name.EndsWith(".svg") } 
        
    foreach ($icon in $icons) {
        Write-Output "    Editing  $($icon.FullName) ..."

        $iconSVG = Get-Content -Path $icon.FullName -Raw

        $iconSVG = $iconSVG -replace "transform="" ?scale([\d\.]*) ?""", ""
        $iconSVG = $iconSVG -replace " transform="" ?translate\([-\d\.]*, ?[-\d\.]*\) ?""", ""
        
        $widths = ([regex]"stroke-width=""([\d\.]*)""").Matches($iconSVG)

        foreach ($width in $widths) {
            $iconSVG = $iconSVG -replace "stroke-width=""$($width.Groups[1].value)""", "stroke-width=""$([double]($width.Groups[1].value) * (1.0 / 2.0))"""
        }

        if ($iconSVG -match "<image xmlns=""http://www.w3.org/2000/svg""") {
            $iconSVG = $iconSVG -replace "<image xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" x=""([\d\.]*)"" y=""([\d\.]*)""", "<image xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" x=""0"" y=""0"""

            $widthMatch = ([regex]"<image xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" x=""0"" y=""0"" width=""([\d\.]*)"" height=""([\d\.]*)""").Matches($iconSVG).Groups[1].Value
            $heightMatch = ([regex]"<image xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" x=""0"" y=""0"" width=""([\d\.]*)"" height=""([\d\.]*)""").Matches($iconSVG).Groups[2].Value

            $iconSVG = $iconSVG -replace "<svg xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" version=""1.1"" width=""[\d\.]*"" height=""[\d\.]*""( viewBox=""0 0 [\d\.]* [\d\.]*"")?", "<svg xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" version=""1.1"" width=""$maxX"" height=""$maxY"" viewBox=""0 0 $maxX $maxY"""
        }
        else {
            $points = ([regex]"([-\d\.]*), ?([-\d\.]*)").Matches($iconSVG) | Select-Object @{label = "X"; expression = { $_.Groups[1].Value } }, @{label = "Y"; expression = { $_.Groups[2].Value } }

            $minX = $points | Select-Object -ExpandProperty X | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            $minY = $points | Select-Object -ExpandProperty Y | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum

            foreach ($point in $points) {
                $newX = $point.X - $minX
                $newY = $point.Y - $minY

                $iconSVG = $iconSVG -replace "$($point.X),$($point.Y)", "$newX,$newY"
            }

            $points = ([regex]"([-\d\.]*), ?([-\d\.]*)").Matches($iconSVG) | Select-Object @{label = "X"; expression = { $_.Groups[1].Value } }, @{label = "Y"; expression = { $_.Groups[2].Value } }

            $maxX = $points | Select-Object -ExpandProperty X | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            $maxY = $points | Select-Object -ExpandProperty Y | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

            $iconSVG = $iconSVG -replace "<svg xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" version=""1.1"" width=""[\d\.]*"" height=""[\d\.]*""( viewBox=""0 0 [\d\.]* [\d\.]*"")?", "<svg xmlns=""http://www.w3.org/2000/svg"" xmlns:xlink=""http://www.w3.org/1999/xlink"" version=""1.1"" width=""$maxX"" height=""$maxY"" viewBox=""0 0 $maxX $maxY"""
        }
        $iconSVG | Set-Content -Path $icon.FullName -Force
    }

    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*).svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        # Cleaning up names
        $obj.BaseName = $obj.BaseName.Replace("___", "_")
        $obj.BaseName = $obj.BaseName.Replace("__", "_")
        if ($obj.BaseName.EndsWith("_")) {
            $obj.BaseName = $obj.BaseName.Substring(0, $obj.BaseName.Length - 1)
        }
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    foreach ($svgFileParsed in $svgFilesParsed) {
        Write-Output "    Copy $($svgFileParsed.FullName) as $($svgFileParsed.Name) ..."
        Copy-Item -Path $svgFileParsed.FullName -Destination (Join-Path $destPath $svgFileParsed.Name) -Force

        $copiedFiles += $svgFileParsed.BaseName
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "Cisco" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}


function DownloadFortinetIcons {
    Write-Output "------ Fortinet ------"

    if (-not $vssConvInstalled) {
        Write-Output "vss2svg-conv not installed, skipping Cisco icons download & format"
        return
    }

    $zipPath = Join-Path $tempPath "Fortinet.zip"
    $extractPath = Join-Path $tempPath "Fortinet"
    $destPath = Join-Path $iconsPath "Fortinet"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://icons.fortinet.com/Fortinet-Icon-Library.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Extract again..."
    $innerZips = Get-ChildItem -Recurse -Path $extractPath | Where-Object { $_.Name.EndsWith(".zip") }

    foreach ($zip in $innerZips) {
        Write-Output "    Extracting $($zip.FullName) ..."
        Expand-Archive -Path $zip.FullName -DestinationPath $extractPath -Force
    }
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit Icons..."
    $icons = Get-ChildItem -Recurse -Path $extractPath | `
        Where-Object { $_.Name.EndsWith(".svg") } 
    
    foreach ($icon in $icons) {
        Write-Output "    Editing  $($icon.FullName) ..."

        $iconSVG = Get-Content -Path $icon.FullName -Raw

        $title = [System.IO.Path]::GetFileNameWithoutExtension($icon)

        $iconSVG = $iconSVG -replace "cls-", "cls-$title-"
        $iconSVG = $iconSVG -replace """st", """st-$title-"
        $iconSVG = $iconSVG -replace "\.st", ".st-$title-"

        $iconSVG | Set-Content -Path $icon.FullName -Force
    }

    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*).svg" | Out-Null

        $baseName = $Matches[1] -replace "_-_", "-"

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value $baseName
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")      

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    foreach ($svgFileParsed in $svgFilesParsed) {
        Write-Output "    Copy $($svgFileParsed.FullName) as $($svgFileParsed.Name) ..."
        Copy-Item -Path $svgFileParsed.FullName -Destination (Join-Path $destPath $svgFileParsed.Name) -Force

        $copiedFiles += $svgFileParsed.BaseName
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "Fortinet" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}



function DownloadFortinetIcons_deprecated_2025-11-29 {
    Write-Output "------ Fortinet ------"

    if (-not $vssConvInstalled) {
        Write-Output "vss2svg-conv not installed, skipping Cisco icons download & format"
        return
    }

    $zipPath = Join-Path $tempPath "Fortinet.zip"
    $extractPath = Join-Path $tempPath "Fortinet"
    $destPath = Join-Path $iconsPath "Fortinet"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://www.fortinet.com/content/dam/fortinet/assets/downloads/Fortinet%20Visio%20Stencil.zip" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Extract again..."
    $innerZips = Get-ChildItem -Recurse -Path $extractPath | Where-Object { $_.Name.EndsWith(".zip") }

    foreach ($zip in $innerZips) {
        Write-Output "    Extracting $($zip.FullName) ..."
        Expand-Archive -Path $zip.FullName -DestinationPath $extractPath -Force
    }
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Convert..."
    $vssFiles = Get-ChildItem -Recurse -Path $extractPath | Where-Object { $_.Name.Contains("Icons") -and $_.Name.EndsWith(".vss") }
    foreach ($vss in $vssFiles) {
        Write-Output "    Converting $($vss.FullName) ..."
        New-Item -Type Directory -Path "$extractPath/ext-$($vss.Name)/" -Force | Out-Null
        vss2svg-conv -i $vss -o "$extractPath/ext-$($vss.Name)/"
    }
    Write-Output "Done"

    Write-Output "Edit Icons :"
    $icons = Get-ChildItem -Recurse -Path $extractPath | `
        Where-Object { $_.Name.EndsWith(".svg") } 
        
    foreach ($icon in $icons) {
        Write-Output "    Editing  $($icon.FullName) ..."

        $iconSVG = Get-Content -Path $icon.FullName -Raw

        $iconSVG = $iconSVG -replace "transform="" scale([\d\.]*) """, ""
        
        $iconSVG -match "version=""1.1"" width=""([\d\.]*)"" height=""([\d\.]*)""" | Out-Null

        $X = $Matches[1];
        $Y = $Matches[2];
        
        $iconSVG = $iconSVG -replace "version=""1.1"" width=""[\d\.]*"" height=""[\d\.]*""", "version=""1.1"" width=""$X"" height=""$Y"" viewBox=""0 0 $X $Y"""
        $iconSVG = $iconSVG -replace "x=""[-\d\.]*"" y=""[-\d\.]*"" ", ""

        $iconSVG | Set-Content -Path $icon.FullName -Force
    }

    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith(".svg") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "(.*).svg" | Out-Null

        $baseName = $Matches[1] -replace "_-_", "-"

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value $baseName
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")      

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    foreach ($svgFileParsed in $svgFilesParsed) {
        Write-Output "    Copy $($svgFileParsed.FullName) as $($svgFileParsed.Name) ..."
        Copy-Item -Path $svgFileParsed.FullName -Destination (Join-Path $destPath $svgFileParsed.Name) -Force

        $copiedFiles += $svgFileParsed.BaseName
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "Fortinet" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"
}

function DownloadMerakiIcons {
    Write-Output "------ Meraki ------"
    $zipPath = Join-Path $tempPath "Meraki.zip"
    $extractPath = Join-Path $tempPath "Meraki"
    $destPath = Join-Path $iconsPath "Meraki"

    Write-Output "Download..."
    Invoke-WebRequest -Uri "https://meraki.cisco.com/product-collateral/cisco-meraki-topology-icons/?file" -OutFile $zipPath
    Write-Output "Done"

    Write-Output "Extract..."
    New-Item -Type Directory -Path $extractPath -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Output "Done"

    Write-Output "Fix permission..."
    if ($IsLinux) {
        foreach ($file in Get-ChildItem $extractPath -Recurse -File) {
            $file.UnixFileMode += "OtherRead"
        }
    }
    Write-Output "Done"

    Write-Output "Edit..."
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith("-large.svg") -and -not $_.Contains("\.") -and -not $_.Contains("__MACOSX") }

    foreach ($icon in $svgFilesRaw) {
        Write-Output "    Editing  $($icon) ..."

        $iconSVG = Get-Content -Path $icon -Raw

        $title = [System.IO.Path]::GetFileNameWithoutExtension($icon)

        $iconSVG = $iconSVG -replace "cls-", "cls-$title-"
        
        $iconSVG | Set-Content -Path $icon -Force
    }
    Write-Output "Done"

    Write-Output "Copy :"
    New-Item -Type Directory -Path $destPath -Force | Out-Null
    $svgFilesRaw = Get-ChildItem $extractPath -Recurse | `
        Select-Object -ExpandProperty FullName | `
        Where-Object { $_.EndsWith("-large.svg") -and -not $_.Contains("\.") -and -not $_.Contains("__MACOSX") }

    # filtering the lowest resolution icons
    $svgFilesParsed = @()
    foreach ($svgFile in $svgFilesRaw) {       
        $obj = [PSCustomObject]@{
            FullName = $svgFile
            FileName = Split-Path $svgFile -leaf
        }

        $obj.FileName -match "topology-icon-(.*)-large.svg" | Out-Null

        $obj | Add-Member -MemberType NoteProperty -Name "BaseName" -Value "$($Matches[1])"
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ("$($obj.BaseName).svg")        

        $svgFilesParsed += $obj
    }

    $copiedFiles = @()

    $svgFilesParsed | ForEach-Object {
        Write-Output "    Copy $($_.FullName) as $($_.Name)  ..."
        Copy-Item -Path $_.FullName -Destination (Join-Path $destPath $_.Name) -Force
        $copiedFiles += $_.BaseName
    }

    Write-Output "Adding data to icons.json..."
    $iconsJson = $null
    
    if (Test-Path $iconsJSONPath) {
        $iconsJson = Get-Content $iconsJSONPath | ConvertFrom-Json
    }
    else {
        $iconsJson = [PSCustomObject]@{
        }
    }

    $copiedFiles = $copiedFiles | Sort-Object
    
    $iconsJson | Add-Member -MemberType NoteProperty -Name "Meraki" -Value $copiedFiles -Force | Out-Null
    $iconsJson | ConvertTo-Json -Depth 100 | Out-File $iconsJSONPath -Force

    Write-Output "Done"


}

function CopySrc {
    Write-Output "====== Copying sources content ======"
    Copy-Item -Path "$srcPath/*" -Destination $buildPath -Recurse -Force
}

function CopySrcDev {
    Write-Output "====== Copying sources content ======"
    Copy-Item -Path "$srcPath/*" -Destination $distPath -Recurse -Force
}

function SetBuildDate {
    Write-Output "====== Setting build date ======"
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    
    # Set build date in build path (for production builds)
    $indexPathBuild = Join-Path $buildPath "index.html"
    if (Test-Path $indexPathBuild) {
        $content = Get-Content -Path $indexPathBuild -Raw
        $content = $content -replace "%%BUILD_DATE%%", $buildDate
        $content | Set-Content -Path $indexPathBuild -NoNewline -Force
        Write-Output "Build date set in build path to: $buildDate"
    }   
}

function SetBuildDateDev {
    Write-Output "====== Setting build date for dev ======"
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"

    # Set build date in dist path (for dev builds)
    $indexPathDist = Join-Path $distPath "index.html"
    if (Test-Path $indexPathDist) {
        $content = Get-Content -Path $indexPathDist -Raw
        $content = $content -replace "%%BUILD_DATE%%", $buildDate
        $content | Set-Content -Path $indexPathDist -NoNewline -Force
        Write-Output "Build date set in dist path to: $buildDate"
    }
}

function CopyDist {
    Write-Output "====== Copying dist content ======"
    Copy-Item -Path "$buildPath/" -Destination $distRootPath -Recurse -Force
}

function InitCleanup {
    Write-Output "====== Cleaning temp & dist ======"
    Remove-Item -Path $rootTempPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $distPath -Recurse -Force -ErrorAction SilentlyContinue
}

function EndCleanup {
    Write-Output "====== Cleaning tmp ======"
    Remove-Item -Path $rootTempPath -Recurse -Force -ErrorAction SilentlyContinue
}

function AllLowercase {
    Write-Output "====== Moving all to lowercase ======"
    $items = Get-ChildItem -Directory -Path $buildPath -Recurse | Sort-Object { ([regex]::Matches($_.FullName, [regex]::Escape([System.IO.Path]::DirectorySeparatorChar))).count }

    $baseLength = (Join-Path $buildPath "" -Resolve).Length + 1

    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($baseLength)
        $newRelativePath = $relativePath.ToLower()
        $newPath = $item.FullName.Substring(0, $baseLength) + $newRelativePath

        if ($item.FullName -cne $newPath) {
            Write-Output "    Moving $($item.FullName) to $($newPath)"
            # Use two-step rename to handle case-insensitive filesystems
            $tempPath = $newPath + "_temp_rename_$(Get-Random)"
            Move-Item -Path $item.FullName -Destination $tempPath -Force
            Move-Item -Path $tempPath -Destination $newPath -Force
        }
    }

    $items = Get-ChildItem -File -Path $buildPath -Recurse | Sort-Object { ([regex]::Matches($_.FullName, [regex]::Escape([System.IO.Path]::DirectorySeparatorChar))).count }

    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($baseLength)
        $newRelativePath = $relativePath.ToLower()
        $newPath = $item.FullName.Substring(0, $baseLength) + $newRelativePath

        if ($item.FullName -cne $newPath) {
            Write-Output "    Moving $($item.FullName) to $($newPath)"
            # Use two-step rename to handle case-insensitive filesystems
            $tempPath = $newPath + "_temp_rename_$(Get-Random)"
            Move-Item -Path $item.FullName -Destination $tempPath -Force
            Move-Item -Path $tempPath -Destination $newPath -Force
        }
    }
}

function GenContactSheets {
    Write-Output "====== Generating contact sheets ======"
    $icons = Get-Content $iconsJSONPath | ConvertFrom-Json
    $samples = Get-Content -Path $samplesJSONPath | ConvertFrom-Json
    $contactSheetTemplatePath = Join-Path $iconsPath "contactsheet.yaml"

    $template = Get-Content -Path $contactSheetTemplatePath -Raw

    $samples | Add-Member -Name "Contact Sheets" -Type NoteProperty -Value @{} -ErrorAction SilentlyContinue

    foreach ($iconSet in $icons | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) {
        Write-Output "    Generating contact sheet for $iconSet ..."

        $ratio = 1 / 2

        $height = [Math]::Ceiling([Math]::Sqrt($icons.$iconSet.length / $ratio))
        $width = [Math]::Ceiling($height / $ratio)

        $rows = $height;
        $columns = [Math]::Ceiling($icons.$iconSet.length / $height)
        
        $iconsStrs = ""

        $x = 0;
        $y = 0;

        foreach ($icon in $icons.$iconSet) {
            if ($x -ge $columns) {
                $x = 0;
                $y++;
            }

            $iconsStrs += "  $($icon): { <<: *iconBase, icon: ""$icon"", iconFamily: ""$iconSet"", x: $x, y: $y}`r`n"
            $x++;
        }

        $templateFilled = $template -replace "{{columns}}", $columns -replace "{{rows}}", $rows -replace "{{icons}}", $iconsStrs

        $templateFilled | Out-File (Join-Path $samplesPath "$iconSet.yaml") -Force

        #$samples."Contact Sheets".$iconSet = "$($iconSet.ToLower()).yaml"
    }

    #$samples | ConvertTo-Json | Out-File $samplesJSONPath -Force
}


Write-Output "Starting DrawTheNet build process..."

if ($steps -contains "InitCleanup") {
    InitCleanup
}

if ($steps -contains "DownloadIcons") {
    DownloadIcons
}

if ($steps -contains "CopySrc") {
    CopySrc
}

if ($steps -contains "CopySrcDev") {
    CopySrcDev
    SetBuildDateDev
}

if ($steps -contains "SetBuildDate") {
    SetBuildDate
}

if ($steps -contains "GenContactSheets") {
    GenContactSheets
}

if ($steps -contains "AllLowercase") {
    AllLowercase
}

if ($steps -contains "CopyDist") {
    CopyDist
}

if ($steps -contains "EndCleanup") {
    EndCleanup
}

Write-Output "All Done"


$endTime = Get-Date
$buildDuration = $endTime - $startTime
Write-Output "Build completed in $($buildDuration.TotalSeconds) seconds."