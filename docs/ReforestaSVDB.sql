USE master;
GO
CREATE DATABASE ReforestaSVDB;
GO
USE ReforestaSVDB;
GO

/* ---------------- TABLA: USUARIOS ---------------- */
CREATE TABLE usuarios
(
    id          INT IDENTITY(1,1) NOT NULL,
    nombre      VARCHAR(200) NOT NULL,
    telefono    VARCHAR(8)   NULL,
    correo      VARCHAR(250) NULL,
    institucion VARCHAR(200) NULL,
    localidad   VARCHAR(200) NULL,
    rol         VARCHAR(20)  NOT NULL
        CONSTRAINT DF_usuarios_rol DEFAULT 'VOLUNTARIO',
    activo      BIT NOT NULL
        CONSTRAINT DF_usuarios_activo DEFAULT 1,

    CONSTRAINT PK_usuarios PRIMARY KEY (id),
    CONSTRAINT CK_usuarios_rol
        CHECK (rol IN ('ADMIN', 'VOLUNTARIO', 'RESPONSABLE')),
    CONSTRAINT CK_usuarios_correo
        CHECK (correo IS NULL OR correo LIKE '%_@_%._%'),
    CONSTRAINT CK_usuarios_telefono
        CHECK (telefono IS NULL
               OR (LEN(telefono) = 8 AND telefono NOT LIKE '%[^0-9]%')),
    CONSTRAINT CK_usuarios_campos_rol
        CHECK
        (
               (rol = 'ADMIN'       AND institucion IS NULL AND localidad IS NULL)
            OR (rol = 'VOLUNTARIO'  AND institucion IS NULL)
            OR (rol = 'RESPONSABLE' AND localidad IS NULL)
        )
);
GO

/* ---------------- TABLA: ESPECIES ---------------- */
CREATE TABLE especies
(
    id     INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT PK_especies PRIMARY KEY (id),
    CONSTRAINT UQ_especies_nombre UNIQUE (nombre)
);
GO

/* ---------------- TABLA: UBICACIONES ---------------- */
CREATE TABLE ubicaciones
(
    id        INT IDENTITY(1,1) NOT NULL,
    zona      VARCHAR(150) NOT NULL,
    ubicacion VARCHAR(250) NOT NULL,
    CONSTRAINT PK_ubicaciones PRIMARY KEY (id),
    CONSTRAINT UQ_ubicaciones_zona_ubicacion UNIQUE (zona, ubicacion)
);
GO

/* ---------------- TABLA: CAMPANIAS ---------------- */
CREATE TABLE campanias
(
    id             INT IDENTITY(1,1) NOT NULL,
    titulo         VARCHAR(150) NOT NULL,
    descripcion    VARCHAR(200) NULL,
    responsable_id INT NOT NULL,
    meta_arboles   INT NOT NULL,
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE NULL,

    CONSTRAINT PK_campanias PRIMARY KEY (id),
    CONSTRAINT CK_campanias_meta
        CHECK (meta_arboles > 0),
    CONSTRAINT CK_campanias_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT FK_campanias_usuarios
        FOREIGN KEY (responsable_id) REFERENCES usuarios(id)
);
GO

/* ---------------- TABLA: INVENTARIOS (LOTES) ---------------- */
CREATE TABLE inventarios
(
    id                INT IDENTITY(1,1) NOT NULL,
    especie_id        INT NOT NULL,
    cantidad          INT NOT NULL,
    campania_id       INT NOT NULL,
    img_url           VARCHAR(250) NULL,
    ubicacion_id      INT NOT NULL,
    usuario_id        INT NOT NULL,
    estado_aprobacion VARCHAR(20) NOT NULL
        CONSTRAINT DF_inventarios_aprobacion DEFAULT 'PENDIENTE',
    aprobado_por      INT NULL,
    fecha_aprobacion  DATETIME2 NULL,

    CONSTRAINT PK_inventarios PRIMARY KEY (id),
    CONSTRAINT CK_inventarios_cantidad
        CHECK (cantidad > 0),
    CONSTRAINT CK_inventarios_estado_aprobacion
        CHECK (estado_aprobacion IN ('PENDIENTE', 'APROBADO', 'RECHAZADO')),
    CONSTRAINT CK_inventarios_aprobacion
        CHECK
        (
               (estado_aprobacion = 'PENDIENTE'
                AND aprobado_por IS NULL AND fecha_aprobacion IS NULL)
            OR (estado_aprobacion IN ('APROBADO', 'RECHAZADO')
                AND aprobado_por IS NOT NULL AND fecha_aprobacion IS NOT NULL)
        ),
    CONSTRAINT FK_inventarios_especies
        FOREIGN KEY (especie_id) REFERENCES especies(id),
    CONSTRAINT FK_inventarios_campanias
        FOREIGN KEY (campania_id) REFERENCES campanias(id) ON DELETE CASCADE,
    CONSTRAINT FK_inventarios_ubicaciones
        FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id),
    CONSTRAINT FK_inventarios_usuarios
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT FK_inventarios_aprobador
        FOREIGN KEY (aprobado_por) REFERENCES usuarios(id)
);
GO

