# Flujo de trabajo — Consultas Empaqplast

## Organización del repo (por dominio)

Reorganizado el 2026-11-19: el repo ya no se agrupa por motor.

```
Consultas con SQL/
├── README.md
├── AGENTS.md
├── docs/
│   ├── INDEX.md          → mapa: leer primero
│   ├── mcp-registry.md   → capacidad → servidor MCP
│   ├── domain/ runbooks/ adr/ plans/
│   ├── catalogo/guia-consultas.html
│   └── consultas/<dominio>/   → activos-fijos, apps, cartera, compras,
│                                eficiencia-energetica, inventario, logistica,
│                                plataforma, produccion, rrhh, supply, ventas
├── scripts/graphify.py   → genera el índice de dependencias
└── graphify-out/         → índice generado (no editar)
```

Pedido nuevo = carpeta del **dominio**, no del motor. El motor va en la cabecera
del archivo y en el `README.md` del dominio.

## Cadena de alertas

Las tres piezas viven **juntas** en la carpeta del dominio:

```
SB1_VIEW_* (HANA)  →  vista OPENQUERY (SQL Server)  →  script Python  →  correo
```

Ejemplos completos: `docs/consultas/compras/` y `docs/consultas/supply/`.

## Decidir ubicación

| Datos en… | Carpeta |
|-----------|---------|
| SAP B1 | `docs/consultas/{dominio}/` |
| TimeControl / OnlyControl | `docs/consultas/rrhh/` |
| Alertas OPENQUERY | la carpeta del dominio (`docs/consultas/compras/`, `supply/`) |
| Power BI RRHH | `docs/consultas/rrhh/` |
| App web / auth | `docs/consultas/apps/` |
| NPS | `docs/consultas/apps/nps/` |
| Script Python multi-BDD | la carpeta del dominio, junto a su consulta |
