$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$Js = Join-Path $ProyectoPath 'axc_carga_v25.js'
$Archivo = 'axc_residente.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo

$MarcadorInicio = '<!-- AXC_CARGA_V25 Commit A - inicio -->'
$MarcadorFin = '<!-- AXC_CARGA_V25 Commit A - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Carga v25 - Commit A.4 (deteccion dinamica + Actividad expandible) ===' -ForegroundColor Cyan

if (-not (Test-Path $Js)) {
    Write-Host "ERROR: No se encuentra $Js" -ForegroundColor Red
    exit 1
}
$contenidoJs = Get-Content $Js -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.3-cargaA4'")) {
    Write-Host 'ERROR: axc_carga_v25.js no es la version cargaA4' -ForegroundColor Red
    exit 1
}
Write-Host "JS A.4: $($contenidoJs.Length) caracteres" -ForegroundColor Green

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

$bloque = $MarcadorInicio + "`r`n<script>`r`n" + $contenidoJs + "`r`n</script>`r`n" + $MarcadorFin + "`r`n"

if ($contenido.Contains($MarcadorInicio)) {
    $idxI = $contenido.IndexOf($MarcadorInicio)
    $idxF = $contenido.IndexOf($MarcadorFin) + $MarcadorFin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque previo reemplazado por A.4' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
$contenido = $contenido.Substring(0, $idxBody) + $bloque + $contenido.Substring($idxBody)

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_residente.html'
Write-Host '  2. Verificar:'
Write-Host '     [AXC_CARGA_V25] cargado v2.5.3-cargaA4'
Write-Host '  3. Visualmente:'
Write-Host '     - Estado con chip en SU columna (no en Inicio)'
Write-Host '     - Inicio y Fin se ven correctamente'
Write-Host '     - Click en Actividad: el input se expande a 400px'
Write-Host '     - Hover en Actividad: tooltip con texto completo'
Write-Host '  4. Cambiar a un residente de 1 semana y otro de 2 semanas - debe funcionar igual'
