/*
Archivo: db/queries_agg_team_E.sql
Propósito: Reportes de agregación para Clase 4 (GROUP BY, HAVING, subconsultas) + VERIFY.
Cómo ejecutar (ajusta usuario, db y contenedor):
  docker compose ps
  docker exec -i <postgres_container> psql -U <user> -d <db> < db/queries_agg_team_E.sql

Regla "evidence mindset":
- Cada reporte declara el grain (una fila representa qué).
- Cada reporte incluye VERIFY con consultas de control.
*/

/*
REPORTE 1: Top 7 categorias por monto de ventas
Qué devuelve: Las 7 categorias con mayor total de ventas (suma de los subtotales).
Grain (una fila representa): Una categoria.
Métrica(s): SUM(orden_detalles.subtotal)
Por qué GROUP BY: para sumar las ventas por categoria.
*/

-- QUERY
SELECT
  c.id AS categoria_id,
  c.nombre AS categoria_nombre,
  SUM(od.subtotal) AS total_ventas
FROM categorias c
JOIN productos p ON p.categoria_id = c.id
JOIN orden_detalles od ON od.producto_id = p.id
JOIN ordenes o ON od.orden_id = o.id  
WHERE o.status IN ('pagado', 'enviado' 'entregado'),
GROUP BY c.id, c.nombre
ORDER BY total_ventas DESC
LIMIT 7;

-- VERIFY: Conteo de filas del top N (debe ser 7 o menos).
SELECT COUNT(*) AS filas
FROM (
  SELECT c.id
  FROM categorias c
  JOIN productos p ON p.categoria_id = c.id
  JOIN orden_detalles od ON od.producto_id = p.id
  GROUP BY c.id, c.nombre
  ORDER BY SUM(od.subtotal) DESC
  LIMIT 7
) t;

-- VERIFY: Recalculo del total para la categoria top.
WITH top AS (
  SELECT c.id AS categoria_id, SUM(od.subtotal) AS total_ventas
  FROM categorias c
  JOIN productos p ON p.categoria_id = c.id
  JOIN orden_detalles od ON od.producto_id = p.id
  GROUP BY c.id
  ORDER BY SUM(od.subtotal) DESC
  LIMIT 1
)
SELECT
  t.categoria_id,
  t.total_ventas,
  SUM(od.subtotal) AS recompute_total
FROM top t
JOIN productos p ON p.categoria_id = t.categoria_id
JOIN orden_detalles od ON od.producto_id = p.id
GROUP BY t.categoria_id, t.total_ventas;

-- REPORTE 2: Clientes con gasto > $500 y al menos 2 items
/*
GRAIN: Una fila representa un Usuario.
METRICAS: Gasto Histórico Total.
USO DE GROUP BY, HAVING Y WHERE:
  - WHERE: Filtra órdenes válidas (no canceladas).
  - GROUP BY: Agrupa toda la actividad por usuario.
  - HAVING: Filtra el resultado de la agrupación (Gasto > 500).
*/

SELECT 
    u.id,
    u.nombre,
    u.email,
    COUNT(DISTINCT o.id) as ordenes_totales,
    SUM(o.total) as gasto_historico
FROM usuarios u
JOIN ordenes o ON o.usuario_id = u.id
WHERE o.status <> 'cancelado'
GROUP BY u.id, u.nombre, u.email
HAVING SUM(o.total) > 500.00
ORDER BY gasto_historico DESC;

-- Verify 1: Check de Totales
SELECT COUNT(*) as cantidad_big_spenders FROM (
    SELECT u.id 
    FROM usuarios u 
    JOIN ordenes o ON o.usuario_id = u.id 
    WHERE o.status <> 'cancelado' 
    GROUP BY u.id 
    HAVING SUM(o.total) > 500
) t;

-- Verify 2 Usuario Margaret - ID 5
-- Verificamos si la suma de sus órdenes en la tabla 'ordenes' coincide con el reporte.
SELECT 
    usuario_id, 
    SUM(total) as suma_tabla_ordenes,
    'Debe coincidir con reporte' as validacion
FROM ordenes
WHERE usuario_id = 5 AND status <> 'cancelado'
GROUP BY usuario_id;

-- REPORTE 3: Usuarios Inactivos (LEFT JOIN)
/*
GRAIN: Una fila representa un Usuario que no ha tenido actividad de compra.
MÉTRICA: No aplica métrica numérica, es un listado de exclusión.
JUSTIFICACIÓN:
 - Se usa LEFT JOIN filtrando por fecha (últimos 60 días) en el ON.
 - Se usa WHERE o.id IS NULL para filtrar solo aquellos donde el JOIN falló (no hubo compra).
*/

-- 1. QUERY PRINCIPAL
SELECT
  u.id AS usuario_id,
  u.nombre AS usuario_nombre,
  u.email
FROM usuarios u
LEFT JOIN ordenes o
  ON o.usuario_id = u.id
  AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
WHERE o.id IS NULL
ORDER BY u.id;

-- 2. VERIFY (Evidence Mindset)
-- Tomamos al primer usuario que salió en la lista de inactivos (LIMIT 1)
-- y contamos manualmente cuántas órdenes tiene en los últimos 60 días.
-- El resultado DEBE ser 0 y la validación debe decir "CORRECTO".

WITH inactivos AS (
  SELECT u.id 
  FROM usuarios u
  LEFT JOIN ordenes o ON o.usuario_id = u.id AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
  WHERE o.id IS NULL
  LIMIT 1
)
SELECT 
    i.id as usuario_id_verificado,
    COUNT(o.id) as ordenes_encontradas_ultimos_60_dias,
    CASE WHEN COUNT(o.id) = 0 THEN 'CORRECTO: Es inactivo' ELSE 'ERROR: Tiene órdenes' END as validacion
FROM inactivos i
LEFT JOIN ordenes o ON o.usuario_id = i.id AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
GROUP BY i.id;