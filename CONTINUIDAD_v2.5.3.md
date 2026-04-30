# 📋 AXC v2.5.3 — Continuidad

> **Fecha de cierre:** 29-30/04/2026
> **Branch:** `Feature/baseline-v2.5`
> **Última sesión:** Fase 5 (Pestaña Carga) — Commits A y B completados
> **Estado producción:** https://dacenturi.github.io/axc-planificacion/ — A y B desplegados via push

---

## 🎯 Resumen ejecutivo

Esta sesión avanzó la **Fase 5 (Pestaña Carga)** con dos commits exitosos (A, B) y descubrió un **bug crítico preexistente de modelo de datos (errores 403)** que afecta tanto local como producción.

| Hito | Estado |
|---|---|
| Migración SQL legacy → oficial | ✅ DB limpia (`'cumple'` → `'cumplio'`, etc.) |
| **Commit A** estado v2.5 + columnas dinámicas + Actividad expandible | ✅ Pusheado (`adaec0a`) |
| **Commit B** render visual 7 estados de días + tooltips | ⏳ A commitear al cerrar la sesión |
| Bug 403 RLS de Supabase | ⚠️ Diagnosticado, no resuelto. **Próxima sesión** |
| Commit C (botón Guardar + Opción C confirmar) | ⏳ Bloqueado por bug 403 |
| Replicar A+B+C a contratista | ⏳ Pendiente |

---

## ✅ Commit A — `adaec0a` (pusheado)

**Mensaje:** `feat(carga): commit A - estado v2.5 read-only + columnas dinamicas + actividad expandible`

### Cambios

| Cambio | Detalle |
|---|---|
| Reemplazo del `<select.sel-e>` por **chip de Estado read-only** | Calculado desde `AXC_BL.calcularEstadoAutomatico(act)` |
| **Detección dinámica de columnas** | Usa selectores (`select.sel-e`, `select.sel-r`, `select.sel-crit`) en lugar de índices fijos. Funciona con 1, 2, 3+ semanas |
| **Actividad expandible al focus** | Click expande input a 400px con sombra. Blur lo vuelve al original |
| **Tooltip permanente en Actividad** | Hover muestra texto completo |
| **Etiquetas amigables** | `'(vacio)'` y `'sin_empezar'` → "Sin actividad" |
| **Días atraso** lee `act.dias_atraso_calculado` (DB) | Fallback usa valores oficiales |

### Archivos commiteados

- `axc_residente.html` (modificado, marcadores `<!-- AXC_CARGA_V25 Commit A -->`)
- `axc_carga_v25.js` (v2.5.3-cargaA4)
- `aplicar_carga_v25_a.ps1`, `_a1`, `_a2`, `_a4`

### Iteraciones (4 versiones para llegar al final)

| Versión | Cambio principal |
|---|---|
| A | Versión inicial con función custom `_calcularEstadoV25` |
| A.1 | Fix offset que pisaba "Razones" con "%" |
| A.2 | Refactor: usa `AXC_BL.calcularEstadoAutomatico` directamente |
| A.3 | Override etiquetas '(vacio)'/'sin_empezar' → "Sin actividad" |
| **A.4** | **Detección dinámica de columnas** (resolvió bug crítico con tablas de 2 semanas) + Actividad expandible + tooltip |

### Bug crítico descubierto y resuelto en A.4

El A.3 asumía índices fijos (`TD[12]=Estado, TD[14]=Días atraso`). Pero en residente con 2 semanas (8 días), los índices se corren:
- TD[12] era **Inicio**, no Estado
- TD[14] era **Estado**, no Días atraso

El A.4 usa **selectores** (`select.sel-e`, `select.sel-r`, `select.sel-crit`) y derive Días atraso = `idxCriticidad - 1`. Funciona con cualquier cantidad de semanas.

---

## ✅ Commit B — `axc_carga_v25_b.js v2.5.3-cargaB`

**Mensaje:** `feat(carga): commit B - render visual 7 estados dias + tooltips`

### Cambios

Render visual diferenciado para los 7 estados oficiales de `days[i].cumple`:

| Estado | Color de fondo | Color texto | Símbolo | Tooltip |
|---|---|---|---|---|
| `plan` | naranja `rgba(240,165,0,0.30)` | naranja | (vacío) | "L 27/4 — Planificado" |
| `cumplio` | verde `rgba(63,185,80,0.30)` | verde | OK | "L 27/4 — Cumplió" |
| `no_cumplio` | rojo `rgba(248,81,73,0.30)` | rojo | ✗ | "L 27/4 — No cumplió" |
| `no_aplica` | gris `rgba(139,148,158,0.20)` | gris | N/A | "L 27/4 — No aplica" |
| `extra_cumplio` | azul `rgba(56,139,253,0.30)` | azul | + | "L 27/4 — Día extra cumplido" |
| `extra_no_cumplio` | rojo oscuro `rgba(180,40,40,0.45)` | rojo claro | +✗ | "L 27/4 — Día extra no cumplido" |
| `sin_marcar` | sin fondo | gris | · | "L 27/4 — Sin marcar" |

