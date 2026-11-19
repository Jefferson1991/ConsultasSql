# Producción

SAP B1 sobre HANA (`EMPAQPLAST_PROD`) con datos de **Beas** para órdenes de
trabajo y tiempos.

| Archivo | Crea | Qué hace |
|---|---|---|
| [SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.sql](SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.sql) | — | Kg transformados por OT de Beas confirmada (`ABGKZ='J'`, `GEL_MENGE>0`). Base del indicador de eficiencia energética. |
| [SB1_VIEW_PROD_TRANSFORMADOS.sql](SB1_VIEW_PROD_TRANSFORMADOS.sql) | `SB1_VIEW_PROD_TRANSFORMADOS` | Misma lógica de kg que la anterior, en vista propia. |
| [trazabilidad-pt-mp.sql](trazabilidad-pt-mp.sql) | — | Trazabilidad producto terminado → materia prima con el lote y la marca **realmente consumidos**: `IGE1 → OITL → ITL1 → OBTN` con `DocType 60`. Corrige el bug de tomar `MAX(OBTN.AbsEntry)`, que devolvía el último lote creado. |
| [movimientos-entrega-pt-em.sql](movimientos-entrega-pt-em.sql) | — | Movimientos de entrega de PT/EM. Solo documentos de marketing: `BEAS_OINM` existe pero este reporte no la usa. |

## moldes/

| Archivo | Qué hace |
|---|---|
| [moldes/SB1_VIEW_ANALISIS_MOLDES.sql](moldes/SB1_VIEW_ANALISIS_MOLDES.sql) | Vista vigente: ciclo real y número de órdenes por molde, artículo, año y mes. |
| [moldes/analisis-moldes-fuente-anotada.sql](moldes/analisis-moldes-fuente-anotada.sql) | El mismo SELECT con las notas de por qué está armado así. |
| [moldes/validacion-ciclo-real-2026.sql](moldes/validacion-ciclo-real-2026.sql) | Consultas de validación en DBeaver cuando el ciclo real sale 0. |
| [moldes/sabana-produccion-por-molde.sql](moldes/sabana-produccion-por-molde.sql) | **Sábana: una fila por molde**, kilos y órdenes de cada mes más el total del año, la máquina en que corrió y las paradas por categoría. Los moldes que no produjeron salen en cero. Año parametrizado al inicio. |
| `moldes/Moldes Activos.xlsx` | Lista de moldes hábiles de Talento: **300 códigos distintos** (287 como activo fijo, 11 recursos del maestro de Beas y 3 agregados el 2026-11-19 porque fabricaban sin estar en la lista). **Es el universo de la sábana**, incrustado en el `.sql`; al cambiar el archivo hay que regenerar ese bloque. |
| [moldes/_historico/analisis-moldes-version-original.sql](moldes/_historico/analisis-moldes-version-original.sql) | Versión anterior: enlazaba por `U_EMPA_COD_FRACTTAL`, una fila por OT y solo 6 moldes. No ejecutar. |

Tres reglas que no se deducen del SQL y cuestan caro si se ignoran:

- **Un molde no corre en una sola máquina.** En 2026, de los 178 moldes que fabricaron, 106 usaron una, 46 dos, 12 tres, 11 cuatro, 2 cinco y 1 seis. La sábana da la máquina principal, cuántas usó, la lista y el porcentaje de kilos de la principal: si ese porcentaje es bajo, "la máquina del molde" no significa nada para ese molde.

- El enlace con Beas va por **`U_EMPA_COD_BEAS`**, no por `U_EMPA_COD_FRACTTAL`. En activos fijos los dos códigos pueden diferir (variantes `-1`, `A`, o códigos de Fracttal).
- Si se agrega `T1."OT"` al `SELECT`/`GROUP BY`, `"No. Ordenes"` tiene que pasar a `COUNT(DISTINCT T1."OT")`, o muestra el número de filas del JOIN en vez del número de órdenes.

Análisis completo de la vista y sus objetos base: [docs/domain/moldes.md](../../domain/moldes.md).
