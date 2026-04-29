# ============================================================
# AXC v2.5 - Fase 4.5b - Curva S en Reporte Global
# ============================================================
# Inyecta dos JS al axc_reporte_global.html:
#   1. axc_curva_s.js: extension del modulo 9 con Curva S
#   2. axc_global_curvas.js: integrador que inserta el wrap y
#      hookea renderDashboard
#
# Idempotente. Backup: .pre_fase4_5b_curvas.bak
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsCurva = Join-Path $ProyectoPath 'axc_curva_s.js'
$JsIntegrador = Join-Path $ProyectoPath 'axc_global_curvas.js'
$Archivo = 'axc_reporte_global.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo
$backup = "$rutaCompleta.pre_fase4_5b_curvas.bak"

$M1Inicio = '<!-- AXC_CurvaS modulo - inicio -->'
$M1Fin = '<!-- AXC_CurvaS modulo - fin -->'
$M2Inicio = '<!-- AXC_GLOBAL_CURVAS integrador - inicio -->'
$M2Fin = '<!-- AXC_GLOBAL_CURVAS integrador - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4.5b - Curva S ===' -ForegroundColor Cyan

if (-not (Test-Path $JsCurva)) {
    Write-Host "ERROR: No se encuentra $JsCurva" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $JsIntegrador)) {
    Write-Host "ERROR: No se encuentra $JsIntegrador" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

$contenidoCurva = Get-Content $JsCurva -Raw -Encoding UTF8
$contenidoIntegrador = Get-Content $JsIntegrador -Raw -Encoding UTF8

if (-not $contenidoCurva.Contains("'2.5.2-paso4.5b'")) {
    Write-Host 'ERROR: axc_curva_s.js no es la version 2.5.2-paso4.5b' -ForegroundColor Red
    exit 1
}

Write-Host "Curva S modulo: $($contenidoCurva.Length) caracteres" -ForegroundColor Green
Write-Host "Integrador: $($contenidoIntegrador.Length) caracteres" -ForegroundColor Green

Copy-Item $rutaCompleta $backup -Force
Write-Host "Backup -> $($Archivo).pre_fase4_5b_curvas.bak" -ForegroundColor DarkGray

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# ---- Bloque 1: modulo Curva S ----
$bloque1 = $M1Inicio + "`r`n<script>`r`n" + $contenidoCurva + "`r`n</script>`r`n" + $M1Fin + "`r`n"
if ($contenido.Contains($M1Inicio)) {
    $idxI = $contenido.IndexOf($M1Inicio)
    $idxF = $contenido.IndexOf($M1Fin) + $M1Fin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque modulo Curva S previo removido' -ForegroundColor DarkCyan
}

# ---- Bloque 2: integrador ----
$bloque2 = $M2Inicio + "`r`n<script>`r`n" + $contenidoIntegrador + "`r`n</script>`r`n" + $M2Fin + "`r`n"
if ($contenido.Contains($M2Inicio)) {
    $idxI = $contenido.IndexOf($M2Inicio)
    $idxF = $contenido.IndexOf($M2Fin) + $M2Fin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque integrador previo removido' -ForegroundColor DarkCyan
}

# Inyectar ambos antes de </body> (el modulo primero, despues el integrador)
$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}

$contenido = $contenido.Substring(0, $idxBody) + $bloque1 + $bloque2 + $contenido.Substring($idxBody)
Write-Host '  Bloques inyectados' -ForegroundColor Green

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_reporte_global.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_CurvaS] cargado v2.5.2-paso4.5b'
Write-Host '     [AXC_GLOBAL_CURVAS] cargado v2.5.2-paso4.5b'
Write-Host '     [AXC_GLOBAL_CURVAS] hook a renderDashboard instalado'
Write-Host '  3. Aparece nuevo chart "Curva S - Planificado vs Real" debajo de "Cumplimiento en el tiempo"'
Write-Host '  4. Validacion en consola:'
Write-Host '     AXC_BL.kpis.calcularCurvaS(window._filteredActs)'
