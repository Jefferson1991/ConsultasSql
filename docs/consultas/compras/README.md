# Compras — alerta de órdenes de compra abiertas

Cadena completa de la alerta. Los tres archivos son un solo flujo y por eso están
juntos; antes vivían en `hana/compras/`, `sqlserver/alertas-b1/` y
`automatizaciones/ordenes-compra/`.

```
SB1_VIEW_ORDENES_COMPRA (HANA)
        ↓  linked server HANAODBC, el WHERE va DENTRO del OPENQUERY
dbo.ORDENES_COMPRA (SQL Server, base AlertasB1)
        ↓  sqlcmd
notificacion-ordenes-compra.py → correo con Excel adjunto
```

| Archivo | Motor | Dónde corre | Qué hace |
|---|---|---|---|
| [SB1_VIEW_ORDENES_COMPRA.sql](SB1_VIEW_ORDENES_COMPRA.sql) | SAP B1 / HANA | esquema `EMPAQPLAST_PROD` | Crea la vista. Una fila por **línea** de OC (OPOR + POR1), con estado, montos, pendientes y trazabilidad. |
| [ORDENES_COMPRA-openquery.sql](ORDENES_COMPRA-openquery.sql) | SQL Server | `SRV-APP\SQLEXPRESS`, base `AlertasB1` | Crea `dbo.ORDENES_COMPRA` como `SELECT * FROM OPENQUERY(HANAODBC, …)` sobre la vista de HANA. |
| [notificacion-ordenes-compra.py](notificacion-ordenes-compra.py) | Python | donde esté programada la tarea | Consulta la vista de SQL Server, arma el Excel y envía el correo. |

## Alcance de la alerta

Según la cabecera de la vista de HANA: serie **OCNAC** (nacionales) y solo
documentos y líneas **abiertos**. El filtro está en el `WHERE` al pie de la vista
y aplica a todo lo que cuelga de ella — la vista de AlertasB1 y la alerta en
Python heredan ese alcance. Cambiarlo ahí cambia los tres.

## Orden de despliegue

1. La vista en HANA.
2. La vista en SQL Server (falla si la de HANA no existe o cambió de columnas).
3. El script, que no necesita despliegue: lee la vista de SQL Server.
