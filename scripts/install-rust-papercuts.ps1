# Silent install Rust (rustup) then papercuts CLI
$ErrorActionPreference = "Continue"

$cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
$cargo = Join-Path $cargoBin "cargo.exe"
$rustup = Join-Path $cargoBin "rustup.exe"
$papercuts = Join-Path $cargoBin "papercuts.exe"

if (-not (Test-Path $rustup)) {
    Write-Host "Installing Rust via rustup-init -y ..."
    $dir = Join-Path $env:TEMP "rustup-init"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $exe = Join-Path $dir "rustup-init.exe"
    Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $exe
    & $exe -y
}

if (-not (Test-Path $rustup)) {
    throw "rustup.exe missing. Install from https://rustup.rs and retry."
}

$env:Path = "$cargoBin;$env:Path"

Write-Host "Repairing/installing stable toolchain ..."
& $rustup toolchain uninstall stable 2>$null
& $rustup toolchain install stable
& $rustup default stable
& $rustup show
& $cargo -V

Write-Host "Installing papercuts (compile may take several minutes) ..."
& $cargo install papercuts

if (-not (Test-Path $papercuts)) {
    throw "papercuts.exe not found after install."
}

Write-Host "OK: $papercuts"
& $papercuts --help
