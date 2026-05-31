-- ============================================================
--  PLATAFORMA DE PRÁCTICAS PEDAGÓGICAS
--  Script DDL para Oracle 10g XE
--  Ejecutar conectado al esquema: practicas (o el que uses)
--  Versión 1.0 | 2026
-- ============================================================
--
--  INSTRUCCIONES:
--  1. Conectar con SQL*Plus o SQL Developer al esquema destino:
--     CONNECT practicas/tu_password@XE
--  2. Ejecutar este script completo: @crear_tablas_oracle.sql
--
-- ============================================================

-- Limpiar objetos anteriores si existen (útil en re-ejecuciones)
BEGIN
  FOR t IN (SELECT table_name FROM user_tables) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ============================================================
-- SECUENCIAS (reemplazan AUTO_INCREMENT de MySQL)
-- ============================================================
CREATE SEQUENCE SEQ_PROGRAMA        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USUARIO         START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PRACTICA        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_INSTITUCION     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CONVENIO        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_GRUPO           START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_GRUPO_EST       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_GRUPO_DOC       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ACTIVIDAD       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_EVIDENCIA       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_VISITA          START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_BANCO_PREG      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CUESTIONARIO    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_CUEST_PREG      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_RESPUESTA       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_RUBRICA         START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_RUB_CRITERIO    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_EVAL_FINAL      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_LOG             START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================
-- 1. TABLA: PROGRAMA
--    Oracle: VARCHAR2, NUMBER(1) en lugar de BOOLEAN,
--            TIMESTAMP en lugar de DATETIME
-- ============================================================
CREATE TABLE programa (
    id              NUMBER(10)    NOT NULL,
    nombre          VARCHAR2(200) NOT NULL,
    codigo_snies    VARCHAR2(20),
    facultad        VARCHAR2(200) NOT NULL,
    modalidad       VARCHAR2(20)  NOT NULL,
    nivel           VARCHAR2(20)  DEFAULT 'Pregrado' NOT NULL,
    acreditado      NUMBER(1)     DEFAULT 0 NOT NULL,
    fecha_registro  TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    activo          NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_programa       PRIMARY KEY (id),
    CONSTRAINT uq_programa_nom   UNIQUE (nombre),
    CONSTRAINT chk_prog_modal    CHECK (modalidad IN ('Presencial','Virtual','A distancia','Mixta')),
    CONSTRAINT chk_prog_nivel    CHECK (nivel IN ('Pregrado','Posgrado')),
    CONSTRAINT chk_prog_acred    CHECK (acreditado IN (0,1)),
    CONSTRAINT chk_prog_activo   CHECK (activo IN (0,1))
);

COMMENT ON TABLE  programa               IS 'Programas de licenciatura del sistema';
COMMENT ON COLUMN programa.acreditado    IS '1=Acreditado, 0=No acreditado';
COMMENT ON COLUMN programa.activo        IS '1=Activo, 0=Eliminado logico';

-- ============================================================
-- 2. TABLA: USUARIO
-- ============================================================
CREATE TABLE usuario (
    id                NUMBER(10)    NOT NULL,
    id_programa       NUMBER(10),
    nombres           VARCHAR2(100) NOT NULL,
    apellidos         VARCHAR2(100) NOT NULL,
    tipo_documento    VARCHAR2(15)  NOT NULL,
    numero_documento  VARCHAR2(20)  NOT NULL,
    correo            VARCHAR2(150) NOT NULL,
    contrasena_hash   VARCHAR2(64)  NOT NULL,
    rol               VARCHAR2(20)  NOT NULL,
    telefono          VARCHAR2(20),
    fecha_creacion    TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    ultimo_acceso     TIMESTAMP,
    activo            NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_usuario           PRIMARY KEY (id),
    CONSTRAINT uq_usuario_doc       UNIQUE (numero_documento),
    CONSTRAINT uq_usuario_correo    UNIQUE (correo),
    CONSTRAINT fk_usuario_programa  FOREIGN KEY (id_programa)
                                    REFERENCES programa(id) ON DELETE SET NULL,
    CONSTRAINT chk_usu_tipo_doc     CHECK (tipo_documento IN ('CC','CE','TI','Pasaporte')),
    CONSTRAINT chk_usu_rol          CHECK (rol IN ('Director','Coordinador','Docente','Estudiante','Institucion')),
    CONSTRAINT chk_usu_activo       CHECK (activo IN (0,1))
);

