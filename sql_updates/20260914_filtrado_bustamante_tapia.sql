----
-- Filtrado (3.8.3): nota 100, cada trabajador con SU tramo y SU fecha
--   Elias Bustamante -> 3.8.3.1 .. 3.8.3.8    fecha 2026-09-09
--   Esteban Tapia    -> 3.8.3.9 .. 3.8.3.16   fecha 2026-09-04
--
-- A diferencia de los scripts anteriores, el tramo de procedimientos tambien
-- viaja por trabajador (cuarta columna de la lista), no es uno solo para todos.
--
-- TAPIA aparece dos veces en la nomina (Cristian Omar, G1 / Esteban German, G4),
-- por eso se filtra tambien por nombre. Los '_' (EL_AS) son comodines de un
-- caracter: calzan con o sin tilde, y mantienen el script libre de acentos.
--
-- Si un nombre no resuelve a exactamente una persona, el bloque aborta sin
-- escribir nada. Solo se tocan ev, evNota y evDate; la difusion se conserva.

do $$
declare
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
      ('BUSTAMANTE %', 'EL_AS%',   '2026-09-09',
       array['3.8.3.1','3.8.3.2','3.8.3.3','3.8.3.4',
             '3.8.3.5','3.8.3.6','3.8.3.7','3.8.3.8']),
      ('TAPIA %',      'ESTEBAN%', '2026-09-04',
       array['3.8.3.9','3.8.3.10','3.8.3.11','3.8.3.12',
             '3.8.3.13','3.8.3.14','3.8.3.15','3.8.3.16'])
    ) as t(ap_like, nombre_like, eval_date, proc_codes)
  loop
    select count(*), min(p->>'id')
      into n_match, pid
    from jsonb_array_elements(d->'people') p
    where upper(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')) like w.ap_like
      and upper(coalesce(p->>'nombre','')) like w.nombre_like;

    if n_match = 0 then
      raise exception 'No se encontro a "%" con nombre "%" en people', w.ap_like, w.nombre_like;
    elsif n_match > 1 then
      raise exception 'Ambiguo: % personas coinciden con "%" / "%"', n_match, w.ap_like, w.nombre_like;
    end if;

    eval_patch := jsonb_build_object('ev', 'ok', 'evNota', 100, 'evDate', w.eval_date);

    foreach code in array w.proc_codes loop
      -- coalesce: si la celda no existiera, la crea; si existe, conserva dif/difDate
      d := jsonb_set(d, array['cells', pid, code],
                     coalesce(d #> array['cells', pid, code], '{}'::jsonb) || eval_patch,
                     true);
      n_cells := n_cells + 1;
    end loop;

    raise notice 'OK  % (%) -> nota 100 en % .. % con fecha %',
                 rpad(w.ap_like, 14), pid,
                 w.proc_codes[1], w.proc_codes[array_length(w.proc_codes,1)], w.eval_date;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % celdas actualizadas', n_cells;
end $$;