### Mecanismo

- **Observer separado del A**: escucha `attributes: ['title', 'style']` con debounce 80ms
- **Guard `dataset.axcEstadoRendered`** evita reprocesar la misma celda
- **NO toca el handler `onclick`** — `AXC_BL.clickearCelda()` cicla los 7 estados
- **Helpers `_parseTitle` y `_generarTitle`** parsean DD/MM/YYYY → "L 27/4 — Estado"

### Validación visual exitosa

| Métrica | Valor en residente Arq. Patricia |
|---|---|
| Versión | `2.5.3-cargaB` |
| Verdes (`cumplio`) | 37 de 120 días |
| Rojos (`no_cumplio`) | 0 (no hay días no cumplidos en este residente) |
| Naranjas (`plan`) | 1 día planificado sin marcar |
| Sin renderear | 81 (días sin valor `cumple`) |

### Archivos a commitear (al cierre de sesión)

- `axc_residente.html` (modificado con bloque `<!-- AXC_CARGA_V25_B Commit B -->`)
- `axc_carga_v25_b.js`
- `aplicar_carga_v25_b.ps1`

---

## 🚨 Bug crítico pendiente — Errores 403 / RLS Supabase

### Síntoma

Banner rojo en producción y local: **"Error guardando en la nube — Los cambios no se están guardando en la nube"**

Console:
```
POST https://zvucnezwhgfgupasgqnd.supabase.co/rest/v1/actividades?on_conflict=id&columns=...
403 (Forbidden)

Sync Supabase error: {code: '42501', details: null, hint: null,
  message: 'new row violates row-level security policy for table "actividades"'}
```

### Causa raíz identificada

**El frontend (axc_residente.html) NO envía campos NOT NULL requeridos por DB:**

| Campo en DB | NOT NULL? | El frontend envía? |
|---|---|---|
| `user_id` | NOT NULL | ❌ NO (envía `_ownerUid` con guion bajo, prefijo metadata) |
| `app` | NOT NULL | ❌ NO |
| `modo` | NOT NULL | ❌ NO (campo ya no se usa según usuario, default `'unica'`) |
| `obra` | NOT NULL | ❌ NO (envía `obra_row` con sufijo) |
| `contratista` | NOT NULL | ❌ NO |
| `residente` | NOT NULL | ❌ NO |
| `orden` | NOT NULL | ❌ NO |
| `dias_atraso_calculado` | NOT NULL | ❌ NO |

### Confirmaciones importantes

| Hecho | Implicación |
|---|---|
| **Bug ES preexistente al Commit A** | NO lo introdujimos en esta sesión |
| **Bug afecta producción y local** | Verificado en https://dacenturi.github.io/axc-planificacion/ con usuario Ing. Albert |
| Los **datos en DB están bien** | Las 157 actividades existentes tienen todos los campos correctos |
| Las **4 actividades reales en DB** se crearon por SQL directo | El frontend nunca persistió cambios reales |
| Los chips, tooltips, render visual **funcionan en memoria** | Pero el sync a Supabase falla 403 |

### Qué está pendiente diagnosticar (próxima sesión)

```sql
-- Query 1: ver valores reales de app/modo en producción
SELECT app, modo, COUNT(*) as cantidad
FROM actividades
GROUP BY app, modo
ORDER BY cantidad DESC;

-- Query 2: ver una actividad real (no DEMO) completa para usar de plantilla
SELECT * FROM actividades WHERE descripcion NOT LIKE '(DEMO)%' LIMIT 1;

-- Query 3: ver políticas RLS (qué chequea exactamente)
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr,
       pg_get_expr(polwithcheck, polrelid) AS with_check_expr
FROM pg_policy
WHERE polrelid = 'actividades'::regclass;

-- Query 4: ver triggers (¿hay un BEFORE INSERT que llene campos?)
SELECT tgname, tgenabled, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'actividades'::regclass AND NOT tgisinternal;
```

### Plan tentativo de fix (Opción A — parche frontend)

1. Hookear `_syncActsToSupabase` para mapear el payload antes del POST:
   - `_ownerUid` → `user_id`
   - `obra_row` → `obra`
   - Agregar campos NOT NULL faltantes con defaults:
     - `app: 'residente'` (o `'contratista'` según página)
     - `modo: 'unica'` (constante por ahora — campo legacy no usado)
     - `contratista: ''` (vacío en página residente)
     - `residente: <selección del header>`
     - `orden: <índice de fila>`
     - `dias_atraso_calculado: act.dias_atraso || 0`
