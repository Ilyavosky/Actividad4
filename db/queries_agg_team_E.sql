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
Qué devuelve: Las 7 categorias con mayor total de ventas (suma de subtotal).
Grain (una fila representa): Una categoria.
Métrica(s): SUM(orden_detalles.subtotal)
Por qué GROUP BY / HAVING / subconsulta: GROUP BY para sumar ventas por categoria.
*/

-- QUERY
SELECT
  c.id AS categoria_id,
  c.nombre AS categoria_nombre,
  SUM(od.subtotal) AS total_ventas
FROM categorias c
JOIN productos p ON p.categoria_id = c.id
JOIN orden_detalles od ON od.producto_id = p.id
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

/*
REPORTE 2: Clientes Top (Compras > $1000)
Qué devuelve: Usuarios cuyo gasto histórico acumulado supera los $1000. (más de un producto en una orden)
Grain (una fila representa): Un usuario único. (Solo existe un usuario con mas de 3 productos en una orden)
Métrica(s): SUM(ordenes.total) para ver el valor total gastado por el cliente.
Por qué HAVING: El filtro (> 1000) aplica sobre la SUMA total, un dato que no existe fila por fila, sino solo después de agrupar.
*/

-- QUERY
SELECT 
  u.id AS usuario_id,
  u.nombre AS usuario_nombre,
  u.email,
  COUNT(o.id) AS total_ordenes,
  SUM(o.total) AS gasto_historico
FROM usuarios u
JOIN ordenes o ON o.usuario_id = u.id
WHERE o.status IN ('pagado', 'entregado')
GROUP BY u.id, u.nombre, u.email
HAVING SUM(o.total) > 1000
ORDER BY gasto_historico DESC;

-- VERIFY: ¿Realmente gastaron más de 1000?
-- 1. Inspección rápida (debe mostrar usuarios con gasto > 1000)
-- Conteo de cuantos 'Top' existen (deberían ser 2: Ada y Margaret)
SELECT COUNT(*) AS cantidad_de_tops
FROM (
  SELECT u.id
  FROM usuarios u
  JOIN ordenes o ON o.usuario_id = u.id
  WHERE o.status IN ('pagado', 'entregado')
  GROUP BY u.id
  HAVING SUM(o.total) > 1000
) t;

-- 2. Caso Puntual
-- Verificamos a Margaret (ID 5) sumando manualmente el precio de sus productos.
SELECT 
    usuario_id, 
    SUM(total) AS validacion_suma_manual
FROM ordenes
WHERE usuario_id = 5 
  AND status IN ('pagado', 'entregado')
GROUP BY usuario_id;

/*
REPORTE 3: Usuarios inactivos en los ultimos 60 dias
Qué devuelve: Usuarios sin ordenes en los ultimos 60 dias.
Grain (una fila representa): Un usuario.
Métrica(s): No aplica (listado de usuarios).
Por qué GROUP BY / HAVING / subconsulta: Se usa LEFT JOIN + IS NULL para detectar ausencia en ventana.
*/

-- QUERY
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

-- VERIFY: Conteo total de inactivos.
SELECT COUNT(*) AS filas
FROM (
  SELECT u.id
  FROM usuarios u
  LEFT JOIN ordenes o
    ON o.usuario_id = u.id
    AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
  WHERE o.id IS NULL
) t;

-- VERIFY: Caso puntual con ordenes en ventana y total historico.
WITH inactivos AS (
  SELECT u.id AS usuario_id
  FROM usuarios u
  LEFT JOIN ordenes o
    ON o.usuario_id = u.id
    AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
  WHERE o.id IS NULL
  ORDER BY u.id
  LIMIT 1
)
SELECT
  i.usuario_id,
  (
    SELECT COUNT(*)
    FROM ordenes o
    WHERE o.usuario_id = i.usuario_id
      AND o.created_at >= CURRENT_DATE - INTERVAL '60 days'
  ) AS ordenes_en_ventana,
  (
    SELECT COUNT(*)
    FROM ordenes o
    WHERE o.usuario_id = i.usuario_id
  ) AS ordenes_total
FROM inactivos i;
