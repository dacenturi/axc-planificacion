# ============================================================
# AXC v2.5 - Fase 4 - Paso 3 - Replicar reporte al contratista
# ============================================================
# Aplica el mismo bloque AXC_REPORTE v2.5.1-paso2e a
# axc_contratista.html. Usa el mismo axc_reporte_residente.js
# que ya esta en C:\AXC.
#
# - Reutiliza el .js del residente (la logica funciona igual)
# - Marcadores propios (Fase 4 Paso 3) para no colisionar
# - Inyecta Chart.js CDN si no esta presente
# - Idempotente
#
# Backup: .pre_fase4_paso3.bak
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File C:\AXC\aplicar_fase4_paso3.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsReporte = Join-Path $ProyectoPath 'axc_reporte_residente.js'
$Archivo = 'axc_contratista.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_fase4_paso3.bak"

$MarcadorChartInicio = '<!-- AXC Chart.js CDN - inicio -->'
$MarcadorChartFin = '<!-- AXC Chart.js CDN - fin -->'
$MarcadorReporteInicio = '<!-- AXC_REPORTE Fase 4 Paso 3 - inicio -->'
$MarcadorReporteFin = '<!-- AXC_REPORTE Fase 4 Paso 3 - fin -->'

$ChartCdnUrl = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4 Paso 3 - Reporte contratista ===' -ForegroundColor Cyan
Write-Host ''

# --- Verificar JS ---
if (-not (Test-Path $JsReporte)) {
    Write-Host "ERROR: No se encuentra $JsReporte" -ForegroundColor Red
    Write-Host '  Aplicar primero el paso 2e en residente.' -ForegroundColor Yellow
    exit 1
}
$contenidoJs = Get-Content $JsReporte -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.1-paso2e'")) {
    Write-Host 'ERROR: axc_reporte_residente.js no es la version paso2e' -ForegroundColor Red
    exit 1
}
Write-Host "JS paso2e cargado: $($contenidoJs.Length) caracteres" -ForegroundColor Green

# --- Verificar HTML ---
if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

# --- Backup ---
Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_fase4_paso3.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# ============================================================
# 1. Verificar modulo 9 v2.5.1 presente
# ============================================================
if (-not $contenido.Contains("_version: '2.5.1'")) {
    Write-Host 'ERROR: HTML no tiene modulo 9 v2.5.1 - aplicar primero aplicar_modulo9.ps1' -ForegroundColor Red
    exit 1
}
Write-Host 'Modulo 9 v2.5.1 detectado en HTML - OK' -ForegroundColor DarkGreen

# ============================================================
# 2. Asegurar que Chart.js este en <head>
# ============================================================
if ($contenido.Contains($MarcadorChartInicio)) {
    Write-Host 'Chart.js CDN ya presente - OK' -ForegroundColor DarkGreen
} else {
    Write-Host 'Inyectando Chart.js CDN en <head>' -ForegroundColor Yellow
    $bloqueChart = $MarcadorChartInicio + "`r`n" `
        + '<script src="' + $ChartCdnUrl + '"></script>' + "`r`n" `
        + $MarcadorChartFin + "`r`n"
    $idxHead = $contenido.LastIndexOf('</head>')
    if ($idxHead -lt 0) {
        Write-Host '  ERROR: no se encontro </head>' -ForegroundColor Red
        exit 2
    }
    $contenido = $contenido.Substring(0, $idxHead) + $bloqueChart + $contenido.Substring($idxHead)
    Write-Host '  Chart.js CDN inyectado' -ForegroundColor Green
}

# ============================================================
# 3. Reemplazar (o inyectar) bloque AXC_REPORTE
# ============================================================
$bloqueReporte = $MarcadorReporteInicio + "`r`n" `
    + '<script>' + "`r`n" `
    + $contenidoJs + "`r`n" `
    + '</script>' + "`r`n" `
    + $MarcadorReporteFin + "`r`n"

if ($contenido.Contains($MarcadorReporteInicio)) {
    $idxI = $contenido.IndexOf($MarcadorReporteInicio)
    $idxF = $contenido.IndexOf($MarcadorReporteFin) + $MarcadorReporteFin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque AXC_REPORTE Paso 3 previo removido' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloqueReporte + $contenido.Substring($idxBody)
Write-Host '  AXC_REPORTE paso2e inyectado en contratista' -ForegroundColor Green

# ============================================================
# Verificacion y escritura
# ============================================================
$cRptIni = ([regex]::Matches($contenido, [regex]::Escape($MarcadorReporteInicio))).Count
$cRptFin = ([regex]::Matches($contenido, [regex]::Escape($MarcadorReporteFin))).Count
$cChartIni = ([regex]::Matches($contenido, [regex]::Escape($MarcadorChartInicio))).Count
$cChartFin = ([regex]::Matches($contenido, [regex]::Escape($MarcadorChartFin))).Count

if ($cRptIni -ne 1 -or $cRptFin -ne 1 -or $cChartIni -ne 1 -or $cChartFin -ne 1) {
    Write-Host "ERROR: marcadores desbalanceados (rpt $cRptIni/$cRptFin, chart $cChartIni/$cChartFin)" -ForegroundColor Red
    exit 3
}

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host '=== Resumen ===' -ForegroundColor Cyan
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_contratista.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_BL.kpis] modulo 9 cargado v2.5.1'
Write-Host '     [AXC_REPORTE] cargado v2.5.1-paso2e'
Write-Host '  3. Click en pestana Reporte - debe verse:'
Write-Host '     - 6 cards (Total / Con baseline / Cumplimiento / Atraso prom / Atrasadas / Tasa baselines)'
Write-Host '     - Donut + Top 5 (vacios si no hay actividades cargadas)'
Write-Host ''
Write-Host '=== Para revertir ===' -ForegroundColor DarkGray
Write-Host "  Copy-Item $($Archivo).pre_fase4_paso3.bak $Archivo -Force"
