/* ============================================================
 * AXC Reporte Global - Adaptacion al modelo v2.5
 * v2.5.1-paso4
 * ============================================================
 * PARCHE MINIMAMENTE INVASIVO sobre axc_reporte_global.html.
 *
 * Estrategia: redefinir las funciones globales _isOK y _isFAIL
 * para que usen la logica v2.5. Esto autoadapta:
 *   - renderKPIs (kpi-total, kpi-ok, kpi-fail, kpi-pct)
 *   - renderGauge (Cumplimiento General)
 *   - cualquier otra funcion que use _isOK/_isFAIL
 *
 * Adicionalmente:
 *   - Hook a renderTable para reescribir columna Estado (idx 8)
 *     con estados v2.5 + chips de color
 *
 * NO TOCA:
 *   - HTML legacy
 *   - Sidebar de filtros
 *   - Charts (siguen usando _filteredActs)
 *   - Layout, colores, vistas
 *
 * Dependencias: AXC_BL.kpis v2.5.1+ (modulo 9)
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_REPORTE_GLOBAL && window.AXC_REPORTE_GLOBAL._v >= '2.5.1-paso4') return;

    // ---------- Estados v2.5 ----------
    var ESTADOS_ATRASO = ['Retrasado', 'Cumplido con atraso'];

    function _estadoDe(act) {
        if (window.AXC_BL && typeof AXC_BL.calcularEstadoAutomatico === 'function') {
            return AXC_BL.calcularEstadoAutomatico(act) || 'Sin asignar';
        }
        if (!act.baseline_confirmada) return 'Sin asignar';
        return act.cumple || 'En proceso';
    }

    function _claseEstado(estado) {
        var map = {
            'Sin asignar': 'na', 'En proceso': 'pending', 'Terminado': 'ok',
            'Cumplido con atraso': 'late', 'Retrasado': 'fail',
            'En espera': 'wait', 'Cancelado': 'na'
        };
        return map[estado] || 'pending';
    }

    function _iconoEstado(estado) {
        var map = {
            'Sin asignar': '—', 'En proceso': '⏳', 'Terminado': '✓',
            'Cumplido con atraso': '⚠', 'Retrasado': '⚠',
            'En espera': '⏸', 'Cancelado': '⊘'
        };
        return map[estado] || '·';
    }

    function _escapeHtml(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    // ---------- CSS para chips de estado (compatible tema oscuro) ----------
    function _injectCSS() {
        if (document.getElementById('axc-global-v25-styles')) return;
        var st = document.createElement('style');
        st.id = 'axc-global-v25-styles';
        st.textContent =
            '.rpt-est-v25{display:inline-block;padding:2px 10px;border-radius:10px;font-size:11px;font-weight:600;font-family:"DM Mono",monospace;white-space:nowrap}' +
            '.rpt-est-v25.rpt-est-ok{background:rgba(16,185,129,0.18);color:#10b981}' +
            '.rpt-est-v25.rpt-est-pending{background:rgba(59,130,246,0.18);color:#3b82f6}' +
            '.rpt-est-v25.rpt-est-fail{background:rgba(239,68,68,0.20);color:#ef4444}' +
            '.rpt-est-v25.rpt-est-late{background:rgba(245,158,11,0.18);color:#f59e0b}' +
            '.rpt-est-v25.rpt-est-wait{background:rgba(168,85,247,0.18);color:#a855f7}' +
            '.rpt-est-v25.rpt-est-na{background:rgba(156,163,175,0.18);color:#9ca3af}';
        document.head.appendChild(st);
    }

    // ---------- Reemplazar _isOK / _isFAIL ----------
    // Estos son los pivotes: KPIs + Gauge usan estas funciones
    // Reemplazandolos, ambos quedan adaptados a v2.5 automaticamente
    function _patch_isOK_isFAIL() {
        // Backup originales por si hace falta debuggear
        if (typeof window._isOK === 'function' && !window._isOK.__axcV25Patched) {
            window._isOK_legacy = window._isOK;
            window._isOK = function (a) {
                if (!a) return false;
                return a.baseline_confirmada === true && a.cumplimiento_pct === 100;
            };
            window._isOK.__axcV25Patched = true;
        }
        if (typeof window._isFAIL === 'function' && !window._isFAIL.__axcV25Patched) {
            window._isFAIL_legacy = window._isFAIL;
            window._isFAIL = function (a) {
                if (!a) return false;
                return _estadoDe(a) === 'Retrasado';
            };
            window._isFAIL.__axcV25Patched = true;
        }
    }

    // ---------- Hook a renderTable para reescribir columna Estado ----------
    function _patch_renderTable() {
        if (typeof window.renderTable !== 'function' || window.renderTable.__axcV25Patched) return;
        var orig = window.renderTable;
        var patched = function () {
            var r = orig.apply(this, arguments);
            try { _adaptarColumnaEstado(); }
            catch (e) { console.warn('[AXC_GLOBAL_V25] adaptar columna Estado:', e); }
            return r;
        };
        patched.__axcV25Patched = true;
        window.renderTable = patched;
    }

    function _adaptarColumnaEstado() {
        var tbody = document.getElementById('tbody');
        if (!tbody) return;
        var acts = window._filteredActs || [];
        var rows = tbody.querySelectorAll('tr');
        if (rows.length !== acts.length) return; // tabla vacia o desincronizada

        for (var i = 0; i < rows.length; i++) {
            var act = acts[i];
            var celdas = rows[i].querySelectorAll('td');
            if (celdas.length < 9) continue; // headers: 0=#, 1=Residente, 2=Obra, 3=Contratista, 4=Sector, 5=Actividad, 6=Inicio, 7=Fin, 8=Estado, 9=Razon, 10=Criticidad, 11=Modo
            var estado = _estadoDe(act);
            var cls = _claseEstado(estado);
            var ico = _iconoEstado(estado);
            celdas[8].innerHTML = '<span class="rpt-est-v25 rpt-est-' + cls + '">' + ico + ' ' + _escapeHtml(estado) + '</span>';
        }
    }

    // ---------- Re-render forzado para reflejar adaptaciones ----------
    function _refrescar() {
        try {
            if (typeof window.renderKPIs === 'function') window.renderKPIs();
            if (typeof window.renderGauge === 'function') window.renderGauge(window._filteredActs || []);
            if (typeof window.renderTable === 'function') window.renderTable();
        } catch (e) {
            console.warn('[AXC_GLOBAL_V25] refrescar:', e);
        }
    }

    // ---------- Init ----------
    function init() {
        if (!window.AXC_BL || !AXC_BL.kpis) {
            console.warn('[AXC_GLOBAL_V25] AXC_BL.kpis no disponible - aplicar primero modulo 9');
            return;
        }
        _injectCSS();
        _patch_isOK_isFAIL();
        _patch_renderTable();
        _refrescar();
    }

    window.AXC_REPORTE_GLOBAL = {
        init: init,
        refrescar: _refrescar,
        _adaptarColumnaEstado: _adaptarColumnaEstado,
        _estadoDe: _estadoDe,
        _v: '2.5.1-paso4'
    };

    // Esperar a que las funciones globales esten disponibles antes de hookear
    if (typeof window._isOK === 'function' && typeof window._isFAIL === 'function' && typeof window.renderTable === 'function') {
        init();
    } else {
        var attempts = 0;
        var retry = setInterval(function () {
            attempts++;
            var ready = typeof window._isOK === 'function'
                     && typeof window._isFAIL === 'function'
                     && typeof window.renderTable === 'function';
            if (ready) {
                init();
                clearInterval(retry);
            } else if (attempts > 30) {
                clearInterval(retry);
                console.warn('[AXC_GLOBAL_V25] timeout esperando funciones globales (_isOK/_isFAIL/renderTable)');
            }
        }, 200);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_REPORTE_GLOBAL] cargado v' + window.AXC_REPORTE_GLOBAL._v);
    }
})();
