----
-- Carga los RUT desde la planilla Hector.xlsx.
--
-- Bloque autocontenido: calcula el digito verificador aqui mismo, no necesita
-- crear ninguna funcion antes.
--
-- 31 de los 36 trabajadores del dashboard aparecen en la planilla. Los cinco
-- que no: Rebolledo (p0), Kunz (p9) y Martinez (p19), que ya se cargaron
-- aparte, y Saavedra (p28) y Varas (p37), que no estan en el listado.
--
-- Los 31 verificadores de la planilla se validaron y estan correctos; el
-- script igual los revisa antes de escribir. Si alguno estuviera malo, no
-- escribe nada y dice cual es y cual corresponde.
--
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
  s          int;
  peso       int;
  i          int;
begin
  ------------------------------------------------------------------
  -- LISTA: pid -> rut   (una sola vez; se usa para validar y escribir)
  ------------------------------------------------------------------
  select jsonb_agg(jsonb_build_object('pid', pid, 'rut', rut))
    into pares
  from (values
      ('p1',   '15.612.089-8'), -- ALVAREZ PEREZ, PEDRO LUIS
      ('p2',   '11.326.446-2'), -- FRITIS ZALAZAR, ROBERTO ENRIQUE
      ('p3',   '17.606.185-5'), -- HIDALGO GARCIA, JULIO ELIAS
      ('p4',   '16.602.101-4'), -- HERRERA AGUILERA, ALEJANDRO ANDRES
      ('p5',   '11.439.946-9'), -- DONOSO BORQUEZ, HERNAN GUSTAVO
      ('p6',   '18.403.704-1'), -- TAPIA LOBOS, CRISTIAN OMAR
      ('p7',   '20.502.538-3'), -- CALDERÓN GALLARDO, LISSETTE CONSUELO
      ('p10',  '15.070.549-5'), -- SANTIBAÑEZ BAHAMONDES, CRISTOPHER NICOLA
      ('p11',  '11.748.137-9'), -- BUSTAMANTE ROJAS, ELIAS BALDOMERO
      ('p12',  '17.302.213-1'), -- OVIEDO FERNANDEZ, MARCO ANDRE
      ('p13',  '15.913.813-5'), -- VALDES ROJAS, JOSE ROBERTO
      ('p14',  '19.352.719-1'), -- FUENTES FUENTES, MATIAS IGNACIO
      ('p15',  '17.302.695-1'), -- BARAHONA CASTILLO, MAURICIO ANDRES
      ('p16',  '11.724.812-7'), -- DIAZ VEGA, CRISTIAN HOMERO
      ('p17',  '15.633.680-7'), -- DE LA FUENTE CISTERNA, CRISTOBAL FELIPE
      ('p18',  '16.821.701-3'), -- JOFRE DELGADO, VICTOR ALEJANDRO
      ('p20',  '18.211.987-3'), -- MUÑOZ BARRIA, OSVALDO IGNACIO
      ('p21',  '14.114.592-4'), -- IBACETA GARCIA, JUAN ALEJANDRO
      ('p22',  '19.124.925-9'), -- CISTERNAS AGUIRRE, LUIS FELIPE
      ('p23',  '17.294.689-5'), -- COLLAO LABARCA, RODRIGO EDUARDO
      ('p24',  '15.033.441-1'), -- CASTILLO OLGUIN, DARIO ANTONIO
      ('p25',  '14.151.103-3'), -- VEGA HERRERA, JORGE ANGELO
      ('p26',  '12.444.781-K'), -- ESCOBAR RUBINA, ROBERTO MAURICIO
      ('p27',  '21.870.635-5'), -- DAZA BERTICHEVIC, RODRIGO
      ('p29',  '15.870.483-8'), -- BOWN HERRERA, JAMES JHON JAN-SIN
      ('p30',  '13.358.835-3'), -- GALLEGUILLOS ARAYA, OSVALDO ARTURO
      ('p31',  '15.031.548-4'), -- BARLARO PODETTI, JULIO ANDRES
      ('p32',  '17.902.171-4'), -- VARGAS ROMO, FERNANDO ILDEFONSO
      ('p33',  '18.138.905-2'), -- BARAHONA CASTILLO, ALEX NICOLAS
      ('p34',  '18.399.063-2'), -- CARVAJAL SALINAS, JEAN MARIO
      ('p35',  '18.845.157-8')  -- TAPIA LOBOS, ESTEBAN GERMAN
  ) as t(pid, rut);
  ------------------------------------------------------------------

  select data into d from dashboard_state where id = 'ops_ppt';
  if d is null then
    raise exception 'No existe la fila dashboard_state con id = ops_ppt';
  end if;

  -- 1) validar TODO antes de tocar nada
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

    -- digito verificador por modulo 11, de derecha a izquierda con pesos 2..7
    s := 0;
    peso := 2;
    for i in reverse length(cuerpo)..1 loop
      s := s + (substr(cuerpo, i, 1))::int * peso;
      peso := case when peso = 7 then 2 else peso + 1 end;
    end loop;
    i := 11 - (s % 11);
    dv_ok := case i when 11 then '0' when 10 then 'K' else i::text end;

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
  end loop;

  update dashboard_state
     set data = d, updated_at = now()
   where id = 'ops_ppt';

  raise notice 'Listo: % RUT cargados desde la planilla', n;
end $$;
