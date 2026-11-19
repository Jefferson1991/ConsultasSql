# Vistas de stock: en qué difieren los archivos guardados y la base

Este repositorio guarda las consultas que hemos hecho; **lo que corre en la base
es otra cosa y manda** (`README.md`). Esta nota registra, para dos vistas que
tienen dos archivos cada una, qué devuelve hoy el motor y en qué se aparta de lo
guardado — para que nadie reutilice una de esas consultas creyendo que reproduce
lo que ve en producción.

Verificado contra `hana-sap-b1-produccion`, esquema `EMPAQPLAST_PROD`, el
**2026-11-19**. No se modificó ninguna vista.

> El usuario conectado **no tiene privilegio para leer `SYS.VIEWS.DEFINITION`**
> (devuelve nulo), así que no se comparó el texto SQL. Se comparó lo observable:
> las columnas de `SYS.VIEW_COLUMNS` y el dato que devuelve la vista.

## `SB1_VIEW_REVISION_STOCK_V2`

Archivos: `docs/consultas/inventario/SB1_VIEW_REVISION_STOCK_V2.sql` y
`…-version-alterna.sql`. Los dos declaran las mismas 53 columnas en el mismo
orden, así que la estructura no los distingue. El dato sí:

```
OITW, ItemCode = 'MPPASO00001', WhsCode = 'UIO_IMPT'
  OnHand 0 + OnOrder 767.250            = 767.250   ← tránsito real
Vista viva, Transito_kg                 = 693.000   = 767.250 − 74.250
```

**La vista que corre resta 74.250 kg** a ese artículo: es el ajuste fijo escrito a
mano para calzar el tránsito de un embarque puntual. Ese `- 74250` está en
`…-version-alterna.sql` (tres veces: `Transito_kg`, `Stock_Neto_kg` y el cálculo
de días) y **no** está en `SB1_VIEW_REVISION_STOCK_V2.sql`, cuya cabecera lo da
por eliminado el 2026-06-23.

Qué significa en la práctica:

- Si reutilizas `SB1_VIEW_REVISION_STOCK_V2.sql` como consulta, para `MPPASO00001` te dará 74.250 kg **más** de tránsito que la vista viva: 1.094.500 de `Stock_Neto_kg` contra los 1.020.250 que devuelve el motor hoy.
- Lo mismo arrastran `Dias_Stock_Neto`, `Costo_MP_Transito` y `Costo_MP_Total`.
- **Por qué difieren no está establecido.** Puede ser que el archivo corregido nunca se haya ejecutado en HANA, o que se ejecutara y luego se revirtiera. La vista reporta `CREATE_TIME` 2025-11-18, anterior al 2026-06-23, pero eso no prueba nada por sí solo: un `ALTER VIEW` no necesariamente actualiza esa marca.
- Si el ajuste sigue siendo correcto para el negocio, el archivo que describe la base es `…-version-alterna.sql`.

## `SB1_VIEW_REPORTE_STOCK_CRITICO`

Archivos: `docs/consultas/supply/SB1_VIEW_REPORTE_STOCK_CRITICO.sql` y
`analisis-stock-critico.sql`. Aquí los distingue el **nombre de dos columnas**. En
la base (`SYS.VIEW_COLUMNS`, posiciones 16 y 17) llevan espacio:

| Posición | Columna en la base | `analisis-stock-critico.sql` | `SB1_VIEW_REPORTE_STOCK_CRITICO.sql` |
|---|---|---|---|
| 16 | `UIO Total` | `AS "UIO Total"` ✔ | `AS "UIO_Total"` ✘ |
| 17 | `GYE Total` | `AS "GYE Total"` ✔ | `AS "GYE_Total"` ✘ |

Las otras 21 columnas coinciden en nombre y orden en ambos archivos. El resto de
la cadena pide el nombre **con espacio**:
`sp_Stock_Critico_Clientes.sql` selecciona `[UIO Total]` y `[GYE Total]`, y
`reporte-stock-critico.py` arma el Excel con esas claves.

Así que el archivo que describe la vista viva, y el que hay que leer para
entender la alerta, es `analisis-stock-critico.sql` — pese a que el nombre de la
vista lo lleva el otro. Si alguna vez se ejecutara
`SB1_VIEW_REPORTE_STOCK_CRITICO.sql` contra la base, el procedimiento y el correo
dejarían de encontrar esas dos columnas.

## Sin verificar

- El **texto** de las definiciones, por el privilegio faltante sobre `SYS.VIEWS.DEFINITION`: puede haber diferencias de lógica que no cambien ni las columnas ni el dato de la fila probada.
- `dbo.vm_atrasos`, que también tiene dos archivos en `docs/consultas/rrhh/atrasos/_historico/`: los servidores MCP de SQL Server de RRHH estaban caídos el 2026-11-19.
