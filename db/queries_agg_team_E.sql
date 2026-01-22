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
REPORTE 2: Usuarios frecuentes (>= 3 ordenes) con monto total
Qué devuelve: Usuarios con al menos 3 ordenes y su monto total acumulado.
Grain (una fila representa): Un usuario.
Métrica(s): COUNT(ordenes.id), SUM(ordenes.total)
Por qué GROUP BY / HAVING / subconsulta: GROUP BY para agregar por usuario y HAVING para filtrar el umbral.
*/

-- QUERY
SELECT
  u.id AS usuario_id,
  u.nombre AS usuario_nombre,
  u.email,
  COUNT(o.id) AS ordenes_count,
  SUM(o.total) AS monto_total
FROM usuarios u
JOIN ordenes o ON o.usuario_id = u.id
GROUP BY u.id, u.nombre, u.email
HAVING COUNT(o.id) >= 3
ORDER BY ordenes_count DESC, u.id;

-- VERIFY: Conteo de filas de usuarios frecuentes.
SELECT COUNT(*) AS filas
FROM (
  SELECT u.id
  FROM usuarios u
  JOIN ordenes o ON o.usuario_id = u.id
  GROUP BY u.id
  HAVING COUNT(o.id) >= 3
) t;

-- VERIFY: Caso puntual con sus ordenes para verificar el conteo.
WITH frecuentes AS (
  SELECT u.id AS usuario_id, COUNT(o.id) AS ordenes_count
  FROM usuarios u
  JOIN ordenes o ON o.usuario_id = u.id
  GROUP BY u.id
  HAVING COUNT(o.id) >= 3
  ORDER BY COUNT(o.id) DESC, u.id
  LIMIT 1
)
SELECT
  f.usuario_id,
  f.ordenes_count,
  o.id AS orden_id,
  o.status,
  o.created_at,
  o.total
FROM frecuentes f
JOIN ordenes o ON o.usuario_id = f.usuario_id
ORDER BY o.created_at, o.id;

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
