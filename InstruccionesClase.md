````markdown
# Clase 4 — Actividad: Reportes con Agregaciones + Evidence Mindset
**Fecha:** 15 de enero de 2026  
**Duración total:** ~55–65 min  
**Modalidad:** equipos (3 roles)

---

## 🎯 Objetivo de la actividad
Que puedas **diseñar reportes correctos y defendibles**, no solo “SQL que corre”.

Al finalizar deberás poder:
- Definir el **grain**: *“una fila representa qué”*.
- Elegir la **métrica correcta** (COUNT / COUNT DISTINCT / SUM / AVG).
- Decidir **WHERE vs HAVING** y justificarlo.
- Probar con **evidencia** que tu resultado es correcto (VERIFY).

---

## 🧑‍🤝‍🧑 Roles por equipo (obligatorio)
- **Driver:** escribe el SQL.
- **Navigator:** explica la lógica (grain, métrica, filtros).
- **QA:** verifica resultados (COUNT/LIMIT/casos puntuales) y reporta bugs.

> Cada 10–15 min, roten roles.

---

## ✅ Setup rápido (5–8 min)
1) Levanta PostgreSQL:
```bash
docker compose up -d
````

2. Verifica que el contenedor está listo:

```bash
docker compose logs -f postgres
```

Busca: `ready to accept connections`

3. Conéctate a `psql` (si tienes container_name):

```bash
docker exec -it postgres_container psql -U postgres -d actividad_db
```

4. Inspección mínima:

```sql
\dt
-- elige 1 tabla y revisa estructura:
\d nombre_tabla
```

**Checkpoint:**

* [ ] Veo tablas con `\dt`
* [ ] La DB tiene datos (harás COUNT más abajo)

---

# 🧩 Parte A — SQL on paper (8–10 min) (SIN computadora)

## Instrucciones

1. Usa la siguiente tablita mini:

| customer | order_id | total | order_date |
| -------: | -------: | ----: | :--------- |
|        A |      101 |   250 | 2026-01-01 |
|        A |      102 |   100 | 2026-01-03 |
|        B |      103 |    80 | 2026-01-03 |
|        C |      104 |   300 | 2026-01-04 |
|        B |      105 |   120 | 2026-01-05 |
|        A |      106 |    60 | 2026-01-06 |

2. Responde en una hoja (en equipo):

* **(1) ¿Qué se agrupa?**
  Ejemplo: por customer / por día / por customer y día
* **(2) ¿Qué métrica se calcula?**
  Ejemplo: COUNT(orders), SUM(total), AVG(total)
* **(3) ¿WHERE o HAVING? ¿y por qué?**

  * WHERE filtra **filas antes** del GROUP BY
  * HAVING filtra **grupos después** del GROUP BY

3. Preparación de explicación (30–45s)
   Cada equipo debe poder decir:

* “Agrupamos por ____ porque el reporte pide ____.”
* “La métrica es ____ porque queremos medir ____.”
* “Usamos WHERE/HAVING porque ____ ocurre antes/después de agrupar.”

**Checkpoint:**

* [ ] El equipo puede explicar su decisión sin “probarlo en SQL”.

---

# 🧪 Parte B — Laboratorio: 3 reportes clave (35 min)

## Entregable

Crea o edita este archivo:

* ✅ **`db/queries_agg.sql`** (recomendado)

> Si tu equipo ya tiene `db/queries.sql`, puedes agregar una sección ahí, pero se prefiere `queries_agg.sql`.

---

## 📌 Reglas del laboratorio (NO negociables)

Debes crear **3 reportes**.
Cada reporte debe incluir:

1. Comentario explicando **qué devuelve y el grain**
2. La **query principal**
3. Un bloque **VERIFY** con evidencia (COUNT/LIMIT/caso puntual)

---

## 🧱 Formato obligatorio por reporte (copia y pega)

```sql
/* 
REPORTE #: <Nombre del reporte>
Qué devuelve: <explicación clara>
Grain (una fila representa): <explicación clara>
Métrica(s): <COUNT/SUM/AVG...>
Por qué GROUP BY / HAVING / subconsulta: <justificación corta>
*/

-- QUERY
SELECT ...
FROM ...
JOIN ...
WHERE ...
GROUP BY ...
HAVING ...
ORDER BY ...
LIMIT ...;

-- VERIFY: <cómo validar sin “creerle” al motor>
-- 1) conteo general
SELECT COUNT(*) FROM ( <pega aquí la query sin ORDER BY/LIMIT si aplica> ) t;

-- 2) inspección rápida
<misma query> LIMIT 5;

-- 3) caso puntual (opcional recomendado)
-- ejemplo: elegir una entidad y comprobar sus filas en la tabla base
SELECT ... WHERE ...;
```

---

## ✅ Reportes sugeridos (elige 3)

Escoge los que mejor “empatan” con tus tablas reales.

### Opción 1 — Top N

Ejemplos:

* Top productos por número de ventas (COUNT)
* Top clientes por compras (COUNT)
* Top por monto (SUM) si tu esquema tiene total/precio

**Requisito:** usar `GROUP BY` + `ORDER BY` + `LIMIT`.

---

### Opción 2 — Entidades frecuentes (HAVING)

Ejemplos:

* Clientes con más de **X** órdenes
* Productos vendidos más de **X** veces

**Requisito:** incluir `HAVING COUNT(...) > X`.

---

### Opción 3 — Churn simple / inactivos

Ejemplos:

* Clientes sin órdenes
* Productos sin ventas

**Requisito:** hacerlo con:

* `LEFT JOIN ... WHERE tabla_relacionada.id IS NULL`
  **o**
* `NOT EXISTS (...)`

---

### Opción 4 — Cohorte simple (si aplica)

* Agrupar por **mes** de primera compra/registro

---

### Opción 5 — Comparación vs promedio (subconsulta escalar)

* “Entidades por encima del promedio global”

---

## 🔍 Anti-errores (lo que más se equivoca la gente)

Antes de dar por buena tu query:

* ¿Tu COUNT está inflado por un JOIN 1:N?

  * Considera `COUNT(DISTINCT pk)` y explícalo.
* ¿Estás filtrando agregaciones con WHERE?

  * Si filtras un COUNT/SUM, normalmente debe ser **HAVING**.
* ¿Tu grain está claro?

  * Si no lo puedes decir en una frase, está mal definido.

---

# 🧠 Evidence mindset (lo que se evalúa)

No se evalúa que “corra y ya”.
Se evalúa que puedas:

* Explicar **por qué** la query es correcta (grain + métrica + filtro)
* Demostrarlo con evidencia (VERIFY)
* Detectar errores típicos (conteos inflados, WHERE vs HAVING)

---

## 📦 Entrega (al final de la clase)

En tu repositorio debe existir:

* [ ] `db/queries_agg.sql` con **3 reportes** completos + VERIFY
* [ ] Cada reporte tiene explicación de **grain**
* [ ] Al menos 2 reportes usan `GROUP BY`
* [ ] Al menos 1 usa `HAVING`
* [ ] Al menos 1 es “inactivos” con `LEFT JOIN + IS NULL` o `NOT EXISTS`

---

## ✅ Checklist de salida (rápido)

* [ ] Puedo explicar mi mejor reporte en 30–45s
* [ ] Puedo justificar WHERE vs HAVING
* [ ] Tengo VERIFY que prueba que no inventé el resultado

```
```