COMMENT ON COLUMN usuario.contrasena_hash IS 'Hash SHA-256 de la contrasena. Nunca texto plano.';

-- ============================================================
-- 3. TABLA: PRACTICA
-- ============================================================
CREATE TABLE practica (
    id              NUMBER(10)    NOT NULL,
    id_programa     NUMBER(10)    NOT NULL,
    numero          NUMBER(1)     NOT NULL,
    nombre          VARCHAR2(200) NOT NULL,
    tipo            VARCHAR2(20)  NOT NULL,
    objetivos       CLOB,
    horas_minimas   NUMBER(6)     NOT NULL,
    semestre        VARCHAR2(20),
    fecha_inicio    DATE          NOT NULL,
    fecha_fin       DATE          NOT NULL,
    estado          VARCHAR2(20)  DEFAULT 'Planificada' NOT NULL,
    fecha_creacion  TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    activo          NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_practica          PRIMARY KEY (id),
    CONSTRAINT uq_practica_num_prog UNIQUE (id_programa, numero),
    CONSTRAINT fk_practica_prog     FOREIGN KEY (id_programa)
                                    REFERENCES programa(id),
    CONSTRAINT chk_prac_numero      CHECK (numero BETWEEN 1 AND 8),
    CONSTRAINT chk_prac_horas       CHECK (horas_minimas > 0),
    CONSTRAINT chk_prac_fechas      CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT chk_prac_tipo        CHECK (tipo IN ('Observacion','Intervencion','Investigativa','Profundizacion','Otro')),
    CONSTRAINT chk_prac_estado      CHECK (estado IN ('Planificada','Activa','Finalizada','Cancelada')),
    CONSTRAINT chk_prac_activo      CHECK (activo IN (0,1))
);

COMMENT ON COLUMN practica.objetivos IS 'CLOB: texto largo de objetivos formativos';

-- ============================================================
-- 4. TABLA: INSTITUCION_RECEPTORA
-- ============================================================
CREATE TABLE institucion_receptora (
    id              NUMBER(10)    NOT NULL,
    nombre          VARCHAR2(300) NOT NULL,
    nit             VARCHAR2(20)  UNIQUE,
    dane            VARCHAR2(20),
    direccion       VARCHAR2(300) NOT NULL,
    municipio       VARCHAR2(100) NOT NULL,
    departamento    VARCHAR2(100) NOT NULL,
    zona            VARCHAR2(10)  NOT NULL,
    nivel_educativo VARCHAR2(100) NOT NULL,
    nombre_rector   VARCHAR2(200),
    correo_contacto VARCHAR2(150),
    telefono        VARCHAR2(20),
    activo          NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_institucion    PRIMARY KEY (id),
    CONSTRAINT chk_inst_zona     CHECK (zona IN ('Urbana','Rural')),
    CONSTRAINT chk_inst_activo   CHECK (activo IN (0,1))
);

-- ============================================================
-- 5. TABLA: CONVENIO
-- ============================================================
CREATE TABLE convenio (
    id                NUMBER(10)    NOT NULL,
    id_programa       NUMBER(10)    NOT NULL,
    id_institucion    NUMBER(10)    NOT NULL,
    numero_convenio   VARCHAR2(50)  NOT NULL,
    fecha_firma       DATE          NOT NULL,
    fecha_inicio      DATE          NOT NULL,
    fecha_vencimiento DATE          NOT NULL,
    objeto            CLOB,
    estado            VARCHAR2(20)  DEFAULT 'En tramite' NOT NULL,
    ruta_documento    VARCHAR2(500),
    fecha_registro    TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_convenio           PRIMARY KEY (id),
    CONSTRAINT uq_convenio_num       UNIQUE (numero_convenio),
    CONSTRAINT fk_conv_programa      FOREIGN KEY (id_programa)
                                     REFERENCES programa(id),
    CONSTRAINT fk_conv_institucion   FOREIGN KEY (id_institucion)
                                     REFERENCES institucion_receptora(id),
    CONSTRAINT chk_conv_fechas       CHECK (fecha_vencimiento >= fecha_inicio),
    CONSTRAINT chk_conv_estado       CHECK (estado IN ('Vigente','Vencido','En tramite','Suspendido'))
);

