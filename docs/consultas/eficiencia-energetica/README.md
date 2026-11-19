# Eficiencia energética

| Archivo | Motor | Qué hace |
|---|---|---|
| [consumo-combustibles.sql](consumo-combustibles.sql) | SAP B1 / HANA | Crea `SB1_VIEW_CONSUMO_COMBUSTIBLES_EFICIENCIA_ENERGETICA`: consumo de combustible por documento y fecha. |

El indicador tiene dos mitades y la otra vive en producción, porque es la misma
lógica de kg de Beas que alimenta el tablero de transformados:

- [produccion/SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.sql](../produccion/SB1_VIEW_KG_TRANSFORMADOS_EFICIENCIA_ENERGETICA.sql) — kg transformados por OT confirmada.

Los datos de planta en vivo (medidores, energía) no salen de SAP: están por OPC UA
(`uaexpert-opcua`) y en PostgreSQL `energia` (`postgres-local-empaqplast`). Ver
[docs/mcp-registry.md](../../mcp-registry.md).
