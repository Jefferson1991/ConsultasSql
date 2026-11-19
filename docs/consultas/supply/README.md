# Supply — alerta de stock crítico de clientes

Evalúa si hay suficiente producto terminado para cubrir lo comprometido con
clientes, y lo manda por correo con semáforo. Mismo patrón que compras.

```
SB1_VIEW_REPORTE_STOCK_CRITICO (HANA)
        ↓  OPENQUERY(HANAODBC)
vista STOCK_CRITICO_CLIENTES → sp_Stock_Critico_Clientes (SQL Server, AlertasB1)
        ↓  sqlcmd -Q "EXEC sp_Stock_Critico_Clientes"
reporte-stock-critico.py → Excel con semáforo + correo
```

| Archivo | Motor | Dónde corre | Qué hace |
|---|---|---|---|
| [SB1_VIEW_REPORTE_STOCK_CRITICO.sql](SB1_VIEW_REPORTE_STOCK_CRITICO.sql) | SAP B1 / HANA | esquema `EMPAQPLAST_PROD` | Crea la vista que consume SQL Server. |
| [analisis-stock-critico.sql](analisis-stock-critico.sql) | SAP B1 / HANA | esquema `EMPAQPLAST_PROD` | Versión documentada del mismo cálculo, con la explicación de qué evalúa el reporte. **Define el mismo objeto que el archivo anterior.** |
| [sp_Stock_Critico_Clientes.sql](sp_Stock_Critico_Clientes.sql) | SQL Server | `SRV-APP\SQLEXPRESS`, base `AlertasB1` | Crea el SP que arma el resultado final. Requiere la vista `STOCK_CRITICO_CLIENTES` (OPENQUERY a HANA). |
| [reporte-stock-critico.py](reporte-stock-critico.py) | Python | donde esté programada la tarea | Ejecuta el SP por `sqlcmd`, genera el Excel con formato y semáforo, envía el correo. |

## Dos archivos para la misma vista: cuál describe la base

`SB1_VIEW_REPORTE_STOCK_CRITICO.sql` y `analisis-stock-critico.sql` son dos
versiones de la misma consulta. Comprobado contra la base el 2026-11-19: **la que
describe la vista viva es `analisis-stock-critico.sql`**, y es la que hay que leer
para entender la alerta.

Los distingue el nombre de dos columnas. En la base, posiciones 16 y 17, llevan
espacio: `UIO Total` y `GYE Total`. El archivo homónimo las declara `UIO_Total` y
`GYE_Total`, con guion bajo. Las otras 21 coinciden.

Importa porque el resto de la cadena pide el nombre con espacio:
`sp_Stock_Critico_Clientes.sql` selecciona `[UIO Total]` y `[GYE Total]`, y
`reporte-stock-critico.py` arma el Excel con esas claves. Si alguna vez se
ejecutara el archivo homónimo contra la base, el procedimiento y el correo
dejarían de encontrar esas columnas.

Evidencia: [docs/domain/stock-diferencias-con-la-bdd.md](../../domain/stock-diferencias-con-la-bdd.md).

## Orden de despliegue

1. La vista en HANA.
2. La vista `STOCK_CRITICO_CLIENTES` y el SP en `AlertasB1`.
3. El script.
