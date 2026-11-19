# Logística

SAP B1 sobre HANA, esquema `EMPAQPLAST_PROD`.

## Pallets del flujo automático

Tres consultas sobre el mismo flujo: la automatización **TransferenciasAutomaticas**
de n8n, que empareja guía (`ODLN`) y transferencia (`OWTR`) escribiendo el enlace
cruzado `U_EntregaRef` y marcando `U_TipoMov` como `TRANSFERENCIA` o `REVERSO`.

| Archivo | Qué responde |
|---|---|
| [pallets-flujo-automatico.sql](pallets-flujo-automatico.sql) | El detalle guía ↔ transferencia que escribió n8n, línea por línea. |
| [pallets-movimientos-por-cliente.sql](pallets-movimientos-por-cliente.sql) | Cuántos pallets `IPPALL0003` salieron cada mes, por cliente, y cuánto hay hoy en stock. |
| [pallets-saldo-por-cliente.sql](pallets-saldo-por-cliente.sql) | Cuántos pallets de madera están con cada cliente y cuántos quedan en planta. |

Supuestos verificados el 2026-10-08, según las cabeceras: solo `OWTR` del flujo,
con `U_TipoMov` en `TRANSFERENCIA` o `REVERSO`.

## Traslados

| Archivo | Qué hace |
|---|---|
| [traslado-vs-salida-promedio-ponderado.sql](traslado-vs-salida-promedio-ponderado.sql) | Solicitud de traslado (consumo) contra la salida de mercancía generada, con promedio ponderado (`OINM.CalcPrice`) por artículo + bodega a la fecha del documento, comparativo de centros de costo y el detalle del asiento contable (`OJDT`/`JDT1`). |

La bodega de referencia del promedio ponderado es **dinámica**: sale del propio
movimiento (`WhsCode` del traslado o de la salida), no está fijada en la consulta.
