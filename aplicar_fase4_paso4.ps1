# ============================================================
# AXC v2.5 - Fase 4 - Paso 4 - Reporte Global v2.5
# ============================================================
# Inyecta el parche que adapta el reporte global al modelo v2.5:
#   - Reemplaza _isOK / _isFAIL con logica v2.5 (afecta KPIs + Gauge)
#   - Hook a renderTable para reescribir columna Estado
#   - NO toca HTML, sidebar, charts, layout
#
# Idempotente. Backup: .pre_fase4_paso4.bak
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File C:\AXC\aplicar_fase4_paso4.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsParche = Join-Path $ProyectoPath 'axc_reporte_global_v25.js'
$Archivo = 'axc_reporte_global.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_fase4_paso4.bak"

$MarcadorInicio = '<!-- AXC_REPORTE_GLOBAL Fase 4 Paso 4 - inicio -->'
$MarcadorFin = '<!-- AXC_REPORTE_GLOBAL Fase 4 Paso 4 - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4 Paso 4 - Reporte Global ===' -ForegroundColor Cyan
Write-Host ''

# --- Verificar JS ---
if (-not (Test-Path $JsParche)) {
    Write-Host "ERROR: No se encuentra $JsParche" -ForegroundColor Red
    exit 1
}
$contenidoJs = Get-Content $JsParche -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.1-paso4'")) {
    Write-Host 'ERROR: axc_reporte_global_v25.js no es la version paso4' -ForegroundColor Red
    exit 1
}
Write-Host "JS paso4 cargado: $($contenidoJs.Length) caracteres" -ForegroundColor Green

# --- Verificar HTML ---
if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

# --- Backup ---
Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_fase4_paso4.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# ============================================================
# Verificar modulo 9 v2.5.1 presente
# ============================================================
if (-not $contenido.Contains("_version: '2.5.1'")) {
    Write-Host 'ERROR: HTML no tiene modulo 9 v2.5.1 - aplicar primero aplicar_modulo9.ps1' -ForegroundColor Red
    exit 1
}
Write-Host 'Modulo 9 v2.5.1 detectado en HTML - OK' -ForegroundColor DarkGreen

# ============================================================
# Reemplazar (o inyectar) bloque del parche
# ============================================================
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
    Write-Host '  Bloque parche previo removido' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloque + $contenido.Substring($idxBody)
Write-Host '  Parche v2.5 inyectado antes de </body>' -ForegroundColor Green

# ============================================================
# Verificacion y escritura
# ============================================================
$cIni = ([regex]::Matches($contenido, [regex]::Escape($MarcadorInicio))).Count
$cFin = ([regex]::Matches($contenido, [regex]::Escape($MarcadorFin))).Count

if ($cIni -ne 1 -or $cFin -ne 1) {
    Write-Host "ERROR: marcadores desbalanceados ($cIni/$cFin)" -ForegroundColor Red
    exit 3
}

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host '=== Resumen ===' -ForegroundColor Cyan
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_reporte_global.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_BL.kpis] modulo 9 cargado v2.5.1'
Write-Host '     [AXC_REPORTE_GLOBAL] cargado v2.5.1-paso4'
Write-Host '  3. Verificar que KPIs (Total / Cumple / No Cumple / Cumplimiento)'
Write-Host '     reflejen el nuevo calculo v2.5'
Write-Host '  4. Verificar que el Gauge tambien refleje el nuevo %'
Write-Host '  5. Verificar columna Estado de tabla con chips de color v2.5'
Write-Host '  6. Validacion en consola:'
Write-Host '     window._isOK.__axcV25Patched      // true'
Write-Host '     window._isFAIL.__axcV25Patched    // true'
Write-Host '     AXC_REPORTE_GLOBAL._v             // 2.5.1-paso4'
Write-Host ''
Write-Host '=== Para revertir ===' -ForegroundColor DarkGray
Write-Host "  Copy-Item $($Archivo).pre_fase4_paso4.bak $Archivo -Force"
