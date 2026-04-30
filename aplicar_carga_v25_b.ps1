$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$Js = Join-Path $ProyectoPath 'axc_carga_v25_b.js'
$Archivo = 'axc_residente.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo

$MarcadorInicio = '<!-- AXC_CARGA_V25_B Commit B - inicio -->'
$MarcadorFin = '<!-- AXC_CARGA_V25_B Commit B - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Carga v25 - Commit B (estados visuales de dias) ===' -ForegroundColor Cyan

if (-not (Test-Path $Js)) {
    Write-Host "ERROR: No se encuentra $Js" -ForegroundColor Red
    exit 1
}
$contenidoJs = Get-Content $Js -Raw -Encoding UTF8
if (-not $contenidoJs.Contains("'2.5.3-cargaB'")) {
    Write-Host 'ERROR: axc_carga_v25_b.js no es la version cargaB' -ForegroundColor Red
    exit 1
}
Write-Host "JS Commit B: $($contenidoJs.Length) caracteres" -ForegroundColor Green

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

$bloque = $MarcadorInicio + "`r`n<script>`r`n" + $contenidoJs + "`r`n</script>`r`n" + $MarcadorFin + "`r`n"

if ($contenido.Contains($MarcadorInicio)) {
    $idxI = $contenido.IndexOf($MarcadorInicio)
    $idxF = $contenido.IndexOf($MarcadorFin) + $MarcadorFin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Bloque B previo reemplazado' -ForegroundColor DarkCyan
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
Write-Host '     [AXC_CARGA_V25_B] cargado v2.5.3-cargaB'
Write-Host '  3. Visualmente:'
Write-Host '     - Dias cumplio: VERDE con OK'
Write-Host '     - Dias no_cumplio: ROJO con X'
Write-Host '     - Dias plan: NARANJA sin texto'
Write-Host '     - Hover en cualquier dia: tooltip "L 27/4 — Estado"'
Write-Host '  4. Click en un dia: cicla por estados, color cambia'
