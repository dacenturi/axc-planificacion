/* ============================================================
 * AXC Dashboard TV - Adaptacion al modelo v2.5
 * v2.5.1-paso5
 * ============================================================
 * Parche minimo sobre axc_dashboard_tv.html.
 *
 * Cambios:
 *   1. Reemplaza _isOK / _isFAIL con logica v2.5
 *      -> afecta kpi-cumpl automaticamente
 *   2. Hookea renderKPIs para:
 *      - Reescribir kpi-retr usando estado calculado v2.5
 *      - Reemplazar kpi-prox por "Tasa Baselines"
 *      - Cambiar label visual "Proximas a vencer" -> "Tasa Baselines"
 *   3. NO toca: layout, charts, rotacion, colores
 *
 * Dependencias: AXC_BL.kpis v2.5.1+ (modulo 9)
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_TV_V25 && window.AXC_TV_V25._v >= '2.5.1-paso5') return;

    function _estadoDe(act) {
        if (window.AXC_BL && typeof AXC_BL.calcularEstadoAutomatico === 'function') {
            return AXC_BL.calcularEstadoAutomatico(act) || 'Sin asignar';
        }
        if (!act.baseline_confirmada) return 'Sin asignar';
        return act.cumple || 'En proceso';
    }

    // ---------- Parche _isOK / _isFAIL ----------
    function _patch_isOK_isFAIL() {
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

    // ---------- Cambiar label visual del kpi-prox ----------
    // Buscamos el elemento que tiene texto "Proximas a vencer" y lo cambiamos
    function _cambiarLabelProx() {
        // El sub muestra "Vencen en los proximos 7 dias" y el label arriba dice "Proximas a vencer".
        // Buscar nodos con esos textos.
        var nodos = document.querySelectorAll('*');
        var cambiados = 0;
        for (var i = 0; i < nodos.length; i++) {
            var el = nodos[i];
            if (el.children.length !== 0) continue; // solo nodos hoja
            var t = (el.textContent || '').trim();
            if (/pr[oó]ximas?\s+a\s+vencer/i.test(t) && t.length < 40) {
                el.textContent = 'Tasa Baselines';
                cambiados++;
                if (el.dataset) el.dataset.axcV25Relabel = 'tasa-baselines';
            }
        }
        return cambiados;
    }

    // ---------- Hook a renderKPIs ----------
    function _patch_renderKPIs() {
        if (typeof window.renderKPIs !== 'function' || window.renderKPIs.__axcV25Patched) return;
        var orig = window.renderKPIs;
        var patched = function (arr) {
            var r = orig.apply(this, arguments);
            try { _adaptarKPIs(arr); }
            catch (e) { console.warn('[AXC_TV_V25] adaptar KPIs:', e); }
            return r;
        };
        patched.__axcV25Patched = true;
        window.renderKPIs = patched;
    }

    function _adaptarKPIs(arr) {
        arr = arr || [];

        // 1. Recalcular kpi-retr con estado v2.5 (en lugar de _normalizeCumple)
        var retr = arr.filter(function (a) { return _estadoDe(a) === 'Retrasado'; }).length;
        var total = arr.length;
        var elRetr = document.getElementById('kpi-retr');
        var elRetrSub = document.getElementById('kpi-retr-sub');
        if (elRetr) elRetr.textContent = retr;
        if (elRetrSub) elRetrSub.textContent = total > 0 ? Math.round(retr / total * 100) + '% del total' : '—';

        // 2. Reemplazar kpi-prox por "Tasa Baselines"
        if (window.AXC_BL && AXC_BL.kpis && AXC_BL.kpis.calcularTasaBaselines) {
            var tasa = AXC_BL.kpis.calcularTasaBaselines(arr);
            var elProx = document.getElementById('kpi-prox');
            var elProxSub = document.getElementById('kpi-prox-sub');
            if (elProx) elProx.textContent = tasa.pctConfirmadas + '%';
            if (elProxSub) {
                elProxSub.textContent = tasa.confirmadas + ' de ' + total + ' baselines confirmadas';
            }
        }
    }

    // ---------- Re-render forzado ----------
    function _refrescar() {
        try {
            if (typeof window.renderKPIs === 'function' && window._allActs) {
                window.renderKPIs(window._allActs);
            }
        } catch (e) {
            console.warn('[AXC_TV_V25] refrescar:', e);
        }
    }

    // ---------- Init ----------
    function init() {
        if (!window.AXC_BL || !AXC_BL.kpis) {
            console.warn('[AXC_TV_V25] AXC_BL.kpis no disponible - aplicar primero modulo 9');
            return;
        }
        _patch_isOK_isFAIL();
        _patch_renderKPIs();
        var n = _cambiarLabelProx();
        if (n === 0) {
            // Reintentar tras pequeno delay si no se encontro el label
            setTimeout(_cambiarLabelProx, 500);
            setTimeout(_cambiarLabelProx, 1500);
        }
        _refrescar();
    }

    window.AXC_TV_V25 = {
        init: init,
        refrescar: _refrescar,
        _v: '2.5.1-paso5'
    };

    // Esperar funciones globales antes de hookear
    function _ready() {
        return typeof window._isOK === 'function'
            && typeof window._isFAIL === 'function'
            && typeof window.renderKPIs === 'function';
    }

    if (_ready()) {
        init();
    } else {
        var attempts = 0;
        var retry = setInterval(function () {
            attempts++;
            if (_ready()) {
                init();
                clearInterval(retry);
            } else if (attempts > 30) {
                clearInterval(retry);
                console.warn('[AXC_TV_V25] timeout esperando _isOK/_isFAIL/renderKPIs');
            }
        }, 200);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_TV_V25] cargado v' + window.AXC_TV_V25._v);
    }
})();
