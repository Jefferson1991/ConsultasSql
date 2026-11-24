# Ventas

Dos asuntos separados: las notas de crédito del BI de Gerencia y la extracción de
facturas para el módulo de pricing.

## notas-credito/

Vistas en `EMPAQPLAST_PROD` para el tablero de Gerencia. Una nota de crédito
vigente (`ORIN`, `CANCELED = 'N'`) queda en cabecera; cada línea (`RIN1`) queda en
detalle.

| Archivo | Motor | Grano |
|---|---|---|
| [notas-credito/SB1_VIEW_NC_CABECERA.sql](notas-credito/SB1_VIEW_NC_CABECERA.sql) | SAP B1 / HANA | 1 fila por documento |
| [notas-credito/SB1_VIEW_NC_DETALLE.sql](notas-credito/SB1_VIEW_NC_DETALLE.sql) | SAP B1 / HANA | 1 fila por línea |

Los montos van **positivos**, como en el módulo de Nota de crédito;
`SB1_VIEW_VENTA_CABECERA_TDW` y `SB1_VIEW_VENTA_DETALLE_TDW` guardan el mismo
documento en negativo. La regla completa y qué descarta la vista de ventas está en
[docs/domain/notas-credito.md](../../domain/notas-credito.md).

## pricing/

| Archivo | Motor | Qué hace |
|---|---|---|
| [pricing/extraer-facturas-pricing.sql](pricing/extraer-facturas-pricing.sql) | SAP B1 / HANA | Facturas de venta, una fila por línea (`OINV` + `INV1`), para la plantilla de RevenueOS. |
| [pricing/llenar-plantilla-pricing.py](pricing/llenar-plantilla-pricing.py) | Python | Lee el `.sql` de al lado, consulta HANA con `hdbcli` y llena la plantilla Excel. |
| [pricing/.env.example](pricing/.env.example) | — | Plantilla de variables. Copiar a `.env` y poner `HANA_PASSWORD`. El `.env` está en `.gitignore`. |

**Los dos archivos tienen que estar en la misma carpeta.** El script resuelve la
consulta como `Path(__file__).parent / "extraer-facturas-pricing.sql"`. Hasta la
reorganización del 2026-11-19 el `.sql` vivía en `hana/ventas/` y el `.py` en
`automatizaciones/pricing/`, así que el script no encontraba su consulta. Si
alguna vez se vuelven a separar, vuelve a romperse.
