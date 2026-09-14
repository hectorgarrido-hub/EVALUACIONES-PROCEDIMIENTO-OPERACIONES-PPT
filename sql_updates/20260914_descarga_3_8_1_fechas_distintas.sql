-- Descarga, Recepcion y Apilamiento (3.8.1): nota 100 en las 7 evaluaciones
-- (3.8.1.1 .. 3.8.1.7, el proceso completo)
--
-- Cada trabajador lleva SU PROPIA fecha de evaluacion:
--   Victor Jofre    -> 2026-09-06
--   Esteban Tapia   -> 2026-09-03
--   Marco Oviedo    -> 2026-09-09
--
-- Los ids no se hardcodean: se resuelven por apellido paterno + nombre.
-- TAPIA aparece dos veces en la nomina (Cristian Omar, G1 / Esteban German, G4),
-- por eso se filtra tambien por nombre. Si un nombre no resuelve a exactamente
-- una persona, el bloque aborta sin escribir nada.
--
-- Solo se tocan ev, evNota y evDate. La difusion (dif, difDate) se conserva.

do $$
declare
  proc_codes text[] := array['3.8.1.1','3.8.1.2','3.8.1.3','3.8.1.4',
                             '3.8.1.5','3.8.1.6','3.8.1.7'];
  d          jsonb;
  w          record;
  pid        text;
  n_match    int;
  code       text;
  eval_patch jsonb;
  n_cells    int := 0;
begin
  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  for w in
    select * from (values
      ('JOFRE',  'VICTOR%',  '2026-09-06'),
      ('TAPIA',  'ESTEBAN%', '2026-09-03'),
      ('OVIEDO', 'MARCO%',   '2026-09-09')
    ) as t(ap_pat, nombre_like, eval_date)
  loop
    select count(*), min(p->>'id')
      into n_match, pid
    from jsonb_array_elements(d->'people') p
    where upper(p->>'apPat') = w.ap_pat
      and upper(p->>'nombre') like w.nombre_like;

    if n_match = 0 then
      raise exception 'No se encontro a %, % en people', w.ap_pat, w.nombre_like;
    elsif n_match > 1 then
      raise exception 'Ambiguo: % personas coinciden con %, %', n_match, w.ap_pat, w.nombre_like;
    end if;

    eval_patch := jsonb_build_object('ev', 'ok', 'evNota', 100, 'evDate', w.eval_date);

    foreach code in array proc_codes loop
      -- coalesce: si la celda no existiera, la crea; si existe, conserva dif/difDate
      d := jsonb_set(d, array['cells', pid, code],
                     coalesce(d #> array['cells', pid, code], '{}'::jsonb) || eval_patch,
                     true);
      n_cells := n_cells + 1;
    end loop;

    raise notice 'OK  % (%) -> nota 100 en 3.8.1.1..3.8.1.7 con fecha %',
                 rpad(w.ap_pat, 8), pid, w.eval_date;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % celdas actualizadas (3 trabajadores x 7 procedimientos)', n_cells;
end $$;
