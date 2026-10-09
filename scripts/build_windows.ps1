# Compilar release Windows — ejecutar en PowerShell con Flutter + Visual Studio
Set-Location $PSScriptRoot\..

flutter pub get
flutter build windows --release

$releaseDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"
if (-not (Test-Path $releaseDir)) {
    Write-Error "No se encontró la carpeta Release: $releaseDir"
    exit 1
}

# Incluir DLLs del Visual C++ Redistributable (evita error VCRUNTIME140.dll)
$vcDlls = @(
    'vcruntime140.dll',
    'vcruntime140_1.dll',
    'msvcp140.dll',
    'msvcp140_1.dll',
    'msvcp140_2.dll',
    'concrt140.dll'
)
foreach ($dll in $vcDlls) {
    $src = Join-Path $env:SystemRoot "System32\$dll"
    if (Test-Path $src) {
        Copy-Item $src $releaseDir -Force
        Write-Host "Copiado: $dll"
    }
}

$readme = @"
GESTOR DE CREDITOS — Bear Helados
=================================

INSTALACION EN WINDOWS
----------------------
1. Descomprima esta carpeta completa en su PC (ej. C:\GestorCreditos).
2. Ejecute gestor_creditos.exe.
3. Si aparece error de VCRUNTIME140.dll, instale el paquete:
   https://aka.ms/vs/17/release/vc_redist.x64.exe
   (Visual C++ Redistributable 2015-2022, x64)

NOTAS
-----
- No mueva solo el .exe: copie TODA la carpeta Release.
- Usuario inicial: admin / admin123 (cambie la contraseña al primer acceso).
- Impresora termica: en Configuracion elija ancho 58 mm o 80 mm segun su impresora.

Soporte: contacte a su proveedor del sistema.
"@
Set-Content -Path (Join-Path $releaseDir "README_INSTALACION.txt") -Value $readme -Encoding UTF8

Write-Host ""
Write-Host "EXE listo en: $releaseDir\gestor_creditos.exe"
Write-Host "Distribuya toda la carpeta Release (incluye DLLs y README_INSTALACION.txt)."
