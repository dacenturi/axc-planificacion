# ============================================================
# AXC v2.5 - Fase 4 - Aplicar Modulo 9 KPIs
# ============================================================
# Inyecta el bloque <script> del modulo 9 (axc_bl_modulo9_kpis.js)
# antes de </body> en los tres archivos HTML del proyecto.
#
# Idempotente: si el bloque ya existe, lo reemplaza por la version
# nueva del .js. Hace backup .pre_modulo9.bak antes de tocar nada.
#
# Uso: desde C:\AXC, ejecutar:
#   powershell -ExecutionPolicy Bypass -File .\aplicar_modulo9.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

# --- Configuracion ---
$ProyectoPath = 'C:\AXC'
$JsModulo = Join-Path $ProyectoPath 'axc_bl_modulo9_kpis.js'
$Archivos = @(
    'axc_residente.html',
    'axc_contratista.html',
    'axc_reporte_global.html'
)
$MarcadorInicio = '<!-- AXC_BL Modulo 9 KPIs - inicio -->'
$MarcadorFin = '<!-- AXC_BL Modulo 9 KPIs - fin -->'

# --- Header ---
Write-Host ''
Write-Host '=== AXC v2.5 - Fase 4 - Modulo 9 KPIs ===' -ForegroundColor Cyan
Write-Host "Proyecto: $ProyectoPath" -ForegroundColor DarkGray
Write-Host ''

# --- 1. Verificar JS de modulo ---
if (-not (Test-Path $JsModulo)) {
    Write-Host "ERROR: No se encuentra $JsModulo" -ForegroundColor Red
    Write-Host 'Asegurate de tener axc_bl_modulo9_kpis.js en C:\AXC junto a este script'
    exit 1
}
$contenidoJs = Get-Content $JsModulo -Raw -Encoding UTF8
$tamJs = $contenidoJs.Length
Write-Host "JS modulo 9 cargado: $tamJs caracteres" -ForegroundColor Green

# --- 2. Construir bloque a inyectar ---
$bloqueScript = $MarcadorInicio + "`r`n" `
    + '<script>' + "`r`n" `
    + $contenidoJs + "`r`n" `
    + '</script>' + "`r`n" `
    + $MarcadorFin + "`r`n"

# --- 3. Procesar cada archivo ---
$resultados = @()

foreach ($archivo in $Archivos) {
    $rutaCompleta = Join-Path $ProyectoPath $archivo
    Write-Host ''
    Write-Host "[$archivo]" -ForegroundColor Yellow

    if (-not (Test-Path $rutaCompleta)) {
        Write-Host '  OMITIDO: archivo no encontrado' -ForegroundColor DarkYellow
        $resultados += [PSCustomObject]@{ Archivo = $archivo; Estado = 'OMITIDO'; Detalle = 'no encontrado' }
        continue
    }

    # Backup
    $backup = "$rutaCompleta.pre_modulo9.bak"
    Copy-Item $rutaCompleta $backup -Force
    Write-Host "  Backup -> $($archivo).pre_modulo9.bak" -ForegroundColor DarkGray

    # Leer
    $contenido = Get-Content $rutaCompleta -Raw -Encoding UTF8
    $tamOriginal = $contenido.Length

    # Detectar y limpiar bloque previo si existe
    $tieneBloquePrevio = $contenido.Contains($MarcadorInicio)
    if ($tieneBloquePrevio) {
        $idxInicio = $contenido.IndexOf($MarcadorInicio)
        $idxFinMarcador = $contenido.IndexOf($MarcadorFin)
        if ($idxFinMarcador -lt 0) {
            Write-Host '  ERROR: marcador inicio sin marcador fin - archivo posiblemente corrupto' -ForegroundColor Red
            $resultados += [PSCustomObject]@{ Archivo = $archivo; Estado = 'ERROR'; Detalle = 'marcadores desbalanceados' }
            continue
        }
        $idxFin = $idxFinMarcador + $MarcadorFin.Length
        # Tambien arrastrar el `r`n posterior si existe
        if ($idxFin + 1 -lt $contenido.Length -and $contenido.Substring($idxFin, 2) -eq "`r`n") {
            $idxFin += 2
        }
        $longitud = $idxFin - $idxInicio
        $contenido = $contenido.Remove($idxInicio, $longitud)
        Write-Host '  Bloque modulo 9 previo detectado y removido' -ForegroundColor DarkCyan
    }

    # Localizar </body> (ultima ocurrencia para evitar matches en strings)
    $idxBody = $contenido.LastIndexOf('</body>')
    if ($idxBody -lt 0) {
        Write-Host '  ERROR: no se encontro </body>' -ForegroundColor Red
        $resultados += [PSCustomObject]@{ Archivo = $archivo; Estado = 'ERROR'; Detalle = 'sin </body>' }
        continue
    }

    # Insertar bloque
    $contenidoNuevo = $contenido.Substring(0, $idxBody) + $bloqueScript + $contenido.Substring($idxBody)
    $tamNuevo = $contenidoNuevo.Length

    # Verificacion: el bloque debe estar exactamente una vez en el resultado
    $countInicio = ([regex]::Matches($contenidoNuevo, [regex]::Escape($MarcadorInicio))).Count
    $countFin = ([regex]::Matches($contenidoNuevo, [regex]::Escape($MarcadorFin))).Count
    if ($countInicio -ne 1 -or $countFin -ne 1) {
        Write-Host "  ERROR de verificacion: marcadores inicio=$countInicio fin=$countFin (esperado 1/1)" -ForegroundColor Red
        $resultados += [PSCustomObject]@{ Archivo = $archivo; Estado = 'ERROR'; Detalle = 'verificacion fallo' }
        continue
    }

    # Escribir
    Set-Content -Path $rutaCompleta -Value $contenidoNuevo -NoNewline -Encoding UTF8
    $delta = $tamNuevo - $tamOriginal
    $accion = if ($tieneBloquePrevio) { 'REEMPLAZADO' } else { 'INYECTADO' }
    Write-Host "  $accion - $tamOriginal -> $tamNuevo (delta $delta)" -ForegroundColor Green
    $resultados += [PSCustomObject]@{ Archivo = $archivo; Estado = $accion; Detalle = "delta $delta" }
}

# --- 4. Resumen final ---
Write-Host ''
Write-Host '=== Resumen ===' -ForegroundColor Cyan
$resultados | Format-Table -AutoSize | Out-String | Write-Host

$exitos = ($resultados | Where-Object { $_.Estado -in @('INYECTADO', 'REEMPLAZADO') }).Count
$errores = ($resultados | Where-Object { $_.Estado -eq 'ERROR' }).Count

if ($errores -gt 0) {
    Write-Host "Hubo $errores errores - revisar arriba" -ForegroundColor Red
    exit 2
}

Write-Host "$exitos archivos procesados correctamente" -ForegroundColor Green
Write-Host ''
Write-Host '=== Smoke test en consola del navegador ===' -ForegroundColor Cyan
Write-Host '  1. Hard reload (Empty Cache and Hard Reload con DevTools abierto)'
Write-Host '  2. En consola pegar:'
Write-Host '     allow pasting'
Write-Host '     Object.keys(AXC_BL.kpis)'
Write-Host '     AXC_BL.kpis.calcularGlobales(acts)'
Write-Host '     AXC_BL.kpis.calcularPorResidente(acts)'
Write-Host '     AXC_BL.kpis.calcularDistribucionEstados(acts)'
Write-Host ''
Write-Host 'Para revertir: copiar los .pre_modulo9.bak sobre los originales' -ForegroundColor DarkGray
