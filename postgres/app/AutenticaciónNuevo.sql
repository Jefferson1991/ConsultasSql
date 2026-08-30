-- Permiso
INSERT INTO auditorias."Permisos" ("Codigo","Nombre","Descripcion","Estado")
SELECT 'CRUD_CATALOGOS', 'CRUD Catálogos', 'Acceso a módulos maestros del sistema', true
WHERE NOT EXISTS (SELECT 1 FROM auditorias."Permisos" WHERE "Codigo"='CRUD_CATALOGOS');

-- Menú
INSERT INTO auditorias."Menus" ("Nombre","Icono","Orden","Estado")
SELECT 'Administración','fa-solid fa-gear',1,true
WHERE NOT EXISTS (SELECT 1 FROM auditorias."Menus" WHERE "Nombre"='Administración');

-- Página Local
INSERT INTO auditorias."Paginas" ("MenuId","Nombre","Icono","Orden","Estado")
SELECT m."Id",'Configuración de Local','fa-solid fa-building',1,true
FROM auditorias."Menus" m
WHERE m."Nombre"='Administración'
AND NOT EXISTS (SELECT 1 FROM auditorias."Paginas" WHERE "Nombre"='Configuración de Local');

-- Página Usuarios
INSERT INTO auditorias."Paginas" ("MenuId","Nombre","Icono","Orden","Estado")
SELECT m."Id",'Configuración de Usuarios','fa-solid fa-users-cog',2,true
FROM auditorias."Menus" m
WHERE m."Nombre"='Administración'
AND NOT EXISTS (SELECT 1 FROM auditorias."Paginas" WHERE "Nombre"='Configuración de Usuarios');

-- Subpágina Sucursales (SIN PaginaId fijo)
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id",NULL,'Sucursales','/sucursales','fa-solid fa-building',1,true
FROM auditorias."Paginas" p
WHERE p."Nombre"='Configuración de Local'
AND NOT EXISTS (SELECT 1 FROM auditorias."SubPaginas" WHERE "Ruta"='/sucursales');


-- Subpágina Personas
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id",per."Id",'Personas','/personas','fa-solid fa-address-card',1,true
FROM auditorias."Paginas" p
JOIN auditorias."Permisos" per ON per."Codigo"='CRUD_CATALOGOS'
WHERE p."Nombre"='Configuración de Usuarios'
AND NOT EXISTS (SELECT 1 FROM auditorias."SubPaginas" WHERE "Ruta"='/personas');



-- Subpágina Usuarios
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id",per."Id",'Usuarios','/usuarios','fa-solid fa-user-gear',2,true
FROM auditorias."Paginas" p
JOIN auditorias."Permisos" per ON per."Codigo"='CRUD_CATALOGOS'
WHERE p."Nombre"='Configuración de Usuarios'
AND NOT EXISTS (SELECT 1 FROM auditorias."SubPaginas" WHERE "Ruta"='/usuarios');



-- Subpágina Roles
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id",per."Id",'Roles','/roles','fa-solid fa-shield-halved',3,true
FROM auditorias."Paginas" p
JOIN auditorias."Permisos" per ON per."Codigo"='CRUD_CATALOGOS'
WHERE p."Nombre"='Configuración de Usuarios'
AND NOT EXISTS (SELECT 1 FROM auditorias."SubPaginas" WHERE "Ruta"='/roles');




-- Asignar permiso al ADMINISTRADOR
INSERT INTO auditorias."RolPermisos" ("RolId","PermisoId")
SELECT r."Id",p."Id"
FROM auditorias."Roles" r
JOIN auditorias."Permisos" p ON p."Codigo"='CRUD_CATALOGOS'
WHERE r."Nombre"='ADMINISTRADOR'
AND NOT EXISTS (
  SELECT 1 FROM auditorias."RolPermisos" rp
  WHERE rp."RolId"=r."Id" AND rp."PermisoId"=p."Id"
);




SELECT "Nombre","Ruta","PaginaId"
FROM auditorias."SubPaginas"
WHERE "Ruta" IN ('/sucursales','/personas','/usuarios','/roles','/permisos')
ORDER BY "Ruta";
-----------------------------------------------------------------------------------


-- Ejecuta en PostgreSQL (schema auditorias)

-- Permiso para administración de catálogos (si no existe)
INSERT INTO auditorias."Permisos" ("Codigo","Nombre","Descripcion","Estado")
SELECT 'CRUD_CATALOGOS', 'CRUD Catálogos', 'Acceso a administración de catálogos', true
WHERE NOT EXISTS (
  SELECT 1 FROM auditorias."Permisos" WHERE "Codigo"='CRUD_CATALOGOS'
);

-- Asegurar página "Configuración de Usuarios"
INSERT INTO auditorias."Paginas" ("MenuId","Nombre","Icono","Orden","Estado")
SELECT m."Id",'Configuración de Usuarios','fa-solid fa-users-cog',2,true
FROM auditorias."Menus" m
WHERE m."Nombre"='Administración'
AND NOT EXISTS (
  SELECT 1 FROM auditorias."Paginas" p WHERE p."Nombre"='Configuración de Usuarios'
);

-- menu-admin
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id", per."Id", 'Menú / Páginas / Subpáginas', '/menu-admin', 'fa-solid fa-sitemap', 99, true
FROM auditorias."Paginas" p
JOIN auditorias."Permisos" per ON per."Codigo"='CRUD_CATALOGOS'
WHERE p."Nombre"='Configuración de Usuarios'
AND NOT EXISTS (
  SELECT 1 FROM auditorias."SubPaginas" sp WHERE sp."Ruta"='/menu-admin'
);

-- permisos (si no está)
INSERT INTO auditorias."SubPaginas" ("PaginaId","PermisoId","Nombre","Ruta","Icono","Orden","Estado")
SELECT p."Id", per."Id", 'Permisos', '/permisos', 'fa-solid fa-key', 4, true
FROM auditorias."Paginas" p
JOIN auditorias."Permisos" per ON per."Codigo"='CRUD_CATALOGOS'
WHERE p."Nombre"='Configuración de Usuarios'
AND NOT EXISTS (
  SELECT 1 FROM auditorias."SubPaginas" sp WHERE sp."Ruta"='/permisos'
);

-- Asignar permiso al rol ADMINISTRADOR
INSERT INTO auditorias."RolPermisos" ("RolId","PermisoId")
SELECT r."Id", p."Id"
FROM auditorias."Roles" r
JOIN auditorias."Permisos" p ON p."Codigo"='CRUD_CATALOGOS'
WHERE r."Nombre"='ADMINISTRADOR'
AND NOT EXISTS (
  SELECT 1 FROM auditorias."RolPermisos" rp
  WHERE rp."RolId"=r."Id" AND rp."PermisoId"=p."Id"
);
































