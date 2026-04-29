/* ============================================================
 * AXC Reporte Global - Fase 4.5.a Fix campos v2.5
 * v2.5.1-paso4.5b (corregido acceso a Supabase)
 * ============================================================
 * BUG: el mapeo de _allActs en axc_reporte_global.html omite los
 * campos del modelo v2.5 (baseline_confirmada, cumplimiento_pct,
 * fecha_fin_plan, dias_atraso_calculado, dias_planificados_baseline).
 *
 * SOLUCION: este parche hace una query adicional a Supabase
 * trayendo solo los campos v2.5 (id + 5 campos), y mergea cada
 * actividad de _allActs con su contraparte en DB. Despues fuerza
 * un re-render para que los KPIs reflejen los datos correctos.
 *
 * v4.5b: corregido el acceso a Supabase. _SB no esta en window,
 * pero window.supabase si. Tambien fallback via new Function.
 * ============================================================ */
(function () {
    'use strict';
    if (window.AXC_GLOBAL_FIX_V25 && window.AXC_GLOBAL_FIX_V25._v >= '2.5.1-paso4.5b') return;

    var _campos_v25 = ['id', 'baseline_confirmada', 'cumplimiento_pct', 'fecha_fin_plan',
                       'dias_atraso_calculado', 'dias_planificados_baseline'];

    var _enriqueciendo = false;

    function _getSB() {
        if (window.supabase && typeof window.supabase.from === 'function') {
            return window.supabase;
        }
        if (window._SB && typeof window._SB.from === 'function') {
            return window._SB;
        }
        try {
            var sb = new Function('try{return typeof _SB!=="undefined"?_SB:null}catch(e){return null}')();
            if (sb && typeof sb.from === 'function') return sb;
        } catch (e) { }
        return null;
    }

    async function enriquecerAllActs() {
        if (_enriqueciendo) return;
        if (!Array.isArray(window._allActs) || window._allActs.length === 0) return;

        var SB = _getSB();
        if (!SB) {
            console.warn('[AXC_GLOBAL_FIX_V25] no se pudo obtener instancia de Supabase');
            return;
        }

        _enriqueciendo = true;
        try {
            var ids = window._allActs.map(function (a) { return a.id; }).filter(Boolean);
            if (ids.length === 0) return;

            var resp = await SB.from('actividades')
                .select(_campos_v25.join(','))
                .in('id', ids);

            if (resp.error) {
                console.warn('[AXC_GLOBAL_FIX_V25] error en query:', resp.error);
                return;
            }

            var mapa = {};
            (resp.data || []).forEach(function (r) {
                mapa[r.id] = r;
            });

            var enriquecidas = 0;
            window._allActs.forEach(function (a) {
                var v25 = mapa[a.id];
                if (v25) {
                    a.baseline_confirmada = v25.baseline_confirmada;
                    a.cumplimiento_pct = v25.cumplimiento_pct;
                    a.fecha_fin_plan = v25.fecha_fin_plan;
                    a.dias_atraso_calculado = v25.dias_atraso_calculado;
                    a.dias_planificados_baseline = v25.dias_planificados_baseline;
                    enriquecidas++;
                }
            });

            console.info('[AXC_GLOBAL_FIX_V25] enriquecidas ' + enriquecidas + ' de ' + window._allActs.length);

            // Re-render llamando al applyFilters original para evitar loop
            if (window.applyFilters && window.applyFilters.__axcFixV25Original) {
                window.applyFilters.__axcFixV25Original();
            } else if (typeof window.applyFilters === 'function') {
                window.applyFilters();
            }
        } catch (e) {
            console.warn('[AXC_GLOBAL_FIX_V25] excepcion:', e);
        } finally {
            _enriqueciendo = false;
        }
    }

    function instalarHook() {
        if (typeof window.applyFilters !== 'function') return false;
        if (window.applyFilters.__axcFixV25Hooked) return true;

        var orig = window.applyFilters;
        var hooked = function () {
            var r = orig.apply(this, arguments);
            if (window._allActs && window._allActs.length > 0 &&
                window._allActs[0].baseline_confirmada === undefined) {
                setTimeout(enriquecerAllActs, 100);
            }
            return r;
        };
        hooked.__axcFixV25Hooked = true;
        hooked.__axcFixV25Original = orig;
        window.applyFilters = hooked;
        console.info('[AXC_GLOBAL_FIX_V25] hook a applyFilters instalado');
        return true;
    }

    function init() {
        if (instalarHook()) {
            if (window._allActs && window._allActs.length > 0) {
                enriquecerAllActs();
            }
        }
    }

    window.AXC_GLOBAL_FIX_V25 = {
        enriquecer: enriquecerAllActs,
        _getSB: _getSB,
        _v: '2.5.1-paso4.5b'
    };

    if (typeof window.applyFilters === 'function') {
        init();
    } else {
        var attempts = 0;
        var retry = setInterval(function () {
            attempts++;
            if (typeof window.applyFilters === 'function') {
                init();
                clearInterval(retry);
            } else if (attempts > 30) {
                clearInterval(retry);
                console.warn('[AXC_GLOBAL_FIX_V25] timeout esperando applyFilters');
            }
        }, 200);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_GLOBAL_FIX_V25] cargado v' + window.AXC_GLOBAL_FIX_V25._v);
    }
})();
