----
-- Corrige la fecha de difusion de 3.8.3.16 "Recuperacion de Concentrado de Piscinas".
--
-- El documento se aprobo el 05/08/2026, pero la difusion quedo registrada el
-- 20/07/2026, o sea antes de que el documento existiera. Segun el criterio de
-- la planilla SNGM esa difusion corresponde a una version anterior y no sirve.
--
-- Fecha real de difusion informada: 07/08/2026.
-- El bloque aborta si la fecha es anterior al 2026-08-05 (fecha de aprobacion).
--
-- Solo se toca 3.8.3.16, y solo dif/difDate. La evaluacion no se toca.
-- No se le crea difusion a quien no la tenia: si la celda esta pendiente,
-- se deja pendiente, porque corregir una fecha no es lo mismo que difundir.

do $$
declare
  nueva_fecha constant text := '2026-08-07';   -- fecha real de difusion
  aprobacion  constant date := '2026-08-05';
  code        constant text := '3.8.3.16';
  d           jsonb;
  pid         text;
  celda       jsonb;
  n_cor       int := 0;
  n_pend      int := 0;
begin
  if nueva_fecha::date < aprobacion then
    raise exception 'La fecha % es anterior a la aprobacion del documento (%). No se escribio nada.',
                    nueva_fecha, aprobacion;
  end if;

  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  for pid in select p->>'id' from jsonb_array_elements(d->'people') p
  loop
    celda := d #> array['cells', pid, code];

    -- sin difusion registrada -> se deja como esta
    if celda is null
       or celda->>'dif' <> 'ok'
       or nullif(celda->>'difDate','') is null then
      n_pend := n_pend + 1;
      continue;
    end if;

    -- ya tiene una fecha valida -> no se toca
    if (celda->>'difDate')::date >= aprobacion then
      continue;
    end if;

    d := jsonb_set(d, array['cells', pid, code],
                   celda || jsonb_build_object('difDate', nueva_fecha),
                   true);
    n_cor := n_cor + 1;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % difusiones de % corregidas a %; % quedaron pendientes y sin tocar',
               n_cor, code, nueva_fecha, n_pend;
end $$;
