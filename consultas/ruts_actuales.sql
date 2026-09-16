----
-- RUT cargados hoy, y si el digito verificador calza.
-- Solo lectura. Autocontenida: calcula el verificador con una lateral, no
-- necesita crear la funcion rut_dv.
select p->>'id' as pid,
       p->>'g'  as turno,
       regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                      '\s+', ' ', 'g') || ', ' || coalesce(p->>'nombre','') as trabajador,
       coalesce(nullif(p->>'rut',''), '(vacio)') as rut,
       case
         when limpio is null or limpio = '' then 'sin rut'
         when limpio !~ '^[0-9]{7,8}[0-9K]$' then 'formato raro'
         when right(limpio, 1) = dv then 'ok'
         else 'DV INCORRECTO -> deberia ser ' || dv
       end as estado
from dashboard_state s,
     lateral jsonb_array_elements(s.data->'people') p,
     lateral (select upper(regexp_replace(coalesce(p->>'rut',''), '[^0-9kK]', '', 'g'))) as a(limpio),
     lateral (
       select case (11 - (sum((substr(left(limpio,-1), i, 1))::int
                              * (2 + (length(left(limpio,-1)) - i) % 6))) % 11)
                when 11 then '0' when 10 then 'K'
                else (11 - (sum((substr(left(limpio,-1), i, 1))::int
                                * (2 + (length(left(limpio,-1)) - i) % 6))) % 11)::text end
       from generate_series(1, length(left(limpio,-1))) i
       where left(limpio,-1) ~ '^[0-9]+$'
     ) as b(dv)
where s.id = 'ops_ppt'
order by turno, trabajador;
