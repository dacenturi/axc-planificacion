/* ============================================================
 * AXC_BL - MODULO 9 - KPIs y Agregaciones v2.5.1
 * ============================================================
 * v2.5.1 - Fixes de schema real:
 *   - Obra: usa `obra_row` con fallback a `obra`
 *   - Residente: agrupa por `_ownerUid` (UUID), opcionalmente
 *     resuelve a nombre via mapa {uuid: nombre} cargado de `perfiles`
 *   - Contratista: filtra `(sin contratista)` cuando no hay campo
 *
 * Funciones puras de agregacion. No leen Supabase salvo el helper
 * cargarMapaResidentes que se invoca explicitamente desde el caller.
 * ============================================================ */
(function () {
    'use strict';

    if (!window.AXC_BL) window.AXC_BL = {};
    // Idempotente: si ya hay version igual o mayor, no recargar
    if (window.AXC_BL.kpis && window.AXC_BL.kpis._version >= '2.5.1') return;

    var ESTADOS_V25 = [
        'Sin asignar', 'En proceso', 'Terminado', 'Cumplido con atraso',
        'Retrasado', 'En espera', 'Cancelado'
    ];
    var ESTADOS_ATRASO = ['Retrasado', 'Cumplido con atraso'];

    // ---------- Helpers internos ----------

    function _round1(n) { return Math.round((n || 0) * 10) / 10; }

    function _estadoDe(act) {
        if (window.AXC_BL && typeof window.AXC_BL.calcularEstadoAutomatico === 'function') {
            return window.AXC_BL.calcularEstadoAutomatico(act) || 'Sin asignar';
        }
        if (!act.baseline_confirmada) return 'Sin asignar';
        return act.cumple || 'En proceso';
    }

    function _getCampoConFallback(act, lista) {
        for (var i = 0; i < lista.length; i++) {
            var v = act[lista[i]];
            if (v !== undefined && v !== null && v !== '') return v;
        }
        return null;
    }

    function _obraDe(act) {
        return _getCampoConFallback(act, ['obra_row', 'obra']) || '(sin obra)';
    }
    function _contratistaDe(act) {
        return _getCampoConFallback(act, ['contratista']) || '(sin contratista)';
    }
    function _residenteDe(act, mapa) {
        var key = _getCampoConFallback(act, ['_ownerUid', 'user_id', 'residente']);
        if (!key) return '(sin residente)';
        if (mapa && mapa[key]) return mapa[key];
        return key;
    }

    function _normalizarDia(d) {
        if (typeof d === 'boolean') return { plan: d, cumple: null };
        return d || { plan: false, cumple: null };
    }

    function _toISODate(date) {
        var y = date.getFullYear();
        var m = String(date.getMonth() + 1).padStart(2, '0');
        var d = String(date.getDate()).padStart(2, '0');
        return y + '-' + m + '-' + d;
    }

    function _isoSemana(date) {
        var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        var weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
        return d.getUTCFullYear() + '-W' + String(weekNo).padStart(2, '0');
    }

    function _agruparConExtractor(actividades, extractor) {
        var grupos = {};
        (actividades || []).forEach(function (act) {
            var k = extractor(act);
            if (!grupos[k]) grupos[k] = [];
            grupos[k].push(act);
        });
        return grupos;
    }

    function _kpisDeGrupo(nombre, acts) {
        var conBL = acts.filter(function (a) { return a.baseline_confirmada; });
        var sumPct = conBL.reduce(function (s, a) { return s + (a.cumplimiento_pct || 0); }, 0);
        var cumpl = conBL.length ? sumPct / conBL.length : 0;

        var atrasadas = acts.filter(function (a) {
            return ESTADOS_ATRASO.indexOf(_estadoDe(a)) !== -1;
        });
        var sumD = atrasadas.reduce(function (s, a) { return s + (a.dias_atraso || 0); }, 0);
        var diasProm = atrasadas.length ? sumD / atrasadas.length : 0;

        return {
            nombre: nombre,
            total: acts.length,
            actividadesConBaseline: conBL.length,
            cumplimientoPct: _round1(cumpl),
            distribucionEstados: calcularDistribucionEstados(acts),
            diasAtrasoPromedio: _round1(diasProm),
            diasAtrasoAcumulado: sumD,
            actividadesAtrasadas: atrasadas.length
        };
    }

    // ---------- Funciones publicas ----------

    function calcularGlobales(actividades) {
        actividades = actividades || [];
        var total = actividades.length;
        var conBL = actividades.filter(function (a) { return a.baseline_confirmada; });
        var sumPct = conBL.reduce(function (s, a) { return s + (a.cumplimiento_pct || 0); }, 0);
        var cumplPromedio = conBL.length ? sumPct / conBL.length : 0;

        var atrasadas = actividades.filter(function (a) {
            return ESTADOS_ATRASO.indexOf(_estadoDe(a)) !== -1;
        });
        var sumDias = atrasadas.reduce(function (s, a) { return s + (a.dias_atraso || 0); }, 0);
        var diasAtrasoPromedio = atrasadas.length ? sumDias / atrasadas.length : 0;

        return {
            totalActividades: total,
            actividadesConBaseline: conBL.length,
            actividadesSinBaseline: total - conBL.length,
            cumplimientoPromedio: _round1(cumplPromedio),
            distribucionEstados: calcularDistribucionEstados(actividades),
            tasaBaselines: calcularTasaBaselines(actividades),
            diasAtrasoPromedio: _round1(diasAtrasoPromedio),
            diasAtrasoAcumulado: sumDias,
            actividadesAtrasadas: atrasadas.length
        };
    }

    function agruparPor(actividades, campo) {
        return _agruparConExtractor(actividades, function (a) {
            var v = a[campo];
            if (v === undefined || v === null || v === '') return '(sin ' + campo + ')';
            return v;
        });
    }

    /**
     * KPIs por residente.
     *   acts: array de actividades
     *   residentesMap: opcional, {uuid: nombre} - si se pasa, el nombre
     *                  del grupo es legible; sino es el UUID
     */
    function calcularPorResidente(actividades, residentesMap) {
        var grupos = _agruparConExtractor(actividades, function (a) {
            return _residenteDe(a, residentesMap);
        });
        return Object.keys(grupos)
            .map(function (k) { return _kpisDeGrupo(k, grupos[k]); })
            .sort(function (a, b) { return b.total - a.total; });
    }

    function calcularPorContratista(actividades) {
        var grupos = _agruparConExtractor(actividades, _contratistaDe);
        var keys = Object.keys(grupos);
        if (keys.length === 1 && keys[0] === '(sin contratista)') return [];
        return keys
            .filter(function (k) { return k !== '(sin contratista)'; })
            .map(function (k) { return _kpisDeGrupo(k, grupos[k]); })
            .sort(function (a, b) { return b.total - a.total; });
    }

    function calcularPorObra(actividades) {
        var grupos = _agruparConExtractor(actividades, _obraDe);
        return Object.keys(grupos)
            .map(function (k) { return _kpisDeGrupo(k, grupos[k]); })
            .sort(function (a, b) { return b.total - a.total; });
    }

    function calcularDistribucionEstados(actividades) {
        actividades = actividades || [];
        var dist = {};
        ESTADOS_V25.forEach(function (e) { dist[e] = 0; });
        actividades.forEach(function (a) {
            var e = _estadoDe(a);
            if (dist[e] === undefined) dist[e] = 0;
            dist[e]++;
        });
        return dist;
    }

    function obtenerTopRetrasadas(actividades, n) {
        actividades = actividades || [];
        n = n || 10;
        return actividades
            .filter(function (a) { return ESTADOS_ATRASO.indexOf(_estadoDe(a)) !== -1; })
            .sort(function (a, b) { return (b.dias_atraso || 0) - (a.dias_atraso || 0); })
            .slice(0, n);
    }

    function filtrarPorRangoFecha(actividades, desde, hasta, modo) {
        actividades = actividades || [];
        modo = modo || 'interseccion';
        if (!desde && !hasta) return actividades.slice();

        var dD = desde ? new Date(desde) : null;
        var dH = hasta ? new Date(hasta) : null;
        if (dH) dH.setHours(23, 59, 59, 999);

        return actividades.filter(function (act) {
            var fI = act.fecha_inicio ? new Date(act.fecha_inicio) : null;
            var fF = act.fecha_fin ? new Date(act.fecha_fin) : null;
            if (modo === 'inicio') {
                if (!fI) return false;
                if (dD && fI < dD) return false;
                if (dH && fI > dH) return false;
                return true;
            }
            if (modo === 'fin') {
                if (!fF) return false;
                if (dD && fF < dD) return false;
                if (dH && fF > dH) return false;
                return true;
            }
            if (!fI || !fF) return false;
            if (dH && fI > dH) return false;
            if (dD && fF < dD) return false;
            return true;
        });
    }

    function calcularSerieTemporal(actividades, granularidad) {
        actividades = actividades || [];
        granularidad = granularidad || 'dia';
        var serie = {};

        actividades
            .filter(function (a) { return a.baseline_confirmada && Array.isArray(a.days) && a.fecha_inicio; })
            .forEach(function (act) {
                var fI = new Date(act.fecha_inicio);
                act.days.forEach(function (raw, idx) {
                    var dia = _normalizarDia(raw);
                    var esExtra = dia.cumple === 'extra_cumple' || dia.cumple === 'extra_no_cumple';
                    if (!dia.plan && !esExtra) return;

                    var fecha = new Date(fI);
                    fecha.setDate(fecha.getDate() + idx);

                    var key;
                    if (granularidad === 'dia') key = _toISODate(fecha);
                    else if (granularidad === 'semana') key = _isoSemana(fecha);
                    else key = _toISODate(fecha).slice(0, 7);

                    if (!serie[key]) {
                        serie[key] = {
                            total: 0, cumple: 0, no_cumple: 0, no_aplica: 0,
                            sin_marcar: 0, extra_cumple: 0, extra_no_cumple: 0
                        };
                    }
                    serie[key].total++;
                    var estado = dia.cumple || 'sin_marcar';
                    if (serie[key][estado] !== undefined) serie[key][estado]++;
                });
            });

        return Object.keys(serie)
            .map(function (k) {
                var d = serie[k];
                var pct = d.total ? Math.round((d.cumple / d.total) * 1000) / 10 : 0;
                return {
                    fecha: k, total: d.total, cumple: d.cumple, no_cumple: d.no_cumple,
                    no_aplica: d.no_aplica, sin_marcar: d.sin_marcar,
                    extra_cumple: d.extra_cumple, extra_no_cumple: d.extra_no_cumple,
                    cumplimientoPct: pct
                };
            })
            .sort(function (a, b) { return a.fecha.localeCompare(b.fecha); });
    }

    function calcularTasaBaselines(actividades) {
        actividades = actividades || [];
        var total = actividades.length;
        var confirmadas = actividades.filter(function (a) { return a.baseline_confirmada; }).length;
        var sinFecha = actividades.filter(function (a) { return !a.fecha_inicio && !a.baseline_confirmada; }).length;
        var borrador = total - confirmadas - sinFecha;
        return {
            total: total,
            confirmadas: confirmadas,
            borrador: borrador,
            sinFechaInicio: sinFecha,
            pctConfirmadas: total ? Math.round((confirmadas / total) * 1000) / 10 : 0
        };
    }

    /**
     * Helper async: carga mapa {uuid: nombre} desde tabla `perfiles`.
     * Uso:
     *   const mapa = await AXC_BL.kpis.cargarMapaResidentes(_SB);
     *   const kpis = AXC_BL.kpis.calcularPorResidente(acts, mapa);
     *
     * opciones.tabla       - default 'perfiles'
     * opciones.filtroRol   - default null (trae todos)
     * opciones.campoNombre - default 'nombre'
     * opciones.campoId     - default 'id'
     */
    function cargarMapaResidentes(supabaseClient, opciones) {
        opciones = opciones || {};
        var tabla = opciones.tabla || 'perfiles';
        var filtroRol = opciones.filtroRol || null;
        var campoId = opciones.campoId || 'id';
        var campoNombre = opciones.campoNombre || 'nombre';

        if (!supabaseClient || typeof supabaseClient.from !== 'function') {
            console.warn('[AXC_BL.kpis] cargarMapaResidentes: supabaseClient invalido');
            return Promise.resolve({});
        }

        var query = supabaseClient.from(tabla).select(campoId + ',' + campoNombre + ',rol');
        if (filtroRol) query = query.eq('rol', filtroRol);

        return query.then(function (res) {
            if (res.error) {
                console.warn('[AXC_BL.kpis] cargarMapaResidentes error:', res.error);
                return {};
            }
            var map = {};
            (res.data || []).forEach(function (p) {
                map[p[campoId]] = p[campoNombre] || p[campoId];
            });
            return map;
        });
    }

    // ---------- Export ----------
    window.AXC_BL.kpis = {
        calcularGlobales: calcularGlobales,
        calcularPorResidente: calcularPorResidente,
        calcularPorContratista: calcularPorContratista,
        calcularPorObra: calcularPorObra,
        calcularDistribucionEstados: calcularDistribucionEstados,
        calcularTasaBaselines: calcularTasaBaselines,
        calcularSerieTemporal: calcularSerieTemporal,
        obtenerTopRetrasadas: obtenerTopRetrasadas,
        filtrarPorRangoFecha: filtrarPorRangoFecha,
        agruparPor: agruparPor,
        cargarMapaResidentes: cargarMapaResidentes,
        ESTADOS_V25: ESTADOS_V25.slice(),
        ESTADOS_ATRASO: ESTADOS_ATRASO.slice(),
        _version: '2.5.1'
    };

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_BL.kpis] modulo 9 cargado v' + window.AXC_BL.kpis._version);
    }
})();
