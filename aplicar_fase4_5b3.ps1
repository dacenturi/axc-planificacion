# ============================================================
# AXC v2.5 - Fase 4.5b - Curva S v3 (fix de tamaño)
# ============================================================
# Reemplaza el integrador anterior con v3 que inserta el chart
# como dash-card correcto (altura controlada).
#
# El modulo axc_curva_s.js queda intacto (sigue funcionando).
# ============================================================

$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsIntegrador = Join-Path $ProyectoPath 'axc_global_curvas.js'
$Archivo = 'axc_reporte_global.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo

$M2Inicio = '<!-- AXC_GLOBAL_CURVAS integrador - inicio -->'
$M2Fin = '<!-- AXC_GLOBAL_CURVAS integrador - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4.5b v3 - Fix tamaño Curva S ===' -ForegroundColor Cyan

if (-not (Test-Path $JsIntegrador)) {
    Write-Host "ERROR: No se encuentra $JsIntegrador" -ForegroundColor Red
    exit 1
}
$contenidoIntegrador = Get-Content $JsIntegrador -Raw -Encoding UTF8
if (-not $contenidoIntegrador.Contains("'2.5.2-paso4.5b3'")) {
    Write-Host 'ERROR: axc_global_curvas.js no es la version 2.5.2-paso4.5b3' -ForegroundColor Red
    exit 1
}
Write-Host "Integrador v3 cargado: $($contenidoIntegrador.Length) caracteres" -ForegroundColor Green

if (-not (Test-Path $rutaCompleta)) {
    Write-Host "ERROR: No se encuentra $rutaCompleta" -ForegroundColor Red
    exit 1
}

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

# Solo reemplazar el bloque del integrador (el modulo Curva S queda intacto)
$bloque = $M2Inicio + "`r`n<script>`r`n" + $contenidoIntegrador + "`r`n</script>`r`n" + $M2Fin + "`r`n"

if ($contenido.Contains($M2Inicio)) {
    $idxI = $contenido.IndexOf($M2Inicio)
    $idxF = $contenido.IndexOf($M2Fin) + $M2Fin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Integrador previo (v2) reemplazado por v3' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
if ($idxBody -lt 0) {
    Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
    exit 2
}
$contenido = $contenido.Substring(0, $idxBody) + $bloque + $contenido.Substring($idxBody)
Write-Host '  Integrador v3 inyectado' -ForegroundColor Green

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_reporte_global.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_GLOBAL_CURVAS] cargado v2.5.2-paso4.5b3'
Write-Host '  3. El chart Curva S debe aparecer con tamaño correcto (~280px)'
Write-Host '  4. Cambiar tab Contratista <-> Residente: chart se redibuja'
Write-Host '  5. Cambiar filtros del sidebar: chart se redibuja'
