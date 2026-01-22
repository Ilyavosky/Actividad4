/*
Archivo: db/queries_agg.sql
Proposito: reportes de agregacion para Clase 4 (GROUP BY, HAVING, subconsultas).
Como ejecutar (ajusta usuario, db y contenedor):
  docker compose ps
  docker exec -i <postgres_container> psql -U <user> -d <db> < db/queries_agg.sql

Regla evidence mindset:
- Cada reporte declara el grain.
- Cada reporte incluye VERIFY con consultas de control.
*/

/*
REPORTE 1: Top productos por ventas
Que devuelve: Top 5 de productos por total de ventas (sumando subtotal).
Grain (una fila representa): Un producto.
Metricas: SUM(orden_detalles.subtotal)
Por que GROUP BY / HAVING / subconsulta: GROUP BY para sumar ventas por producto.
*/

-- QUERY
SELECT
  p.id AS producto_id,
  p.nombre AS producto_nombre,
  SUM(od.subtotal) AS total_ventas
FROM productos p
JOIN orden_detalles od ON od.producto_id = p.id
JOIN ordenes o ON o.id = od.orden_id
WHERE o.status <> 'cancelado'
GROUP BY p.id, p.nombre
ORDER BY total_ventas DESC
LIMIT 5;

-- VERIFY: Conteo de filas del top N.
SELECT COUNT(*) AS filas
FROM (
  SELECT p.id
  FROM productos p
  JOIN orden_detalles od ON od.producto_id = p.id
  JOIN ordenes o ON o.id = od.orden_id
  WHERE o.status <> 'cancelado'
  GROUP BY p.id, p.nombre
  ORDER BY SUM(od.subtotal) DESC
  LIMIT 5
) t;

-- VERIFY: Recalculo del total para el producto top.
WITH top AS (
  SELECT p.id AS producto_id, SUM(od.subtotal) AS total_ventas
  FROM productos p
  JOIN orden_detalles od ON od.producto_id = p.id
  JOIN ordenes o ON o.id = od.orden_id
  WHERE o.status <> 'cancelado'
  GROUP BY p.id
  ORDER BY SUM(od.subtotal) DESC
  LIMIT 1
)
SELECT
  t.producto_id,
  t.total_ventas,
  SUM(od.subtotal) AS recompute_total
FROM top t
JOIN orden_detalles od ON od.producto_id = t.producto_id
JOIN ordenes o ON o.id = od.orden_id
WHERE o.status <> 'cancelado'
GROUP BY t.producto_id, t.total_ventas;

/*
REPORTE 2: Usuarios frecuentes (>= 3 ordenes)
Que devuelve: Usuarios con al menos 3 ordenes no canceladas.
Grain (una fila representa): Un usuario.
Metricas: COUNT(ordenes.id)
Por que GROUP BY / HAVING / subconsulta: GROUP BY para contar ordenes por usuario y HAVING para filtrar el umbral.
*/

-- QUERY
SELECT
  u.id AS usuario_id,
  u.nombre AS usuario_nombre,
  u.email,
  COUNT(o.id) AS ordenes_count
FROM usuarios u
JOIN ordenes o ON o.usuario_id = u.id
WHERE o.status <> 'cancelado'
GROUP BY u.id, u.nombre, u.email
HAVING COUNT(o.id) >= 3
ORDER BY ordenes_count DESC, u.id;

-- VERIFY: Conteo de filas de usuarios frecuentes.
SELECT COUNT(*) AS filas
FROM (
  SELECT u.id
  FROM usuarios u
  JOIN ordenes o ON o.usuario_id = u.id
  WHERE o.status <> 'cancelado'
  GROUP BY u.id, u.nombre, u.email
  HAVING COUNT(o.id) >= 3
) t;

-- VERIFY: Caso puntual con sus ordenes para verificar el conteo.
WITH frecuentes AS (
  SELECT u.id AS usuario_id, COUNT(o.id) AS ordenes_count
  FROM usuarios u
  JOIN ordenes o ON o.usuario_id = u.id
  WHERE o.status <> 'cancelado'
  GROUP BY u.id
  HAVING COUNT(o.id) >= 3
  ORDER BY COUNT(o.id) DESC
  LIMIT 1
)
SELECT
  f.usuario_id,
  f.ordenes_count,
  o.id AS orden_id,
  o.status,
  o.created_at
FROM frecuentes f
JOIN ordenes o ON o.usuario_id = f.usuario_id
WHERE o.status <> 'cancelado'
ORDER BY o.created_at;

/*
REPORTE 3: Usuarios inactivos en los ultimos 90 dias
Que devuelve: Usuarios sin ordenes en los ultimos 90 dias.
Grain (una fila representa): Un usuario.
Metricas: No aplica (listado de usuarios).
Por que GROUP BY / HAVING / subconsulta: No aplica GROUP BY; se usa LEFT JOIN + IS NULL para detectar ausencia de ordenes en la ventana.
*/

-- QUERY
SELECT
  u.id AS usuario_id,
  u.nombre AS usuario_nombre,
  u.email
FROM usuarios u
LEFT JOIN ordenes o
  ON o.usuario_id = u.id
  AND o.created_at >= CURRENT_DATE - INTERVAL '90 days'
WHERE o.id IS NULL
ORDER BY u.id;

-- VERIFY: Conteo total de inactivos.
SELECT COUNT(*) AS filas
FROM (
  SELECT u.id
  FROM usuarios u
  LEFT JOIN ordenes o
    ON o.usuario_id = u.id
    AND o.created_at >= CURRENT_DATE - INTERVAL '90 days'
  WHERE o.id IS NULL
) t;

-- VERIFY: Caso puntual con ordenes en 90 dias y total historico.
WITH inactivos AS (
  SELECT u.id AS usuario_id
  FROM usuarios u
  LEFT JOIN ordenes o
    ON o.usuario_id = u.id
    AND o.created_at >= CURRENT_DATE - INTERVAL '90 days'
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
      AND o.created_at >= CURRENT_DATE - INTERVAL '90 days'
  ) AS ordenes_en_90_dias,
  (
    SELECT COUNT(*)
    FROM ordenes o
    WHERE o.usuario_id = i.usuario_id
  ) AS ordenes_total
FROM inactivos i;
