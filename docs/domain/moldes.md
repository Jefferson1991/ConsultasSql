# Análisis: SB1_VIEW_ANALISIS_MOLDES y objetos relacionados

Análisis realizado contra HANA (esquema `EMPAQPLAST_PROD`).

---

## 1. Objetos base analizados

### 1.1 SB1_VIEW_ACTIVOS_FIJOS (vista)

**Propósito:** Catálogo de activos fijos (incluye moldes) con datos de amortización y maestros.

**Tablas base (dependencias):** AADT, ACS1, ITM7, ITM8, ODPV, OITM.

**Columnas relevantes para ANALISIS_MOLDES:**

| Columna | Uso en ANALISIS_MOLDES |
|--------|------------------------|
| `Cod_Articulo` | Identificador del activo (ej. AFMOLINY0867) |
| `U_EMPA_COD_FRACTTAL` | Código molde Fracttal → **clave de JOIN con BEAS** |
| `U_EMPA_COD_BEAS` | Código molde BEAS |
| `U_EMPA_COD_RECURSO` | Tipo recurso (ej. MOLDE) |
| `Descripcion` | Descripción del activo/molde |
| `Vida_Util_Meses`, `Resto_Vida_Util_*`, `Numero_de_Amortizaciones_P` | Métricas de vida útil |
| `Procedencia`, `Marca`, `Modelo`, `Serie` | Datos del activo |

**Volumen:** 228 filas (todos los activos fijos, no solo moldes).

---

### 1.2 SB1_VIEW_BEAS_RESUMEN_OF (vista)

**Propósito:** Resumen de órdenes de fabricación BEAS (OF): una fila por OT con producto, molde, máquina, cantidades, fechas y ciclos estándar.

**Tablas base:** BEAS_APLATZ, BEAS_FTAPL, BEAS_FTHAUPT, BEAS_FTPOS, BEAS_FTSTMP, BEAS_RESOURCEN, IGN1, OITM, OITW.

**Columnas relevantes para ANALISIS_MOLDES:**

| Columna | Uso en ANALISIS_MOLDES |
|--------|------------------------|
| `OT` | Nº orden de trabajo → **clave para JOIN con BEAS_PARADAS y BEAS_TIEMPOS_PRODUCCION** |
| `MOLDE_CODIGO` | Código molde BEAS → **JOIN con ACTIVOS_FIJOS** (U_EMPA_COD_FRACTTAL = MOLDE_CODIGO) |
| `AREA` | Área de producción (ej. UIO-SOP_CONV) |
| `FECHA_INICIO` | Para año/mes y ordenamiento |
| `NO_CAVIDADE_ESTANDAR` | Cavidades estándar (MAX en GROUP BY) |
| `CAVIDADES_HABILES_1` | Cavidades hábiles (MAX/MIN) |
| `CICLO_MOLDE` | Ciclo estándar del molde (MAX) |

**Filtro en la vista:** `MOLDE_CODIGO IN ('MOLINY0867','MOLINY1086','MOLINY1102','MOLINY1233','MOLINY1245','MOLINY1426')` → 96 órdenes para esos 6 moldes.

---

### 1.3 BEAS_PARADAS (tabla)

**Propósito:** Registro de paradas por OT/recurso; permite clasificar por causa (ej. fallas de molde).

**Columnas principales:** OT, APLATZ_ID, KSTST_ID, Fecha_Inicio_Mayor, Fecha_Final_Menor, Horas_Paro, Recurso_Nombre, Grupo_Recurso, Tipo_Recurso, **GRUNDID**, Descripcion_Causa, Causa_Interna, Operador, Estado_Parada.

**Uso en ANALISIS_MOLDES:**  
- **JOIN:** `T1."OT" = T2."OT" AND T2."GRUNDID" = 'Moldes'`  
- **Métrica:** `COUNT(T2."GRUNDID")` → **"No Fallas Moldes"** (solo paradas clasificadas como de molde).

---

### 1.4 BEAS_TIEMPOS_PRODUCCION (tabla)

