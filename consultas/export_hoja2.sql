----
-- Exportacion para la Hoja 2 del libro SNGM (difusion y evaluacion).
-- Solo lectura. Descarga el resultado como CSV desde el editor de Supabase.
--
-- Formato de salida igual al de la planilla modelo:
--   fecha_difusion        -> dd/mm/aaaa   o  PENDIENTE
--   fecha_evaluacion_nota -> dd/mm/aaaa / 100%   o  PENDIENTE
--
-- La grilla de 31 procedimientos se arma aqui y se cruza con LEFT JOIN, para
-- que una celda ausente en la base salga PENDIENTE (que es como la muestra la
-- app, que rellena con fillDefaults al cargar).
with proc as (
  select '3.8.1.' || i as code, 1 as proceso, i as nro from generate_series(1,7)  i
  union all select '3.8.2.' || i, 2, i from generate_series(1,8)  i
  union all select '3.8.3.' || i, 3, i from generate_series(1,16) i
),
persona as (
  select p->>'id' as pid,
         p->>'g'  as turno,
         regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                        '\s+', ' ', 'g') || ', ' || coalesce(p->>'nombre','') as trabajador,
         s.data #> array['cells', p->>'id'] as celdas
  from dashboard_state s, lateral jsonb_array_elements(s.data->'people') p
  where s.id = 'ops_ppt'
)
select persona.pid,
       persona.turno,
       persona.trabajador,
       proc.code,
       case
         when (persona.celdas -> proc.code ->> 'dif') = 'ok'
          and nullif(persona.celdas -> proc.code ->> 'difDate','') is not null
         then to_char((persona.celdas -> proc.code ->> 'difDate')::date, 'DD/MM/YYYY')
         else 'PENDIENTE'
       end as fecha_difusion,
       case
         when (persona.celdas -> proc.code ->> 'ev') = 'ok'
          and nullif(persona.celdas -> proc.code ->> 'evDate','') is not null
         then to_char((persona.celdas -> proc.code ->> 'evDate')::date, 'DD/MM/YYYY')
              || coalesce(' / ' || nullif(persona.celdas -> proc.code ->> 'evNota','') || '%', '')
         else 'PENDIENTE'
       end as fecha_evaluacion_nota
from persona cross join proc
order by persona.turno, persona.trabajador, proc.proceso, proc.nro;
