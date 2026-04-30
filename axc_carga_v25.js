/* ============================================================
 * AXC Carga - Adaptación al modelo v2.5 (Commit A.4)
 * v2.5.3-cargaA4
 * ============================================================
 * COMMIT A.4 — Fixes y mejoras UX:
 *   1. FIX: detección dinámica de columnas (no más índices fijos).
 *      Ahora funciona con 1, 2, 3 semanas — busca Estado/Razones/
 *      Criticidad por SELECTOR del select original, no por índice.
 *
 *   2. NUEVA: Input Actividad se expande al focus (~400px),
 *      vuelve a su tamaño original al perder focus.
 *
 *   3. NUEVA: Tooltip en Actividad (muestra texto completo al hover).
 *
 * Detección de columnas:
 *   - Estado:     TD con <select.sel-e> O <span.estado-chip-v25>
 *   - Razones:    TD con <select.sel-r>
 *   - Criticidad: TD con <select.sel-crit>
 *   - Días atraso: TD inmediatamente ANTES de Criticidad
 *   - (Las demás columnas — Inicio, Fin, Días — quedan intactas)
 * ============================================================ */
(function () {
    'use strict';

    if (window.AXC_CARGA_V25 && window.AXC_CARGA_V25._v >= '2.5.3-cargaA4') return;

    var COLOR_ESTADO = {
        '':                    { bg: 'rgba(139,148,158,0.10)', border: 'rgba(139,148,158,0.40)', color: '#8b949e', icon: '○' },
        'sin_empezar':         { bg: 'rgba(139,148,158,0.10)', border: 'rgba(139,148,158,0.40)', color: '#8b949e', icon: '○' },
        'en_proceso':          { bg: 'rgba(56,139,253,0.10)',  border: 'rgba(56,139,253,0.40)',  color: '#388bfd', icon: '⏳' },
        'terminado':           { bg: 'rgba(63,185,80,0.10)',   border: 'rgba(63,185,80,0.40)',   color: '#3fb950', icon: '✓' },
        'cumplido_con_atraso': { bg: 'rgba(210,153,34,0.10)',  border: 'rgba(210,153,34,0.40)',  color: '#d29922', icon: '⚠' },
        'retrasado':           { bg: 'rgba(248,81,73,0.10)',   border: 'rgba(248,81,73,0.40)',   color: '#f85149', icon: '⚠' },
        'cancelado':           { bg: 'rgba(110,118,129,0.10)', border: 'rgba(110,118,129,0.40)', color: '#6e7681', icon: '✕' }
    };

    var ETIQUETAS_OVERRIDE = {
        '': 'Sin actividad',
        'sin_empezar': 'Sin actividad'
    };

    function _getEtiqueta(estado) {
        if (Object.prototype.hasOwnProperty.call(ETIQUETAS_OVERRIDE, estado)) {
            return ETIQUETAS_OVERRIDE[estado];
        }
        if (window.AXC_BL && AXC_BL.ETIQUETAS_ESTADO && AXC_BL.ETIQUETAS_ESTADO[estado]) {
            return AXC_BL.ETIQUETAS_ESTADO[estado];
        }
        return estado || 'Sin actividad';
    }

    function _calcularEstado(act) {
        if (!window.AXC_BL || typeof AXC_BL.calcularEstadoAutomatico !== 'function') return '';
        try { return AXC_BL.calcularEstadoAutomatico(act) || ''; }
        catch (e) { return ''; }
    }

    function _calcularDiasAtraso(act) {
        if (act && typeof act.dias_atraso_calculado === 'number') {
            return act.dias_atraso_calculado;
        }
        if (!act || !Array.isArray(act.days)) return 0;
        var extra = 0;
        act.days.forEach(function (d) {
            if (!d) return;
            if (d.cumple === 'extra_cumplio' || d.cumple === 'extra_no_cumplio') extra++;
        });
        return extra;
    }

    function _renderChipEstado(estado) {
        var c = COLOR_ESTADO[estado] || COLOR_ESTADO[''];
        var label = _getEtiqueta(estado);
        return '<span class="estado-chip-v25" ' +
               'style="display:inline-flex;align-items:center;gap:4px;' +
               'padding:3px 8px;border-radius:6px;font-size:11px;font-weight:600;' +
               'background:' + c.bg + ';border:1px solid ' + c.border + ';color:' + c.color + ';' +
               'font-family:DM Mono,monospace;white-space:nowrap;width:100%;justify-content:center;" ' +
               'title="Estado calculado automaticamente desde el cumplimiento diario">' +
               '<span style="font-size:12px">' + c.icon + '</span> ' +
               '<span>' + label + '</span>' +
               '</span>';
    }

    function _renderDiasAtraso(atraso) {
        if (!atraso || atraso === 0) {
            return '<span style="color:var(--text3);font-size:11px;padding:0 6px">0</span>';
        }
        var color = atraso >= 3 ? '#f85149' : '#d29922';
        return '<span style="color:' + color + ';font-size:11px;padding:0 6px;font-weight:700" ' +
               'title="Dias extra ejecutados fuera del plan original">' + atraso + 'd</span>';
    }

    function _findActFromRow(tr) {
        try {
            var acts = new Function('try{return typeof acts!=="undefined"?acts:[]}catch(e){return[]}')();
            var idx = [].indexOf.call(tr.parentElement.children, tr);
            if (idx >= 0 && idx < acts.length) return acts[idx];
        } catch (e) { }
        return null;
    }

    // --- Detección dinámica de columnas ---
    function _detectarColumnas(tr) {
        var tds = tr.querySelectorAll('td');
        var result = {
            tdEstado: null,
            tdRazones: null,
            tdCriticidad: null,
            tdAtraso: null,
            idxCriticidad: -1
        };

        for (var i = 0; i < tds.length; i++) {
            var td = tds[i];

            // Estado: el que tiene select.sel-e original O el chip ya aplicado
            if (!result.tdEstado && (td.querySelector('select.sel-e') || td.querySelector('.estado-chip-v25'))) {
                result.tdEstado = td;
            }

            if (!result.tdRazones && td.querySelector('select.sel-r')) {
                result.tdRazones = td;
            }

            if (!result.tdCriticidad && td.querySelector('select.sel-crit')) {
                result.tdCriticidad = td;
                result.idxCriticidad = i;
            }
        }

        // Días atraso = TD inmediatamente ANTES de Criticidad
        if (result.idxCriticidad > 0) {
            result.tdAtraso = tds[result.idxCriticidad - 1];
        }

        return result;
    }

    function _procesarFila(tr) {
        if (!tr) return;
        var act = _findActFromRow(tr);
        if (!act) return;

        var cols = _detectarColumnas(tr);
        var estado = _calcularEstado(act);
        var atraso = _calcularDiasAtraso(act);

        // Estado: reemplazar select.sel-e por chip (idempotente)
        if (cols.tdEstado) {
            var hasChip = cols.tdEstado.querySelector('.estado-chip-v25');
            var hasSelect = cols.tdEstado.querySelector('select.sel-e');
            if (hasSelect || !hasChip) {
                cols.tdEstado.innerHTML = _renderChipEstado(estado);
                cols.tdEstado.style.padding = '2px 6px';
            }
        }

        // Días atraso (verificar que NO sea Razones, Estado, ni un día)
        if (cols.tdAtraso) {
            var esRazones = cols.tdAtraso === cols.tdRazones;
            var esEstado = cols.tdAtraso === cols.tdEstado;
            var esDia = cols.tdAtraso.querySelector('.db');
            if (!esRazones && !esEstado && !esDia) {
                cols.tdAtraso.innerHTML = _renderDiasAtraso(atraso);
            }
        }

        // NO TOCAR Razones

        tr.dataset.axcV25Processed = '1';
    }

    function _procesarTabla() {
        var tbl = document.getElementById('tbl');
        if (!tbl) return;
        tbl.querySelectorAll('tbody tr').forEach(_procesarFila);
        _aplicarComportamientoActividad();
    }

    // --- Actividad expandible al focus ---
    function _aplicarComportamientoActividad() {
        var inputs = document.querySelectorAll('#tbl tbody tr input.inp[placeholder*="escripci"]');
        inputs.forEach(function (inp) {
            if (inp.dataset.axcExpandible === '1') return;
            inp.dataset.axcExpandible = '1';

            var actualizarTitle = function () {
                inp.title = inp.value || 'Sin descripcion';
            };
            actualizarTitle();
            inp.addEventListener('input', actualizarTitle);

            inp.addEventListener('focus', function () {
                inp.dataset.axcOriginalWidth = inp.style.width || '';
                inp.dataset.axcOriginalZ = inp.style.zIndex || '';
                inp.style.position = 'relative';
                inp.style.zIndex = '50';
                inp.style.width = '400px';
                inp.style.minWidth = '400px';
                inp.style.transition = 'width 0.15s ease, min-width 0.15s ease';
                inp.style.boxShadow = '0 4px 12px rgba(0,0,0,0.4)';
            });

            inp.addEventListener('blur', function () {
                inp.style.width = inp.dataset.axcOriginalWidth || '';
                inp.style.minWidth = '';
                inp.style.zIndex = inp.dataset.axcOriginalZ || '';
                inp.style.position = '';
                inp.style.boxShadow = '';
            });
        });
    }

    function _instalarObserver() {
        var tbl = document.getElementById('tbl');
        if (!tbl) return false;
        var tbody = tbl.querySelector('tbody');
        if (!tbody) return false;

        _procesarTabla();

        var observer = new MutationObserver(function () {
            clearTimeout(window._axcCargaV25Timeout);
            window._axcCargaV25Timeout = setTimeout(_procesarTabla, 100);
        });
        observer.observe(tbody, { childList: true, subtree: true, attributes: false });

        console.info('[AXC_CARGA_V25] observer instalado en #tbl tbody');
        return true;
    }

    function _actualizarBadgeVersion() {
        var badges = document.querySelectorAll('[class*="version" i], .badge, [data-version]');
        badges.forEach(function (b) {
            var t = (b.textContent || '').trim();
            if (t === 'v1.0' || t === 'V1.0' || t === '1.0') {
                b.textContent = 'v2.5';
                b.title = 'Versión 2.5 — Baseline congelada y cumplimiento día a día';
            }
        });
    }

    function init() {
        if (!window.AXC_BL || typeof AXC_BL.calcularEstadoAutomatico !== 'function') {
            var attempts = 0;
            var retry = setInterval(function () {
                attempts++;
                if (window.AXC_BL && typeof AXC_BL.calcularEstadoAutomatico === 'function') {
                    clearInterval(retry);
                    init();
                } else if (attempts > 40) {
                    clearInterval(retry);
                    console.warn('[AXC_CARGA_V25] timeout esperando AXC_BL');
                }
            }, 250);
            return;
        }

        if (!_instalarObserver()) {
            var attempts2 = 0;
            var retry2 = setInterval(function () {
                attempts2++;
                if (_instalarObserver()) {
                    clearInterval(retry2);
                } else if (attempts2 > 40) {
                    clearInterval(retry2);
                    console.warn('[AXC_CARGA_V25] timeout esperando #tbl');
                }
            }, 250);
        }
        _actualizarBadgeVersion();
    }

    window.AXC_CARGA_V25 = {
        procesarTabla: _procesarTabla,
        forzarReproceso: _procesarTabla,
        calcularEstado: _calcularEstado,
        calcularAtraso: _calcularDiasAtraso,
        detectarColumnas: _detectarColumnas,
        _v: '2.5.3-cargaA4'
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        setTimeout(init, 100);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_CARGA_V25] cargado v' + window.AXC_CARGA_V25._v);
    }
})();
