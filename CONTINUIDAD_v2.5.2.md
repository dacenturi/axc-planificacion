# AXC Planificación — Estado v2.5.2 (Fase 4.5 completa)

**Fecha de cierre:** 29 de abril de 2026
**Cliente:** AXC Constructora (Paraguay)
**Desarrollado por:** Conexdata — Pablo Daniel Centurión
**Branch activa:** `Feature/baseline-v2.5`
**Carpeta:** `C:\AXC`
**URL producción:** https://dacenturi.github.io/axc-planificacion/

---

## Resumen ejecutivo

La versión v2.5.2 añade dos funcionalidades clave sobre la baseline v2.5.1:

1. **Bug fix campos v2.5 en Reporte Global** (Fase 4.5.a) — los KPIs de Cumple/No cumple/% Cumplimiento ahora muestran datos reales en lugar de 0, gracias a una query enriquecedora que trae los 5 campos del modelo v2.5 que el mapeo original omitía.

2. **Curva S Planificado vs Real** (Fase 4.5.b) — gráfico en Reporte Global y Panel TV que compara el avance planificado según baselines confirmadas vs el avance real ejecutado, día a día.

---

## Commits acumulados (branch `Feature/baseline-v2.5`)

| Hash | Mensaje |
|---|---|
| `48bc707` | feat: etapa 1 integracion visual residente |
| `10320b4` | feat: etapas 2 y 5 integracion visual residente |
| `52fc72d` | feat: etapas 3 y 4 integracion visual residente |
| `8cd3c76` | feat: replicacion completa fase 3 al contratista |
| `a9b68d5` | feat: fase 4 pasos 1-3 — modulo 9 KPIs + reporte interno residente y contratista v2.5 |
| `58d09b3` | feat: fase 4 paso 4 — reporte global adaptado a modelo v2.5 |
| `14595fe` | feat: fase 4 paso 5 — panel TV adaptado a modelo v2.5 con tasa baselines |
| **(este)** | **feat: fase 4.5 — fix campos v2.5 + Curva S en Reporte Global y Panel TV** |

---

## Archivos JS modulares en `C:\AXC`

| Archivo | Versión | Propósito |
|---|---|---|
| `axc_bl_modulo9_kpis.js` | 2.5.1 | 11 funciones agregación + ESTADOS_V25 + ESTADOS_ATRASO + cargarMapaResidentes |
| `axc_reporte_residente.js` | 2.5.1 | UI Reporte interno (residente y contratista) con KPIs + donut + Top 5 |
| `axc_reporte_global_v25.js` | 2.5.1-paso4 | Parche que reemplaza `_isOK`/`_isFAIL` y hookea `renderTable` para chips |
| `axc_dashboard_tv_v25.js` | 2.5.1-paso5 | Parche TV: aplica módulo 9 + transforma kpi-prox → Tasa Baselines |
| **`axc_reporte_global_fix_v25.js`** | **2.5.1-paso4.5b** | **Fix Fase 4.5.a: enriquece `_allActs` con campos v2.5** |
| **`axc_curva_s.js`** | **2.5.2-paso4.5b** | **Módulo: `calcularCurvaS()` + `renderCurvaS()` con Chart.js** |
| **`axc_global_curvas.js`** | **2.5.2-paso4.5b3** | **Integrador Curva S en Reporte Global (dash-card)** |
| **`axc_tv_curvas.js`** | **2.5.2-paso4.5b-tv2** | **Integrador Curva S en Panel TV (full width)** |

## HTMLs modificados

| Archivo | Modificaciones |
|---|---|
| `axc_residente.html` | módulo 9 + reporte residente |
| `axc_contratista.html` | módulo 9 + reporte residente |
| `axc_reporte_global.html` | paso 4 + fix 4.5.a + curva S |
| `axc_dashboard_tv.html` | paso 5 + curva S TV (full width) |

---

## Decisiones técnicas Fase 4.5

### 4.5.a — Bug fix campos v2.5 en Reporte Global

