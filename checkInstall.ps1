param(
    [string] $package = "asf",
    [string] $server = "localhost",
    [string] $workspace_path = "C:/tools"
)

if (-not $workspace_path)
{
    Write-Warning "workspace_path isn't set"
}

if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    $progressPreference = 'silentlyContinue'
    Write-Host "Installing WinGet PowerShell module from PSGallery..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
    Repair-WinGetPackageManager -AllUsers
    Write-Host "Done."
}

function addEnvironment {
    [CmdletBinding()]
    param (
        [string] $name,
        [string] $value
    )
    if ($name -eq "PATH") {
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if (-not $currentPath.Contains($value)) {
            $updatedPath = "$currentPath;$value;"
            [Environment]::SetEnvironmentVariable("PATH", $updatedPath, "User")
            $env:Path += ";$value"
            Write-Host "Added environment $value"
        }
    }
    else {
        [Environment]::SetEnvironmentVariable("$name", "$value", "User")
        Set-Item "Env:$name" "$value"
        Write-Host "Added environment $name = $((Get-Item "Env:$name").Value)"
    }
}

function installPackageWinget {
    [CmdletBinding()]
    param (
        [string] $name,
        [string] $packageId,
        [bool] $addPath = $true
    )
    $envName = "$($name.ToUpper())_PATH"
    $envVar = (Get-Item "Env:$envName" -ErrorAction SilentlyContinue).Value
    if ($envVar -and $addPath) {
        if (-not (Test-Path -Path "$envVar")) {
            Write-Host "Installing $packageId to $workspace_path/$name"
            if ($addPath) {
                winget install -e --id $packageId --location "$workspace_path/$name"
                addEnvironment $envName $workspace_path/$name
            }
            else {
                winget install -e --id $packageId
            }
        }
    }
    else {
        if ($addPath) {
            if (-not (Test-Path -Path "$workspace_path/$name")) {
                Write-Host "Installing $packageId"
                if ($addPath) {
                    winget install -e --id $packageId --location "$workspace_path/$name"
                    addEnvironment $envName $workspace_path/$name
                }
                else {
                    winget install -e --id $packageId
                }
            }
            else {
                if ($addPath) {
                    addEnvironment $envName $workspace_path/$name
                }
            }
        }
        else {
            if (-not (Get-Command "$name" -ErrorAction SilentlyContinue)) {
                Write-Host "Installing $packageId"
                if ($addPath) {
                    winget install -e --id $packageId --location "$workspace_path/$name"
                    addEnvironment $envName $workspace_path/$name
                }
                else {
                    winget install -e --id $packageId
                }
            }
        }
    }
    # if ($name -eq "msys") {
    #     & "$env:MSYS_PATH\usr\bin\pacman.exe" -Suy
    # }
}

function installPackageMsys {
    [CmdletBinding()]
    param (
        [string] $name,
        [string] $packageId,
        [bool] $addPath = $true
    )
    if (-not (Test-Path -Path "$env:MSYS_PATH/usr/bin/pacman.exe")) {
        Write-Error "MSYS2 isn't installed"
        exit
    }
    & "$env:MSYS_PATH\usr\bin\pacman.exe" -Q $packageId *> $null
    if ($LASTEXITCODE) {
        & "$env:MSYS_PATH/usr/bin/pacman.exe" -S --noconfirm $packageId
    }
    if ($addPath) {
        $envName = "$($name.ToUpper())_PATH"
        addEnvironment $envName $workspace_path/$name
    }
}

function installPackage {
    [CmdletBinding()]
    param (
        [string] $name,
        [string] $packageId,
        [bool] $addPath = $true
    )
    $envName = "$($name.ToUpper())_PATH"
    $envVar = (Get-Item "Env:$envName" -ErrorAction SilentlyContinue).Value
    switch ($name) {
        "arm" {
            # if (-not (Get-Command "arm-none-eabi-gcc" -ErrorAction SilentlyContinue)) {
            if ((-not $envVar) -or (-not (Get-Command "$envName/arm-none-eabi-gcc.exe" -ErrorAction SilentlyContinue))) {
                if (-not (Get-Command "$workspace_path\$packageId\bin\arm-none-eabi-gcc.exe" -ErrorAction SilentlyContinue)) {
                    $url = "https://gitlab.arm.com/api/v4/projects/tooling%2Fgnu-toolchains-for-arm/packages/generic/gnu-toolchain/15.3.rel1/arm-gnu-toolchain-15.3.rel1-mingw-w64-x86_64-arm-none-eabi.msi"
                    $msi = Get-ChildItem "$env:USERPROFILE\Downloads" -File |
                    Where-Object Name -like "*$packageId*" |  Select-Object -First 1
                    if ($msi) {
                        $msi = $msi.FullName
                        $workspace_path = $workspace_path.Replace("/", "\")
                        Start-Process msiexec.exe -Wait -ArgumentList @(
                            "/i"
                            "`"$msi`""
                            "INSTALLDIR=`"$workspace_path\$packageId`""
                            "EULA=1"
                        )
                    }
                    else {
                        Write-Warning "Download $packageId from $url"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                    }
                }
                if ((-not $envVar) -and (Get-Command "$envName/arm-none-eabi-gcc.exe" -ErrorAction SilentlyContinue)) {
                    addEnvironment "$($name.ToUpper())_PATH" "$workspace_path\$packageId\bin"
                }
            }
        }


        Default {}
    }
}

$packageList = @{
    "cmake"     = { param($p) installPackageWinget $p "Kitware.CMake"           $false }
    "git"       = { param($p) installPackageWinget $p "Git.Git"                 $false }
    "msys"      = { param($p) installPackageWinget $p "MSYS2.MSYS2"             $true  }
    "ninja"     = { param($p) installPackageMsys   $p "mingw-w64-x86_64-ninja"  $false }
    "make"      = { param($p) installPackageMsys   $p "make"                    $false }
    "arm"       = { param($p) installPackage       $p "arm-none-eabi"           $false }
}

if ($PSVersionTable.PSVersion -lt [System.Version]"7.5.0") {
    winget upgrade --id Microsoft.PowerShell
}

if ($packageList.ContainsKey($package)) {
    & $packageList[$package] $package
}
else {
    Write-Error "Wrong package name. Available packages:"
    foreach ($p in $packageList) {
        Write-Host $p.Keys
    }
    exit
}

