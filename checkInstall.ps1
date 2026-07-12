param(
    [string] $package = "pic",
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
                    Start-Process $url
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
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                    }
                }
                if ((-not $envVar) -and (Get-Command "$workspace_path\$packageId\bin\arm-none-eabi-gcc.exe" -ErrorAction SilentlyContinue)) {
                    if (-$addPath) {
                        addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId\bin"
                    }
                }
            }
        }

        "asf" {
            if (-not ($envVar -and (Test-Path -Path $envVar))) {
                if (-not (Test-Path -Path "$workspace_path\$packageId")) {
                    $url = "https://ww1.microchip.com/downloads/en/DeviceDoc/asf-standalone-archive-3.52.0.113.zip"
                    $zip = "$env:USERPROFILE\Downloads\$packageId.zip"
                    $zipFound = Get-ChildItem "$env:USERPROFILE\Downloads" -File |
                        Where-Object Name -like "*$packageId*" |  Select-Object -First 1
                    if (-not $zipFound) {
                        Write-Host "Downloading ASF..."
                        Invoke-WebRequest -Uri $url -OutFile $zip
                    }
                    if ($zipFound) {
                        Write-Host "Installing ASF..."
                        Expand-Archive -Path $zipFound -DestinationPath $workspace_path -Force
                    }
                    else {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
        }

        "avr" {
            if (-not ($envVar -and (Test-Path -Path $envVar))) {
                if (-not (Test-Path -Path "$workspace_path\$packageId")) {
                    $url = "https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/avr8-gnu-toolchain-4.0.0.52-win32.any.x86_64.zip"
                    $zip = "$env:USERPROFILE\Downloads\$packageId.zip"
                    $zipFound = Get-ChildItem "$env:USERPROFILE\Downloads" -File |
                        Where-Object Name -like "*$packageId*" |  Select-Object -First 1
                    if (-not $zipFound) {
                        Write-Host "Downloading AVR toolchain..."
                        Invoke-WebRequest -Uri $url -OutFile $zip
                    }
                    if ($zipFound) {
                        Write-Host "Installing AVR toolchain..."
                        Expand-Archive -Path $zipFound -DestinationPath $workspace_path -Force
                    }
                    else {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
        }

        "idf" {
            if (-not ($envVar -and (Test-Path -Path $envVar))) {
                if (-not (Test-Path -Path $workspace_path/$packageId)) {
                    $url = "https://github.com/espressif/esp-idf.git"
                    git clone --recurse-submodules $url "$workspace_path/$packageId"
                    addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
                }
            }
            if (-not $envVar -and (Test-Path -Path $workspace_path/$packageId)){
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
            if (-not (Test-Path -Path "$HOME/.espressif")) {
                & "$workspace_path/$packageId/install.ps1"
            }
            if ($envVar -and (Test-Path -Path $envVar)) {
                if (-not (Get-Command "xtensa-esp-elf-gcc" -ErrorAction SilentlyContinue)) {
                    $compiler_path = Get-ChildItem -Directory "$HOME/.espressif/tools/xtensa-esp-elf"
                    $compiler_path = Get-ChildItem -Directory $compiler_path
                    addEnvironment "PATH" "$compiler_path\bin"
                }
                if (-not (Get-Command "xtensa-esp32-elf-gdb" -ErrorAction SilentlyContinue)) {
                    $compiler_path = Get-ChildItem -Directory "$HOME/.espressif/tools/xtensa-esp-elf-gdb"
                    $compiler_path = Get-ChildItem -Directory $compiler_path
                    addEnvironment "PATH" "$compiler_path\bin"
                }
                if (-not (Get-Command "riscv32-esp-elf-gcc" -ErrorAction SilentlyContinue)) {
                    $compiler_path = Get-ChildItem -Directory "$HOME/.espressif/tools/riscv32-esp-elf"
                    $compiler_path = Get-ChildItem -Directory $compiler_path
                    addEnvironment "PATH" "$compiler_path\bin"
                }
                if (-not (Get-Command "riscv32-esp-elf-gdb" -ErrorAction SilentlyContinue)) {
                    $compiler_path = Get-ChildItem -Directory "$HOME/.espressif/tools/riscv32-esp-elf-gdb"
                    $compiler_path = Get-ChildItem -Directory $compiler_path
                    addEnvironment "PATH" "$compiler_path\bin"
                }
            
            }
            else {
                Write-Error "ESP-IDF isn't installed"
            }
        }

        "msp430" {
            if (-not ($envVar -and (Test-Path -Path $envVar))) {
                $url = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/msp430-gcc-full-windows-installer-9.3.1.2.exe"
                $exe = "$env:USERPROFILE\Downloads\$packageId.exe"
                if (-not (Test-Path -Path $exe)) {
                    Write-Host "Downloading MSP430 toolchain..."
                    Invoke-WebRequest -Uri $url -OutFile $exe
                    if (-not (Test-Path -Path $exe)) {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                if (Test-Path -Path $exe) {
                    Write-Host "Installing MSP430 toolchain..."
                    Start-Process -FilePath $exe -ArgumentList "--prefix `"$workspace_path\$packageId`"" -Wait
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
        }

        "pic" {
            if (-not ($envVar -and (Test-Path -Path $envVar))) {
                if (-not (Test-Path -Path "$workspace_path\$packageId")) {
                    $url = "https://packs.download.microchip.com/Microchip.PIC32MX_DFP.1.7.380.atpack"
                    $zip = "$env:USERPROFILE\Downloads\$packageId.zip"
                    $zipFound = Get-ChildItem "$env:USERPROFILE\Downloads" -File |
                        Where-Object Name -like "*$packageId*" |  Select-Object -First 1
                    if ($zipFound) {
                        Write-Host "Installing PIC DPF..."
                        Expand-Archive -Path $zipFound -DestinationPath $workspace_path -Force
                    }
                    else {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
            # if (-not ($envVar -and (Test-Path -Path $envVar))) {
            #     if (-not (Test-Path -Path $workspace_path/$packageId)) {
                    
            #         $url = "https://github.com/Microchip-MPLAB-Harmony/dev_packs.git"
            #         git clone --recurse-submodules $url "$workspace_path/$packageId"
            #         addEnvironment "$($name.ToUpper())_PATH" "$workspace_path\$packageId"
            #     }
            #     if (-not $envVar -and (Test-Path -Path $workspace_path/$packageId)){
            #         addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            #     }
            # }
        }

        "xc8" {
             if (-not ($envVar -and (Test-Path -Path $envVar))) {
                $url = "https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/xc8-v4.00-full-install-windows-x64-installer.exe"
                $exe = "$env:USERPROFILE\Downloads\$packageId.exe"
                if (-not (Test-Path -Path $exe)) {
                    Write-Host "Downloading XC32 GCC compiler..."
                    Invoke-WebRequest -Uri $url -OutFile $exe
                    if (-not (Test-Path -Path $exe)) {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                if (Test-Path -Path $exe) {
                    Write-Host "Installing XC32 GCC compiler..."
                    Start-Process -FilePath $exe -ArgumentList "--prefix `"$workspace_path\$packageId`"" -Wait
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
        }

        "xc32" {
             if (-not ($envVar -and (Test-Path -Path $envVar))) {
                $url = "https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/xc32-v6.00-full-install-windows-x64-installer.exe"
                $exe = "$env:USERPROFILE\Downloads\$packageId.exe"
                if (-not (Test-Path -Path $exe)) {
                    Write-Host "Downloading XC32 GCC compiler..."
                    Invoke-WebRequest -Uri $url -OutFile $exe
                    if (-not (Test-Path -Path $exe)) {
                        Write-Warning "Download $packageId from"
                        Write-Warning "$url"
                        Write-Warning "And retry"
                        exit
                    }
                }
                if (Test-Path -Path $exe) {
                    Write-Host "Installing XC32 GCC compiler..."
                    Start-Process -FilePath $exe -ArgumentList "--prefix `"$workspace_path\$packageId`"" -Wait
                }
                addEnvironment "$($name.ToUpper())_PATH" "$workspace_path/$packageId"
            }
        }

        Default {}
    }
}

$packageList = @{
    "cmake"     = { param($p) installPackageWinget $p "Kitware.CMake"                   $false }
    "git"       = { param($p) installPackageWinget $p "Git.Git"                         $false }
    "7zip"      = { param($p) installPackageWinget $p "7zip.7zip"                       $false }
    "msys"      = { param($p) installPackageWinget $p "MSYS2.MSYS2"                     $true  }
    "ninja"     = { param($p) installPackageMsys   $p "mingw-w64-x86_64-ninja"          $false }
    "make"      = { param($p) installPackageMsys   $p "make"                            $false }
    "gcc"       = { param($p) installPackageMsys   $p "mingw-w64-x86_64-gcc"            $false }
    "gdb"       = { param($p) installPackageMsys   $p "mingw-w64-x86_64-gdb"            $false }
    "arm"       = { param($p) installPackage       $p "arm-none-eabi"                   $true  }
    "asf"       = { param($p) installPackage       $p "xdk-asf-3.52.0"                  $true  }
    "avr"       = { param($p) installPackage       $p "avr8-gnu-toolchain-win32_x86_64" $true  }
    "idf"       = { param($p) installPackage       $p "esp-idf"                         $true  }
    "msp430"    = { param($p) installPackage       $p "msp430-gcc"                      $true  }
    "pic"       = { param($p) installPackage       $p "pic-dfp"                         $true  }
    "xc8"       = { param($p) installPackage       $p "xc8"                             $true  }
    "xc32"      = { param($p) installPackage       $p "xc32"                            $true  }
    "ocd"       = { param($p) installPackage       $p "openocd"                         $true  }
    "stlink"    = { param($p) installPackage       $p "stlink"                          $true  }
    "jlink"     = { param($p) installPackage       $p "jlink"                           $true  }
    "vcpkg"     = { param($p) installPackage       $p "vcpkg"                           $true  }
    "mplab"     = { param($p) installPackage       $p "mplab"                           $true  }
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

