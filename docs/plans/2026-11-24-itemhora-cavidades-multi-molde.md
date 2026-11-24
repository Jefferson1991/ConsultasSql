# ItemHora: cavidades con múltiples moldes

- **Date:** 2026-11-24
- **Status:** Implemented
- **Approved by:** Jefferson, chat 2026-11-24 (acepta recomendación solo DAX)
- **Scope:** columna calculada `Fact_Ordenes_Beas[ItemHora]` y medida hermana `ItemHoraCicloPromedio` en `EFicienciaO.pbip`; nota en `docs/domain/moldes.md`
- **Out of scope:** cambios a `SB1_VIEW_BEAS_RESUMEN_OF`, `BEAS_TIEMPOS_PRODUCCION`, columnas nuevas de lista de moldes en HANA

## Problem

En OTs con dos moldes (ej. OT 9054: `MOLSOP0914` + `MOLSOP0915`, 1 cav c/u) `ItemHora` usaba `CAVIDADES_HABILES_1` (=1, UDF de la OF) y devolvía 48 en vez de 96.

## Decision

Usar `TOTAL_CAVIDADES_ESTANDAR` (suma de `UDF3` de todos los recursos `MOL%` de la OT; ya existe en la vista y en el modelo):

`(3600 * TOTAL_CAVIDADES_ESTANDAR) / CICLO_MOLDE`

Misma corrección en `ItemHoraCicloPromedio` (mismo error de columna).

## Alternatives rejected

- Redefinir `CAVIDADES_HABILES_1` en la vista → rompe `SB1_VIEW_ANALISIS_MOLDES` y consumidores del UDF de OF.
- Ampliar la vista con `MOLDES_CODIGOS` / `NUM_MOLDES` → útil para mostrar el 2.º molde; fuera del arreglo mínimo aceptado.
- Priorizar solo cavidades de tiempos → `ItemHoraPromedio` ya lo hace; la columna de orden debe calcularse sin depender de tiempos reportados.

## Downstream impact

- `EFicienciaO.../tables/Fact_Ordenes_Beas.tmdl` → `ItemHora`, `ItemHoraCicloPromedio`
- Medidas que leen `ItemHora` (`Unidades x hora interrumpida`, `H.Req.Prod.Planificada`, etc.)
- Sin cambio de grano ni de vistas HANA

## Questions resolved

- ¿Suma de cavidades de ambos moldes? → Sí (Mario Loachamín 2026-11-16; Jefferson 2026-11-24).
- ¿Vista o DAX? → Solo DAX con columna ya existente.

## Verification

```dax
EVALUATE
SELECTCOLUMNS(
  FILTER(Fact_Ordenes_Beas, Fact_Ordenes_Beas[OT] = 9054),
  "ItemHora", Fact_Ordenes_Beas[ItemHora],
  "CAV", Fact_Ordenes_Beas[TOTAL_CAVIDADES_ESTANDAR]
)
```

Pasando: `ItemHora = 96`, `CAV = 2` (tras recargar el modelo en Desktop).

## Outcome

Aplicado en `EFicienciaO.SemanticModel/.../Fact_Ordenes_Beas.tmdl`: `ItemHora` y `ItemHoraCicloPromedio` leen `TOTAL_CAVIDADES_ESTANDAR`. Proyecto validado (0 errores). Regla anotada en `docs/domain/moldes.md`. Verificación en vivo pendiente de recargar el `.pbip` en Desktop (OT 9054 → ItemHora = 96).