/* ---------------- TABLA: ARBOLES_PLANTADOS ---------------- */
CREATE TABLE arboles_plantados
(
    id            INT IDENTITY(1,1) NOT NULL,
    fecha         DATE NOT NULL,
    estado        VARCHAR(50) NOT NULL
        CONSTRAINT DF_arboles_plantados_estado DEFAULT 'SANO',
    inventario_id INT NOT NULL,

    CONSTRAINT PK_arboles_plantados PRIMARY KEY (id),
    CONSTRAINT CK_arboles_plantados_estado
        CHECK (estado IN ('SANO', 'DETERIORADO', 'PERDIDO')),
    CONSTRAINT FK_arboles_plantados_inventarios
        FOREIGN KEY (inventario_id) REFERENCES inventarios(id) ON DELETE CASCADE
);
GO

/* ---------------- TABLA: MANTENIMIENTOS ---------------- */
CREATE TABLE mantenimientos
(
    id                INT IDENTITY(1,1) NOT NULL,
    fecha             DATETIME2 NOT NULL
        CONSTRAINT DF_mantenimientos_fecha DEFAULT SYSDATETIME(),
    descripcion       VARCHAR(250) NOT NULL,
    arbol_plantado_id INT NOT NULL,

    CONSTRAINT PK_mantenimientos PRIMARY KEY (id),
    CONSTRAINT FK_mantenimientos_arboles_plantados
        FOREIGN KEY (arbol_plantado_id) REFERENCES arboles_plantados(id) ON DELETE CASCADE
);
GO

/* ================================================================
    Índices para claves foráneas y consultas frecuentes
   ================================================================ */

CREATE UNIQUE INDEX UX_usuarios_correo
    ON usuarios(correo) WHERE correo IS NOT NULL;
CREATE INDEX IX_campanias_responsable_id        ON campanias(responsable_id);
CREATE INDEX IX_inventarios_especie_id          ON inventarios(especie_id);
CREATE INDEX IX_inventarios_campania_id         ON inventarios(campania_id);
CREATE INDEX IX_inventarios_ubicacion_id        ON inventarios(ubicacion_id);
CREATE INDEX IX_inventarios_usuario_id          ON inventarios(usuario_id);
CREATE INDEX IX_inventarios_aprobado_por        ON inventarios(aprobado_por);
CREATE INDEX IX_inventarios_estado_aprobacion   ON inventarios(estado_aprobacion);
CREATE INDEX IX_arboles_plantados_inventario_id ON arboles_plantados(inventario_id);
CREATE INDEX IX_arboles_plantados_estado        ON arboles_plantados(estado);
CREATE INDEX IX_mantenimientos_arbol_plantado_id ON mantenimientos(arbol_plantado_id);
GO

/* ================================================================
   Triggers de reglas de negocio
   ================================================================ */