-- ============================================================
-- 6. TABLA: GRUPO
-- ============================================================
CREATE TABLE grupo (
    id              NUMBER(10)    NOT NULL,
    id_practica     NUMBER(10)    NOT NULL,
    id_institucion  NUMBER(10)    NOT NULL,
    nombre          VARCHAR2(100) NOT NULL,
    cupo_maximo     NUMBER(3)     DEFAULT 30 NOT NULL,
    jornada         VARCHAR2(15),
    observaciones   CLOB,
    fecha_creacion  TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    activo          NUMBER(1)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_grupo         PRIMARY KEY (id),
    CONSTRAINT fk_grupo_prac    FOREIGN KEY (id_practica)
                                REFERENCES practica(id),
    CONSTRAINT fk_grupo_inst    FOREIGN KEY (id_institucion)
                                REFERENCES institucion_receptora(id),
    CONSTRAINT chk_grupo_cupo   CHECK (cupo_maximo > 0),
    CONSTRAINT chk_grupo_jorn   CHECK (jornada IN ('Manana','Tarde','Noche','Completa')),
    CONSTRAINT chk_grupo_act    CHECK (activo IN (0,1))
);

-- ============================================================
-- 7. TABLA: GRUPO_ESTUDIANTE
-- ============================================================
CREATE TABLE grupo_estudiante (
    id                NUMBER(10)    NOT NULL,
    id_grupo          NUMBER(10)    NOT NULL,
    id_estudiante     NUMBER(10)    NOT NULL,
    fecha_inscripcion DATE          NOT NULL,
    fecha_retiro      DATE,
    causa_retiro      CLOB,
    estado            VARCHAR2(15)  DEFAULT 'Activo' NOT NULL,
    CONSTRAINT pk_grupo_est       PRIMARY KEY (id),
    CONSTRAINT uq_grupo_est       UNIQUE (id_grupo, id_estudiante),
    CONSTRAINT fk_ge_grupo        FOREIGN KEY (id_grupo)
                                  REFERENCES grupo(id),
    CONSTRAINT fk_ge_estudiante   FOREIGN KEY (id_estudiante)
                                  REFERENCES usuario(id),
    CONSTRAINT chk_ge_estado      CHECK (estado IN ('Activo','Retirado','Finalizado'))
);

-- ============================================================
-- 8. TABLA: GRUPO_DOCENTE
-- ============================================================
CREATE TABLE grupo_docente (
    id               NUMBER(10)  NOT NULL,
    id_grupo         NUMBER(10)  NOT NULL,
    id_docente       NUMBER(10)  NOT NULL,
    fecha_asignacion DATE        NOT NULL,
    fecha_fin        DATE,
    es_principal     NUMBER(1)   DEFAULT 1 NOT NULL,
    CONSTRAINT pk_grupo_doc       PRIMARY KEY (id),
    CONSTRAINT fk_gd_grupo        FOREIGN KEY (id_grupo)    REFERENCES grupo(id),
    CONSTRAINT fk_gd_docente      FOREIGN KEY (id_docente)  REFERENCES usuario(id),
    CONSTRAINT chk_gd_principal   CHECK (es_principal IN (0,1))
);

