-- Embarque (3.8.2): nota 100 en las 8 evaluaciones (3.8.2.1 .. 3.8.2.8, el proceso completo)
-- Fecha de evaluacion: 2026-09-01
-- Trabajadores: Esteban Tapia, Osvaldo Galleguillos, Jean Carvajal, Gabriela Varas,
--               James Bown, Fernando Vargas, Julio Barlaro, Alex Barahona
--
-- Los ids (p0, p1, ...) no se hardcodean: se resuelven por apellido paterno + nombre.
-- Es imprescindible aqui porque hay apellidos repetidos en la nomina:
--   TAPIA    -> Cristian Omar (G1)  y  Esteban German (G4)
--   BARAHONA -> Mauricio Andres (G2) y  Alex Nicolas  (G4)
-- Si un nombre no resuelve a exactamente una persona, el script aborta sin escribir nada.
--
-- Solo se tocan los campos de evaluacion (ev, evNota, evDate).
-- La difusion (dif, difDate) se conserva porque se fusiona con '||'.

do $$
declare
  proc_codes text[] := array['3.8.2.1','3.8.2.2','3.8.2.3','3.8.2.4',
                             '3.8.2.5','3.8.2.6','3.8.2.7','3.8.2.8'];
  eval_patch jsonb := '{"ev":"ok","evNota":100,"evDate":"2026-09-01"}'::jsonb;
  d          jsonb;
  w          record;
  pid        text;
  n_match    int;
  code       text;
  n_cells    int := 0;
begin
  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  for w in
    select * from (values
      ('TAPIA',        'ESTEBAN%'),
      ('GALLEGUILLOS', 'OSVALDO%'),
      ('CARVAJAL',     'JEAN%'),
      ('VARAS',        'GABRIELA%'),
      ('BOWN',         'JAMES%'),
      ('VARGAS',       'FERNANDO%'),
      ('BARLARO',      'JULIO%'),
      ('BARAHONA',     'ALEX%')
    ) as t(ap_pat, nombre_like)
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

    foreach code in array proc_codes loop
      -- coalesce: si la celda no existiera, la crea; si existe, conserva dif/difDate
      d := jsonb_set(d, array['cells', pid, code],
                     coalesce(d #> array['cells', pid, code], '{}'::jsonb) || eval_patch,
                     true);
      n_cells := n_cells + 1;
    end loop;

    raise notice 'OK  % (%) -> nota 100 en 3.8.2.1..3.8.2.8', rpad(w.ap_pat, 13), pid;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % celdas actualizadas (8 trabajadores x 8 procedimientos)', n_cells;
end $$;
