# RRHH / Talento Humano

El dominio más grande del repo: 17 archivos, todos sobre SQL Server. Tres
servidores distintos según la cabecera de cada archivo:

| Base | Servidor | Qué guarda |
|---|---|---|
| `TCONTROL` | `SRV-BIOM-001\SQLEXPRESS2008R2` | Biométrico: timbradas, asistencia, novedades, catálogos de permiso |
| `TH` | `SRV-APP\SQLEXPRESS` (192.168.20.15) | Talento Humano: vistas de consumo, ausentismo, atrasos, festivos |
| `dispensarioMedico` | `SRV-APP\SQLEXPRESS` | Planificación de turnos (`cargaTurnosSLPC`) |

Linked servers en juego: `ONLYC` (hacia OnlyControl/TCONTROL) y `EMP_NOM` (hacia nómina).

## ausentismo/ — lo vigente

Solo estos dos archivos. El orden importa y el paso 2 falla si no corrió el 1.

| # | Archivo | Servidor | Base |
|---|---|---|---|
| 1 | [ausentismo/1-vistas-en-tcontrol.sql](ausentismo/1-vistas-en-tcontrol.sql) | `SRV-BIOM-001\SQLEXPRESS2008R2` | `TCONTROL` |
| 2 | [ausentismo/2-consumo-en-th.sql](ausentismo/2-consumo-en-th.sql) | `SRV-APP\SQLEXPRESS` | `TH` |
| 3 | `EXEC dbo.sp_th_cargar_ausentismo;` | `SRV-APP\SQLEXPRESS` | `TH` |

El procedimiento completo está en [docs/runbooks/ausentismo.md](../../runbooks/ausentismo.md).

## atrasos/

`vm_atrasos` es el reporte principal de Talento Humano para atrasos y faltas
injustificadas. Todo lo que hay hoy está en `_historico/`: son las versiones que
llevaron a la vista vigente, incluidas **dos que definen `dbo.vm_atrasos`**
(`vm-atrasos-cuadro-horarios.sql` y `vm-atrasos-vista-completa.sql`) y una
propuesta de reescritura por tablas de parámetros
(`ausentismo/_historico/ausentismo-transparente-propuesta.sql`). Antes de ejecutar
cualquiera, compara contra lo que hay vivo en `TH`. El análisis está en
[docs/domain/atrasos.md](../../domain/atrasos.md).

## Resto

| Archivo | Base | Qué hace |
|---|---|---|
| [permisos/permisos-con-paga.sql](permisos/permisos-con-paga.sql) | TCONTROL | Replica la pantalla "Asignación de Permisos" con período (21 al 20) y estado de exportación. |
| [permisos/catalogo-tipos-permiso.sql](permisos/catalogo-tipos-permiso.sql) | TCONTROL | Catálogo real de tipos de permiso con `CD_PAGADO` (0 = sin paga, 1 = con paga). |
| [permisos/correccion-permiso-sin-paga.sql](permisos/correccion-permiso-sin-paga.sql) | TCONTROL | Corrección puntual por año y período. |
| [asistencia/asistencia-empleados.sql](asistencia/asistencia-empleados.sql) | TCONTROL | Asistencia completa por empleado. |
| [asistencia/cumplimiento-turnos-planta.sql](asistencia/cumplimiento-turnos-planta.sql) | dispensarioMedico + TCONTROL vía `ONLYC` | Turnos planificados vs asistencia real. |
| [asistencia/carga-rotacion-turnos.sql](asistencia/carga-rotacion-turnos.sql) | dispensarioMedico | ETL de rotación al formato legacy `cargaTurnosSLPC`, con log y detección de duplicados. |
| [asistencia/correccion-codigo-empleado.sql](asistencia/correccion-codigo-empleado.sql) | dispensarioMedico | Repuebla `codigoEmpleadoSLPC` desde `NOMINA_ID`. |
| [calendario/festivos-ecuador-2026.sql](calendario/festivos-ecuador-2026.sql) | TH | Tabla de festivos, función `fn_es_festivo`, SP de carga y auditoría. Soporte de la regla de feriados de `vm_atrasos`. |
| [powerbi/consultas-tablero-rrhh.sql](powerbi/consultas-tablero-rrhh.sql) | TCONTROL + ONLYCONTROL | Consultas del tablero de asistencia. |
| [powerbi/consultas-tablero-atrasos.sql](powerbi/consultas-tablero-atrasos.sql) | TH | Consultas del tablero de atrasos. Los nombres de columna son fijos según `dbo.vm_atrasos`. |

Documentación: [docs/domain/rrhh-tablero-powerbi.md](../../domain/rrhh-tablero-powerbi.md) ·
[docs/runbooks/powerbi-rrhh-consultas-diarias.md](../../runbooks/powerbi-rrhh-consultas-diarias.md)

## Aviso de conexión

Los servidores MCP `sqlserver-timecontrol`, `sqlserver-onlycontrol` y
`sqlserver-etl-local-th` estaban caídos el 2026-11-19. Mientras sigan así, el
esquema vivo de estos orígenes no se puede verificar y nada de lo que diga este
README sobre columnas o códigos debe darse por confirmado contra la base.