2. Validar con UNA fila primero antes de sync masivo
3. Si funciona → seguir con Commit C

---

## 🔧 Migración SQL ejecutada esta sesión (DB limpia)

### Contexto

DB tenía mismatch masivo de valores legacy en `days[*].cumple`:
- Demo: 73 acts con `'cumple'` (legacy) afectando 359 días
- Datos reales: ya estaban con valores oficiales `'cumplio'`

`AXC_BL.calcularEstadoAutomatico()` no reconoce `'cumple'` (legacy) y devuelve vacío. Por eso el chip de Estado mostraba siempre "Sin empezar" para las 73 demos.

### Mapeo aplicado

```
'cumple'           → 'cumplio'
'no_cumple'        → 'no_cumplio'
'na'               → 'no_aplica'
'extra_cumple'     → 'extra_cumplio'
'extra_no_cumple'  → 'extra_no_cumplio'
('plan' y 'sin_marcar' sin cambios — ya oficiales)
```

### SQL ejecutado (en Supabase Dashboard)

1. **Backup:** `CREATE TABLE actividades_backup_legacy_29abr` con 74 filas afectadas
2. **UPDATE:** usando `jsonb_array_elements` con CASE para mapear (la regex string falló porque jsonb reordena keys; solución usa `EXISTS + jsonb_array_elements`)
3. **Verificación:** 0 filas con valores legacy restantes ✅
4. **Distribución final:** solo valores oficiales (cumplio:362, no_cumplio:9, no_aplica:2, plan:6+1, sin_marcar:11)

⚠️ **IMPORTANTE:** la tabla `actividades_backup_legacy_29abr` sigue existiendo. Si todo está OK en producción, se puede dropear: `DROP TABLE actividades_backup_legacy_29abr;`

---

## 📐 Decisiones tomadas (válidas para C y futuras)

| Decisión | Detalle |
|---|---|
| **Confirmación de planificación** | **Opción C**: residente confirma con regla de fecha (función `AXC_BL.puedeConfirmarResidente()` ya existe) |
| **% Cumpl en Carga** | **NO** mostrar (solo en Reporte) |
| **Click en celda de día** | Cicla los 7 estados (handler ya implementado, no tocar) |
| **Tooltip de celdas** | Explícito: "L 27/4 — Cumplió" |
| **Días pasados** | Editables sin restricción de fecha |
| **Etiqueta '(vacio)' / 'sin_empezar'** | Override → "Sin actividad" |
| **Input Actividad** | Expandible al focus a 400px + tooltip permanente |
| **Botón Guardar (Commit C)** | **Explícito** (NO auto-guardar). Banner + borde rojo en campos faltantes |
| **Click en días si fila incompleta** | NO permitir (mostrar warning "Complete Obra y Actividad primero") |
| **Validar al apretar Guardar** | Bloquear filas incompletas, marcar en rojo, NO enviar a DB |
| **Campo `modo`** | Ya no se usa. Default `'unica'` constante en parche futuro (NO eliminar columna por ahora) |

---

## 📋 Plan próxima sesión

### Prioridad 1 (CRÍTICA): Resolver bug 403

| Paso | Acción |
|---|---|
| 1 | Ejecutar las 4 queries SQL diagnósticas |
| 2 | Confirmar valores correctos para `app`, `modo`, `contratista`, `residente` |
| 3 | Verificar si hay triggers BEFORE INSERT que llenen campos automáticamente |
| 4 | Si NO hay triggers → parche frontend que mapee payload |
| 5 | Validar sync funciona (POST 200 OK) con UNA fila primero |
| 6 | Aplicar a contratista también |

### Prioridad 2: Commit C (después del fix 403)

| Tarea | Detalle |
|---|---|
| 1 | Identificar/crear botón "Guardar" en UI (no existe actualmente) |
| 2 | Bloquear auto-guardado existente (reemplazar `save` por versión que solo guarda al click) |
| 3 | Validar antes de guardar: marcar filas con obra/actividad vacíos en rojo |
| 4 | "Guardar (X válidas, Y incompletas)" — solo enviar las válidas |
| 5 | NO permitir click en días si fila no tiene Obra/Actividad |
| 6 | Botón "🔒 Confirmar planificación" + "Confirmar todas las visibles" |
| 7 | Bloqueo de campos básicos post-confirmación |
| 8 | Indicador visual BORRADOR vs EN EJECUCIÓN |
| 9 | Implementar Opción C: residente confirma con regla de fecha |

### Prioridad 3: Replicar a contratista

`axc_contratista.html`: aplicar A.4 + B + C (mismo código JS, ya hay precedente de Fase 3).