/* RN-06: el responsable de la campaña debe ser RESPONSABLE y estar activo */
CREATE TRIGGER trg_campanias_valida_responsable
ON campanias
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(responsable_id)
       AND EXISTS
       (
           SELECT 1
           FROM inserted AS i
           INNER JOIN usuarios AS u ON u.id = i.responsable_id
           WHERE u.rol <> 'RESPONSABLE' OR u.activo = 0
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'El responsable de la campaña debe tener rol RESPONSABLE y estar activo.', 1;
    END;
END;
GO

/* RN-07: el usuario del lote debe ser VOLUNTARIO o RESPONSABLE y estar activo */
CREATE TRIGGER trg_inventarios_valida_usuario
ON inventarios
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(usuario_id)
       AND EXISTS
       (
           SELECT 1
           FROM inserted AS i
           INNER JOIN usuarios AS u ON u.id = i.usuario_id
           WHERE u.rol NOT IN ('VOLUNTARIO', 'RESPONSABLE') OR u.activo = 0
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, 'El usuario asignado al lote debe ser VOLUNTARIO o RESPONSABLE y estar activo.', 1;
    END;
END;
GO

/* RN-08: solo un ADMIN activo puede aprobar o rechazar un lote */
CREATE TRIGGER trg_inventarios_valida_aprobador
ON inventarios
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(aprobado_por)
       AND EXISTS
       (
           SELECT 1
           FROM inserted AS i
           INNER JOIN usuarios AS u ON u.id = i.aprobado_por
           WHERE u.rol <> 'ADMIN' OR u.activo = 0
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50005, 'Solo un usuario ADMIN activo puede aprobar o rechazar un lote.', 1;
    END;
END;
GO

/* RN-09: los árboles registrados no superan la cantidad del lote */
CREATE TRIGGER trg_arboles_plantados_limite_lote
ON arboles_plantados
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS
    (
        SELECT 1
        FROM inventarios AS inv
        WHERE inv.id IN (SELECT inventario_id FROM inserted)
          AND (SELECT COUNT(*) FROM arboles_plantados AS a
               WHERE a.inventario_id = inv.id) > inv.cantidad
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, 'Los árboles registrados superan la cantidad del lote.', 1;
    END;
END;
GO

/* RN-09: la cantidad del lote no baja de los árboles ya registrados */
CREATE TRIGGER trg_inventarios_cantidad_minima
ON inventarios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(cantidad)
       AND EXISTS
       (
           SELECT 1
           FROM inserted AS i
           WHERE (SELECT COUNT(*) FROM arboles_plantados AS a
                  WHERE a.inventario_id = i.id) > i.cantidad
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'La cantidad del lote no puede ser menor a los árboles ya registrados.', 1;
    END;
END;
GO

/* RN-02: un cambio de rol o una baja no puede dejar datos inválidos */
CREATE TRIGGER trg_usuarios_integridad
ON usuarios
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF (UPDATE(rol) OR UPDATE(activo))
       AND EXISTS
       (
           SELECT 1
           FROM inserted AS i
           WHERE
               -- deja de ser RESPONSABLE pero todavía coordina campañas
               (i.rol <> 'RESPONSABLE'
                AND EXISTS (SELECT 1 FROM campanias AS c WHERE c.responsable_id = i.id))
               -- pasa a ADMIN pero tiene lotes asignados como usuario de campo
            OR (i.rol = 'ADMIN'
                AND EXISTS (SELECT 1 FROM inventarios AS v WHERE v.usuario_id = i.id))
               -- deja de ser ADMIN pero aprobó lotes
            OR (i.rol <> 'ADMIN'
                AND EXISTS (SELECT 1 FROM inventarios AS v WHERE v.aprobado_por = i.id))
               -- se desactiva un responsable con campañas vigentes
            OR (i.activo = 0
                AND EXISTS (SELECT 1 FROM campanias AS c
                            WHERE c.responsable_id = i.id
                              AND (c.fecha_fin IS NULL
                                   OR c.fecha_fin >= CAST(GETDATE() AS DATE))))
       )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50006, 'El cambio de rol o la baja del usuario deja campañas o lotes con datos inválidos.', 1;
    END;
END;
GO

/* ================================================================
    Vistas de resumen
   ================================================================ */

/* Resumen de árboles por campaña, especie y estado */
CREATE VIEW vw_resumen_estado_campania
AS
SELECT
    c.id     AS campania_id,
    c.titulo AS campania,
    e.nombre AS especie,
    a.estado,
    COUNT(*) AS total_arboles
FROM campanias AS c
INNER JOIN inventarios AS i ON i.campania_id = c.id
INNER JOIN especies AS e ON e.id = i.especie_id
INNER JOIN arboles_plantados AS a ON a.inventario_id = i.id
GROUP BY c.id, c.titulo, e.nombre, a.estado;
GO

/* RF-05: meta planificada frente a árboles realmente plantados */
CREATE VIEW vw_avance_campania
AS
SELECT
    c.id           AS campania_id,
    c.titulo       AS campania,
    c.meta_arboles,
    t.plantados    AS arboles_plantados,
    ISNULL(t.sanos, 0) AS arboles_sanos,
    CASE WHEN c.meta_arboles > t.plantados
         THEN c.meta_arboles - t.plantados ELSE 0 END AS faltan_para_meta,
    CAST(100.0 * t.plantados / c.meta_arboles AS DECIMAL(6,1)) AS porcentaje_meta,
    CASE WHEN t.plantados = 0 THEN NULL
         ELSE CAST(100.0 * ISNULL(t.sanos, 0) / t.plantados AS DECIMAL(5,1))
    END AS porcentaje_sanos
FROM campanias AS c
CROSS APPLY
(
    SELECT COUNT(*) AS plantados,
           SUM(CASE WHEN a.estado = 'SANO' THEN 1 ELSE 0 END) AS sanos
    FROM inventarios AS i
    INNER JOIN arboles_plantados AS a ON a.inventario_id = i.id
    WHERE i.campania_id = c.id
) AS t;
GO

/* ================================================================
    Datos de prueba (simulados)
   ================================================================ */

/* ---------------- 10 USUARIOS ---------------- */
INSERT INTO usuarios (nombre, telefono, correo, institucion, localidad, rol)
VALUES
(N'Administrador ReforestaSV', '22001234', 'admin@reforestasv.org', NULL, NULL, 'ADMIN'),
(N'Pedro Tejada', '77001122', 'pedro.tejada@adesco.org', N'ADESCO Lomas de Camachalo', NULL, 'RESPONSABLE'),
(N'Marta Elena Rivas', '77002233', 'marta.rivas@alcaldianejapa.gob.sv', N'Alcaldía de Nejapa', NULL, 'RESPONSABLE'),
(N'Jorge Alberto Mejía', '77003344', 'jorge.mejia@comitejuvenil.org', N'Comité Ambiental Juvenil', NULL, 'RESPONSABLE'),
(N'Erick Fuentes', '78003344', 'erick.fuentes@mail.com', NULL, N'Lomas de Camachalo', 'VOLUNTARIO'),
(N'Ana López', '78004455', 'ana.lopez@mail.com', NULL, N'Nejapa', 'VOLUNTARIO'),
(N'Luis Martínez', '78005566', 'luis.martinez@mail.com', NULL, N'Apopa', 'VOLUNTARIO'),
(N'Carolina Hernández', '78006677', 'carolina.hernandez@mail.com', NULL, N'Lomas de Camachalo', 'VOLUNTARIO'),
(N'Roberto Alas', '78007788', 'roberto.alas@mail.com', NULL, N'Nejapa', 'VOLUNTARIO'),
(N'Daniela Portillo', '78008899', 'daniela.portillo@mail.com', NULL, N'Apopa', 'VOLUNTARIO');
GO

/* ---------------- 10 ESPECIES ---------------- */
INSERT INTO especies (nombre)
VALUES (N'Ceiba'), (N'Maquilishuat'), (N'Cedro'), (N'Mango indio'), (N'Palma'),
       (N'Pino'), (N'Madrecacao'), (N'Conacaste'), (N'Cortés blanco'), (N'Jocote');
GO

/* ---------------- 10 UBICACIONES ---------------- */
INSERT INTO ubicaciones (zona, ubicacion)
VALUES
(N'Cerro Nejapa', N'Ladera norte'),
(N'Cerro Nejapa', N'Ladera sur'),
(N'Cerro Nejapa', N'Cima del cerro'),
(N'Lomas de Camachalo', N'Caserío Lomas de Camachalo'),
(N'Lomas de Camachalo', N'Quebrada de acceso'),
(N'Parque Las Minas', N'Sector entrada'),
(N'Parque Las Minas', N'Sector oriente'),
(N'Nejapa', N'Camino hacia Apopa'),
(N'Apopa', N'Zona alta de Apopa'),
(N'Nejapa', N'Cauce de la quebrada Las Cañas');
GO

/* ---------------- 10 CAMPAÑAS (con meta de árboles) ---------------- */
INSERT INTO campanias (titulo, descripcion, responsable_id, meta_arboles, fecha_inicio, fecha_fin)
VALUES
(N'Reforestación Parque Las Minas', N'Siembra de especies nativas en el parque', 2, 10, '2026-10-23', '2026-12-16'),
(N'Reforestación Cerro Nejapa 2026', N'Siembra en la ladera norte del cerro', 3, 8, '2026-11-01', '2026-11-30'),
(N'Siembra Lomas de Camachalo', N'Jornada comunitaria en el caserío', 2, 10, '2026-07-10', '2026-07-25'),
(N'Jornada Ladera Norte', N'Recuperación de zonas de erosión', 4, 8, '2026-08-01', '2026-08-15'),
(N'Recuperación de Quebrada', N'Protección de la quebrada de acceso', 3, 12, '2026-08-20', '2026-09-05'),
(N'Campaña Cima del Cerro', N'Reforestación de la parte alta del cerro', 4, 6, '2026-09-10', '2026-09-30'),
(N'Reforestación Zona Alta de Apopa', N'Siembra en zonas altas de Apopa', 2, 10, '2026-09-15', '2026-10-15'),
(N'Siembra Escolar Nejapa', N'Jornada con estudiantes de la zona', 3, 5, '2026-05-04', '2026-05-18'),
(N'Jornada de Invierno', N'Siembra aprovechando la época lluviosa', 4, 8, '2026-06-01', '2026-06-20'),
(N'Campaña Cauce Las Cañas', N'Reforestación del cauce de la quebrada', 2, 10, '2026-12-01', NULL);
GO

/* ---------------- 10 INVENTARIOS (LOTES) ---------------- */
INSERT INTO inventarios (especie_id, cantidad, campania_id, img_url, ubicacion_id, usuario_id)
VALUES
(1, 5, 1, NULL, 6, 5),
(5, 3, 1, NULL, 6, 6),
(4, 4, 2, 'evidencias/mango_lote3.jpg', 1, 5),
(2, 6, 3, 'evidencias/maquilishuat_lote4.jpg', 4, 8),
(3, 5, 4, NULL, 1, 7),
(6, 8, 5, 'evidencias/pino_lote6.jpg', 5, 9),
(8, 4, 6, NULL, 3, 10),
(7, 6, 7, NULL, 9, 6),
(10, 3, 8, 'evidencias/jocote_lote9.jpg', 8, 7),
(9, 5, 9, NULL, 2, 8);
GO

/* El administrador (id 1) aprueba los lotes 1 a 8; los lotes 9 y 10 quedan PENDIENTES */
UPDATE inventarios
SET estado_aprobacion = 'APROBADO',
    aprobado_por      = 1,
    fecha_aprobacion  = SYSDATETIME()
WHERE id BETWEEN 1 AND 8;
GO

/* ---------------- 20 ÁRBOLES PLANTADOS ---------------- */
INSERT INTO arboles_plantados (fecha, estado, inventario_id)
VALUES
('2026-10-23', 'SANO', 1), ('2026-10-23', 'SANO', 1), ('2026-10-24', 'DETERIORADO', 1),
('2026-10-23', 'SANO', 2), ('2026-10-24', 'PERDIDO', 2),
('2026-11-02', 'SANO', 3), ('2026-11-02', 'SANO', 3),
('2026-07-12', 'SANO', 4), ('2026-07-12', 'DETERIORADO', 4), ('2026-07-13', 'SANO', 4),
('2026-08-03', 'SANO', 5), ('2026-08-03', 'PERDIDO', 5),
('2026-08-22', 'SANO', 6), ('2026-08-23', 'SANO', 6),
('2026-09-12', 'DETERIORADO', 7), ('2026-09-12', 'SANO', 7),
('2026-09-17', 'SANO', 8), ('2026-09-18', 'SANO', 8),
('2026-05-06', 'PERDIDO', 9),
('2026-06-03', 'SANO', 10);
GO

/* ---------------- 15 MANTENIMIENTOS ---------------- */
INSERT INTO mantenimientos (fecha, descripcion, arbol_plantado_id)
VALUES
('2026-10-24T08:30:00', N'Riego inicial', 1),
('2026-10-24T09:00:00', N'Riego inicial', 2),
('2026-10-30T10:15:00', N'Riego y control de plagas', 3),
('2026-10-31T08:45:00', N'Inspección: el árbol se perdió', 5),
('2026-11-05T09:30:00', N'Poda de formación', 6),
('2026-07-20T08:00:00', N'Riego', 8),
('2026-07-27T07:50:00', N'Fertilización', 9),
('2026-08-10T09:10:00', N'Riego', 11),
('2026-08-14T10:00:00', N'Inspección: el árbol se perdió', 12),
('2026-08-28T08:20:00', N'Poda de formación', 13),
('2026-09-20T09:40:00', N'Fertilización', 15),
('2026-09-25T08:05:00', N'Riego', 16),
('2026-05-12T07:30:00', N'Inspección: el árbol se perdió', 19),
('2026-06-10T09:00:00', N'Riego', 20),
('2026-10-30T09:00:00', N'Riego', 1);
GO

/* ================================================================
    Validación de la carga y consulta general
   ================================================================ */

/* Conteo de registros por tabla (esperado: 10, 10, 10, 10, 10, 20, 15) */
SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL SELECT 'especies',          COUNT(*) FROM especies
UNION ALL SELECT 'ubicaciones',       COUNT(*) FROM ubicaciones
UNION ALL SELECT 'campanias',         COUNT(*) FROM campanias
UNION ALL SELECT 'inventarios',       COUNT(*) FROM inventarios
UNION ALL SELECT 'arboles_plantados', COUNT(*) FROM arboles_plantados
UNION ALL SELECT 'mantenimientos',    COUNT(*) FROM mantenimientos;
GO

/* Consulta general con múltiples JOIN para validar las relaciones */
SELECT
    c.id AS campania_id, c.titulo AS campania, c.meta_arboles,
    r.nombre AS responsable,
    i.id AS lote_id, i.estado_aprobacion,
    e.nombre AS especie, i.cantidad,
    ub.zona, ub.ubicacion,
    v.nombre AS usuario_de_campo,
    a.id AS arbol_id, a.fecha AS fecha_siembra, a.estado,
    m.fecha AS fecha_mantenimiento, m.descripcion AS mantenimiento
FROM campanias AS c
INNER JOIN usuarios AS r       ON c.responsable_id = r.id
INNER JOIN inventarios AS i    ON i.campania_id = c.id
INNER JOIN especies AS e       ON i.especie_id = e.id
INNER JOIN ubicaciones AS ub   ON i.ubicacion_id = ub.id
INNER JOIN usuarios AS v       ON i.usuario_id = v.id
INNER JOIN arboles_plantados AS a ON a.inventario_id = i.id
LEFT JOIN mantenimientos AS m  ON m.arbol_plantado_id = a.id
ORDER BY c.id, i.id, a.id, m.fecha;
GO

/* ================================================================
    Consultas de inserción
   ================================================================ */

INSERT INTO usuarios (nombre, telefono, correo, localidad, rol)
VALUES (N'Sofía Granados', '70112233', 'sofia.granados@mail.com', N'Nejapa', 'VOLUNTARIO');

INSERT INTO especies (nombre) VALUES (N'Laurel');

DECLARE @especie    INT = (SELECT id FROM especies WHERE nombre = N'Laurel');
DECLARE @campania   INT = (SELECT id FROM campanias WHERE titulo = N'Reforestación Cerro Nejapa 2026');
DECLARE @ubicacion  INT = (SELECT id FROM ubicaciones WHERE ubicacion = N'Cima del cerro');
DECLARE @voluntario INT = (SELECT id FROM usuarios WHERE nombre = N'Sofía Granados');
DECLARE @lote INT;

INSERT INTO inventarios (especie_id, cantidad, campania_id, ubicacion_id, usuario_id)
VALUES (@especie, 6, @campania, @ubicacion, @voluntario);
SET @lote = SCOPE_IDENTITY();

INSERT INTO arboles_plantados (fecha, inventario_id)
VALUES ('2026-11-03', @lote), ('2026-11-03', @lote);

SELECT * FROM arboles_plantados WHERE inventario_id = @lote;
GO

/* ================================================================
    Consultas de actualización
   ================================================================ */

UPDATE arboles_plantados SET estado = 'PERDIDO' WHERE id = 3;
UPDATE inventarios SET cantidad = 7 WHERE id = 1;
UPDATE campanias SET fecha_fin = '2026-12-31' WHERE titulo = N'Reforestación Parque Las Minas';
UPDATE usuarios SET telefono = '78009999' WHERE nombre = N'Ana López';
UPDATE mantenimientos SET descripcion = N'Poda de formación y fertilización' WHERE id = 5;

/* Aprobación de un lote pendiente por el administrador (RF-07) */
UPDATE inventarios
SET estado_aprobacion = 'APROBADO', aprobado_por = 1, fecha_aprobacion = SYSDATETIME()
WHERE id = 9;

/* Baja lógica de un usuario sin borrar su historial (RF-08) */
UPDATE usuarios SET activo = 0 WHERE nombre = N'Roberto Alas';

SELECT id, estado FROM arboles_plantados WHERE id = 3;
SELECT id, cantidad FROM inventarios WHERE id = 1;
SELECT id, nombre, activo FROM usuarios WHERE nombre = N'Roberto Alas';
GO

/* ================================================================
   Consultas de eliminación
   ================================================================ */

DELETE FROM mantenimientos   WHERE id = 15;
DELETE FROM arboles_plantados WHERE id = 20;
GO

DECLARE @responsable INT = (SELECT id FROM usuarios WHERE nombre = N'Pedro Tejada');
DECLARE @voluntario  INT = (SELECT id FROM usuarios WHERE nombre = N'Erick Fuentes');
DECLARE @especie     INT = (SELECT id FROM especies WHERE nombre = N'Ceiba');
DECLARE @ubicacion   INT = (SELECT TOP 1 id FROM ubicaciones ORDER BY id);
DECLARE @campania INT, @lote INT;

INSERT INTO campanias (titulo, descripcion, responsable_id, meta_arboles, fecha_inicio, fecha_fin)
VALUES (N'Campaña temporal', N'Prueba de eliminación en cascada', @responsable, 2, '2026-12-01', '2026-12-02');
SET @campania = SCOPE_IDENTITY();

INSERT INTO inventarios (especie_id, cantidad, campania_id, ubicacion_id, usuario_id)
VALUES (@especie, 2, @campania, @ubicacion, @voluntario);
SET @lote = SCOPE_IDENTITY();

INSERT INTO arboles_plantados (fecha, inventario_id)
VALUES ('2026-12-01', @lote), ('2026-12-01', @lote);

INSERT INTO mantenimientos (descripcion, arbol_plantado_id)
SELECT N'Riego', MIN(id) FROM arboles_plantados WHERE inventario_id = @lote;

SELECT 'ANTES' AS momento,
    (SELECT COUNT(*) FROM inventarios WHERE campania_id = @campania) AS lotes,
    (SELECT COUNT(*) FROM arboles_plantados WHERE inventario_id = @lote) AS arboles,
    (SELECT COUNT(*) FROM mantenimientos AS m
       INNER JOIN arboles_plantados AS a ON a.id = m.arbol_plantado_id
       WHERE a.inventario_id = @lote) AS mantenimientos;

DELETE FROM campanias WHERE id = @campania;

SELECT 'DESPUES' AS momento,
    (SELECT COUNT(*) FROM inventarios WHERE campania_id = @campania) AS lotes,
    (SELECT COUNT(*) FROM arboles_plantados WHERE inventario_id = @lote) AS arboles,
    (SELECT COUNT(*) FROM mantenimientos AS m
       INNER JOIN arboles_plantados AS a ON a.id = m.arbol_plantado_id
       WHERE a.inventario_id = @lote) AS mantenimientos;
GO

/* ================================================================
    Consultas de información y reportes
   ================================================================ */

/* 1. Árboles de ciertas especies que no están perdidos (JOIN + filtro) */
SELECT a.id AS arbol_id, e.nombre AS especie, c.titulo AS campania, a.fecha, a.estado
FROM arboles_plantados AS a
INNER JOIN inventarios AS i ON a.inventario_id = i.id
INNER JOIN especies AS e    ON i.especie_id = e.id
INNER JOIN campanias AS c   ON i.campania_id = c.id
WHERE e.nombre IN (N'Ceiba', N'Palma', N'Cedro') AND a.estado <> 'PERDIDO'
ORDER BY a.fecha DESC;

/* 2. Total de árboles por estado (agregación) */
SELECT estado, COUNT(*) AS total_arboles
FROM arboles_plantados
GROUP BY estado
ORDER BY total_arboles DESC;

/* 3. META PLANIFICADA FRENTE A RESULTADO REAL por campaña (RF-05) */
SELECT campania, meta_arboles, arboles_plantados,
       faltan_para_meta, porcentaje_meta, porcentaje_sanos
FROM vw_avance_campania
ORDER BY porcentaje_meta DESC;

/* 4. Lotes sin seguimiento: cantidad del lote contra árboles registrados (subconsulta en JOIN) */
SELECT c.titulo AS campania,
       SUM(i.cantidad) AS cantidad_en_lotes,
       SUM(ISNULL(t.registrados, 0)) AS arboles_registrados,
       SUM(i.cantidad) - SUM(ISNULL(t.registrados, 0)) AS sin_seguimiento
FROM campanias AS c
INNER JOIN inventarios AS i ON i.campania_id = c.id
LEFT JOIN (SELECT inventario_id, COUNT(*) AS registrados
           FROM arboles_plantados GROUP BY inventario_id) AS t
       ON t.inventario_id = i.id
GROUP BY c.id, c.titulo
ORDER BY c.titulo;

/* 5. Estadísticas por especie (funciones de agregación) */
SELECT e.nombre AS especie, COUNT(i.id) AS lotes, SUM(i.cantidad) AS total_plantado,
       CAST(AVG(CAST(i.cantidad AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS promedio_por_lote,
       MIN(i.cantidad) AS lote_menor, MAX(i.cantidad) AS lote_mayor
FROM especies AS e
INNER JOIN inventarios AS i ON i.especie_id = e.id
GROUP BY e.id, e.nombre
ORDER BY total_plantado DESC;

/* 6. Lotes por encima del promedio (subconsulta escalar) */
SELECT i.id AS lote_id, e.nombre AS especie, i.cantidad
FROM inventarios AS i
INNER JOIN especies AS e ON i.especie_id = e.id
WHERE i.cantidad > (SELECT AVG(cantidad) FROM inventarios)
ORDER BY i.cantidad DESC;

/* 7. Árboles que nunca han recibido mantenimiento (NOT EXISTS) */
SELECT a.id AS arbol_id, a.fecha, a.estado
FROM arboles_plantados AS a
WHERE NOT EXISTS (SELECT 1 FROM mantenimientos AS m WHERE m.arbol_plantado_id = a.id)
ORDER BY a.id;

/* 8. Campañas coordinadas por ADESCO (subconsulta con IN) */
SELECT c.id, c.titulo, c.fecha_inicio
FROM campanias AS c
WHERE c.responsable_id IN (SELECT id FROM usuarios WHERE institucion LIKE N'ADESCO%')
ORDER BY c.fecha_inicio;

/* 9. Funciones de texto y fecha */
SELECT UPPER(titulo) AS campania,
       DATENAME(MONTH, fecha_inicio) AS mes_inicio,
       YEAR(fecha_inicio) AS anio,
       DATEDIFF(DAY, fecha_inicio, fecha_fin) AS duracion_dias
FROM campanias
ORDER BY fecha_inicio;

/* 10. Último mantenimiento de cada árbol (OUTER APPLY) */
SELECT a.id AS arbol_id, a.estado, m.fecha AS ultimo_mantenimiento, m.descripcion
FROM arboles_plantados AS a
OUTER APPLY (SELECT TOP 1 fecha, descripcion FROM mantenimientos
             WHERE arbol_plantado_id = a.id ORDER BY fecha DESC) AS m
ORDER BY a.id;

/* 11. Lotes pendientes de aprobación */
SELECT i.id AS lote_id, c.titulo AS campania, e.nombre AS especie, i.cantidad, u.nombre AS usuario_de_campo
FROM inventarios AS i
INNER JOIN campanias AS c ON c.id = i.campania_id
INNER JOIN especies AS e  ON e.id = i.especie_id
INNER JOIN usuarios AS u  ON u.id = i.usuario_id
WHERE i.estado_aprobacion = 'PENDIENTE';

/* 12. Vista de resumen por campaña, especie y estado */
SELECT * FROM vw_resumen_estado_campania ORDER BY campania, especie, estado;
GO