-- ============================================================
-- 9. TABLA: REGISTRO_ACTIVIDAD
-- ============================================================
CREATE TABLE registro_actividad (
    id                 NUMBER(10)   NOT NULL,
    id_grupo_est       NUMBER(10)   NOT NULL,
    fecha_actividad    DATE         NOT NULL,
    tipo_actividad     VARCHAR2(20) NOT NULL,
    descripcion        CLOB         NOT NULL,
    horas_invertidas   NUMBER(4,1)  NOT NULL,
    estado_validacion  VARCHAR2(15) DEFAULT 'Pendiente' NOT NULL,
    id_docente_valida  NUMBER(10),
    observacion_doc    CLOB,
    fecha_registro     TIMESTAMP    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_actividad          PRIMARY KEY (id),
    CONSTRAINT fk_act_grupo_est      FOREIGN KEY (id_grupo_est)
                                     REFERENCES grupo_estudiante(id),
    CONSTRAINT fk_act_docente_val    FOREIGN KEY (id_docente_valida)
                                     REFERENCES usuario(id) ON DELETE SET NULL,
    CONSTRAINT chk_act_horas         CHECK (horas_invertidas BETWEEN 0.5 AND 12),
    CONSTRAINT chk_act_tipo          CHECK (tipo_actividad IN
                                     ('Observacion','Planeacion','Intervencion',
                                      'Evaluacion','Reunion','Otro')),
    CONSTRAINT chk_act_estado        CHECK (estado_validacion IN
                                     ('Pendiente','Aprobado','Rechazado'))
);

-- ============================================================
-- 10. TABLA: EVIDENCIA
-- ============================================================
CREATE TABLE evidencia (
    id              NUMBER(10)    NOT NULL,
    id_actividad    NUMBER(10)    NOT NULL,
    tipo_evidencia  VARCHAR2(15)  NOT NULL,
    nombre_archivo  VARCHAR2(300) NOT NULL,
    ruta_url        VARCHAR2(500) NOT NULL,
    extension       VARCHAR2(10),
    tamanio_kb      NUMBER(10),
    fecha_carga     TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_evidencia       PRIMARY KEY (id),
    CONSTRAINT fk_ev_actividad    FOREIGN KEY (id_actividad)
                                  REFERENCES registro_actividad(id) ON DELETE CASCADE,
    CONSTRAINT chk_ev_tipo        CHECK (tipo_evidencia IN ('Archivo','Enlace','Imagen','Video'))
);

-- ============================================================
-- 11. TABLA: VISITA_DOCENTE
-- ============================================================
CREATE TABLE visita_docente (
    id               NUMBER(10)   NOT NULL,
    id_grupo         NUMBER(10)   NOT NULL,
    id_docente       NUMBER(10)   NOT NULL,
    fecha_visita     DATE         NOT NULL,
    tipo_visita      VARCHAR2(15) NOT NULL,
    estudiantes_obs  CLOB,
    objetivo         CLOB         NOT NULL,
    observaciones    CLOB         NOT NULL,
    recomendaciones  CLOB,
    fecha_registro   TIMESTAMP    DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_visita          PRIMARY KEY (id),
    CONSTRAINT fk_vis_grupo       FOREIGN KEY (id_grupo)   REFERENCES grupo(id),
    CONSTRAINT fk_vis_docente     FOREIGN KEY (id_docente) REFERENCES usuario(id),
    CONSTRAINT chk_vis_tipo       CHECK (tipo_visita IN ('Presencial','Virtual'))
);

-- ============================================================
-- 12. TABLA: BANCO_PREGUNTAS
-- ============================================================
CREATE TABLE banco_preguntas (
    id             NUMBER(10)    NOT NULL,
    id_programa    NUMBER(10)    NOT NULL,
    id_practica    NUMBER(10),
    id_autor       NUMBER(10)    NOT NULL,
    enunciado      CLOB          NOT NULL,
    tipo_pregunta  VARCHAR2(25)  NOT NULL,
    categoria      VARCHAR2(100),
    opciones       CLOB,
    activo         NUMBER(1)     DEFAULT 1 NOT NULL,
    fecha_creacion TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_banco_preg       PRIMARY KEY (id),
    CONSTRAINT fk_bp_programa      FOREIGN KEY (id_programa) REFERENCES programa(id),
    CONSTRAINT fk_bp_practica      FOREIGN KEY (id_practica) REFERENCES practica(id)
                                   ON DELETE SET NULL,
    CONSTRAINT fk_bp_autor         FOREIGN KEY (id_autor)    REFERENCES usuario(id),
    CONSTRAINT chk_bp_tipo         CHECK (tipo_pregunta IN
                                   ('Abierta','Seleccion_multiple',
                                    'Verdadero_falso','Escala_Likert')),
    CONSTRAINT chk_bp_activo       CHECK (activo IN (0,1))
);

