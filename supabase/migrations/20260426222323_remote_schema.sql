


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."es_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select rol = 'admin' from public.perfiles where id = auth.uid()),
    false
  );
$$;


ALTER FUNCTION "public"."es_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.perfiles (id, nombre, rol)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'rol', 'residente')
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."actividades" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "app" "text" NOT NULL,
    "modo" "text" DEFAULT ''::"text" NOT NULL,
    "fecha_inicio" "date",
    "fecha_fin" "date",
    "obra" "text" DEFAULT ''::"text" NOT NULL,
    "contratista" "text" DEFAULT ''::"text" NOT NULL,
    "residente" "text" DEFAULT ''::"text" NOT NULL,
    "sector" "text" DEFAULT ''::"text" NOT NULL,
    "descripcion" "text" DEFAULT ''::"text" NOT NULL,
    "days" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "cumple" "text" DEFAULT ''::"text" NOT NULL,
    "razon" "text" DEFAULT ''::"text" NOT NULL,
    "criticidad" "text" DEFAULT ''::"text" NOT NULL,
    "orden" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "dias_atraso" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "actividades_app_check" CHECK (("app" = ANY (ARRAY['contratista'::"text", 'residente'::"text"]))),
    CONSTRAINT "actividades_criticidad_check" CHECK (("criticidad" = ANY (ARRAY[''::"text", 'Alta'::"text", 'Media'::"text", 'Baja'::"text"]))),
    CONSTRAINT "actividades_cumple_check" CHECK (("cumple" = ANY (ARRAY[''::"text", 'Sí'::"text", 'No'::"text", 'En proceso'::"text", 'Terminado'::"text", 'Cumplido con atraso'::"text", 'En espera'::"text", 'Retrasado'::"text", 'Cancelado'::"text"]))),
    CONSTRAINT "actividades_modo_check" CHECK (("modo" = ANY (ARRAY[''::"text", 'unica'::"text", 'multi'::"text"])))
);


ALTER TABLE "public"."actividades" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."asignaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "obra_id" "uuid",
    "residente_id" "uuid",
    "contratista" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."asignaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."listas" (
    "id" bigint NOT NULL,
    "tipo" "text" NOT NULL,
    "valor" "text" NOT NULL,
    "obra_ref" "text" DEFAULT ''::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."listas" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."listas_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."listas_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."listas_id_seq" OWNED BY "public"."listas"."id";



CREATE TABLE IF NOT EXISTS "public"."obras" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."obras" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."perfiles" (
    "id" "uuid" NOT NULL,
    "nombre" "text" NOT NULL,
    "rol" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "residente" "text",
    CONSTRAINT "perfiles_rol_check" CHECK (("rol" = ANY (ARRAY['admin'::"text", 'residente'::"text"])))
);


ALTER TABLE "public"."perfiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."perfiles"."residente" IS 'Nombre del residente asignado al usuario (FK informal a listas tipo=residentes). Los admins pueden tener esto NULL. Los usuarios residentes lo tienen obligatoriamente.';



CREATE TABLE IF NOT EXISTS "public"."planillas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "user_email" "text",
    "obra" "text",
    "contratista" "text",
    "residente" "text",
    "fecha_inicio" "date",
    "fecha_fin" "date",
    "modo" "text" DEFAULT 'unica'::"text",
    "actividades" "jsonb" DEFAULT '[]'::"jsonb",
    "total" integer DEFAULT 0,
    "cumplidas" integer DEFAULT 0,
    "no_cumplidas" integer DEFAULT 0,
    "pct_cumplimiento" integer DEFAULT 0,
    "estado" "text" DEFAULT 'borrador'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."planillas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ppc_historial" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "semana_id" "uuid",
    "obra_id" "uuid",
    "total_actividades" integer,
    "cumplidas" integer,
    "ppc_porcentaje" numeric(5,2),
    "semana_numero" integer,
    "fecha_cierre" "date",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ppc_historial" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."semanas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "obra_id" "uuid",
    "residente_id" "uuid",
    "fecha_inicio" "date" NOT NULL,
    "fecha_fin" "date" NOT NULL,
    "semana_numero" integer,
    "estado" "text" DEFAULT 'activa'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "semanas_estado_check" CHECK (("estado" = ANY (ARRAY['activa'::"text", 'cerrada'::"text"])))
);


ALTER TABLE "public"."semanas" OWNER TO "postgres";


ALTER TABLE ONLY "public"."listas" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."listas_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."actividades"
    ADD CONSTRAINT "actividades_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."asignaciones"
    ADD CONSTRAINT "asignaciones_obra_id_residente_id_key" UNIQUE ("obra_id", "residente_id");



