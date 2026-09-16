----
-- Carga / actualiza los RUT de los trabajadores.
--
-- COMO USARLO: llena la lista de abajo con pares (pid, rut). El rut puede ir
-- en cualquier formato: 12.345.678-5, 12345678-5 o 123456785; el script lo
-- normaliza a 12.345.678-5 antes de guardar.
--
-- Valida el digito verificador (modulo 11) de TODOS antes de escribir. Si uno
-- solo esta malo, no escribe nada y te dice cual es y cual seria el correcto.
-- Es a proposito: mas vale corregir la lista que dejar la mitad cargada.
--
-- Los pid son los que devolvio la consulta de control (p0..p37).
-- Solo se toca el campo rut; el resto de la ficha queda igual.

do $$
declare
  pares      jsonb;
  d          jsonb;
  reg        record;
  cuerpo     text;
  dv_dado    text;
  dv_ok      text;
  rut_fmt    text;
  errores    text[] := '{}';
  faltantes  text[] := '{}';
  n          int := 0;
begin
  ------------------------------------------------------------------
  -- LISTA: pid -> rut     (reemplaza estos ejemplos por los reales)
  ------------------------------------------------------------------
  pares := '[
    {"pid":"p0",  "rut":"11.111.111-1"},
    {"pid":"p1",  "rut":"12.345.678-5"},
    {"pid":"p29", "rut":"15.304.493-7"}
  ]'::jsonb;
  ------------------------------------------------------------------

  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  -- 1) validar todo antes de tocar nada
  for reg in select x->>'pid' as pid, x->>'rut' as rut from jsonb_array_elements(pares) x
  loop
    if not exists (select 1 from jsonb_array_elements(d->'people') p where p->>'id' = reg.pid) then
      faltantes := faltantes || reg.pid;
      continue;
    end if;

    cuerpo  := upper(regexp_replace(coalesce(reg.rut,''), '[^0-9kK]', '', 'g'));
    dv_dado := right(cuerpo, 1);
    cuerpo  := left(cuerpo, -1);

    if cuerpo !~ '^[0-9]{7,8}$' or dv_dado !~ '^[0-9K]$' then
      errores := errores || (reg.pid || ': "' || coalesce(reg.rut,'') || '" no parece un RUT');
      continue;
    end if;

    dv_ok := rut_dv(cuerpo);
    if dv_dado <> dv_ok then
      errores := errores || (reg.pid || ': "' || reg.rut || '" DV incorrecto, deberia ser -' || dv_ok);
    end if;
  end loop;

  if array_length(faltantes,1) > 0 then
    raise exception 'Estos pid no existen en people: %', array_to_string(faltantes, ', ');
  end if;
  if array_length(errores,1) > 0 then
    raise exception 'No se escribio nada. RUT con problemas:%',
                    chr(10) || '  ' || array_to_string(errores, chr(10) || '  ');
  end if;

  -- 2) recien ahora escribir
  for reg in select x->>'pid' as pid, x->>'rut' as rut from jsonb_array_elements(pares) x
  loop
    cuerpo  := upper(regexp_replace(reg.rut, '[^0-9kK]', '', 'g'));
    dv_dado := right(cuerpo, 1);
    cuerpo  := left(cuerpo, -1);
    rut_fmt := reverse(regexp_replace(reverse(cuerpo), '(\d{3})(?=\d)', '\1.', 'g')) || '-' || dv_dado;

    d := jsonb_set(d, '{people}', (
      select jsonb_agg(case when p->>'id' = reg.pid
                            then p || jsonb_build_object('rut', rut_fmt)
                            else p end)
      from jsonb_array_elements(d->'people') p));

    n := n + 1;
    raise notice 'OK  % -> %', rpad(reg.pid, 4), rut_fmt;
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % RUT actualizados', n;
end $$;
