# Flujo de trabajo — Consultas Empaqplast

## Organización del repo (por BDD)

```
Consultas con SQL/
├── README.md
├── hana/              → SAP B1 (EMPAQPLAST_PROD)
├── sqlserver/         → TimeControl, AlertasB1, ETL
├── postgres/          → App Empaqplast, NPS
├── automatizaciones/    → Python (alertas, Excel)
├── fracttal/            → Exportes
└── catalogo-consultas/
```

Pedido nuevo = subcarpeta dentro del motor (`hana/cartera/`, `sqlserver/rrhh/`, etc.).

## Cadena de alertas

```
hana/.../SB1_VIEW_*  →  sqlserver/alertas-b1/ OPENQUERY  →  automatizaciones/*/  →  correo
```

## Decidir ubicación

| Datos en… | Carpeta |
|-----------|---------|
| SAP B1 | `hana/{dominio}/` |
| TimeControl / OnlyControl | `sqlserver/rrhh/` |
| Alertas OPENQUERY | `sqlserver/alertas-b1/` |
| Power BI RRHH | `sqlserver/rrhh/` |
| App web / auth | `postgres/app/` |
| NPS | `postgres/nps/` |
| Script Python multi-BDD | `automatizaciones/{tema}/` |
