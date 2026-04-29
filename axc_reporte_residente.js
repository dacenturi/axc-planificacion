/* ============================================================
 * AXC_REPORTE - Reporte interno v2.5 (residente) - paso 2e
 * ============================================================
 * v2.5.1-paso2e
 *
 * IGUAL AL PASO 2b PERO SIN BARRA DE FILTROS DESDE/HASTA.
 * El filtro vive en Carga (window._filtroObras) y este reporte
 * por ahora muestra TODAS las actividades (decision: solo paso2b
 * sin tocar la integracion con Carga - eso queda para mas adelante).
 *
 * UI:
 *   - 6 KPI cards (Total / Con baseline / Cumplimiento /
 *     Atraso prom / Atrasadas / Tasa baselines)
 *   - Donut Chart.js de distribucion de estados
 *   - Top 5 retrasadas con click-to-navigate a Carga
 *
 * Dependencias: AXC_BL.kpis v2.5.1+, Chart.js (en <head>)
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_REPORTE && window.AXC_REPORTE._v >= '2.5.1-paso2e') return;

    var HTML_TEMPLATE =
        '<div class="sec-head">' +
            '<div class="sec-title">📊 Reporte de actividades <small id="rpt-sub" style="color:#888;font-weight:normal"></small></div>' +
        '</div>' +
        '<div class="kpi-grid-v25">' +
            '<div class="kpi kpi-total"><div class="kpi-l">Total actividades</div><div class="kpi-v" id="kv-total">-</div></div>' +
            '<div class="kpi kpi-baseline"><div class="kpi-l">Con baseline</div><div class="kpi-v" id="kv-baseline">-</div></div>' +
            '<div class="kpi kpi-cumpl"><div class="kpi-l">Cumplimiento</div><div class="kpi-v" id="kv-cumpl">-</div></div>' +
            '<div class="kpi kpi-atraso"><div class="kpi-l">Atraso prom</div><div class="kpi-v" id="kv-atraso-prom">-</div></div>' +
            '<div class="kpi kpi-atrasadas"><div class="kpi-l">Atrasadas</div><div class="kpi-v" id="kv-atrasadas">-</div></div>' +
            '<div class="kpi kpi-tasa"><div class="kpi-l">Tasa baselines</div><div class="kpi-v" id="kv-tasa-bl">-</div></div>' +
        '</div>' +
        '<div class="rpt-bloque">' +
            '<div class="rpt-card-v25">' +
                '<h3>Distribución de estados</h3>' +
                '<div class="rpt-canvas-wrap"><canvas id="rpt-chart-estados"></canvas></div>' +
            '</div>' +
            '<div class="rpt-card-v25">' +
                '<h3>Top 5 retrasadas</h3>' +
                '<div id="rpt-top5"></div>' +
            '</div>' +
        '</div>';

    var CSS_TEMPLATE =
        '.kpi-grid-v25{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:14px;margin-top:8px}' +
        '@media(max-width:1100px){.kpi-grid-v25{grid-template-columns:repeat(3,1fr)}}' +
        '@media(max-width:620px){.kpi-grid-v25{grid-template-columns:repeat(2,1fr)}}' +
        '.kpi-grid-v25 .kpi{padding:10px 12px;border-radius:6px;background:#fff;border:1px solid #e5e7eb;border-left:3px solid #9ca3af}' +
        '.kpi-grid-v25 .kpi-l{font-size:11px;color:#666;margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}' +
        '.kpi-grid-v25 .kpi-v{font-size:22px;font-weight:700;color:#222;font-family:"DM Mono",monospace}' +
        '.kpi-grid-v25 .kpi-total{border-left-color:#3b82f6}' +
        '.kpi-grid-v25 .kpi-baseline{border-left-color:#8b5cf6}' +
        '.kpi-grid-v25 .kpi-cumpl{border-left-color:#10b981}' +
        '.kpi-grid-v25 .kpi-atraso{border-left-color:#f59e0b}' +
        '.kpi-grid-v25 .kpi-atrasadas{border-left-color:#ef4444}' +
        '.kpi-grid-v25 .kpi-tasa{border-left-color:#C8A028}' +
        '.rpt-bloque{display:grid;grid-template-columns:1fr 1fr;gap:14px}' +
        '@media(max-width:900px){.rpt-bloque{grid-template-columns:1fr}}' +
        '.rpt-card-v25{background:#fff;border:1px solid #e5e7eb;border-radius:6px;padding:14px}' +
        '.rpt-card-v25 h3{margin:0 0 10px 0;font-size:13px;color:#333;text-transform:uppercase;letter-spacing:.5px}' +
        '.rpt-canvas-wrap{position:relative;height:280px}' +
        '.rpt-empty{padding:50px 20px;text-align:center;color:#888;font-size:14px}' +
        '.rpt-top5-table{width:100%;border-collapse:collapse}' +
        '.rpt-top5-table th{font-size:11px;color:#666;padding:6px 8px;border-bottom:1px solid #e5e7eb;text-align:left;text-transform:uppercase;letter-spacing:.3px}' +
        '.rpt-top5-table td{padding:8px;font-size:13px;border-bottom:1px solid #f5f5f5}' +
        '.rpt-top5-row{cursor:pointer;transition:background .12s}' +
        '.rpt-top5-row:hover{background:#fffbeb}' +
        '.chip-danger{background:#fee;color:#c00;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:600;font-family:"DM Mono",monospace}' +
        '.rpt-target-highlight{outline:2px solid #f59e0b!important;outline-offset:2px;transition:outline .3s}';

    // ---------- Acceso a `acts` (let en script principal) ----------
    var _readActs = new Function(
        'try { return typeof acts !== "undefined" && Array.isArray(acts) ? acts : []; } catch(e) { return []; }'
    );
    function _getActs() {
        try { return _readActs() || []; }
        catch (e) { return []; }
    }

    // ---------- Estado interno ----------
    var _mapaResidentes = null;
    var _chartEstados = null;
    var _htmlInjected = false;
    var _cssInjected = false;

    // ---------- Helpers ----------
    function _escapeHtml(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function _injectCSS() {
        if (_cssInjected) return;
        var st = document.createElement('style');
        st.id = 'axc-reporte-styles';
        st.textContent = CSS_TEMPLATE;
        document.head.appendChild(st);
        _cssInjected = true;
    }

    function _injectHTML() {
        if (_htmlInjected) return;
        var page = document.getElementById('page-reporte');
        if (!page) {
            console.warn('[AXC_REPORTE] no se encontro #page-reporte');
            return;
        }
        page.innerHTML = HTML_TEMPLATE;
        _htmlInjected = true;
    }

    function _setText(id, valor) {
        var el = document.getElementById(id);
        if (el) el.textContent = valor;
    }

    function _actualizarSubtitulo(total) {
        var sub = document.getElementById('rpt-sub');
        if (sub) sub.textContent = '· ' + total + ' actividades';
    }

    // ---------- Render ----------
    function _renderDonut(dist) {
        var ctx = document.getElementById('rpt-chart-estados');
        if (!ctx || typeof Chart === 'undefined') return;
        var labels = AXC_BL.kpis.ESTADOS_V25;
        var data = labels.map(function (l) { return dist[l] || 0; });
        var colorMap = {
            'Sin asignar': '#9ca3af', 'En proceso': '#3b82f6', 'Terminado': '#10b981',
            'Cumplido con atraso': '#f59e0b', 'Retrasado': '#ef4444',
            'En espera': '#a855f7', 'Cancelado': '#374151'
        };
        var bgColors = labels.map(function (l) { return colorMap[l] || '#999'; });

        if (_chartEstados) {
            _chartEstados.data.datasets[0].data = data;
            _chartEstados.update();
            return;
        }
        _chartEstados = new Chart(ctx, {
            type: 'doughnut',
            data: { labels: labels, datasets: [{ data: data, backgroundColor: bgColors, borderWidth: 1, borderColor: '#fff' }] },
            options: {
                responsive: true, maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'right', labels: { font: { size: 11 }, boxWidth: 14, padding: 8 } },
                    tooltip: {
                        callbacks: {
                            label: function (ctx) {
                                var total = ctx.dataset.data.reduce(function (a, b) { return a + b; }, 0);
                                var pct = total ? ((ctx.parsed / total) * 100).toFixed(1) : '0';
                                return ctx.label + ': ' + ctx.parsed + ' (' + pct + '%)';
                            }
                        }
                    }
                },
                cutout: '60%'
            }
        });
    }

    function _renderTop5(top5) {
        var container = document.getElementById('rpt-top5');
        if (!container) return;
        if (!top5 || top5.length === 0) {
            container.innerHTML = '<div class="rpt-empty">🎉 Sin actividades retrasadas</div>';
            return;
        }
        var rows = top5.map(function (a, i) {
            var desc = a.descripcion || a.item || '(sin descripción)';
            var obra = a.obra_row || a.obra || '';
            var dias = a.dias_atraso || 0;
            return '<tr class="rpt-top5-row" data-act-id="' + _escapeHtml(a.id) + '">' +
                '<td>' + (i + 1) + '</td>' +
                '<td>' + _escapeHtml(desc) + '</td>' +
                '<td style="text-align:center"><span class="chip-danger">' + dias + 'd</span></td>' +
                '<td>' + _escapeHtml(obra) + '</td>' +
            '</tr>';
        }).join('');
        container.innerHTML =
            '<table class="rpt-top5-table">' +
                '<thead><tr><th style="width:30px">#</th><th>Actividad</th><th style="width:60px;text-align:center">Atraso</th><th style="width:30%">Obra</th></tr></thead>' +
                '<tbody>' + rows + '</tbody>' +
            '</table>';

        container.querySelectorAll('.rpt-top5-row').forEach(function (tr) {
            tr.addEventListener('click', function () {
                _navegarAActividad(tr.getAttribute('data-act-id'));
            });
        });
    }

    function _navegarAActividad(actId) {
        if (typeof window.showPage !== 'function') return;
        window.showPage('carga');
        setTimeout(function () {
            var sel = ['[data-act-id="' + actId + '"]', '[data-id="' + actId + '"]', 'tr[id="row-' + actId + '"]'];
            var row = null;
            for (var i = 0; i < sel.length && !row; i++) row = document.querySelector(sel[i]);
            if (!row) {
                console.info('[AXC_REPORTE] no se encontro fila para act ' + actId);
                return;
            }
            row.scrollIntoView({ behavior: 'smooth', block: 'center' });
            row.classList.add('rpt-target-highlight');
            setTimeout(function () { row.classList.remove('rpt-target-highlight'); }, 2500);
        }, 350);
    }

    // ---------- API publica ----------
    function render() {
        if (!_htmlInjected) _injectHTML();
        if (!window.AXC_BL || !AXC_BL.kpis) {
            console.warn('[AXC_REPORTE] AXC_BL.kpis no disponible');
            return;
        }
        var acts = _getActs();
        var k = AXC_BL.kpis.calcularGlobales(acts);

        _setText('kv-total', k.totalActividades);
        _setText('kv-baseline', k.actividadesConBaseline + '/' + k.totalActividades);
        _setText('kv-cumpl', k.cumplimientoPromedio + '%');
        _setText('kv-atraso-prom', k.diasAtrasoPromedio + 'd');
        _setText('kv-atrasadas', k.actividadesAtrasadas);
        _setText('kv-tasa-bl', k.tasaBaselines.pctConfirmadas + '%');

        _actualizarSubtitulo(acts.length);
        _renderDonut(k.distribucionEstados);
        _renderTop5(AXC_BL.kpis.obtenerTopRetrasadas(acts, 5));
    }

    function init() {
        _injectCSS();
        _injectHTML();
        if (!_mapaResidentes && window._SB && window.AXC_BL && AXC_BL.kpis && AXC_BL.kpis.cargarMapaResidentes) {
            return AXC_BL.kpis.cargarMapaResidentes(window._SB)
                .then(function (mapa) { _mapaResidentes = mapa || {}; })
                .catch(function (e) { console.warn('[AXC_REPORTE] cargarMapaResidentes:', e); });
        }
        return Promise.resolve();
    }

    function onShowPage() {
        return Promise.resolve(init()).then(render);
    }

    window.AXC_REPORTE = {
        init: init,
        render: render,
        onShowPage: onShowPage,
        _v: '2.5.1-paso2e',
        _getActs: _getActs
    };

    // ---------- Hook a showPage ----------
    (function () {
        function _hook(orig) {
            var patched = function (name) {
                var r = orig.apply(this, arguments);
                if (name === 'reporte') {
                    try { onShowPage(); }
                    catch (e) { console.error('[AXC_REPORTE] onShowPage error:', e); }
                }
                return r;
            };
            patched.__axcPatched = true;
            window.showPage = patched;
        }

        if (typeof window.showPage === 'function' && !window.showPage.__axcPatched) {
            _hook(window.showPage);
        } else if (typeof window.showPage !== 'function') {
            var attempts = 0;
            var retry = setInterval(function () {
                attempts++;
                if (typeof window.showPage === 'function' && !window.showPage.__axcPatched) {
                    _hook(window.showPage);
                    clearInterval(retry);
                } else if (attempts > 20) {
                    clearInterval(retry);
                }
            }, 200);
        }
    })();

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_REPORTE] cargado v' + window.AXC_REPORTE._v);
    }
})();
