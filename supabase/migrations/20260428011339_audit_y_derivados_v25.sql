-- ============================================================
-- AXC Planificacion - Migration v2.5.1
-- Auditoria administrativa + campos derivados
-- Fecha: 2026-04-27
-- ============================================================
-- OBJETIVO:
-- Agregar tabla de auditoria para intervenciones administrativas
-- sobre actividades confirmadas, junto con dos campos derivados
-- en la tabla actividades que se actualizan automaticamente.
-- ============================================================

-- ============================================================
-- 1. NUEVA TABLA: baseline_audit_log
-- ============================================================

CREATE TABLE public.baseline_audit_log (
  id bigserial PRIMARY KEY,
  actividad_id uuid NOT NULL
    REFERENCES public.actividades(id) ON DELETE CASCADE,
  accion text NOT NULL
    CHECK (accion IN ('confirm_retroactive', 'revert_to_draft')),
  admin_id uuid NOT NULL
    REFERENCES auth.users(id) ON DELETE SET NULL,
  motivo text NOT NULL
    CHECK (length(trim(motivo)) >= 20),
  contexto_previo jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.baseline_audit_log IS
  'Registro de intervenciones administrativas sobre baselines confirmadas. Cada accion requiere motivo justificado.';

COMMENT ON COLUMN public.baseline_audit_log.actividad_id IS
  'Referencia a la actividad afectada. ON DELETE CASCADE: si se borra la actividad se borra su historial.';

COMMENT ON COLUMN public.baseline_audit_log.accion IS
  'Tipo de accion: confirm_retroactive (admin confirma una actividad cuya fecha de inicio paso) o revert_to_draft (admin revierte una baseline confirmada).';

COMMENT ON COLUMN public.baseline_audit_log.admin_id IS
  'Administrador que ejecuto la accion. ON DELETE SET NULL para preservar el historial si el admin es eliminado.';

COMMENT ON COLUMN public.baseline_audit_log.motivo IS
  'Justificacion en texto libre. Constraint exige minimo 20 caracteres efectivos.';

COMMENT ON COLUMN public.baseline_audit_log.contexto_previo IS
  'Snapshot opcional del estado de la actividad antes de la intervencion. Util para reversiones.';

-- Indice para consultas eficientes por actividad
CREATE INDEX idx_audit_actividad ON public.baseline_audit_log(actividad_id);

-- Indice para consultas eficientes por admin (reportes)
CREATE INDEX idx_audit_admin ON public.baseline_audit_log(admin_id);

-- Indice para listado cronologico (vista del reporte global)
CREATE INDEX idx_audit_created_at ON public.baseline_audit_log(created_at DESC);

-- ============================================================
-- 2. POLITICAS RLS PARA baseline_audit_log
-- ============================================================

ALTER TABLE public.baseline_audit_log ENABLE ROW LEVEL SECURITY;

-- Solo administradores pueden leer el log de auditoria
CREATE POLICY "Admins pueden leer log de auditoria"
  ON public.baseline_audit_log
  FOR SELECT
  TO authenticated
  USING (public.es_admin());

-- Solo administradores pueden insertar registros (acciones admin)
CREATE POLICY "Admins pueden registrar acciones de auditoria"
  ON public.baseline_audit_log
  FOR INSERT
  TO authenticated
  WITH CHECK (public.es_admin() AND admin_id = auth.uid());

-- Nadie puede modificar ni eliminar registros existentes (inmutabilidad del log)
-- No se crean policies de UPDATE ni DELETE intencionalmente

-- ============================================================
-- 3. NUEVAS COLUMNAS DERIVADAS EN actividades
-- ============================================================

ALTER TABLE public.actividades
  ADD COLUMN dias_planificados_baseline integer NULL;

COMMENT ON COLUMN public.actividades.dias_planificados_baseline IS
  'Cantidad de dias que estaban marcados como planificados al momento de confirmar la baseline. Se establece automaticamente al confirmar.';

ALTER TABLE public.actividades
  ADD COLUMN dias_atraso_calculado integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.actividades.dias_atraso_calculado IS
  'Cantidad de dias extra registrados despues de la confirmacion (extra cumplido + extra no cumplido). Se actualiza automaticamente.';

-- Constraint: si la actividad esta confirmada, dias_planificados_baseline no puede ser NULL
ALTER TABLE public.actividades
  ADD CONSTRAINT chk_dias_planificados_coherencia
  CHECK (
    (baseline_confirmada = false)
    OR (baseline_confirmada = true AND dias_planificados_baseline IS NOT NULL)
  );

-- Constraint: dias_atraso_calculado no puede ser negativo
ALTER TABLE public.actividades
  ADD CONSTRAINT chk_dias_atraso_no_negativo
  CHECK (dias_atraso_calculado >= 0);

-- ============================================================
-- 4. FUNCION HELPER: contar dias planificados en array days
-- ============================================================

CREATE OR REPLACE FUNCTION public.contar_dias_planificados(days_array jsonb)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    contador integer := 0;
    elemento jsonb;
BEGIN
    -- Caso 1: array es NULL o vacio
    IF days_array IS NULL OR jsonb_array_length(days_array) = 0 THEN
        RETURN 0;
    END IF;

    -- Iterar cada elemento del array
    FOR elemento IN SELECT * FROM jsonb_array_elements(days_array) LOOP
        -- Caso 2: formato viejo (booleano simple)
        IF jsonb_typeof(elemento) = 'boolean' THEN
            IF elemento::boolean = true THEN
                contador := contador + 1;
            END IF;
        -- Caso 3: formato nuevo (objeto con propiedad plan)
        ELSIF jsonb_typeof(elemento) = 'object' THEN
            IF (elemento->>'plan')::boolean = true THEN
                contador := contador + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN contador;
END $$;

COMMENT ON FUNCTION public.contar_dias_planificados IS
  'Cuenta dias planificados en array days, soportando formato viejo (booleano) y nuevo (objeto con plan).';

-- ============================================================
-- 5. FUNCION HELPER: contar dias extra en array days
-- ============================================================

CREATE OR REPLACE FUNCTION public.contar_dias_extra(days_array jsonb)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    contador integer := 0;
    elemento jsonb;
    cumple_valor text;
BEGIN
    IF days_array IS NULL OR jsonb_array_length(days_array) = 0 THEN
        RETURN 0;
    END IF;

    FOR elemento IN SELECT * FROM jsonb_array_elements(days_array) LOOP
        -- Solo formato nuevo soporta dias extra
        IF jsonb_typeof(elemento) = 'object' THEN
            cumple_valor := elemento->>'cumple';
            -- Dias extra: extra_cumplio o extra_no_cumplio
            IF cumple_valor IN ('extra_cumplio', 'extra_no_cumplio') THEN
                contador := contador + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN contador;
END $$;

COMMENT ON FUNCTION public.contar_dias_extra IS
  'Cuenta dias marcados como extra (cumplio o no cumplio) en array days nuevo formato.';

-- ============================================================
-- 6. TRIGGER: actualizar campos derivados automaticamente
-- ============================================================

CREATE OR REPLACE FUNCTION public.actualizar_campos_derivados()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Al confirmar baseline: capturar cantidad de dias planificados
    IF NEW.baseline_confirmada = true AND
       (OLD.baseline_confirmada IS NULL OR OLD.baseline_confirmada = false) THEN
        NEW.dias_planificados_baseline := public.contar_dias_planificados(NEW.days);
    END IF;

    -- Siempre recalcular dias de atraso a partir de dias extra
    NEW.dias_atraso_calculado := public.contar_dias_extra(NEW.days);

    RETURN NEW;
END $$;

COMMENT ON FUNCTION public.actualizar_campos_derivados IS
  'Trigger que actualiza dias_planificados_baseline al confirmar y dias_atraso_calculado en cada modificacion.';

CREATE TRIGGER trg_actualizar_campos_derivados
  BEFORE INSERT OR UPDATE ON public.actividades
  FOR EACH ROW
  EXECUTE FUNCTION public.actualizar_campos_derivados();

COMMENT ON TRIGGER trg_actualizar_campos_derivados ON public.actividades IS
  'Mantiene actualizados los campos dias_planificados_baseline y dias_atraso_calculado.';

-- ============================================================
-- 7. INICIALIZACION DE CAMPOS DERIVADOS PARA REGISTROS EXISTENTES
-- ============================================================

-- Para las 35 actividades existentes (todas en borrador, baseline_confirmada=false):
-- - dias_planificados_baseline: NULL (correcto, se llenara al confirmar)
-- - dias_atraso_calculado: calcular en base al days actual (deberia ser 0 porque
--   no hay actividades confirmadas con dias extra todavia)
UPDATE public.actividades
SET dias_atraso_calculado = public.contar_dias_extra(days)
WHERE days IS NOT NULL;

-- ============================================================
-- 8. VERIFICACION POST-MIGRATION
-- ============================================================

DO $$
DECLARE
    tabla_existe boolean;
    columnas_nuevas integer;
    constraints_nuevos integer;
    indices_nuevos integer;
    funciones_nuevas integer;
    trigger_existe boolean;
    actividades_total integer;
    actividades_con_atraso_inicializado integer;
BEGIN
    -- Verificar tabla baseline_audit_log
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'baseline_audit_log'
    ) INTO tabla_existe;

    -- Verificar columnas nuevas en actividades
    SELECT count(*) INTO columnas_nuevas
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'actividades'
      AND column_name IN ('dias_planificados_baseline', 'dias_atraso_calculado');

    -- Verificar constraints nuevos
    SELECT count(*) INTO constraints_nuevos
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND constraint_name IN (
        'chk_dias_planificados_coherencia',
        'chk_dias_atraso_no_negativo'
      );

    -- Verificar indices nuevos en audit log
    SELECT count(*) INTO indices_nuevos
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'baseline_audit_log'
      AND indexname IN (
        'idx_audit_actividad',
        'idx_audit_admin',
        'idx_audit_created_at'
      );

    -- Verificar funciones helper
    SELECT count(*) INTO funciones_nuevas
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'contar_dias_planificados',
        'contar_dias_extra',
        'actualizar_campos_derivados'
      );

    -- Verificar trigger
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_actualizar_campos_derivados'
    ) INTO trigger_existe;

    -- Contar actividades inicializadas
    SELECT count(*) INTO actividades_total
    FROM public.actividades;

    SELECT count(*) INTO actividades_con_atraso_inicializado
    FROM public.actividades
    WHERE dias_atraso_calculado IS NOT NULL;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Migration v2.5.1 aplicada:';
    RAISE NOTICE '  - Tabla baseline_audit_log creada: %', tabla_existe;
    RAISE NOTICE '  - Columnas nuevas en actividades: % (esperado: 2)', columnas_nuevas;
    RAISE NOTICE '  - Constraints nuevos: % (esperado: 2)', constraints_nuevos;
    RAISE NOTICE '  - Indices en audit log: % (esperado: 3)', indices_nuevos;
    RAISE NOTICE '  - Funciones helper: % (esperado: 3)', funciones_nuevas;
    RAISE NOTICE '  - Trigger creado: %', trigger_existe;
    RAISE NOTICE '  - Actividades existentes: %', actividades_total;
    RAISE NOTICE '  - Actividades inicializadas: %', actividades_con_atraso_inicializado;
    RAISE NOTICE '============================================';

    IF NOT tabla_existe OR
       columnas_nuevas <> 2 OR
       constraints_nuevos <> 2 OR
       indices_nuevos <> 3 OR
       funciones_nuevas <> 3 OR
       NOT trigger_existe OR
       actividades_total <> actividades_con_atraso_inicializado THEN
        RAISE EXCEPTION 'Migration incompleta. Revisar errores arriba.';
    END IF;

    RAISE NOTICE 'Validacion exitosa.';
END $$;
