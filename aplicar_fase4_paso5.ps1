# ============================================================
# AXC v2.5 - Fase 4 - Paso 5 - Panel TV adaptado a v2.5
# ============================================================
# Hace dos cosas en una pasada:
#   1. Inyecta el modulo 9 KPIs en axc_dashboard_tv.html
#      (no estaba aplicado previamente)
#   2. Inyecta el parche v2.5 que adapta _isOK/_isFAIL,
#      hookea renderKPIs y cambia kpi-prox por Tasa Baselines.
#
# Idempotente. Backup: .pre_fase4_paso5.bak
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File C:\AXC\aplicar_fase4_paso5.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsModulo9 = Join-Path $ProyectoPath 'axc_bl_modulo9_kpis.js'
$JsParche = Join-Path $ProyectoPath 'axc_dashboard_tv_v25.js'
$Archivo = 'axc_dashboard_tv.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_fase4_paso5.bak"

$M9Inicio = '<!-- AXC_BL Modulo 9 KPIs - inicio -->'
$M9Fin = '<!-- AXC_BL Modulo 9 KPIs - fin -->'
$ParcheInicio = '<!-- AXC_TV_V25 Fase 4 Paso 5 - inicio -->'
$ParcheFin = '<!-- AXC_TV_V25 Fase 4 Paso 5 - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4 Paso 5 - Panel TV ===' -ForegroundColor Cyan
Write-Host ''

# --- Verificar JS dependencias ---
if (-not (Test-Path $JsModulo9)) {
    Write-Host "ERROR: No se encuentra $JsModulo9" -ForegroundColor Red
    Write-Host '  Aplicar primero el paso 1 (modulo 9).' -ForegroundColor Yellow
    exit 1
}
$contenidoM9 = Get-Content $JsModulo9 -Raw -Encoding UTF8
if (-not $contenidoM9.Contains("_version: '2.5.1'")) {
    Write-Host 'ERROR: axc_bl_modulo9_kpis.js no es v2.5.1' -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $JsParche)) {
    Write-Host "ERROR: No se encuentra $JsParche" -ForegroundColor Red
    exit 1
}
$contenidoParche = Get-Content $JsParche -Raw -Encoding UTF8
if (-not $contenidoParche.Contains("'2.5.1-paso5'")) {
    Write-Host 'ERROR: axc_dashboard_tv_v25.js no es paso5' -ForegroundColor Red
    exit 1
}

Write-Host "Modulo 9 cargado: $($contenidoM9.Length) caracteres" -ForegroundColor Green
Write-Host "Parche TV cargado: $($contenidoParche.Length) caracteres" -ForegroundColor Green

# --- Verificar HTML ---
if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

# --- Backup ---
Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_fase4_paso5.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# ============================================================
# 1. Modulo 9 - reemplazar o inyectar
# ============================================================
Write-Host ''
Write-Host '[1/2] Modulo 9 KPIs' -ForegroundColor Yellow

$bloqueM9 = $M9Inicio + "`r`n" `
    + '<script>' + "`r`n" `
    + $contenidoM9 + "`r`n" `
    + '</script>' + "`r`n" `
    + $M9Fin + "`r`n"

if ($contenido.Contains($M9Inicio)) {
    $idxI = $contenido.IndexOf($M9Inicio)
    $idxF = $contenido.IndexOf($M9Fin) + $M9Fin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque modulo 9 previo removido' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloqueM9 + $contenido.Substring($idxBody)
Write-Host '  Modulo 9 inyectado' -ForegroundColor Green

# ============================================================
# 2. Parche TV v2.5 - reemplazar o inyectar
# ============================================================
Write-Host ''
Write-Host '[2/2] Parche TV v2.5' -ForegroundColor Yellow

$bloqueParche = $ParcheInicio + "`r`n" `
    + '<script>' + "`r`n" `
    + $contenidoParche + "`r`n" `
    + '</script>' + "`r`n" `
    + $ParcheFin + "`r`n"

if ($contenido.Contains($ParcheInicio)) {
    $idxI = $contenido.IndexOf($ParcheInicio)
    $idxF = $contenido.IndexOf($ParcheFin) + $ParcheFin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque parche previo removido' -ForegroundColor DarkCyan
}

# Insertar despues del modulo 9 (que se hace cargo de definir AXC_BL.kpis)
$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloqueParche + $contenido.Substring($idxBody)
Write-Host '  Parche TV inyectado' -ForegroundColor Green

# ============================================================
# Verificacion y escritura
# ============================================================
$cM9I = ([regex]::Matches($contenido, [regex]::Escape($M9Inicio))).Count
$cM9F = ([regex]::Matches($contenido, [regex]::Escape($M9Fin))).Count
$cPI = ([regex]::Matches($contenido, [regex]::Escape($ParcheInicio))).Count
$cPF = ([regex]::Matches($contenido, [regex]::Escape($ParcheFin))).Count

if ($cM9I -ne 1 -or $cM9F -ne 1 -or $cPI -ne 1 -or $cPF -ne 1) {
    Write-Host "ERROR: marcadores desbalanceados (m9 $cM9I/$cM9F, parche $cPI/$cPF)" -ForegroundColor Red
    exit 3
}

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host '=== Resumen ===' -ForegroundColor Cyan
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_dashboard_tv.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_BL.kpis] modulo 9 cargado v2.5.1'
Write-Host '     [AXC_TV_V25] cargado v2.5.1-paso5'
Write-Host '  3. Verificar visualmente:'
Write-Host '     - kpi-cumpl recalculado con baseline v2.5'
Write-Host '     - kpi-retr recalculado con estado calculado v2.5'
Write-Host '     - El KPI que decia "Proximas a vencer" ahora dice "Tasa Baselines"'
Write-Host '     - El valor del card es % de baselines confirmadas'
Write-Host '  4. Validacion en consola:'
Write-Host '     console.log(AXC_TV_V25._v, window._isOK.__axcV25Patched, AXC_BL.kpis._version)'
Write-Host ''
Write-Host '=== Para revertir ===' -ForegroundColor DarkGray
Write-Host "  Copy-Item $($Archivo).pre_fase4_paso5.bak $Archivo -Force"