ALTER TABLE ONLY "public"."asignaciones"
    ADD CONSTRAINT "asignaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."listas"
    ADD CONSTRAINT "listas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."obras"
    ADD CONSTRAINT "obras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."perfiles"
    ADD CONSTRAINT "perfiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."planillas"
    ADD CONSTRAINT "planillas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ppc_historial"
    ADD CONSTRAINT "ppc_historial_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."semanas"
    ADD CONSTRAINT "semanas_pkey" PRIMARY KEY ("id");



CREATE INDEX "actividades_app_idx" ON "public"."actividades" USING "btree" ("app");



CREATE INDEX "actividades_contratista_idx" ON "public"."actividades" USING "btree" ("contratista");



CREATE INDEX "actividades_fecha_idx" ON "public"."actividades" USING "btree" ("fecha_inicio", "fecha_fin");



CREATE INDEX "actividades_obra_idx" ON "public"."actividades" USING "btree" ("obra");



CREATE INDEX "actividades_residente_idx" ON "public"."actividades" USING "btree" ("residente");



CREATE INDEX "actividades_user_idx" ON "public"."actividades" USING "btree" ("user_id");



CREATE INDEX "idx_actividades_cumple_app" ON "public"."actividades" USING "btree" ("app", "cumple");



CREATE INDEX "idx_listas_obra_ref" ON "public"."listas" USING "btree" ("obra_ref");



CREATE INDEX "idx_listas_tipo" ON "public"."listas" USING "btree" ("tipo");



CREATE INDEX "idx_planillas_contratista" ON "public"."planillas" USING "btree" ("contratista");



CREATE INDEX "idx_planillas_created_at" ON "public"."planillas" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_planillas_estado" ON "public"."planillas" USING "btree" ("estado");



CREATE INDEX "idx_planillas_obra" ON "public"."planillas" USING "btree" ("obra");



CREATE INDEX "idx_planillas_residente" ON "public"."planillas" USING "btree" ("residente");



CREATE INDEX "idx_planillas_user_id" ON "public"."planillas" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "actividades_set_updated_at" BEFORE UPDATE ON "public"."actividades" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "planillas_updated_at" BEFORE UPDATE ON "public"."planillas" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



ALTER TABLE ONLY "public"."actividades"
    ADD CONSTRAINT "actividades_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."asignaciones"
    ADD CONSTRAINT "asignaciones_obra_id_fkey" FOREIGN KEY ("obra_id") REFERENCES "public"."obras"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."asignaciones"
    ADD CONSTRAINT "asignaciones_residente_id_fkey" FOREIGN KEY ("residente_id") REFERENCES "public"."perfiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."perfiles"
    ADD CONSTRAINT "perfiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."planillas"
    ADD CONSTRAINT "planillas_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ppc_historial"
    ADD CONSTRAINT "ppc_historial_obra_id_fkey" FOREIGN KEY ("obra_id") REFERENCES "public"."obras"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ppc_historial"
    ADD CONSTRAINT "ppc_historial_semana_id_fkey" FOREIGN KEY ("semana_id") REFERENCES "public"."semanas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."semanas"
    ADD CONSTRAINT "semanas_obra_id_fkey" FOREIGN KEY ("obra_id") REFERENCES "public"."obras"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."semanas"
    ADD CONSTRAINT "semanas_residente_id_fkey" FOREIGN KEY ("residente_id") REFERENCES "public"."perfiles"("id");



CREATE POLICY "Usuario puede actualizar sus propias planillas" ON "public"."planillas" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuario puede eliminar sus propias planillas" ON "public"."planillas" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuario puede insertar sus propias planillas" ON "public"."planillas" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuarios logueados pueden eliminar listas" ON "public"."listas" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Usuarios logueados pueden insertar listas" ON "public"."listas" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Usuarios logueados pueden leer listas" ON "public"."listas" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Usuarios logueados pueden ver todas las planillas" ON "public"."planillas" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."actividades" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "actividades_delete" ON "public"."actividades" FOR DELETE TO "authenticated" USING (("public"."es_admin"() OR ("auth"."uid"() = "user_id") OR ("residente" = ( SELECT "perfiles"."residente"
   FROM "public"."perfiles"
  WHERE ("perfiles"."id" = "auth"."uid"())))));



