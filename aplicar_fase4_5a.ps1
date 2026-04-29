# ============================================================
# AXC v2.5 - Fase 4.5.a - Fix campos v2.5 en Reporte Global
# ============================================================
# Inyecta el parche que enriquece window._allActs con los campos
# del modelo v2.5 (baseline_confirmada, cumplimiento_pct, etc)
# que el mapeo legacy omitia.
#
# Idempotente. Backup: .pre_fase4_5a.bak
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsParche = Join-Path $ProyectoPath 'axc_reporte_global_fix_v25.js'
$Archivo = 'axc_reporte_global.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_fase4_5a.bak"

$MarcadorInicio = '<!-- AXC_GLOBAL_FIX_V25 Fase 4.5a - inicio -->'
$MarcadorFin = '<!-- AXC_GLOBAL_FIX_V25 Fase 4.5a - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4.5a - Fix campos v2.5 ===' -ForegroundColor Cyan

if (-not (Test-Path $JsParche)) {
    Write-Host "ERROR: No se encuentra $JsParche" -ForegroundColor Red
    exit 1
}
$contenidoJs = Get-Content $JsParche -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.1-paso4.5a'")) {
    Write-Host 'ERROR: axc_reporte_global_fix_v25.js no es la version paso4.5a' -ForegroundColor Red
    exit 1
}
Write-Host "JS fix cargado: $($contenidoJs.Length) caracteres" -ForegroundColor Green

if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_fase4_5a.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# Reemplazar o inyectar
$bloque = $MarcadorInicio + "`r`n" `
    + '<script>' + "`r`n" `
    + $contenidoJs + "`r`n" `
    + '</script>' + "`r`n" `
    + $MarcadorFin + "`r`n"

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
Write-Host '  Parche inyectado antes de </body>' -ForegroundColor Green

$cIni = ([regex]::Matches($contenido, [regex]::Escape($MarcadorInicio))).Count
$cFin = ([regex]::Matches($contenido, [regex]::Escape($MarcadorFin))).Count
if ($cIni -ne 1 -or $cFin -ne 1) {
    Write-Host "ERROR: marcadores desbalanceados ($cIni/$cFin)" -ForegroundColor Red
    exit 3
}

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_reporte_global.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_GLOBAL_FIX_V25] cargado v2.5.1-paso4.5a'
Write-Host '     [AXC_GLOBAL_FIX_V25] hook a applyFilters instalado'
Write-Host '     [AXC_GLOBAL_FIX_V25] enriquecidas N de N'
Write-Host '  3. KPIs Cumple / No Cumple deben mostrar numeros distintos de 0'
Write-Host '  4. Validacion en consola:'
Write-Host '     window._allActs.filter(a => a.baseline_confirmada === true).length'
Write-Host '     // Esperado: ~84 con datos demo'
Write-Host ''
Write-Host '=== Para revertir ===' -ForegroundColor DarkGray
Write-Host "  Copy-Item $($Archivo).pre_fase4_5a.bak $Archivo -Force"
