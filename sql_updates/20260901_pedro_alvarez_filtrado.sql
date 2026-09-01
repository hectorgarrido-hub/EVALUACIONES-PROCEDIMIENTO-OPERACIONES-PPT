-- Pedro Álvarez: nota 100 en las últimas 8 evaluaciones de Filtrado (3.8.3)
-- Procedimientos: 3.8.3.9 .. 3.8.3.16   |   Fecha evaluación: 2026-09-01
--
-- Estructura real del dato:
--   tabla  dashboard_state(id text, data jsonb, updated_at)
--   fila   id = 'ops_ppt'
--   data = { people: [ {id, g, rut, nombre, apPat, apMat, cargo}, ... ],
--            cells:  { <personId>: { <procCode>: {dif, ev, difDate, evDate, evNota} } } }
--
-- El id de la persona NO se hardcodea: se resuelve por apellido/nombre, porque
-- los ids (p1, p2, ...) dependen de altas y bajas hechas sobre la fila.
-- Solo se fusionan los campos de evaluación; dif/difDate se conservan.

do $$
declare
  pid        text;
  proc_codes text[] := array['3.8.3.9','3.8.3.10','3.8.3.11','3.8.3.12',
                             '3.8.3.13','3.8.3.14','3.8.3.15','3.8.3.16'];
  eval_patch jsonb := '{"ev":"ok","evNota":100,"evDate":"2026-09-01"}'::jsonb;
  d          jsonb;
  code       text;
begin
  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  -- Resolver el id de Pedro Álvarez desde el array people
  select p->>'id' into pid
  from jsonb_array_elements(d->'people') p
  where upper(p->>'apPat') = 'ALVAREZ'
    and upper(p->>'nombre') like 'PEDRO%';

  if pid is null then
    raise exception 'No se encontró a Pedro Álvarez en people';
  end if;

  foreach code in array proc_codes loop
    if d #> array['cells', pid, code] is null then
      raise exception 'No existe la celda cells.%.%', pid, code;
    end if;
    -- '||' fusiona: conserva dif y difDate, sobrescribe ev/evNota/evDate
    d := jsonb_set(d, array['cells', pid, code],
                   (d #> array['cells', pid, code]) || eval_patch);
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Pedro Álvarez (%): nota 100 en 3.8.3.9..3.8.3.16 con fecha 2026-09-01', pid;
end $$;

-- Verificación
-- select k as proc, v
-- from dashboard_state,
--      lateral jsonb_each(data #> array['cells', 'p1']) as e(k, v)
-- where id = 'ops_ppt' and k like '3.8.3.%';
