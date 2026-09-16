----
-- Resumen por turno (la cabecera del correo). Misma logica de conteo.
with proc as (
  select '3.8.1.' || i as code, 1 as proceso from generate_series(1,7)  i
  union all select '3.8.2.' || i, 2 from generate_series(1,8)  i
  union all select '3.8.3.' || i, 3 from generate_series(1,16) i
),
persona as (
  select p->>'id' as pid, p->>'g' as turno,
         s.data #> array['cells', p->>'id'] as celdas
  from dashboard_state s, lateral jsonb_array_elements(s.data->'people') p
  where s.id = 'ops_ppt'
),
marcada as (
  select persona.turno, persona.pid, proc.proceso,
         (  (persona.celdas -> proc.code ->> 'ev') = 'ok'
            and ( nullif(persona.celdas -> proc.code ->> 'evNota','') is null
                  or ( (persona.celdas -> proc.code ->> 'evNota') ~ '^[0-9]+([.][0-9]+)?$'
                       and (persona.celdas -> proc.code ->> 'evNota')::numeric >= 60 ) )
         ) as ok
  from persona cross join proc
)
select coalesce(turno, 'TOTAL')                        as turno,
       count(distinct pid)                             as trabajadores,
       count(*) filter (where ok)                      as hechas,
       count(*)                                        as total,
       round(100.0 * count(*) filter (where ok) / count(*))::int || '%' as avance,
       count(*) filter (where not ok or ok is null)    as faltan,
       count(distinct pid) filter (where not ok or ok is null) as con_pendientes
from marcada
group by rollup (turno)
order by turno nulls last;
