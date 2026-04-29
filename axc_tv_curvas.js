/* ============================================================
 * AXC Panel TV - Integrador Curva S (Fase 4.5.b TV)
 * v2.5.2-paso4.5b-tv2
 * ============================================================
 * Inserta un septimo card "Curva S" en la grilla del Panel TV
 * ocupando el ANCHO COMPLETO (full width, span 2 columnas).
 * Hookea renderKPIs() para redibujar al actualizarse los datos.
 *
 * v2: agregado style="grid-column:1 / span 2" para full width
 *     en el grid de 2 columnas del TV.
 *
 * Requiere: AXC_BL.charts.renderCurvaS (axc_curva_s.js)
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_TV_CURVAS && window.AXC_TV_CURVAS._v >= '2.5.2-paso4.5b-tv2') return;

    function _insertarCardCurvaS() {
        if (document.getElementById('ch-curva-s')) return true;

        var charts = document.querySelector('.charts');
        if (!charts) {
            var trend = document.getElementById('ch-trend');
            charts = trend && trend.closest('.charts');
        }
        if (!charts) {
            console.warn('[AXC_TV_CURVAS] no se encontro contenedor .charts');
            return false;
        }

        // Full width: span 2 columnas en el grid del TV
        var html =
            '<div class="card" id="card-curva-s" style="grid-column:1 / span 2">' +
                '<div class="card-title">' +
                    '<h3>📈 Curva S · Planificado vs Real</h3>' +
                    '<span class="badge" id="badge-curva-s">— %</span>' +
                '</div>' +
                '<div class="card-body">' +
                    '<canvas id="ch-curva-s" class="chart-canvas"></canvas>' +
                '</div>' +
            '</div>';

        charts.insertAdjacentHTML('beforeend', html);
        return true;
    }

    function _renderCurvaS() {
        var acts = window._allActs || [];
        if (!window.AXC_BL || !AXC_BL.charts || !AXC_BL.charts.renderCurvaS) {
            console.warn('[AXC_TV_CURVAS] AXC_BL.charts.renderCurvaS no disponible');
            return;
        }
        var data = AXC_BL.charts.renderCurvaS('ch-curva-s', acts);
        if (data && !data.vacio) {
            var badge = document.getElementById('badge-curva-s');
            if (badge) {
                var gap = data.totalDiasPlanificado > 0
                    ? Math.round((data.totalDiasPlanificado - data.totalDiasReal) / data.totalDiasPlanificado * 100)
                    : 0;
                badge.textContent = data.pctAvanceTotal + '% real (' + (gap > 0 ? '-' + gap : '+0') + ' vs plan)';
            }
        }
    }

    function _hookRenderKPIs() {
        if (typeof window.renderKPIs !== 'function') return false;
        if (window.renderKPIs.__axcTvCurvasHooked) return true;

        var orig = window.renderKPIs;
        var hooked = function (arr) {
            var r = orig.apply(this, arguments);
            try {
                _insertarCardCurvaS();
                _renderCurvaS();
            } catch (e) {
                console.warn('[AXC_TV_CURVAS] excepcion en render:', e);
            }
            return r;
        };
        hooked.__axcTvCurvasHooked = true;
        window.renderKPIs = hooked;
        console.info('[AXC_TV_CURVAS] hook a renderKPIs instalado');
        return true;
    }

    function init() {
        if (!_insertarCardCurvaS()) return;
        _hookRenderKPIs();
        setTimeout(_renderCurvaS, 200);
    }

    window.AXC_TV_CURVAS = {
        render: _renderCurvaS,
        insertarCard: _insertarCardCurvaS,
        _v: '2.5.2-paso4.5b-tv2'
    };

    function _ready() {
        return document.querySelector('.charts') &&
               typeof window.renderKPIs === 'function' &&
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
                console.warn('[AXC_TV_CURVAS] timeout esperando dependencias');
            }
        }, 250);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_TV_CURVAS] cargado v' + window.AXC_TV_CURVAS._v);
    }
})();
