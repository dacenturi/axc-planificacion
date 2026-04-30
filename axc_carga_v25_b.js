/* ============================================================
 * AXC Carga - Commit B: render visual de 7 estados de días
 * v2.5.3-cargaB
 * ============================================================
 * COMMIT B — Estados visuales de días:
 *   El HTML del residente NO renderea diferenciado los 7 estados
 *   oficiales del sistema v2.5. Todos los días se ven con el mismo
 *   fondo naranja, sin importar si son cumplio/no_cumplio/etc.
 *
 *   Este parche aplica los estilos correctos sobre cada .db según
 *   el valor de days[i].cumple, con icono y tooltip explicativo.
 *
 * Estados soportados:
 *   plan              -> 🟧 naranja, sin texto
 *   cumplio           -> ✅ verde, "OK"
 *   no_cumplio        -> ❌ rojo, "X"
 *   no_aplica         -> ⏸ gris, "—"
 *   extra_cumplio     -> 🟦 azul, "+"
 *   extra_no_cumplio  -> 🟥 rojo oscuro, "+X"
 *   sin_marcar        -> sin fondo, neutro
 *   (sin valor)       -> deja como está (fuera del plan)
 *
 * NO toca:
 *   - El handler onclick (AXC_BL.clickearCelda ya cicla los estados)
 *   - La lógica de guardado en Supabase
 *   - El observer del Commit A (lo extiende)
 * ============================================================ */
