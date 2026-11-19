# Qué versión de las vistas de stock está viva en HANA

Verificado contra producción (`hana-sap-b1-produccion`, esquema `EMPAQPLAST_PROD`)
el **2026-11-19**. Dos vistas tienen dos definiciones en el repo; esto dice cuál
coincide con la que está corriendo, y con qué evidencia.

> El usuario conectado **no tiene privilegio para leer `SYS.VIEWS.DEFINITION`**
> (devuelve nulo), así que no se comparó el texto SQL. Se comparó lo que sí es
> observable: las columnas de `SYS.VIEW_COLUMNS` y el dato que devuelve la vista.

## `SB1_VIEW_REVISION_STOCK_V2` — la viva es la versión **con** el ajuste a mano

| | |
|---|---|
| **Archivo que coincide con producción** | `docs/consultas/inventario/SB1_VIEW_REVISION_STOCK_V2-version-alterna.sql` |
| **Archivo corregido, NO desplegado** | `docs/consultas/inventario/SB1_VIEW_REVISION_STOCK_V2.sql` |

Las dos definiciones declaran las mismas 53 columnas, en el mismo orden, así que
la estructura no las distingue. El dato sí:

```
OITW, ItemCode = 'MPPASO00001', WhsCode = 'UIO_IMPT'
  OnHand 0 + OnOrder 767.250            = 767.250   ← tránsito real
Vista viva, Transito_kg                 = 693.000   = 767.250 − 74.250
```

El `- 74250` es el ajuste fijo que se escribió a mano **solo para
`MPPASO00001`** para calzar el tránsito de un embarque puntual, y que la cabecera
de `SB1_VIEW_REVISION_STOCK_V2.sql` da por eliminado el 2026-06-23. **En HANA
sigue puesto.** La vista registra `CREATE_TIME` 2025-11-18, anterior a esa fecha:
la corrección nunca llegó a producción.

Consecuencia mientras no se despliegue la versión corregida, para ese artículo:

- `Transito_kg` queda 74.250 kg por debajo del tránsito real.
- `Stock_Neto_kg` arrastra el mismo faltante: hoy devuelve 1.020.250 donde el cálculo sin ajuste da 1.094.500.
- `Dias_Stock_Neto` y las columnas de costo que usan la misma expresión (`Costo_MP_Transito`, `Costo_MP_Total`) quedan subestimadas en proporción.

El ajuste aparece **tres veces** en la versión viva: en `Transito_kg`, en
`Stock_Neto_kg` y en el cálculo de días. Quitarlo es desplegar
`SB1_VIEW_REVISION_STOCK_V2.sql`, que es idéntica salvo eso.

**Decisión pendiente de Jefferson:** desplegar la corregida, o dejar el ajuste si
el embarque que lo motivó sigue vigente. No se desplegó nada: §5 prohíbe escribir
en producción desde una tarea de desarrollo.

## `SB1_VIEW_REPORTE_STOCK_CRITICO` — la viva es `analisis-stock-critico.sql`

| | |
|---|---|
| **Archivo que coincide con producción** | `docs/consultas/supply/analisis-stock-critico.sql` |
| **Archivo que NO coincide y rompe la alerta** | `docs/consultas/supply/SB1_VIEW_REPORTE_STOCK_CRITICO.sql` |

Aquí las distingue el **nombre de dos columnas**. En producción
(`SYS.VIEW_COLUMNS`, posiciones 16 y 17) se llaman con espacio:

| Posición | Columna viva | `analisis-stock-critico.sql` | `SB1_VIEW_REPORTE_STOCK_CRITICO.sql` |
|---|---|---|---|
| 16 | `UIO Total` | `AS "UIO Total"` ✔ | `AS "UIO_Total"` ✘ |
| 17 | `GYE Total` | `AS "GYE Total"` ✔ | `AS "GYE_Total"` ✘ |

Las otras 21 columnas coinciden en nombre y orden en ambos archivos.

Esto no es cosmético: **los dos consumidores de la cadena piden las columnas con
espacio.**

- `docs/consultas/supply/sp_Stock_Critico_Clientes.sql` las selecciona como `[UIO Total]` y `[GYE Total]`.
- `docs/consultas/supply/reporte-stock-critico.py` las usa como `'UIO Total'` y `'GYE Total'` para armar el Excel.

Desplegar `SB1_VIEW_REPORTE_STOCK_CRITICO.sql` renombra esas dos columnas y
**rompe el procedimiento y el correo de stock crítico**, pese a ser el archivo que
lleva el nombre de la vista. Hasta que se unifiquen, el archivo de referencia es
`analisis-stock-critico.sql`.

## Qué queda sin verificar

- No se comparó el **texto** de las definiciones, por el privilegio faltante sobre `SYS.VIEWS.DEFINITION`. Puede haber diferencias de lógica que no cambien ni las columnas ni el dato de la fila probada.
- La tercera definición duplicada del repo, `dbo.vm_atrasos` (`docs/consultas/rrhh/atrasos/_historico/`), **no se pudo comparar**: los servidores MCP de SQL Server de RRHH estaban caídos el 2026-11-19.