-- ============================================================
-- 13. TABLA: CUESTIONARIO
-- ============================================================
CREATE TABLE cuestionario (
    id             NUMBER(10)    NOT NULL,
    id_practica    NUMBER(10)    NOT NULL,
    id_docente     NUMBER(10)    NOT NULL,
    titulo         VARCHAR2(300) NOT NULL,
    descripcion    CLOB,
    es_obligatorio NUMBER(1)     DEFAULT 1 NOT NULL,
    fecha_apertura TIMESTAMP,
    fecha_cierre   TIMESTAMP,
    activo         NUMBER(1)     DEFAULT 1 NOT NULL,
    fecha_creacion TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_cuestionario     PRIMARY KEY (id),
    CONSTRAINT fk_cue_practica     FOREIGN KEY (id_practica) REFERENCES practica(id),
    CONSTRAINT fk_cue_docente      FOREIGN KEY (id_docente)  REFERENCES usuario(id),
    CONSTRAINT chk_cue_obligat     CHECK (es_obligatorio IN (0,1)),
    CONSTRAINT chk_cue_activo      CHECK (activo IN (0,1))
);

-- ============================================================
-- 14. TABLA: CUESTIONARIO_PREGUNTA
-- ============================================================
CREATE TABLE cuestionario_pregunta (
    id              NUMBER(10)  NOT NULL,
    id_cuestionario NUMBER(10)  NOT NULL,
    id_pregunta     NUMBER(10)  NOT NULL,
    orden           NUMBER(3)   DEFAULT 1 NOT NULL,
    obligatoria     NUMBER(1)   DEFAULT 1 NOT NULL,
    CONSTRAINT pk_cuest_preg        PRIMARY KEY (id),
    CONSTRAINT uq_cp_cuest_preg     UNIQUE (id_cuestionario, id_pregunta),
    CONSTRAINT fk_cp_cuestionario   FOREIGN KEY (id_cuestionario)
                                    REFERENCES cuestionario(id) ON DELETE CASCADE,
    CONSTRAINT fk_cp_pregunta       FOREIGN KEY (id_pregunta)
                                    REFERENCES banco_preguntas(id),
    CONSTRAINT chk_cp_obligat       CHECK (obligatoria IN (0,1))
);

-- ============================================================
-- 15. TABLA: RESPUESTA_ESTUDIANTE
-- ============================================================
CREATE TABLE respuesta_estudiante (
    id                NUMBER(10)    NOT NULL,
    id_cuestionario   NUMBER(10)    NOT NULL,
    id_pregunta       NUMBER(10)    NOT NULL,
    id_estudiante     NUMBER(10)    NOT NULL,
    respuesta_texto   CLOB,
    respuesta_opcion  VARCHAR2(200),
    fecha_respuesta   TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    retroalimentacion CLOB,
    fecha_retro       TIMESTAMP,
    id_docente_retro  NUMBER(10),
    CONSTRAINT pk_respuesta           PRIMARY KEY (id),
    CONSTRAINT uq_re_cuest_preg_est   UNIQUE (id_cuestionario, id_pregunta, id_estudiante),
    CONSTRAINT fk_re_cuestionario     FOREIGN KEY (id_cuestionario)
                                      REFERENCES cuestionario(id),
    CONSTRAINT fk_re_pregunta         FOREIGN KEY (id_pregunta)
                                      REFERENCES banco_preguntas(id),
    CONSTRAINT fk_re_estudiante       FOREIGN KEY (id_estudiante)
                                      REFERENCES usuario(id),
    CONSTRAINT fk_re_docente_retro    FOREIGN KEY (id_docente_retro)
                                      REFERENCES usuario(id) ON DELETE SET NULL
);

