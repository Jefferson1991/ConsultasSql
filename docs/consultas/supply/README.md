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

## Cuidado: dos archivos definen la misma vista

`SB1_VIEW_REPORTE_STOCK_CRITICO.sql` y `analisis-stock-critico.sql` crean ambos
`SB1_VIEW_REPORTE_STOCK_CRITICO`. El índice topológico lo marca en
`public_surface`. Antes de ejecutar uno, verifica cuál refleja la versión viva en
HANA: no son necesariamente idénticos, y desplegar el equivocado cambia el
resultado de la alerta sin que nadie se entere.

## Orden de despliegue

1. La vista en HANA.
2. La vista `STOCK_CRITICO_CLIENTES` y el SP en `AlertasB1`.
3. El script.
