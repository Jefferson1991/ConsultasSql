# Consultas, por dominio

Los archivos ejecutables del repo: vistas, procedimientos, reportes y los scripts
Python que los orquestan. Están agrupados por **de qué tratan**, no por el motor
en que corren, porque las tres automatizaciones reales cruzan motores.

El motor no se perdió: está en la tabla del `README.md` de cada dominio y en la
cabecera de cada archivo.

| Dominio | Qué hay | Motores |
|---|---|---|
| [activos-fijos/](activos-fijos/) | Sábana de activos fijos para Power BI y exportes de Fracttal | HANA |
| [apps/](apps/) | Auth, permisos y menús de las apps; DDL de infraestructura; NPS | PostgreSQL |
| [cartera/](cartera/) | Bloqueo de clientes, vencidas con excedente, retenciones | HANA |
| [compras/](compras/) | **Cadena de alerta** de órdenes de compra abiertas | HANA → SQL Server → Python |
| [eficiencia-energetica/](eficiencia-energetica/) | Consumo de combustibles | HANA |
| [inventario/](inventario/) | Stock, antigüedad PT/MP, ubicaciones, datos maestros, auditoría UIO/GYE | HANA |
| [logistica/](logistica/) | Pallets del flujo automático y traslados vs salidas | HANA |
| [plataforma/](plataforma/) | Administración de SAP B1, búsquedas formateadas, backups, diagnóstico | HANA + SQL Server |
| [produccion/](produccion/) | Transformados, trazabilidad PT→MP y análisis de moldes | HANA + Beas |
| [rrhh/](rrhh/) | Ausentismo, atrasos, permisos, asistencia, festivos y Power BI | SQL Server |
| [supply/](supply/) | **Cadena de alerta** de stock crítico de clientes | HANA → SQL Server → Python |
| [ventas/](ventas/) | Notas de crédito del BI de Gerencia y **cadena** de pricing | HANA → Python |

## Reglas para un pedido nuevo

1. **Dominio, no motor.** El archivo va en la carpeta del asunto. Si el pedido cruza motores, los tres archivos van juntos en el mismo dominio.
2. **Nombre.** Si el script crea un objeto de base de datos, el archivo se llama igual que el objeto (`SB1_VIEW_NC_CABECERA.sql`): así se lo encuentra desde el mensaje de error del motor. Si es un reporte o un análisis, kebab-case en español, sin fechas ni espacios.
3. **Cabecera obligatoria** en el archivo: propósito, motor y esquema o base, supuestos verificados con su fecha, y orden de despliegue si hay más de un paso.
4. **Actualiza el `README.md` del dominio** en el mismo pedido: fila nueva con archivo, motor, dónde corre y qué hace.
5. **`_historico/`** para lo que quedó superado. No se ejecuta; se conserva para entender por qué la versión vigente es como es.

## Dependencias

`graphify-out/graph.json` tiene el grafo completo: qué objeto crea cada archivo,
qué referencia, y qué depende de qué. Se regenera con `python scripts/graphify.py`.