**Propósito:** Tiempos de producción por OT: ciclos reales, cavidades hábiles reales, cantidades buena/mala, etc.

**Columnas principales:** OT, Posicion, Empleado_ID, Recurso_ID, Centro_Trabajo, Tipo_Recurso, Hora_Inicio, Hora_Fin, Tiempo_Total_*, Cantidad_Buena/Mala, **Tiempo_Ciclo_Real**, **Cavidades_Habiles**, Num_Registros, Num_Operarios.

**Uso en ANALISIS_MOLDES:**  
- **JOIN:** `T1."OT" = T3."OT"` (sin filtrar por posición/recurso).  
- **Métricas:**  
  - `AVG(COALESCE(T3."Tiempo_Ciclo_Real", 0))` → **"Ciclo Real"**  
  - `MAX/MIN(COALESCE(T3."Cavidades_Habiles", 0))` → **"Maximo/Min Cavidades Reales"**

**Importante:** Si una OT no tiene ningún registro en `BEAS_TIEMPOS_PRODUCCION`, el LEFT JOIN no aporta filas de T3 y el resultado es Ciclo Real = 0 y cavidades reales en 0.

---

## 2. Vista SB1_VIEW_ANALISIS_MOLDES

### 2.1 Definición lógica (resumen)

La vista agrupa por **molde, artículo de activo, año y mes** y combina:

1. **Datos de activo fijo (T0)** – moldes identificados por `U_EMPA_COD_FRACTTAL`.
2. **Órdenes BEAS (T1)** – por `MOLDE_CODIGO` = `U_EMPA_COD_FRACTTAL`.
3. **Paradas de molde (T2)** – por OT y `GRUNDID = 'Moldes'` → cuenta de fallas.
4. **Tiempos de producción (T3)** – por OT → ciclo real y cavidades reales (promedio/máximo/mínimo).

**Filtro aplicado:** solo moldes `MOLINY0867`, `MOLINY1086`, `MOLINY1102`, `MOLINY1233`, `MOLINY1245`, `MOLINY1426`.

**Agregaciones:**  
- Cavidades: MAX/MIN de cavidades hábiles (T1 y T3).  
- Ciclo: MAX(T1.CICLO_MOLDE) → "Ciclo Estandar"; AVG(T3.Tiempo_Ciclo_Real) → "Ciclo Real".  
- Conteos: COUNT(T2.GRUNDID) → "No Fallas Moldes"; COUNT(DISTINCT T1.OT) → "No. Ordenes".

### 2.2 Columnas de salida

| Columna | Origen |
|--------|--------|
| OT, Anio, Mes | T1 (BEAS_RESUMEN_OF) |
| Cod_Articulo, U_EMPA_*, Descripcion, Vida_Util_*, Resto_*, Numero_de_Amortizaciones_P, Procedencia, Marca, Modelo, Serie | T0 (ACTIVOS_FIJOS) |
| MOLDE_CODIGO, AREA | T1 |
| Cavidades Estandar, Maximo/Minimo Cavidades Habiles | T1 (NO_CAVIDADE_ESTANDAR, CAVIDADES_HABILES_1) |
| Maximo Cavidades Reales, Min Cavidades Reales | T3 (BEAS_TIEMPOS_PRODUCCION) |
| Ciclo Estandar | T1 (CICLO_MOLDE) |
| Ciclo Real | T3 (Tiempo_Ciclo_Real) |
| No Fallas Moldes | T2 (BEAS_PARADAS, GRUNDID='Moldes') |
| No. Ordenes | COUNT(DISTINCT T1.OT) |

### 2.3 Volumen y calidad de datos (consulta ejecutada en HANA)

- **Total filas:** 1 545  
- **Con Ciclo Real > 0:** 1 305  
- **Sin Ciclo Real (0 o NULL):** 240  

Las filas con "Ciclo Real" = 0 corresponden a OTs que **no tienen ningún registro en BEAS_TIEMPOS_PRODUCCION**. El comentario en `Fact_Analisis_Moldes.sql` y la consulta de diagnóstico (filas 72–94) explican y listan esas OTs.

