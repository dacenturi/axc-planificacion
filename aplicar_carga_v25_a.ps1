$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$Js = Join-Path $ProyectoPath 'axc_carga_v25.js'
$Archivo = 'axc_residente.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_carga_v25_a.bak"

$MarcadorInicio = '<!-- AXC_CARGA_V25 Commit A - inicio -->'
$MarcadorFin = '<!-- AXC_CARGA_V25 Commit A - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Carga v25 - Commit A (columnas calculadas) ===' -ForegroundColor Cyan

if (-not (Test-Path $Js)) {
    Write-Host "ERROR: No se encuentra $Js" -ForegroundColor Red
    exit 1
}
$contenidoJs = Get-Content $Js -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.3-cargaA'")) {
    Write-Host 'ERROR: axc_carga_v25.js no es la version cargaA' -ForegroundColor Red
    exit 1
}
Write-Host "JS Carga v25: $($contenidoJs.Length) caracteres" -ForegroundColor Green

if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_carga_v25_a.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

$bloque = $MarcadorInicio + "`r`n<script>`r`n" + $contenidoJs + "`r`n</script>`r`n" + $MarcadorFin + "`r`n"

if ($contenido.Contains($MarcadorInicio)) {
    $idxI = $contenido.IndexOf($MarcadorInicio)
    $idxF = $contenido.IndexOf($MarcadorFin) + $MarcadorFin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque previo removido' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloque + $contenido.Substring($idxBody)

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_residente.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_CARGA_V25] cargado v2.5.3-cargaA'
Write-Host '     [AXC_CARGA_V25] observer instalado en #tbl tbody'
Write-Host '  3. Visualmente:'
Write-Host '     - Columna Estado: chip read-only (no dropdown)'
Write-Host '     - Columna % Cumpl: numero con color'
Write-Host '     - Columna Dias atraso: numero o 0'
Write-Host '     - Badge: v2.5 (no v1.0)'
Write-Host '  4. Validacion:'
Write-Host '     window.AXC_CARGA_V25._v'
Write-Host '     document.querySelectorAll(".estado-chip-v25").length'