CREATE POLICY "actividades_insert" ON "public"."actividades" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "actividades_select" ON "public"."actividades" FOR SELECT TO "authenticated" USING (("public"."es_admin"() OR ("auth"."uid"() = "user_id") OR ("residente" = ( SELECT "perfiles"."residente"
   FROM "public"."perfiles"
  WHERE ("perfiles"."id" = "auth"."uid"())))));



CREATE POLICY "actividades_update" ON "public"."actividades" FOR UPDATE TO "authenticated" USING (("public"."es_admin"() OR ("auth"."uid"() = "user_id") OR ("residente" = ( SELECT "perfiles"."residente"
   FROM "public"."perfiles"
  WHERE ("perfiles"."id" = "auth"."uid"()))))) WITH CHECK (("public"."es_admin"() OR ("auth"."uid"() = "user_id") OR ("residente" = ( SELECT "perfiles"."residente"
   FROM "public"."perfiles"
  WHERE ("perfiles"."id" = "auth"."uid"())))));



ALTER TABLE "public"."asignaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "asignaciones_acceso" ON "public"."asignaciones" FOR SELECT USING ((("residente_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text"))))));



CREATE POLICY "asignaciones_admin_write" ON "public"."asignaciones" USING ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text")))));



ALTER TABLE "public"."listas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."obras" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "obras_acceso" ON "public"."obras" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."asignaciones" "a"
  WHERE (("a"."obra_id" = "obras"."id") AND ("a"."residente_id" = "auth"."uid"()))))));



CREATE POLICY "obras_admin_write" ON "public"."obras" USING ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text")))));



ALTER TABLE "public"."perfiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "perfiles_delete_admin" ON "public"."perfiles" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p2"
  WHERE (("p2"."id" = "auth"."uid"()) AND ("p2"."rol" = 'admin'::"text")))));



CREATE POLICY "perfiles_insert_admin" ON "public"."perfiles" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p2"
  WHERE (("p2"."id" = "auth"."uid"()) AND ("p2"."rol" = 'admin'::"text")))));



CREATE POLICY "perfiles_select_all" ON "public"."perfiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "perfiles_update_admin" ON "public"."perfiles" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p2"
  WHERE (("p2"."id" = "auth"."uid"()) AND ("p2"."rol" = 'admin'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."perfiles" "p2"
  WHERE (("p2"."id" = "auth"."uid"()) AND ("p2"."rol" = 'admin'::"text")))));



ALTER TABLE "public"."planillas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ppc_acceso" ON "public"."ppc_historial" USING (((EXISTS ( SELECT 1
   FROM "public"."semanas" "s"
  WHERE (("s"."id" = "ppc_historial"."semana_id") AND ("s"."residente_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text"))))));



ALTER TABLE "public"."ppc_historial" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."semanas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "semanas_acceso" ON "public"."semanas" USING ((("residente_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."perfiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("p"."rol" = 'admin'::"text"))))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."es_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."es_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."es_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."actividades" TO "anon";
GRANT ALL ON TABLE "public"."actividades" TO "authenticated";
GRANT ALL ON TABLE "public"."actividades" TO "service_role";



GRANT ALL ON TABLE "public"."asignaciones" TO "anon";
GRANT ALL ON TABLE "public"."asignaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."asignaciones" TO "service_role";



GRANT ALL ON TABLE "public"."listas" TO "anon";
GRANT ALL ON TABLE "public"."listas" TO "authenticated";
GRANT ALL ON TABLE "public"."listas" TO "service_role";



GRANT ALL ON SEQUENCE "public"."listas_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."listas_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."listas_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."obras" TO "anon";
GRANT ALL ON TABLE "public"."obras" TO "authenticated";
GRANT ALL ON TABLE "public"."obras" TO "service_role";



GRANT ALL ON TABLE "public"."perfiles" TO "anon";
GRANT ALL ON TABLE "public"."perfiles" TO "authenticated";
GRANT ALL ON TABLE "public"."perfiles" TO "service_role";



GRANT ALL ON TABLE "public"."planillas" TO "anon";
GRANT ALL ON TABLE "public"."planillas" TO "authenticated";
GRANT ALL ON TABLE "public"."planillas" TO "service_role";



GRANT ALL ON TABLE "public"."ppc_historial" TO "anon";
GRANT ALL ON TABLE "public"."ppc_historial" TO "authenticated";
GRANT ALL ON TABLE "public"."ppc_historial" TO "service_role";



GRANT ALL ON TABLE "public"."semanas" TO "anon";
GRANT ALL ON TABLE "public"."semanas" TO "authenticated";
GRANT ALL ON TABLE "public"."semanas" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


