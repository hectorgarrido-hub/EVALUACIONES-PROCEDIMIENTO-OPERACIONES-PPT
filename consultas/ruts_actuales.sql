----
-- RUT cargados hoy, y si el digito verificador calza.
-- Solo lectura. Sirve para ver que falta y que esta malo antes de actualizar.
select p->>'id' as pid,
       p->>'g'  as turno,
       regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                      '\s+', ' ', 'g') || ', ' || coalesce(p->>'nombre','') as trabajador,
       coalesce(nullif(p->>'rut',''), '(vacio)') as rut,
       case
         when nullif(p->>'rut','') is null then 'sin rut'
         when upper(regexp_replace(p->>'rut', '[^0-9kK]', '', 'g')) !~ '^[0-9]{7,8}[0-9K]$' then 'formato raro'
         when upper(right(regexp_replace(p->>'rut', '[^0-9kK]', '', 'g'), 1))
              = rut_dv(left(regexp_replace(p->>'rut', '[^0-9kK]', '', 'g'), -1)) then 'ok'
         else 'DV INCORRECTO -> deberia ser '
              || rut_dv(left(regexp_replace(p->>'rut', '[^0-9kK]', '', 'g'), -1))
       end as estado
from dashboard_state s, lateral jsonb_array_elements(s.data->'people') p
where s.id = 'ops_ppt'
order by turno, trabajador;