### 2.4 Relación entre objetos (diagrama)

```
SB1_VIEW_ACTIVOS_FIJOS (T0)
    U_EMPA_COD_FRACTTAL = MOLDE_CODIGO
            │
            ▼
SB1_VIEW_BEAS_RESUMEN_OF (T1) ◄── filtro MOLDE_CODIGO IN (...)
    OT ─────────────────────────┬──► BEAS_PARADAS (T2)  [GRUNDID='Moldes'] → No Fallas Moldes
    OT ─────────────────────────┴──► BEAS_TIEMPOS_PRODUCCION (T3) → Ciclo Real, Cavidades Reales
```

### 2.5 Observaciones y recomendaciones

1. **Ciclo Real = 0:** Es esperado cuando la OT no tiene datos en `BEAS_TIEMPOS_PRODUCCION`. La consulta de diagnóstico en el script sirve para listar esas OTs.
2. **Filtro fijo de moldes:** La vista está limitada a 6 códigos. Para ampliar o parametrizar, habría que cambiar el `WHERE` (o exponer la lista por parámetro si se convierte en procedimiento).
3. **GROUP BY y Ordenes:** El script indica que si se agrega `T1."OT"` al SELECT/GROUP BY, "No. Ordenes" debe ser `COUNT(DISTINCT T1."OT")` para no inflar por el JOIN con T3.
4. **LEFT JOINs:** ACTIVOS_FIJOS sin órdenes BEAS para ese molde seguirán saliendo (con NULL en columnas de T1/T2/T3); el filtro actual sobre `T1."MOLDE_CODIGO"` hace que solo entren moldes que sí tienen al menos una OT en la lista.

---

## 3. Corrección: JOIN por U_EMPA_COD_BEAS (no U_EMPA_COD_FRACTTAL)

**Problema:** Al filtrar por año 2026, moldes como MOLSOP1254, MOLINY1170, MOLSOP1132, etc. no mostraban Ciclo Real aunque las órdenes de BEAS_TIEMPOS_PRODUCCION sí tenían ciclo real.

**Causa raíz:**
- En BEAS, `MOLDE_CODIGO` en `SB1_VIEW_BEAS_RESUMEN_OF` corresponde al **código BEAS** del molde.
- En `SB1_VIEW_ACTIVOS_FIJOS`, `U_EMPA_COD_BEAS` es el código del molde en BEAS y `U_EMPA_COD_FRACTTAL` puede ser distinto (variantes -1, A, o código Fracttal).
- El JOIN estaba usando `U_EMPA_COD_FRACTTAL = MOLDE_CODIGO`. Cuando ambos difieren, no hay match y no se vinculan las OTs ni los tiempos de producción → Ciclo Real = 0.
- Además, el filtro `WHERE` solo permitía 6 moldes; el resto (MOLSOP1254, MOLINY1170, etc.) ni siquiera entraban en el resultado.

**Solución aplicada en Fact_Analisis_Moldes.sql:**
1. **JOIN corregido:** `T0."U_EMPA_COD_BEAS" = T1."MOLDE_CODIGO"` (antes `U_EMPA_COD_FRACTTAL`).
2. **Filtro ampliado:** lista de moldes actualizada con los 24 códigos que indicaste (para que 2026 y demás años muestren esos moldes con Ciclo Real cuando exista en BEAS_TIEMPOS_PRODUCCION).

Para que el cambio aplique en la base debes **recrear la vista** `SB1_VIEW_ANALISIS_MOLDES` ejecutando el `CREATE OR REPLACE VIEW` con el SELECT actualizado del script.

---

## 4. Consultas de apoyo (ya en Fact_Analisis_Moldes.sql)

- **Diagnóstico Ciclo Real = 0:** OTs que están en `SB1_VIEW_BEAS_RESUMEN_OF` pero no tienen filas en `BEAS_TIEMPOS_PRODUCCION` (líneas 79–94).

Este análisis se basa en la estructura obtenida desde HANA (columnas de resultados y dependencias de objetos) y en la definición SQL en `Fact_Analisis_Moldes.sql`.

---

