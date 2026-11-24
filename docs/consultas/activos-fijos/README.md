# Activos fijos

| Archivo | Motor | Qué hace |
|---|---|---|
| [activos-fijos-powerbi.sql](activos-fijos-powerbi.sql) | SAP B1 / HANA | Crea `SB1_VIEW_ACTIVOS_FIJOS_SALDOS` (una fila por activo, con grupo, clase, cuentas, asignación, UDF y amortización) y `SB1_VIEW_PROYECTOS_ACTIVOS_FIJOS`. Área de depreciación: **FINANCIERO**. |
| [activos-fijos-hasta-fecha.sql](activos-fijos-hasta-fecha.sql) | SAP B1 / HANA | Reporte de activos con corte a una fecha. |

## fracttal/

Exportes del sistema de mantenimiento, no consultas: se descargan de Fracttal y
se usan para cruzar el maestro de activos de B1 con el de mantenimiento.

| Archivo | Qué es |
|---|---|
| `fracttal/reporte-activos-fracttal.xlsx` | Export de activos |
| `fracttal/reporte-activos-fracttal-v2.xlsx` | Export de activos, versión 2 |

`stats_out.txt` está en la misma carpeta pero lo ignora `.gitignore`.

Para consultar Fracttal en vivo hay servidor MCP propio (`fracttal`): ver
[docs/mcp-registry.md](../../mcp-registry.md). Los códigos de molde de Fracttal y
los de Beas **no siempre coinciden**; eso importa en
[produccion/moldes/](../produccion/moldes/).