-- ============================================================
-- 16. TABLA: RUBRICA
-- ============================================================
CREATE TABLE rubrica (
    id             NUMBER(10)    NOT NULL,
    id_practica    NUMBER(10)    NOT NULL,
    id_autor       NUMBER(10)    NOT NULL,
    nombre         VARCHAR2(300) NOT NULL,
    escala_max     NUMBER(5,2)   DEFAULT 5.00 NOT NULL,
    escala_min     NUMBER(5,2)   DEFAULT 3.00 NOT NULL,
    activo         NUMBER(1)     DEFAULT 1 NOT NULL,
    fecha_creacion TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_rubrica         PRIMARY KEY (id),
    CONSTRAINT fk_rub_practica    FOREIGN KEY (id_practica) REFERENCES practica(id),
    CONSTRAINT fk_rub_autor       FOREIGN KEY (id_autor)    REFERENCES usuario(id),
    CONSTRAINT chk_rub_escala     CHECK (escala_max > escala_min AND escala_min >= 0),
    CONSTRAINT chk_rub_activo     CHECK (activo IN (0,1))
);

-- ============================================================
-- 17. TABLA: RUBRICA_CRITERIO
-- ============================================================
CREATE TABLE rubrica_criterio (
    id                NUMBER(10)    NOT NULL,
    id_rubrica        NUMBER(10)    NOT NULL,
    nombre            VARCHAR2(200) NOT NULL,
    descripcion       CLOB,
    ponderacion       NUMBER(5,2)   NOT NULL,
    nivel_excelente   CLOB          NOT NULL,
    nivel_bueno       CLOB          NOT NULL,
    nivel_aceptable   CLOB          NOT NULL,
    nivel_deficiente  CLOB          NOT NULL,
    valor_excelente   NUMBER(5,2)   NOT NULL,
    valor_bueno       NUMBER(5,2)   NOT NULL,
    valor_aceptable   NUMBER(5,2)   NOT NULL,
    valor_deficiente  NUMBER(5,2)   NOT NULL,
    orden             NUMBER(3)     DEFAULT 1 NOT NULL,
    CONSTRAINT pk_rub_criterio      PRIMARY KEY (id),
    CONSTRAINT fk_rc_rubrica        FOREIGN KEY (id_rubrica)
                                    REFERENCES rubrica(id) ON DELETE CASCADE,
    CONSTRAINT chk_rc_ponderacion   CHECK (ponderacion > 0 AND ponderacion <= 100),
    CONSTRAINT chk_rc_valores       CHECK (valor_excelente >= valor_bueno
                                       AND valor_bueno >= valor_aceptable
                                       AND valor_aceptable >= valor_deficiente)
);

-- ============================================================
-- 18. TABLA: EVALUACION_FINAL
-- ============================================================
CREATE TABLE evaluacion_final (
    id                  NUMBER(10)    NOT NULL,
    id_grupo_est        NUMBER(10)    NOT NULL,
    id_rubrica          NUMBER(10)    NOT NULL,
    id_docente          NUMBER(10)    NOT NULL,
    nota_calculada      NUMBER(5,2)   NOT NULL,
    nota_definitiva     NUMBER(5,2)   NOT NULL,
    observacion_general CLOB          NOT NULL,
    detalle_criterios   CLOB,
    aprobado            NUMBER(1)     NOT NULL,
    fecha_evaluacion    TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_eval_final       PRIMARY KEY (id),
    CONSTRAINT uq_ef_grupo_est     UNIQUE (id_grupo_est),
    CONSTRAINT fk_ef_grupo_est     FOREIGN KEY (id_grupo_est) REFERENCES grupo_estudiante(id),
    CONSTRAINT fk_ef_rubrica       FOREIGN KEY (id_rubrica)   REFERENCES rubrica(id),
    CONSTRAINT fk_ef_docente       FOREIGN KEY (id_docente)   REFERENCES usuario(id),
    CONSTRAINT chk_ef_aprobado     CHECK (aprobado IN (0,1))
);