(function () {
    'use strict';

    if (window.AXC_CARGA_V25_B && window.AXC_CARGA_V25_B._v >= '2.5.3-cargaB') return;

    var DIAS_NOMBRE = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    var DIAS_LETRA = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

    // Estilos por estado
    var ESTILOS_DIA = {
        'plan': {
            bg: 'rgba(240,165,0,0.30)',
            color: 'var(--accent)',
            text: '',
            icon: '',
            label: 'Planificado'
        },
        'cumplio': {
            bg: 'rgba(63,185,80,0.30)',
            color: 'var(--green)',
            text: 'OK',
            icon: '✓',
            label: 'Cumplió'
        },
        'no_cumplio': {
            bg: 'rgba(248,81,73,0.30)',
            color: 'var(--red)',
            text: '✗',
            icon: '✗',
            label: 'No cumplió'
        },
        'no_aplica': {
            bg: 'rgba(139,148,158,0.20)',
            color: '#8b949e',
            text: 'N/A',
            icon: '⏸',
            label: 'No aplica'
        },
        'extra_cumplio': {
            bg: 'rgba(56,139,253,0.30)',
            color: '#388bfd',
            text: '+',
            icon: '+',
            label: 'Día extra cumplido'
        },
        'extra_no_cumplio': {
            bg: 'rgba(180,40,40,0.45)',
            color: '#ff6b6b',
            text: '+✗',
            icon: '+✗',
            label: 'Día extra no cumplido'
        },
        'sin_marcar': {
            bg: 'transparent',
            color: 'var(--text3)',
            text: '·',
            icon: '·',
            label: 'Sin marcar'
        }
    };

    // Estilo CSS común para los días
    var ESTILO_BASE_DIA = 'font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;';

    // Parsea el title actual (formato: "DD/MM/YYYY" o "DD/MM/YYYY - estado")
    function _parseTitle(title) {
        if (!title) return { fecha: '', estado: '' };
        var parts = title.split(' - ');
        return {
            fecha: parts[0] || '',
            estado: parts[1] || ''
        };
    }

    // Genera el title nuevo: "L 27/4 — Cumplió"
    function _generarTitle(fechaStr, cumple) {
        if (!fechaStr) return '';
        // Parsear DD/MM/YYYY
        var m = fechaStr.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
        if (!m) return fechaStr;
        var dd = m[1], mm = m[2], yyyy = m[3];
        var d = new Date(parseInt(yyyy), parseInt(mm) - 1, parseInt(dd));
        var letra = DIAS_LETRA[d.getDay()];
        var label = ESTILOS_DIA[cumple]?.label || 'Sin actividad';
        return letra + ' ' + parseInt(dd) + '/' + parseInt(mm) + ' — ' + label;
    }

    // Aplica el estilo a un .db según su estado
    function _renderDia(div, cumple) {
        if (!div) return;

        // Si no hay valor de cumple, dejar como está (fuera del plan)
        if (!cumple) {
            // Limpiar tooltip a algo neutro
            var t = _parseTitle(div.title);
            if (t.fecha) {
                div.title = _generarTitle(t.fecha, '') || div.title;
            }
            return;
        }

        var estilo = ESTILOS_DIA[cumple];
        if (!estilo) return; // estado desconocido, no tocar

        // Aplicar estilo inline
        div.style.background = estilo.bg;
        div.style.color = estilo.color;
        div.style.fontSize = '11px';
        div.style.fontWeight = '700';
        div.style.display = 'flex';
        div.style.alignItems = 'center';
        div.style.justifyContent = 'center';

        // Texto interno (sobreescribe lo que esté)
        if (estilo.text) {
            div.innerHTML = estilo.text;
        } else {
            div.innerHTML = '';
        }

        // Tooltip
        var t = _parseTitle(div.title);
        if (t.fecha) {
            div.title = _generarTitle(t.fecha, cumple);
        }

        // Marca de procesado para no reaplicar
        div.dataset.axcEstadoRendered = cumple;
    }

    // Localiza el array `acts` desde el closure global del HTML
    function _findActs() {
        try {
            return new Function('try{return typeof acts!=="undefined"?acts:[]}catch(e){return[]}')();
        } catch (e) {
            return [];
        }
    }

    // Procesa toda la tabla aplicando estilos a los días
    function _procesarDias() {
        var tbl = document.getElementById('tbl');
        if (!tbl) return;

        var acts = _findActs();
        if (!acts || acts.length === 0) return;

        var filas = tbl.querySelectorAll('tbody tr');
        filas.forEach(function (tr, idx) {
            var act = acts[idx];
            if (!act || !Array.isArray(act.days)) return;

            // Buscar todos los .db dentro de la fila (en orden)
            var divs = tr.querySelectorAll('.db');
            divs.forEach(function (div, i) {
                var d = act.days[i];
                if (!d) return;

                // Re-renderizar siempre (los clicks pueden cambiar el valor)
                if (div.dataset.axcEstadoRendered !== d.cumple) {
                    _renderDia(div, d.cumple || '');
                }
            });
        });
    }

    // Hookear con debounce al observer del Commit A si existe, o crear uno nuevo
    function _instalarObserver() {
        var tbl = document.getElementById('tbl');
        if (!tbl) return false;
        var tbody = tbl.querySelector('tbody');
        if (!tbody) return false;

        // Procesar inmediatamente
        _procesarDias();

        // Observer propio para captar cambios después de clicks
        var observer = new MutationObserver(function () {
            clearTimeout(window._axcCargaBTimeout);
            window._axcCargaBTimeout = setTimeout(_procesarDias, 80);
        });
        observer.observe(tbody, { childList: true, subtree: true, attributes: true, attributeFilter: ['title', 'style'] });

        console.info('[AXC_CARGA_V25_B] observer instalado en #tbl tbody (estados visuales)');
        return true;
    }

    function init() {
        if (!_instalarObserver()) {
            var attempts = 0;
            var retry = setInterval(function () {
                attempts++;
                if (_instalarObserver()) {
                    clearInterval(retry);
                } else if (attempts > 40) {
                    clearInterval(retry);
                    console.warn('[AXC_CARGA_V25_B] timeout esperando #tbl');
                }
            }, 250);
        }
    }

    window.AXC_CARGA_V25_B = {
        procesarDias: _procesarDias,
        ESTILOS_DIA: ESTILOS_DIA,
        _v: '2.5.3-cargaB'
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        setTimeout(init, 200);
    }

    if (typeof console !== 'undefined' && console.info) {
        console.info('[AXC_CARGA_V25_B] cargado v' + window.AXC_CARGA_V25_B._v);
    }
})();
