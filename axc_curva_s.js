/* ============================================================
 * AXC Curva S - Planificado vs Real (Fase 4.5.b)
 * v2.5.2-paso4.5b
 * ============================================================
 * Agrega al modulo 9 una funcion pura calcularCurvaS(acts) que
 * devuelve series temporales acumuladas (planificado vs real).
 *
 * Tambien expone renderChartCurvaS(canvasId, acts, opts) que
 * dibuja el chart con Chart.js.
 *
 * Granularidad: por dias.
 * Filtra automaticamente actividades con baseline_confirmada=true
 * (sin baseline no hay plan vs real).
 *
 * Uso desde HTML:
 *   const curva = AXC_BL.kpis.calcularCurvaS(acts);
 *   AXC_BL.charts.renderCurvaS('chartCurvaS', acts);
 * ============================================================ */
(function () {
    'use strict';

    if (!window.AXC_BL || !window.AXC_BL.kpis) {
        console.warn('[AXC_CurvaS] modulo 9 no esta cargado, esperando...');
        return;
    }

    // ---------- Helpers ----------
    function _parseFecha(s) {
        if (!s) return null;
        if (s instanceof Date) return s;
        // 'YYYY-MM-DD' o 'YYYY-MM-DDTHH:MM:SS...'
        var d = new Date(s + (s.length === 10 ? 'T00:00:00' : ''));
        return isNaN(d.getTime()) ? null : d;
    }

    function _diasEntre(d1, d2) {
        if (!d1 || !d2) return 0;
        return Math.round((d2 - d1) / (1000 * 60 * 60 * 24));
    }

    function _fmtFecha(d) {
        var dd = String(d.getDate()).padStart(2, '0');
        var mm = String(d.getMonth() + 1).padStart(2, '0');
        return dd + '/' + mm;
    }

    // ---------- calcularCurvaS ----------
    /**
     * Calcula la curva S de planificado vs real.
     * Considera SOLO actividades con baseline_confirmada=true.
     *
     * Retorna:
     *   {
     *     labels: ['01/04', '02/04', ...],
     *     fechas: [Date, Date, ...],
     *     planificado: [0, 5, 12, ...],   // unidades dia/persona acumuladas (NO %)
     *     real: [0, 3, 9, ...],           // idem
     *     planificadoPct: [0, 8, 20, ...], // % acumulado vs total
     *     realPct: [0, 5, 15, ...],       // idem
     *     totalDiasPlanificado: 60,
     *     totalDiasReal: 42,
     *     pctAvanceTotal: 70  // pct total cumplido a hoy
     *   }
     */
    function calcularCurvaS(acts) {
        acts = acts || [];
        var conBL = acts.filter(function (a) { return a.baseline_confirmada === true; });
        if (conBL.length === 0) {
            return {
                labels: [], fechas: [], planificado: [], real: [],
                planificadoPct: [], realPct: [],
                totalDiasPlanificado: 0, totalDiasReal: 0, pctAvanceTotal: 0,
                vacio: true
            };
        }

        // 1. Determinar rango de fechas
        var fechaMin = null, fechaMax = null;
        conBL.forEach(function (a) {
            var fi = _parseFecha(a.fecha_inicio);
            var ff = _parseFecha(a.fecha_fin_plan || a.fecha_fin);
            if (fi && (!fechaMin || fi < fechaMin)) fechaMin = fi;
            if (ff && (!fechaMax || ff > fechaMax)) fechaMax = ff;
        });
        if (!fechaMin || !fechaMax) {
            return { labels: [], fechas: [], planificado: [], real: [],
                planificadoPct: [], realPct: [], totalDiasPlanificado: 0,
                totalDiasReal: 0, pctAvanceTotal: 0, vacio: true };
        }

        // 2. Generar array de fechas dia por dia
        var fechas = [];
        var d = new Date(fechaMin);
        while (d <= fechaMax) {
            fechas.push(new Date(d));
            d.setDate(d.getDate() + 1);
        }
        var nDias = fechas.length;

        // 3. Series por dia (planificado y real, NO acumulado todavia)
        var planificadoPorDia = new Array(nDias).fill(0);
        var realPorDia = new Array(nDias).fill(0);

        conBL.forEach(function (a) {
            var fi = _parseFecha(a.fecha_inicio);
            if (!fi) return;
            var idxInicio = _diasEntre(fechaMin, fi);
            var days = Array.isArray(a.days) ? a.days : [];

            for (var i = 0; i < days.length; i++) {
                var idx = idxInicio + i;
                if (idx < 0 || idx >= nDias) continue;

                var entry = days[i];
                var esPlan = false, esReal = false;

                if (typeof entry === 'object' && entry !== null) {
                    esPlan = entry.plan === true;
                    esReal = entry.cumple === 'cumple' || entry.cumple === 'Cumple';
                } else if (entry === true) {
                    // Formato legacy: array de booleans
                    esPlan = true;
                }

                if (esPlan) planificadoPorDia[idx]++;
                if (esReal) realPorDia[idx]++;
            }
        });

        // 4. Acumular
        var planAcum = [], realAcum = [];
        var sumP = 0, sumR = 0;
        for (var i = 0; i < nDias; i++) {
            sumP += planificadoPorDia[i];
            sumR += realPorDia[i];
            planAcum.push(sumP);
            realAcum.push(sumR);
        }

        var totalP = sumP;
        var totalR = sumR;

        // 5. Convertir a porcentajes (vs total planificado al 100%)
        var planPct = planAcum.map(function (v) { return totalP > 0 ? Math.round((v / totalP) * 1000) / 10 : 0; });
        var realPct = realAcum.map(function (v) { return totalP > 0 ? Math.round((v / totalP) * 1000) / 10 : 0; });

        return {
            labels: fechas.map(_fmtFecha),
            fechas: fechas,
            planificado: planAcum,
            real: realAcum,
            planificadoPct: planPct,
            realPct: realPct,
            totalDiasPlanificado: totalP,
            totalDiasReal: totalR,
            pctAvanceTotal: totalP > 0 ? Math.round((totalR / totalP) * 100) : 0,
            vacio: false
        };
    }

    // ---------- renderCurvaS ----------
    var _chartInstancia = null;

    function renderCurvaS(canvasId, acts, opts) {
        opts = opts || {};
        var canvas = document.getElementById(canvasId);
        if (!canvas) {
            console.warn('[AXC_CurvaS] canvas no encontrado:', canvasId);
            return;
        }
        if (typeof Chart === 'undefined') {
            console.warn('[AXC_CurvaS] Chart.js no esta cargado');
            return;
        }

        var data = calcularCurvaS(acts);

        // Destruir chart previo si existe
        if (_chartInstancia) {
            try { _chartInstancia.destroy(); } catch (e) { }
            _chartInstancia = null;
        }

        if (data.vacio) {
            // Mostrar empty state
            var ctx = canvas.getContext('2d');
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#9ca3af';
            ctx.font = '12px monospace';
            ctx.textAlign = 'center';
            ctx.fillText('Sin actividades con baseline confirmada para graficar', canvas.width / 2, canvas.height / 2);
            return data;
        }

        _chartInstancia = new Chart(canvas, {
            type: 'line',
            data: {
                labels: data.labels,
                datasets: [
                    {
                        label: 'Planificado',
                        data: data.planificadoPct,
                        borderColor: '#3b82f6',
                        backgroundColor: 'rgba(59,130,246,0.10)',
                        borderWidth: 2,
                        pointRadius: 0,
                        tension: 0.25,
                        fill: false
                    },
                    {
                        label: 'Real',
                        data: data.realPct,
                        borderColor: '#10b981',
                        backgroundColor: 'rgba(16,185,129,0.10)',
                        borderWidth: 2,
                        pointRadius: 0,
                        tension: 0.25,
                        fill: false
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#cbd5e1', font: { family: 'DM Mono, monospace', size: 11 } }
                    },
                    tooltip: {
                        callbacks: {
                            label: function (ctx) {
                                return ctx.dataset.label + ': ' + ctx.parsed.y + '%';
                            }
                        }
                    },
                    title: {
                        display: !!opts.title,
                        text: opts.title || 'Curva S',
                        color: '#cbd5e1',
                        font: { family: 'DM Mono, monospace', size: 13 }
                    }
                },
                scales: {
                    x: {
                        ticks: {
                            color: '#94a3b8',
                            font: { family: 'DM Mono, monospace', size: 10 },
                            maxRotation: 45,
                            autoSkip: true,
                            maxTicksLimit: 15
                        },
                        grid: { color: 'rgba(148,163,184,0.10)' }
                    },
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            color: '#94a3b8',
                            font: { family: 'DM Mono, monospace', size: 10 },
                            callback: function (v) { return v + '%'; }
                        },
                        grid: { color: 'rgba(148,163,184,0.10)' },
                        title: {
                            display: true,
                            text: '% avance acumulado',
                            color: '#94a3b8',
                            font: { family: 'DM Mono, monospace', size: 10 }
                        }
                    }
                }
            }
        });

        return data;
    }

    // ---------- Exponer en namespace ----------
    AXC_BL.kpis.calcularCurvaS = calcularCurvaS;
    AXC_BL.charts = AXC_BL.charts || {};
    AXC_BL.charts.renderCurvaS = renderCurvaS;
    AXC_BL.charts._curvaS_v = '2.5.2-paso4.5b';

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_CurvaS] cargado v' + AXC_BL.charts._curvaS_v);
    }
})();
