----
-- Filtrado (3.8.3): nota 100 en las 16 evaluaciones (3.8.3.1 .. 3.8.3.16)
--   Victor Jofre            -> 2026-09-06
--   Cristobal de la Fuente  -> 2026-09-07
--
-- OJO con de la Fuente: el dashboard parte el apellido por espacios y guarda
-- solo el primer token en apPat, asi que su registro quedo como
--   apPat = 'DE'   apMat = 'LA FUENTE CISTERNA'
-- Por eso no se compara apPat solo, sino el apellido completo
-- (apPat || ' ' || apMat), que funciona tanto con el dato como esta hoy como
-- si alguien corrige el apPat a mano mas adelante.
--
-- El '_' en CRIST_BAL y V_CTOR es un comodin de un caracter: calza con o sin
-- tilde. Asi el script no lleva ningun acento adentro y no depende de como el
-- editor maneje la codificacion al pegarlo.
--
-- Si un nombre no resuelve a exactamente una persona, el bloque aborta sin
-- escribir nada. Solo se tocan ev, evNota y evDate; la difusion se conserva.

do $$
declare
  proc_codes text[] := array['3.8.3.1','3.8.3.2','3.8.3.3','3.8.3.4',
                             '3.8.3.5','3.8.3.6','3.8.3.7','3.8.3.8',
                             '3.8.3.9','3.8.3.10','3.8.3.11','3.8.3.12',
                             '3.8.3.13','3.8.3.14','3.8.3.15','3.8.3.16'];
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
      ('JOFRE %',         'V_CTOR%',    '2026-09-06'),
      ('DE LA FUENTE %',  'CRIST_BAL%', '2026-09-07')
    ) as t(ap_like, nombre_like, eval_date)
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

    foreach code in array proc_codes loop
      -- coalesce: si la celda no existiera, la crea; si existe, conserva dif/difDate
      d := jsonb_set(d, array['cells', pid, code],
                     coalesce(d #> array['cells', pid, code], '{}'::jsonb) || eval_patch,
                     true);
      n_cells := n_cells + 1;
    end loop;

    raise notice 'OK  % (%) -> nota 100 en 3.8.3.1..3.8.3.16 con fecha %',
                 rpad(w.ap_like, 15), pid, w.eval_date;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % celdas actualizadas (2 trabajadores x 16 procedimientos)', n_cells;
end $$;
