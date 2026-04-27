-- ============================================================
-- AXC Planificacion - Migration v2.5
-- Baseline + Cumplimiento Diario
-- Fecha: 2026-04-27
-- ============================================================
-- OBJETIVO:
-- Agregar soporte para "baseline congelada" + cumplimiento diario.
-- Permite distinguir actividades en BORRADOR (editables) vs
-- EN EJECUCION (con planificacion confirmada e inmutable).
-- ============================================================

-- ============================================================
-- 1. NUEVAS COLUMNAS EN actividades
-- ============================================================

ALTER TABLE public.actividades
  ADD COLUMN baseline_confirmada boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.actividades.baseline_confirmada IS
  'TRUE si la planificacion fue confirmada por el residente (estado EN EJECUCION). FALSE = BORRADOR (editable).';

ALTER TABLE public.actividades
  ADD COLUMN baseline_confirmada_at timestamptz NULL;

COMMENT ON COLUMN public.actividades.baseline_confirmada_at IS
  'Timestamp en que se confirmo la baseline. NULL si aun esta en borrador.';

ALTER TABLE public.actividades
  ADD COLUMN baseline_confirmada_por uuid NULL
    REFERENCES auth.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.actividades.baseline_confirmada_por IS
  'Usuario que confirmo la baseline. ON DELETE SET NULL para preservar la actividad si se borra el usuario.';

ALTER TABLE public.actividades
  ADD COLUMN cumplimiento_pct numeric(5,2) NULL;

COMMENT ON COLUMN public.actividades.cumplimiento_pct IS
  'Porcentaje de cumplimiento calculado: cumplidos / (cumplidos + no_cumplidos) * 100. NULL si no aplica (sin marcas).';

ALTER TABLE public.actividades
  ADD COLUMN fecha_fin_plan date NULL;

COMMENT ON COLUMN public.actividades.fecha_fin_plan IS
  'Fecha fin original al momento de confirmar baseline. Se usa para detectar retrasos post-confirmacion.';

-- ============================================================
-- 2. CONSTRAINTS DE COHERENCIA
-- ============================================================

-- Si baseline_confirmada = TRUE, los 3 campos relacionados NO pueden ser NULL
ALTER TABLE public.actividades
  ADD CONSTRAINT chk_baseline_coherencia
  CHECK (
    (baseline_confirmada = false)
    OR
    (baseline_confirmada = true
     AND baseline_confirmada_at IS NOT NULL
     AND baseline_confirmada_por IS NOT NULL
     AND fecha_fin_plan IS NOT NULL)
  );

COMMENT ON CONSTRAINT chk_baseline_coherencia ON public.actividades IS
  'Garantiza que cuando una actividad esta confirmada, los campos at/por/fecha_fin_plan tengan valor.';

-- Si cumplimiento_pct tiene valor, debe estar entre 0 y 100
ALTER TABLE public.actividades
  ADD CONSTRAINT chk_cumplimiento_pct_rango
  CHECK (
    cumplimiento_pct IS NULL
    OR (cumplimiento_pct >= 0 AND cumplimiento_pct <= 100)
  );

COMMENT ON CONSTRAINT chk_cumplimiento_pct_rango ON public.actividades IS
  'Garantiza que el porcentaje de cumplimiento este entre 0 y 100, o sea NULL.';

-- ============================================================
-- 3. INDICES PARA PERFORMANCE
-- ============================================================

-- Acelera queries de dashboards que filtran por estado de baseline
CREATE INDEX idx_actividades_baseline_confirmada
  ON public.actividades(baseline_confirmada)
  WHERE baseline_confirmada = true;

COMMENT ON INDEX public.idx_actividades_baseline_confirmada IS
  'Indice parcial para acelerar consultas sobre actividades en EJECUCION.';

-- ============================================================
-- 4. VERIFICACION POST-MIGRATION
-- ============================================================
-- Las siguientes consultas son informativas. Confirman que la migration
-- se aplico correctamente. No alteran datos.
-- ============================================================

DO $$
DECLARE
    col_count integer;
    constraint_count integer;
    index_count integer;
BEGIN
    -- Contar columnas nuevas
    SELECT count(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'actividades'
      AND column_name IN (
        'baseline_confirmada',
        'baseline_confirmada_at',
        'baseline_confirmada_por',
        'cumplimiento_pct',
        'fecha_fin_plan'
      );

    -- Contar constraints nuevos
    SELECT count(*) INTO constraint_count
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'actividades'
      AND constraint_name IN (
        'chk_baseline_coherencia',
        'chk_cumplimiento_pct_rango'
      );

    -- Contar indices nuevos
    SELECT count(*) INTO index_count
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'actividades'
      AND indexname = 'idx_actividades_baseline_confirmada';

    RAISE NOTICE 'Migration v2.5 aplicada:';
    RAISE NOTICE '  - Columnas nuevas: % (esperado: 5)', col_count;
    RAISE NOTICE '  - Constraints nuevos: % (esperado: 2)', constraint_count;
    RAISE NOTICE '  - Indices nuevos: % (esperado: 1)', index_count;

    IF col_count <> 5 OR constraint_count <> 2 OR index_count <> 1 THEN
        RAISE EXCEPTION 'Migration incompleta. Revisar errores arriba.';
    END IF;
END $$;
