/* ============================================================
 * AXC Reporte Global - Integrador Curva S (Fase 4.5.b)
 * v2.5.2-paso4.5b3
 * ============================================================
 * Inserta el wrap del chart Curva S en el Reporte Global como
 * un dash-card hermano del de Cumplimiento en el tiempo.
 * Hookea renderDashboard() para que se redibuje al cambiar filtros.
 *
 * v3: Insertar como dash-card dash-card-wide hermano del padre
 * de wrap-tiempo, con altura forzada al canvas para no expandirse.
 *
 * Requiere: AXC_BL.charts.renderCurvaS (axc_curva_s.js)
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_GLOBAL_CURVAS && window.AXC_GLOBAL_CURVAS._v >= '2.5.2-paso4.5b3') return;

    function _insertarWrapCurvaS() {
        // Si ya existe el card de Curva S, no duplicar
        if (document.getElementById('wrap-curvas')) return true;

        // Encontrar el dash-card que contiene wrap-tiempo
        var wt = document.getElementById('wrap-tiempo');
        if (!wt) {
            console.warn('[AXC_GLOBAL_CURVAS] no se encontro wrap-tiempo');
            return false;
        }
        var dashCardTiempo = wt.closest('.dash-card');
        if (!dashCardTiempo) {
            console.warn('[AXC_GLOBAL_CURVAS] wrap-tiempo no esta dentro de un dash-card');
            return false;
        }

        var html =
            '<div class="dash-card dash-card-wide">' +
                '<div class="dash-card-title">📈 Curva S — Planificado vs Real' +
                    '<button type="button" class="info-icon" tabindex="0" aria-label="Explicacion del calculo" data-tip="Compara el avance planificado segun baselines confirmadas vs el avance real ejecutado, dia a dia. Solo considera actividades con baseline confirmada. La diferencia entre ambas lineas indica adelanto o atraso global del proyecto.">ⓘ</button>' +
                '</div>' +
                '<div class="chart-wrap tall" id="wrap-curvas">' +
                    '<canvas id="chartCurvaS" style="max-height:280px"></canvas>' +
                '</div>' +
            '</div>';

        dashCardTiempo.insertAdjacentHTML('afterend', html);
        return true;
    }

    function _renderCurvaS() {
        var acts = window._filteredActs || [];
        if (typeof AXC_BL === 'undefined' || !AXC_BL.charts || !AXC_BL.charts.renderCurvaS) {
            console.warn('[AXC_GLOBAL_CURVAS] AXC_BL.charts.renderCurvaS no disponible');
            return;
        }
        AXC_BL.charts.renderCurvaS('chartCurvaS', acts);
    }

    function _hookRenderDashboard() {
        if (typeof window.renderDashboard !== 'function') return false;
        if (window.renderDashboard.__axcCurvasHooked) return true;

        var orig = window.renderDashboard;
        var hooked = function () {
            var r = orig.apply(this, arguments);
            try {
                // Asegurar que el wrap existe (puede haber sido removido en algun re-render)
                _insertarWrapCurvaS();
                _renderCurvaS();
            }
            catch (e) { console.warn('[AXC_GLOBAL_CURVAS] excepcion en render:', e); }
            return r;
        };
        hooked.__axcCurvasHooked = true;
        window.renderDashboard = hooked;
        console.info('[AXC_GLOBAL_CURVAS] hook a renderDashboard instalado');
        return true;
    }

    function init() {
        if (!_insertarWrapCurvaS()) return;
        _hookRenderDashboard();
        setTimeout(_renderCurvaS, 200);
    }

    window.AXC_GLOBAL_CURVAS = {
        render: _renderCurvaS,
        insertarWrap: _insertarWrapCurvaS,
        _v: '2.5.2-paso4.5b3'
    };

    function _ready() {
        return document.getElementById('wrap-tiempo') &&
               typeof window.renderDashboard === 'function' &&
               window.AXC_BL && AXC_BL.charts && AXC_BL.charts.renderCurvaS;
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
            } else if (attempts > 40) {
                clearInterval(retry);
                console.warn('[AXC_GLOBAL_CURVAS] timeout esperando dependencias');
            }
        }, 250);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_GLOBAL_CURVAS] cargado v' + window.AXC_GLOBAL_CURVAS._v);
    }
})();