**Síntoma:** los KPIs Cumple, No Cumple y % Cumplimiento mostraban 0 en el Reporte Global, aunque la DB tenía 88 baselines confirmadas.

**Causa raíz:** el mapeo `window._allActs = (data||[]).map(r => ({...}))` en `axc_reporte_global.html` solo proyecta 17 campos del registro de DB, omitiendo los 5 campos del modelo v2.5: `baseline_confirmada`, `cumplimiento_pct`, `fecha_fin_plan`, `dias_atraso_calculado`, `dias_planificados_baseline`. Por eso `_isOK`/`_isFAIL` de paso 4 siempre devolvían 0.

**Solución:** patch externo (`axc_reporte_global_fix_v25.js`) que:
1. Hookea `applyFilters()` para detectar el momento en que `_allActs` está cargado.
2. Hace una segunda query a Supabase trayendo solo `id` + 5 campos v2.5.
3. Mergea los datos en memoria (mutación in-place).
4. Llama al `applyFilters` original (`__axcFixV25Original`) para forzar re-render con los datos completos.

**Helper crítico** `_getSB()`: maneja 3 fallbacks para obtener la instancia de Supabase, ya que `_SB` no está en `window` pero `window.supabase` sí (descubrimiento de la sesión).

### 4.5.b — Curva S

**Definición canónica:**
- Solo considera `acts.filter(a => a.baseline_confirmada === true)`.
- Itera día por día desde `min(fecha_inicio)` hasta `max(fecha_fin_plan)`.
- Para cada actividad, suma 1 al **planificado** si `days[i].plan === true`.
- Para cada actividad, suma 1 al **real** si `days[i].cumple === 'cumple'`.
- Acumula y normaliza al 100% del total planificado.

**Output:**
```js
{
  labels: ['19/03', '20/03', ...],
  fechas: [Date, ...],
  planificado: [0, 5, 12, ...],     // unidades dia/persona acumuladas
  real: [0, 3, 9, ...],
  planificadoPct: [0, 8, 20, ...],  // % vs total planificado
  realPct: [0, 5, 15, ...],
  totalDiasPlanificado: 156,
  totalDiasReal: 106,
  pctAvanceTotal: 68,                // pct real total
  vacio: false
}
```

**Decisiones de granularidad:**
- **Por días** (no semanas): line chart suave con detalle.
- **Filtradas (respeta sidebar)**: la curva refleja los filtros aplicados.
- **Solo baseline confirmada**: implícito (sin baseline no hay plan).

**Visual:**
- Reporte Global: nuevo `<div class="dash-card dash-card-wide">` hermano del card de "Cumplimiento en el tiempo". Canvas con `max-height:280px`.
- Panel TV: nuevo `<div class="card" style="grid-column:1 / span 2">` (full width en grid de 2 columnas) al final de `.charts`. Badge muestra `"X% real (-Y vs plan)"`.

---

## Datos demo cargados en DB

**157 actividades totales** (37 originales + 120 demos):
- 87 con baseline_confirmada (72.5% del total).
- 50 contratista + 107 residente (con prefijo `(DEMO)` para limpieza fácil).
- Distribución de estados: ~36 Sin asignar, ~25 En proceso, ~30 Terminado, ~15 Retrasado, ~10 En espera, ~10 Cumplido con atraso.
- Concentradas en últimas 6 semanas (19/03 → ~02/05).

**Cleanup cuando termines pruebas:**
```sql
DELETE FROM actividades WHERE descripcion LIKE '(DEMO)%';
```

---

## Items pendientes (post Fase 4.5)

