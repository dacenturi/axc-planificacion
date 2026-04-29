$ErrorActionPreference = 'Stop'

$ProyectoPath = 'C:\AXC'
$JsTv = Join-Path $ProyectoPath 'axc_tv_curvas.js'
$Archivo = 'axc_dashboard_tv.html'
$rutaCompleta = Join-Path $ProyectoPath $Archivo

$M2Inicio = '<!-- AXC_TV_CURVAS integrador - inicio -->'
$M2Fin = '<!-- AXC_TV_CURVAS integrador - fin -->'

Write-Host ''
Write-Host '=== AXC v2.5 - Curva S TV v3 (fix layout balanceado) ===' -ForegroundColor Cyan

if (-not (Test-Path $JsTv)) {
    Write-Host "ERROR: No se encuentra $JsTv" -ForegroundColor Red
    exit 1
}
$contenidoTv = Get-Content $JsTv -Raw -Encoding UTF8
if (-not $contenidoTv.Contains("'2.5.2-paso4.5b-tv3'")) {
    Write-Host 'ERROR: axc_tv_curvas.js no es la version tv3' -ForegroundColor Red
    exit 1
}
Write-Host "Integrador TV v3: $($contenidoTv.Length) caracteres" -ForegroundColor Green

$contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
$tamOriginal = $contenido.Length

$bloque = $M2Inicio + "`r`n<script>`r`n" + $contenidoTv + "`r`n</script>`r`n" + $M2Fin + "`r`n"

if ($contenido.Contains($M2Inicio)) {
    $idxI = $contenido.IndexOf($M2Inicio)
    $idxF = $contenido.IndexOf($M2Fin) + $M2Fin.Length
    if ($idxF -lt $contenido.Length -and $contenido.Substring($idxF, 2) -eq "`r`n") { $idxF += 2 }
    $contenido = $contenido.Remove($idxI, $idxF - $idxI)
    Write-Host '  Integrador previo (v2) reemplazado por v3' -ForegroundColor DarkCyan
}

$idxBody = $contenido.LastIndexOf('</body>')
$contenido = $contenido.Substring(0, $idxBody) + $bloque + $contenido.Substring($idxBody)
Write-Host '  Integrador v3 inyectado' -ForegroundColor Green

Set-Content -Path $rutaCompleta -Value $contenido -NoNewline -Encoding UTF8
$tamNuevo = $contenido.Length

Write-Host ''
Write-Host "$Archivo : $tamOriginal -> $tamNuevo (delta $($tamNuevo - $tamOriginal))" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test ===' -ForegroundColor Cyan
Write-Host '  1. Empty Cache and Hard Reload de axc_dashboard_tv.html'
Write-Host '  2. F12 - Console - verificar:'
Write-Host '     [AXC_TV_CURVAS] cargado v2.5.2-paso4.5b-tv3'
Write-Host '  3. Los 6 cards originales deben verse completos (~220px)'
Write-Host '  4. La Curva S debe estar abajo, compacta (~240px), full width'
Write-Host '  5. Validacion en consola:'
Write-Host '     document.querySelectorAll(".card").forEach(c=>console.log(c.id||"-",c.offsetHeight))'
