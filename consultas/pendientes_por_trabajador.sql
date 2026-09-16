----
-- Evaluaciones pendientes por trabajador.
--
-- Cuenta igual que el dashboard: una evaluacion esta OK si ev='ok' y la nota
-- esta vacia o es >= 60. Nota bajo 60 = pendiente (hay que repetirla).
--
-- Importante: la grilla de 31 procedimientos se arma aqui, y las celdas se
-- cruzan con LEFT JOIN. Es a proposito: la app rellena con fillDefaults() las
-- celdas que no existen en la base, asi que una celda ausente (p.ej. 3.8.3.16,
-- que se agrego despues) cuenta como pendiente, igual que en pantalla.
with proc as (
  select '3.8.1.' || i as code, 1 as proceso, i as nro from generate_series(1,7)  i
  union all
  select '3.8.2.' || i,          2,           i        from generate_series(1,8)  i
  union all
  select '3.8.3.' || i,          3,           i        from generate_series(1,16) i
),
persona as (
  select p->>'id' as pid,
         p->>'g'  as turno,
         regexp_replace(trim(coalesce(p->>'apPat','') || ' ' || coalesce(p->>'apMat','')),
                        '\s+', ' ', 'g') || ', ' || coalesce(p->>'nombre','') as trabajador,
         p->>'cargo' as cargo,
         s.data #> array['cells', p->>'id'] as celdas
  from dashboard_state s, lateral jsonb_array_elements(s.data->'people') p
  where s.id = 'ops_ppt'
),
marcada as (
  select persona.turno, persona.trabajador, persona.cargo,
         proc.code, proc.proceso, proc.nro,
         (  (persona.celdas -> proc.code ->> 'ev') = 'ok'
            and ( nullif(persona.celdas -> proc.code ->> 'evNota','') is null
                  or ( (persona.celdas -> proc.code ->> 'evNota') ~ '^[0-9]+([.][0-9]+)?$'
                       and (persona.celdas -> proc.code ->> 'evNota')::numeric >= 60 ) )
         ) as ok
  from persona cross join proc
)
select turno,
       trabajador,
       cargo,
       count(*) filter (where ok)                     as hechas,
       count(*)                                       as total,
       round(100.0 * count(*) filter (where ok) / count(*))::int || '%' as avance,
       count(*) filter (where not ok or ok is null)   as faltan,
       count(*) filter (where (not ok or ok is null) and proceso = 1) as f_descarga,
       count(*) filter (where (not ok or ok is null) and proceso = 2) as f_embarque,
       count(*) filter (where (not ok or ok is null) and proceso = 3) as f_filtrado,
       coalesce(string_agg(code, ', ' order by proceso, nro)
                filter (where not ok or ok is null), '-')             as pendientes
from marcada
group by turno, trabajador, cargo
order by turno, count(*) filter (where not ok or ok is null) desc, trabajador;