## 5. Verificado el 2026-11-19 (sábana de producción por molde)

Hechos comprobados contra producción al construir
`docs/consultas/produccion/moldes/sabana-produccion-por-molde.sql`:

- **Enlace molde → producción:** `SB1_VIEW_PROD_TRANSFORMADOS."Lote_Orden"` = `SB1_VIEW_BEAS_RESUMEN_OF."OT"`. Esa vista ya resuelve `MOLDE_CODIGO` por OT y tiene **una sola posición por OT** (6.597 OTs, todas con una fila), así que el join no multiplica kilos.
- **`U_EMPA_COD_BEAS` vs `U_EMPA_COD_FRACTTAL`:** hoy los dos resuelven el **mismo conjunto de 132 moldes** (cero que enlacen por uno y no por el otro). La corrección de §3 sigue siendo la correcta, pero a esta fecha no cambia la cobertura.
- **`U_EMPA_COD_RECURSO` no sirve para identificar moldes:** marca `'MOLDE'` en 212 de las 240 filas de `SB1_VIEW_ACTIVOS_FIJOS`, incluidas máquinas. La clase de activo sí discrimina: `PPE-MOLDE-10` tiene 70 activos.
- **`SB1_VIEW_ACTIVOS_FIJOS` no es el maestro completo:** son 240 filas, todas `Estado_Activo = 'A'`. 82 códigos de molde que sí producen no están en ella, entre ellos `MOLSOP1350` (154 OTs).
- **Producción sin molde:** en 2026, 1.445 de 3.958 órdenes de transformados (3,38 M kg de 15,15 M) no tienen OT en Beas. Son `CARNEEXT`, `IMPRES-2`, `BOBINZ-3`, `SELLA-3`, `EXTRUS-1`: extrusión, impresión, bobinado y sellado, procesos sin molde.
- **Defecto de `SB1_VIEW_ANALISIS_MOLDES`:** su `WHERE T3."Tiempo_Ciclo_Real" > 0` convierte los tres `LEFT JOIN` en `INNER`, así que un molde sin tiempos de producción desaparece de la salida. Señalado, no corregido.

### Cuántos moldes son (resuelto el 2026-11-19)

La fuente es `docs/consultas/produccion/moldes/Moldes Activos.xlsx`, hoja
`MOLDES HABILES`, que aportó Jefferson. No está en la base de datos.

| | |
|---|---|
| Filas del archivo | 301 (eran 298 antes del 2026-11-19) |
| Con clase de activo (`CLASE`) | **287** — los moldes como activo fijo |
| Sin código SAP | **14** — los 11 recursos que solo existen en el maestro de recursos de Beas, más los 3 agregados abajo |
| Códigos `COD. FRACCTAL` distintos | **300** (`MOLSOP1327` aparece dos veces en el archivo) |

El código que une con Beas es `COD. FRACCTAL`, que es el que Beas guarda en
`SB1_VIEW_BEAS_RESUMEN_OF.MOLDE_CODIGO`.

**La base no tiene esta lista.** `SB1_VIEW_ACTIVOS_FIJOS` son 240 filas en total
—es una vista filtrada, no el maestro— y Beas solo conoce los moldes que
aparecieron en alguna orden: por `LIKE 'MOL%'` la unión de ambas da 270, no 297.
Por eso la sábana incrusta la lista y se regenera desde el Excel cuando cambie.

Contraste contra producción 2026: de los 178 moldes que fabricaron, 3 no estaban
en la lista — `MOLINY1402AB` (7.615 kg), `MOLINY1440` (88 kg) y `MOLINYSTD0002`
(6 kg). **Se agregaron al Excel el 2026-11-19**, con el código y la descripción
tomados de `SB1_VIEW_BEAS_RESUMEN_OF`, y `COD SAP` y `CLASE` vacíos porque no se
les encontró ficha de activo fijo. Con eso ya no queda ningún molde fabricando
fuera de la lista.

La columna `Origen_Molde` de la sábana sigue marcando `FUERA DE LA LISTA` si
aparece otro: esa es la señal de que al archivo le falta una fila.