| Prioridad | Item | Descripción |
|---|---|---|
| Baja | Curva S en Reporte interno | Decisión: NO replicar (residente ve sus actividades, no necesita curva global) |
| Media | Sincronización filtros Carga ↔ Reporte | Paso 2d archivado, pendiente revisar |
| Media | Filtros expandidos en Carga (Fase 3.5) | Contratista/Residente/Sector — modelo de datos a definir |
| Alta | Manual de usuario v2.3 → v2.5.x (Fase 5) | Documentación |
| Alta | Merge `Feature/baseline-v2.5` → `main` (Fase 6) | Despliegue final a GitHub Pages |
| Cleanup | Borrar 120 datos demo | Cuando termine pruebas |
| Mejora | Multi-residente para admin | Sistema ya tiene `_axcEsAdmin` pero sin elaborar UI |

---

## Recordatorios técnicos clave

### Acceso a variables locales del HTML

- En `axc_residente.html` y `axc_contratista.html`: `acts` es `let`, no está en window. Acceder con:
  ```js
  new Function('try{return typeof acts!=="undefined"?acts:[]}catch(e){return[]}')()
  ```

- En `axc_reporte_global.html` y `axc_dashboard_tv.html`: `_SB` también es scope local. Pero `window.supabase` SÍ está. Helper `_getSB()` con 3 fallbacks (window.supabase → window._SB → eval).

### Patrón de parches

- Scripts PowerShell idempotentes con marcadores HTML únicos por paso/fase.
- **Backups** automáticos `.pre_<fase>.bak` antes de cada inyección.
- Estrategia de override: redefinir funciones globales (`_isOK`, `_isFAIL`, `applyFilters`, `renderKPIs`, `renderDashboard`) para auto-adaptar el comportamiento sin tocar el código original.

### Bugs comunes

- Charts se expanden a 12000+ px si no están dentro de `.dash-card` o `.card` con altura controlada (`max-height:280px` en canvas).
- El throttle de `enriquecerAllActs` puede bloquear llamadas legítimas — eliminado en v4.5b.
- **Empty Cache and Hard Reload** obligatorio tras cada cambio (Ctrl+Shift+Delete + Ctrl+Shift+R).
- NO pegar JS multilínea en consola PowerShell (errores frecuentes con backticks). Usar archivos .ps1 o `here-strings`.

### Schema DB (tabla `actividades`)

26 campos, 19 NOT NULL. Constraints CHECK críticos:
- `app IN ('contratista','residente')`
- `cumple IN ('','Sí','No','En proceso','Terminado','Cumplido con atraso','En espera','Retrasado','Cancelado')`
- `criticidad IN ('','Alta','Media','Baja')`
- `chk_baseline_coherencia` (relaciones entre baseline_confirmada y los _calculados)

---

## Validación final del estado

Métricas observadas en última sesión (157 actividades demo):

| Indicador | Valor |
|---|---|
| Total actividades | 157 |
| Con baseline confirmada | 87-88 (varía por filtros) |
| % Cumplimiento (Contratista) | 72% |
| Tasa Baselines | 46% |
| Curva S — Total días planificado | 156 |
| Curva S — Total días real | 106 |
| Curva S — % avance | **68%** |
| Curva S — Gap vs plan | **-32 puntos** |

---

## Para retomar en otra sesión

1. **Verificar estado del repo:**
   ```bash
   cd C:\AXC
   git status
   git log --oneline -10
   ```

2. **Confirmar branch activa:** `Feature/baseline-v2.5`.

3. **Probar versiones de los módulos** abriendo cualquier HTML y revisando consola:
   ```
   [AXC_BL.kpis] modulo 9 cargado v2.5.1
   [AXC_REPORTE_GLOBAL] cargado v2.5.1-paso4
   [AXC_GLOBAL_FIX_V25] cargado v2.5.1-paso4.5b
   [AXC_CurvaS] cargado v2.5.2-paso4.5b
   [AXC_GLOBAL_CURVAS] cargado v2.5.2-paso4.5b3
   [AXC_TV_V25] cargado v2.5.1-paso5
   [AXC_TV_CURVAS] cargado v2.5.2-paso4.5b-tv2
   ```

4. **Próximo trabajo natural:** Fase 5 (manual usuario) o Fase 6 (merge a main + deploy).

---

*Documento generado al cierre de sesión 29/04/2026 — Fase 4.5 completa.*