### Limpieza pendiente (opcional)

- `DROP TABLE actividades_backup_legacy_29abr` (si todo OK en prod)
- Eliminar columna `modo` (si se confirma que no se usa en ningún lado)

---

## 🔑 Recordatorios técnicos clave

### Acceso a scope local del HTML

```javascript
// acts es scope local en HTML, acceder vía:
const acts = new Function('try{return typeof acts!=="undefined"?acts:[]}catch(e){return[]}')();

// _SB y _SB.auth accesibles vía new Function similar
```

### API de AXC_BL (no inventar)

- `AXC_BL.calcularEstadoAutomatico(act)` ya implementa los 7 estados oficiales — usar directamente
- `AXC_BL.ETIQUETAS_ESTADO` mapea estado → label oficial
- `AXC_BL.ESTADOS_CUMPLE` valores: `'plan'`, `'cumplio'`, `'no_cumplio'`, `'no_aplica'`, `'sin_marcar'`, `'extra_cumplio'`, `'extra_no_cumplio'`
- `AXC_BL.clickearCelda(actId, idx)` cicla los 7 estados al click (ya implementado, NO tocar)
- `AXC_BL.puedeConfirmarResidente()` existe (necesario para Opción C)

### Detección de columnas dinámica (no asumir índices)

```javascript
// 17 vs 19 TDs en fila depende de cuántas semanas tiene la planificación
//   1 sem → 17 TDs
//   2 sem → 19+ TDs
// Detección por selector:
//   Estado:     <select.sel-e> O <span.estado-chip-v25>
//   Razones:    <select.sel-r>
//   Criticidad: <select.sel-crit>
//   Días atraso: TD justo antes de Criticidad
```

### Funciones de guardado existentes

| Función | Estado |
|---|---|
| `window.save` | function (entry point) |
| `window.save_orig` | function (versión original sin parches) |
| `window._syncActsToSupabase` | function (la que falla con 403) |
| `window._updateValidationUI` | function (validación visual de campos rojos) |

NO hay botón Guardar en UI actual — todo es auto-save.

### Las RLS rechazan con `42501`

Cuando `user_id` no se envía o no matchea `auth.uid()` → 403 + `42501`. Otros campos NOT NULL faltantes también pueden causar errores similares.

---

## 📦 Commits acumulados al cierre

```
8cd3c76 — feat: replicacion completa fase 3 al contratista
a9b68d5 — feat: fase 4 pasos 1-3 - modulo 9 KPIs + reporte interno residente y contratista v2.5
58d09b3 — feat: fase 4 paso 4 - reporte global adaptado a modelo v2.5
14595fe — feat: fase 4 paso 5 - panel TV adaptado a modelo v2.5 con tasa baselines
a4c20a3 — feat: fase 4.5 - fix campos v2.5 + Curva S full width Reporte Global y Panel TV
cee5b90 — fix: layout TV balanceado - Curva S compacta + grid-auto-rows minmax 220px
adaec0a — feat(carga): commit A - estado v2.5 read-only + columnas dinamicas + actividad expandible
[PENDIENTE — al cerrar la sesión: Commit B]
[BLOQUEADO por bug 403: Commit C]
```

---

## 📁 Archivos en C:\AXC al cierre

| Archivo | Estado en repo |
|---|---|
| `axc_residente.html` | ✅ Modificado con A y B (B sin commit todavía) |
| `axc_carga_v25.js` (v2.5.3-cargaA4) | ✅ Commiteado |
| `axc_carga_v25_b.js` (v2.5.3-cargaB) | ⏳ Sin commit |
| `aplicar_carga_v25_a.ps1`, `_a1`, `_a2`, `_a4`.ps1 | ✅ Commiteados |
| `aplicar_carga_v25_b.ps1` | ⏳ Sin commit |
| `axc_contratista.html` | ⏳ NO modificado todavía |
| `axc_contratista_pre_fase3.html`, `axc_residente_pre_fase3.html` | Backups locales (no commiteados) |
| `cleanup_demo_fase4.sql`, `datos_demo_fase4.sql` | SQL viejos locales (no commiteados) |

---

## 🚀 Comando para retomar próxima sesión

```powershell
cd C:\AXC
git status                           # Ver estado actual
git log --oneline -5                 # Ver últimos commits
git pull                             # Asegurar estar al día con remoto
```

Si el branch quedó desincronizado, hacer:
```powershell
git fetch
git checkout Feature/baseline-v2.5
git pull
```

Luego abrir el residente y validar que A y B funcionan visualmente (chips de estado en su columna, días con colores, Actividad expandible).

Y arrancar con las **4 queries SQL diagnósticas del bug 403** documentadas arriba.

---

**Fin del documento de continuidad v2.5.3.**
