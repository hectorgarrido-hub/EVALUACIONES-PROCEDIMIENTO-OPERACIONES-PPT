-- verificador de RUT (modulo 11)
create or replace function rut_dv(cuerpo text) returns text language plpgsql immutable as $f$
declare s int := 0; peso int := 2; i int; c text;
begin
  cuerpo := regexp_replace(cuerpo, '[^0-9]', '', 'g');
  if cuerpo = '' then return null; end if;
  for i in reverse length(cuerpo)..1 loop
    s := s + (substr(cuerpo, i, 1))::int * peso;
    peso := case when peso = 7 then 2 else peso + 1 end;
  end loop;
  i := 11 - (s % 11);
  return case i when 11 then '0' when 10 then 'K' else i::text end;
end $f$;