-- ============================================================
-- 19. TABLA: LOG_AUDITORIA
-- ============================================================
CREATE TABLE log_auditoria (
    id              NUMBER(15)    NOT NULL,
    id_usuario      NUMBER(10),
    accion          VARCHAR2(15)  NOT NULL,
    tabla_afectada  VARCHAR2(100) NOT NULL,
    id_registro     NUMBER(10),
    descripcion     CLOB          NOT NULL,
    valor_anterior  CLOB,
    valor_nuevo     CLOB,
    ip_origen       VARCHAR2(45),
    fecha_accion    TIMESTAMP     DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_log_auditoria   PRIMARY KEY (id),
    CONSTRAINT fk_log_usuario     FOREIGN KEY (id_usuario)
                                  REFERENCES usuario(id) ON DELETE SET NULL,
    CONSTRAINT chk_log_accion     CHECK (accion IN
                                  ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','EXPORT'))
);

-- ============================================================
-- ÍNDICES DE RENDIMIENTO
-- ============================================================
CREATE INDEX idx_practica_prog     ON practica          (id_programa);
CREATE INDEX idx_practica_estado   ON practica          (estado);
CREATE INDEX idx_convenio_inst     ON convenio          (id_institucion, estado);
CREATE INDEX idx_convenio_venc     ON convenio          (fecha_vencimiento);
CREATE INDEX idx_grupo_prac        ON grupo             (id_practica);
CREATE INDEX idx_grupo_inst        ON grupo             (id_institucion);
CREATE INDEX idx_ge_grupo          ON grupo_estudiante  (id_grupo);
CREATE INDEX idx_ge_estudiante     ON grupo_estudiante  (id_estudiante);
CREATE INDEX idx_ge_estado         ON grupo_estudiante  (estado);
CREATE INDEX idx_gd_grupo          ON grupo_docente     (id_grupo);
CREATE INDEX idx_act_grupo_est     ON registro_actividad(id_grupo_est);
CREATE INDEX idx_act_fecha         ON registro_actividad(fecha_actividad);
CREATE INDEX idx_act_estado_val    ON registro_actividad(estado_validacion);
CREATE INDEX idx_ev_actividad      ON evidencia         (id_actividad);
CREATE INDEX idx_vis_grupo         ON visita_docente    (id_grupo);
CREATE INDEX idx_bp_programa       ON banco_preguntas   (id_programa);
CREATE INDEX idx_bp_practica       ON banco_preguntas   (id_practica);
CREATE INDEX idx_cue_practica      ON cuestionario      (id_practica);
CREATE INDEX idx_re_cuest_est      ON respuesta_estudiante(id_cuestionario, id_estudiante);
CREATE INDEX idx_rub_practica      ON rubrica           (id_practica);
CREATE INDEX idx_rc_rubrica        ON rubrica_criterio  (id_rubrica);
CREATE INDEX idx_log_fecha         ON log_auditoria     (fecha_accion);
CREATE INDEX idx_log_usuario       ON log_auditoria     (id_usuario);
CREATE INDEX idx_usuario_rol       ON usuario           (rol);
CREATE INDEX idx_usuario_prog      ON usuario           (id_programa);

-- ============================================================
-- DATOS DE PRUEBA INICIALES
-- ============================================================

-- Programa de prueba
INSERT INTO programa (id, nombre, facultad, modalidad, nivel, acreditado)
VALUES (SEQ_PROGRAMA.NEXTVAL,
        'Licenciatura en Matematicas',
        'Facultad de Ciencias de la Educacion',
        'Presencial', 'Pregrado', 0);

-- Usuario Director (contrasena: Admin2026)
-- Hash SHA-256 de 'Admin2026':
-- Ejecutar en Java: HashUtil.sha256("Admin2026") para obtener el hash real
INSERT INTO usuario (id, id_programa, nombres, apellidos, tipo_documento,
    numero_documento, correo, contrasena_hash, rol)
VALUES (SEQ_USUARIO.NEXTVAL, 1, 'Carlos', 'Diaz', 'CC',
    '12345678',
    'director@universidad.edu.co',
    'b6d767d2f8ed5d21a44b0e5886680cb9e1c2726ea1a6a71a5a08a8f8d8a7d14a',
    'Director');

COMMIT;

-- ============================================================
-- VERIFICACIÓN FINAL
-- ============================================================
SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

SELECT sequence_name, last_number
FROM user_sequences
ORDER BY sequence_name;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
