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

## Cuidado: dos archivos definen la misma vista, y uno rompe la alerta

`SB1_VIEW_REPORTE_STOCK_CRITICO.sql` y `analisis-stock-critico.sql` crean ambos
`SB1_VIEW_REPORTE_STOCK_CRITICO`.

**Comparado contra producción el 2026-11-19: la vista viva es la de
`analisis-stock-critico.sql`.** En HANA las columnas 16 y 17 se llaman `UIO Total`
y `GYE Total`, **con espacio**; `SB1_VIEW_REPORTE_STOCK_CRITICO.sql` las declara
como `UIO_Total` y `GYE_Total`, con guion bajo.

No es cosmético: `sp_Stock_Critico_Clientes.sql` las pide como `[UIO Total]` y
`[GYE Total]`, y `reporte-stock-critico.py` las usa con ese nombre para armar el
Excel. **Desplegar `SB1_VIEW_REPORTE_STOCK_CRITICO.sql` rompe el procedimiento y
el correo**, aunque sea el archivo que lleva el nombre de la vista.

Detalle y evidencia: [docs/domain/stock-definiciones-vigentes.md](../../domain/stock-definiciones-vigentes.md).

## Orden de despliegue

1. La vista en HANA.
2. La vista `STOCK_CRITICO_CLIENTES` y el SP en `AlertasB1`.
3. El script.
