----
-- Completa la DIFUSION que falta con fecha 2026-07-20 (20/07/2026).
--
-- Solo rellena huecos: una celda que ya tiene difusion con fecha se deja tal
-- cual, sea cual sea esa fecha. Se considera "falta" cuando dif <> 'ok' o la
-- difDate esta vacia, y tambien cuando la celda no existe en la base (la app
-- las rellena con fillDefaults() al cargar, asi que en pantalla salen sin
-- difundir).
--
-- Quedan fuera Leonardo Saavedra y Cristopher Santibanez: no se les toca nada.
-- El '_' en SANTIBA_EZ es comodin de un caracter: calza con o sin enie.
--
-- Solo se tocan dif y difDate. Las evaluaciones (ev, evNota, evDate) se conservan.

do $$
declare
  fecha_dif  constant text := '2026-07-20';
  proc_codes text[];
  excluidos  text[];
  d          jsonb;
  pid        text;
  code       text;
  celda      jsonb;
  n_cells    int := 0;
  n_ya       int := 0;
begin
  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  -- grilla de 31 procedimientos
  select array_agg(c order by p, n)
    into proc_codes
  from (
    select '3.8.1.' || i as c, 1 as p, i as n from generate_series(1,7)  i
    union all select '3.8.2.' || i, 2, i from generate_series(1,8)  i
    union all select '3.8.3.' || i, 3, i from generate_series(1,16) i
  ) t;

  -- ids a excluir: Leonardo Saavedra y Cristopher Santibanez
  select array_agg(p->>'id')
    into excluidos
  from jsonb_array_elements(d->'people') p
  where (upper(regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                             '\s+', ' ', 'g')) like 'SAAVEDRA%'
         and upper(coalesce(p->>'nombre','')) like 'LEONARDO%')
     or (upper(regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                             '\s+', ' ', 'g')) like 'SANTIBA_EZ%'
         and upper(coalesce(p->>'nombre','')) like 'CRISTOPHER%');

  if excluidos is null or array_length(excluidos,1) <> 2 then
    raise exception 'Esperaba excluir exactamente 2 personas (Saavedra y Santibanez), encontre %',
                    coalesce(array_length(excluidos,1), 0);
  end if;
  raise notice 'Excluidos (no se tocan): %', array_to_string(excluidos, ', ');

  -- mismo motivo: si no existiera el objeto 'cells', nada de abajo se grabaria
  if d->'cells' is null then
    d := jsonb_set(d, array['cells'], '{}'::jsonb, true);
  end if;

  for pid in select p->>'id' from jsonb_array_elements(d->'people') p
  loop
    if pid = any(excluidos) then
      continue;
    end if;

    -- jsonb_set con create_missing solo crea el ULTIMO nivel de la ruta: si
    -- 'cells.<pid>' no existe, escribir 'cells.<pid>.<code>' no hace nada y
    -- falla en silencio. Por eso la fila del trabajador se crea antes.
    if d #> array['cells', pid] is null then
      d := jsonb_set(d, array['cells', pid], '{}'::jsonb, true);
      raise notice 'Se creo la fila de celdas de % (no existia en la base)', pid;
    end if;

    foreach code in array proc_codes loop
      celda := d #> array['cells', pid, code];

      -- ya difundida con fecha -> no se toca
      if celda is not null
         and celda->>'dif' = 'ok'
         and nullif(celda->>'difDate','') is not null then
        n_ya := n_ya + 1;
        continue;
      end if;

      -- '||' fusiona: escribe dif/difDate y conserva ev, evNota y evDate
      d := jsonb_set(d, array['cells', pid, code],
                     coalesce(celda, '{}'::jsonb)
                       || jsonb_build_object('dif', 'ok', 'difDate', fecha_dif),
                     true);
      n_cells := n_cells + 1;
    end loop;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % celdas completadas con difusion al %; % ya la tenian y quedaron intactas',
               n_cells, fecha_dif, n_ya;
end $$;
