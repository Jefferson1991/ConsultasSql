# Sábana de producción por molde y mes

- **Date:** 2026-11-19
- **Status:** Implemented
- **Approved by:** Jefferson, en sesión: "necesito un query que emita esta sábana" — listado de moldes no repetidos, cuánto se fabricó con cada uno por mes y el total del año; los que no produjeron, en cero o en blanco.
- **Scope:** `docs/consultas/produccion/moldes/sabana-produccion-por-molde.sql` (nuevo), fila en `docs/consultas/produccion/README.md`, hechos verificados a `docs/domain/moldes.md`.
- **Out of scope:** no se modifica `SB1_VIEW_ANALISIS_MOLDES` ni ninguna otra vista; no se crea ningún objeto en HANA. La consulta es de solo lectura.

## Problem

`SB1_VIEW_ANALISIS_MOLDES` responde otra pregunta: eficiencia de ciclo y cavidades
por molde, artículo, año y mes. Tres cosas la hacen inservible para esta sábana:

1. **No lista todos los moldes.** Su `WHERE T3."Tiempo_Ciclo_Real" > 0` convierte los tres `LEFT JOIN` en `INNER`: un molde sin tiempos de producción desaparece de la salida. Lo pedido es lo contrario — que aparezca con ceros.
2. **Repite el molde.** Agrupa también por `Cod_Articulo`, así que un molde que hizo tres artículos sale en tres filas por mes.
3. **No trae kilos.** Devuelve ciclos, cavidades y conteo de órdenes, no producción.

## Decision

Consulta nueva, independiente, que no toca la vista existente.

- **Universo de moldes = unión** de los moldes de activos fijos (`SB1_VIEW_ACTIVOS_FIJOS`, `U_EMPA_COD_RECURSO = 'MOLDE'`) y de los que aparecen en órdenes de Beas (`SB1_VIEW_BEAS_RESUMEN_OF.MOLDE_CODIGO`). Verificado: 182 en activos fijos, 214 en Beas, **265 únicos**. Basarse solo en activos fijos perdería los más usados — `MOLSOP1350`, con 154 OTs, no está en el maestro de activos.
- **Enlace molde → producción:** `SB1_VIEW_PROD_TRANSFORMADOS."Lote_Orden"` = `SB1_VIEW_BEAS_RESUMEN_OF."OT"`, que ya resuelve el molde por OT. Verificado que esa vista tiene **una sola posición por OT** (6.597 OTs, todas con una fila), así que el join no multiplica kilos.
- **Grano de salida:** una fila por molde. Kilos y número de órdenes por mes, más totales del año. Sin producción → 0.
- **Año como parámetro** al inicio de la consulta, para que se cambie en un solo lugar.

## Alternatives rejected

- **Corregir `SB1_VIEW_ANALISIS_MOLDES`** — responde otra pregunta y la usan otros reportes; cambiarla para esto rompería su propósito.
- **Partir de `BEAS_TIEMPOS_PRODUCCION`** (`Cantidad_Buena` por OT y recurso) — mide lo declarado en planta, no lo recibido a inventario. Jefferson pidió explícitamente lo transformado y procesado, que es `SB1_VIEW_PROD_TRANSFORMADOS`.
- **Listar solo moldes con producción** — lo pedido incluye los que no produjeron, en blanco.

## Downstream impact

Ninguno: archivo nuevo, de solo lectura. No lo referencia ningún otro archivo del repo (verificado en `graphify-out/graph.json`), y no crea ni altera objetos en la base.

## Questions resolved

- ¿Por qué código enlaza el molde, `U_EMPA_COD_BEAS` o `U_EMPA_COD_FRACTTAL`? → `docs/domain/moldes.md` §3 manda usar `U_EMPA_COD_BEAS`. Verificado el 2026-11-19: hoy ambos resuelven **el mismo conjunto de 132 moldes** (0 que enlacen por uno y no por el otro), así que la elección no cambia la cobertura, pero se usa el documentado. → Verificado en sesión.
- ¿Toda la producción tiene molde? → No. En 2026, 1.445 de 3.958 órdenes (3,38 M kg de 15,15 M) no tienen OT en la vista de Beas; son `CARNEEXT`, `IMPRES-2`, `BOBINZ-3`, `SELLA-3`, `EXTRUS-1`: extrusión, impresión, bobinado y sellado, **procesos sin molde**. Quedan fuera de la sábana por definición. → Verificado en sesión.

## Verification

```
-- ejecutada contra produccion el 2026-11-19
265 moldes unicos | 182 en activos fijos | 214 en Beas
178 con produccion en 2026 | 87 en blanco
```

Pasa si: la consulta devuelve 265 filas para 2026, una por molde, sin repetir; los
87 sin producción salen con todos los meses en 0; y la suma de `KG_TOTAL` cuadra
con los kilos de transformados que sí tienen OT de Beas.

## Outcome

Implementado el 2026-11-19. La consulta se ejecutó contra producción y devuelve
265 filas, una por molde, con los meses en cero donde no hubo producción. Queda
señalado en `docs/domain/moldes.md` el defecto de `SB1_VIEW_ANALISIS_MOLDES` (el
`WHERE` que anula los `LEFT JOIN`), sin corregirlo: eso es otra decisión.

**Pendiente que afecta al universo.** Jefferson indicó, ya terminada la consulta,
que son **287 moldes como activos fijos** y **11 recursos del maestro de recursos
de Beas**. Ninguna fuente consultada da 287: la clase `PPE-MOLDE-10` tiene 70
activos, `U_EMPA_COD_RECURSO = 'MOLDE'` marca 182 códigos (y es un flag poco
fiable: etiqueta también máquinas), Beas referencia 214 códigos de molde y
`@OS_ACTIVOF` tiene 161 filas con "MOLDE" en la descripción. El detalle está en
`docs/domain/moldes.md` §5. Falta que Jefferson diga de qué tabla o reporte salen
los 287; el cambio es de un bloque, el CTE `UNIVERSO`.
