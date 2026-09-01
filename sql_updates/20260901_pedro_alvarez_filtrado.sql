-- Update Pedro Álvarez (p1) with nota 100 for the last 8 evaluations of Filtrado (3.8.3.9-3.8.3.16)
-- Date: 01-09-2026
-- Worker: Pedro Álvarez (id: p1, index: 1 in workers array)
-- Procedures: 3.8.3.9 through 3.8.3.16 (indices 8-15 in PROCS array)
-- Nota: 100
-- Date: 2026-09-01

do $
declare
  current_cells jsonb;
  eval_obj jsonb := '{"ev":"ok","evNota":100,"evDate":"2026-09-01"}'::jsonb;
  i integer;
begin
  -- Get current cells
  select cells into current_cells from dashboard_state where id = 1;
  
  -- Update each procedure (indices 8-15 for 3.8.3.9-3.8.3.16)
  -- Worker index is 1 (p1 = Pedro Álvarez)
  for i in 8..15 loop
    current_cells := jsonb_set(current_cells, array[i::text, '1'], eval_obj);
  end loop;
  
  -- Update the database
  update dashboard_state set cells = current_cells where id = 1;
  
  raise notice 'Successfully updated Pedro Álvarez with nota 100 for procedures 3.8.3.9-3.8.3.16 (date: 2026-09-01)';
end $;
