-- Embarque (3.8.2): nota 100 en las 8 evaluaciones (3.8.2.1 .. 3.8.2.8, el proceso completo)
-- Trabajador: Victor Jofre   |   Fecha de evaluacion: 2026-09-06
--
-- El id no se hardcodea: se resuelve por apellido paterno + nombre.
-- Si no resuelve a exactamente una persona, el bloque aborta sin escribir nada.
-- Solo se tocan ev, evNota y evDate. La difusion (dif, difDate) se conserva.

do $$
declare
  proc_codes text[] := array['3.8.2.1','3.8.2.2','3.8.2.3','3.8.2.4',
                             '3.8.2.5','3.8.2.6','3.8.2.7','3.8.2.8'];
  eval_patch jsonb := '{"ev":"ok","evNota":100,"evDate":"2026-09-06"}'::jsonb;
  d          jsonb;
  pid        text;
  n_match    int;
  code       text;
  n_cells    int := 0;
begin
  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  select count(*), min(p->>'id')
    into n_match, pid
  from jsonb_array_elements(d->'people') p
  where upper(p->>'apPat') = 'JOFRE'
    and upper(p->>'nombre') like 'VICTOR%';

  if n_match = 0 then
    raise exception 'No se encontro a Victor Jofre en people';
  elsif n_match > 1 then
    raise exception 'Ambiguo: % personas coinciden con JOFRE, VICTOR%%', n_match;
  end if;

  foreach code in array proc_codes loop
    -- coalesce: si la celda no existiera, la crea; si existe, conserva dif/difDate
    d := jsonb_set(d, array['cells', pid, code],
                   coalesce(d #> array['cells', pid, code], '{}'::jsonb) || eval_patch,
                   true);
    n_cells := n_cells + 1;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Victor Jofre (%): nota 100 en 3.8.2.1..3.8.2.8 con fecha 2026-09-06 (% celdas)',
               pid, n_cells;
end $$;
