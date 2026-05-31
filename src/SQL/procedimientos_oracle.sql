-- ============================================================
--  PLATAFORMA DE PRÁCTICAS PEDAGÓGICAS
--  Procedimientos Almacenados, Funciones y Disparadores
--  Motor: Oracle 10g XE
--  Versión: 1.0 | 2026
-- ============================================================
--  INSTRUCCIONES DE EJECUCIÓN:
--  1. Conectar al esquema: CONNECT practicas/password@XE
--  2. Ejecutar como script en SQL*Plus: @procedimientos_oracle.sql
--     O en SQL Developer: Ejecutar como Script (F5)
-- ============================================================


-- ============================================================
--  SECCIÓN 1: FUNCIONES
--  Retornan un valor escalar, usables en SELECT y WHERE
-- ============================================================

-- ------------------------------------------------------------
-- FN_01: Calcular horas cumplidas por un estudiante en un grupo
-- Suma las horas aprobadas de registro_actividad
-- Uso: SELECT FN_HORAS_CUMPLIDAS(5) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_HORAS_CUMPLIDAS(
    p_id_grupo_est IN NUMBER
)
RETURN NUMBER
IS
    v_horas NUMBER := 0;
BEGIN
    SELECT NVL(SUM(horas_invertidas), 0)
    INTO   v_horas
    FROM   registro_actividad
    WHERE  id_grupo_est      = p_id_grupo_est
    AND    estado_validacion  = 'Aprobado';

    RETURN v_horas;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN -1;
END FN_HORAS_CUMPLIDAS;
/

-- ------------------------------------------------------------
-- FN_02: Calcular nota automática desde rúbrica
-- Recibe el id de evaluacion_final ya insertada
-- y recalcula la nota con base en el JSON de detalle_criterios
-- En Oracle 10g no hay soporte JSON nativo; la nota_calculada
-- se almacena directamente al insertar la evaluación.
-- Esta función devuelve la nota_calculada almacenada.
-- Uso: SELECT FN_NOTA_EVALUACION(3) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_NOTA_EVALUACION(
    p_id_eval IN NUMBER
)
RETURN NUMBER
IS
    v_nota NUMBER(5,2) := 0;
BEGIN
    SELECT nota_calculada
    INTO   v_nota
    FROM   evaluacion_final
    WHERE  id = p_id_eval;

    RETURN v_nota;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN -1;
END FN_NOTA_EVALUACION;
/

-- ------------------------------------------------------------
-- FN_03: Verificar si un convenio está vigente
-- Retorna 1 si vigente, 0 si vencido
-- Uso: SELECT FN_CONVENIO_VIGENTE(2) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_CONVENIO_VIGENTE(
    p_id_institucion IN NUMBER
)
RETURN NUMBER
IS
    v_vigente NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO   v_vigente
    FROM   convenio
    WHERE  id_institucion    = p_id_institucion
    AND    estado            = 'Vigente'
    AND    fecha_vencimiento >= SYSDATE;

    IF v_vigente > 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END FN_CONVENIO_VIGENTE;
/

-- ------------------------------------------------------------
-- FN_04: Contar estudiantes activos en un grupo
-- Uso: SELECT FN_ESTUDIANTES_GRUPO(1) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_ESTUDIANTES_GRUPO(
    p_id_grupo IN NUMBER
)
RETURN NUMBER
IS
    v_total NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO   v_total
    FROM   grupo_estudiante
    WHERE  id_grupo = p_id_grupo
    AND    estado   = 'Activo';

    RETURN v_total;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END FN_ESTUDIANTES_GRUPO;
/

-- ------------------------------------------------------------
-- FN_05: Verificar si un estudiante aprobó la práctica
-- Compara nota_definitiva con escala_min de la rúbrica
-- Retorna 1 aprobó, 0 reprobó, -1 sin evaluación
-- Uso: SELECT FN_APROBO_PRACTICA(10) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_APROBO_PRACTICA(
    p_id_grupo_est IN NUMBER
)
RETURN NUMBER
IS
    v_aprobado NUMBER := -1;
BEGIN
    SELECT aprobado
    INTO   v_aprobado
    FROM   evaluacion_final
    WHERE  id_grupo_est = p_id_grupo_est;

    RETURN v_aprobado;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN -1;
    WHEN OTHERS THEN
        RETURN -1;
END FN_APROBO_PRACTICA;
/

-- ------------------------------------------------------------
-- FN_06: Obtener porcentaje de cumplimiento de horas
-- Calcula (horas_cumplidas / horas_minimas) * 100
-- Uso: SELECT FN_PORCENTAJE_HORAS(5) FROM DUAL;
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION FN_PORCENTAJE_HORAS(
    p_id_grupo_est IN NUMBER
)
RETURN NUMBER
IS
    v_horas_min    NUMBER := 0;
    v_horas_cum    NUMBER := 0;
    v_porcentaje   NUMBER := 0;
BEGIN
    -- Obtener horas mínimas de la práctica
    SELECT pr.horas_minimas
    INTO   v_horas_min
    FROM   grupo_estudiante ge
    JOIN   grupo           g  ON ge.id_grupo    = g.id
    JOIN   practica        pr ON g.id_practica  = pr.id
    WHERE  ge.id = p_id_grupo_est;

    -- Obtener horas cumplidas aprobadas
    v_horas_cum := FN_HORAS_CUMPLIDAS(p_id_grupo_est);

    -- Calcular porcentaje
    IF v_horas_min > 0 THEN
        v_porcentaje := ROUND((v_horas_cum / v_horas_min) * 100, 2);
    END IF;

    -- Máximo 100%
    IF v_porcentaje > 100 THEN
        v_porcentaje := 100;
    END IF;

    RETURN v_porcentaje;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        RETURN 0;
END FN_PORCENTAJE_HORAS;
/


-- ============================================================
--  SECCIÓN 2: PROCEDIMIENTOS ALMACENADOS
-- ============================================================

-- ------------------------------------------------------------
-- PR_01: Inscribir estudiante en un grupo
-- Valida: convenio vigente, cupo disponible, no duplicado
-- Uso: EXEC PR_INSCRIBIR_ESTUDIANTE(1, 5, SYSDATE, 'OK');
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_INSCRIBIR_ESTUDIANTE(
    p_id_grupo        IN  NUMBER,
    p_id_estudiante   IN  NUMBER,
    p_fecha           IN  DATE,
    p_resultado       OUT VARCHAR2
)
IS
    v_cupo_max      NUMBER := 0;
    v_inscritos     NUMBER := 0;
    v_id_inst       NUMBER := 0;
    v_ya_inscrito   NUMBER := 0;
BEGIN
    -- Verificar si ya está inscrito
    SELECT COUNT(*)
    INTO   v_ya_inscrito
    FROM   grupo_estudiante
    WHERE  id_grupo      = p_id_grupo
    AND    id_estudiante = p_id_estudiante
    AND    estado        = 'Activo';

    IF v_ya_inscrito > 0 THEN
        p_resultado := 'ERROR: El estudiante ya está inscrito en este grupo.';
        RETURN;
    END IF;

    -- Obtener cupo máximo e institución del grupo
    SELECT cupo_maximo, id_institucion
    INTO   v_cupo_max, v_id_inst
    FROM   grupo
    WHERE  id     = p_id_grupo
    AND    activo = 1;

    -- Verificar convenio vigente con la institución
    IF FN_CONVENIO_VIGENTE(v_id_inst) = 0 THEN
        p_resultado := 'ERROR: La institución no tiene convenio vigente.';
        RETURN;
    END IF;

    -- Verificar cupo disponible
    v_inscritos := FN_ESTUDIANTES_GRUPO(p_id_grupo);

    IF v_inscritos >= v_cupo_max THEN
        p_resultado := 'ERROR: El grupo no tiene cupos disponibles ('
                       || v_inscritos || '/' || v_cupo_max || ').';
        RETURN;
    END IF;

    -- Insertar inscripción
    INSERT INTO grupo_estudiante (
        id, id_grupo, id_estudiante, fecha_inscripcion, estado
    ) VALUES (
        SEQ_GRUPO_EST.NEXTVAL, p_id_grupo, p_id_estudiante, p_fecha, 'Activo'
    );

    COMMIT;
    p_resultado := 'OK: Estudiante inscrito exitosamente. Cupos: '
                   || (v_inscritos + 1) || '/' || v_cupo_max;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_resultado := 'ERROR: Grupo no encontrado o inactivo.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_resultado := 'ERROR inesperado: ' || SQLERRM;
END PR_INSCRIBIR_ESTUDIANTE;
/

-- ------------------------------------------------------------
-- PR_02: Registrar actividad de estudiante
-- Valida que la práctica esté activa y las horas sean válidas
-- Uso: EXEC PR_REGISTRAR_ACTIVIDAD(1,'Observacion','Desc',2.5,SYSDATE,'OK');
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_REGISTRAR_ACTIVIDAD(
    p_id_grupo_est    IN  NUMBER,
    p_tipo            IN  VARCHAR2,
    p_descripcion     IN  CLOB,
    p_horas           IN  NUMBER,
    p_fecha           IN  DATE,
    p_resultado       OUT VARCHAR2
)
IS
    v_estado_prac   VARCHAR2(20);
    v_id_act        NUMBER;
BEGIN
    -- Verificar que la práctica del grupo esté activa
    SELECT pr.estado
    INTO   v_estado_prac
    FROM   grupo_estudiante ge
    JOIN   grupo           g  ON ge.id_grupo   = g.id
    JOIN   practica        pr ON g.id_practica = pr.id
    WHERE  ge.id = p_id_grupo_est;

    IF v_estado_prac <> 'Activa' THEN
        p_resultado := 'ERROR: La práctica no está en estado Activa (Estado actual: '
                       || v_estado_prac || ').';
        RETURN;
    END IF;

    -- Validar rango de horas
    IF p_horas < 0.5 OR p_horas > 12 THEN
        p_resultado := 'ERROR: Las horas deben estar entre 0.5 y 12.';
        RETURN;
    END IF;

    -- Insertar actividad
    INSERT INTO registro_actividad (
        id, id_grupo_est, fecha_actividad, tipo_actividad,
        descripcion, horas_invertidas, estado_validacion
    ) VALUES (
        SEQ_ACTIVIDAD.NEXTVAL, p_id_grupo_est, p_fecha,
        p_tipo, p_descripcion, p_horas, 'Pendiente'
    );

    COMMIT;
    p_resultado := 'OK: Actividad registrada. Horas pendientes de aprobación: ' || p_horas;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_resultado := 'ERROR: Inscripción no encontrada.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_resultado := 'ERROR: ' || SQLERRM;
END PR_REGISTRAR_ACTIVIDAD;
/

-- ------------------------------------------------------------
-- PR_03: Validar actividad (aprobar o rechazar horas)
-- Solo el docente asesor del grupo puede validar
-- Uso: EXEC PR_VALIDAR_ACTIVIDAD(1, 3, 'Aprobado', 'Bien hecho', 'OK');
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_VALIDAR_ACTIVIDAD(
    p_id_actividad    IN  NUMBER,
    p_id_docente      IN  NUMBER,
    p_nuevo_estado    IN  VARCHAR2,
    p_observacion     IN  CLOB,
    p_resultado       OUT VARCHAR2
)
IS
    v_id_grupo      NUMBER;
    v_es_docente    NUMBER := 0;
BEGIN
    -- Obtener grupo de la actividad
    SELECT g.id
    INTO   v_id_grupo
    FROM   registro_actividad ra
    JOIN   grupo_estudiante   ge ON ra.id_grupo_est = ge.id
    JOIN   grupo              g  ON ge.id_grupo     = g.id
    WHERE  ra.id = p_id_actividad;

    -- Verificar que el docente pertenezca al grupo
    SELECT COUNT(*)
    INTO   v_es_docente
    FROM   grupo_docente
    WHERE  id_grupo  = v_id_grupo
    AND    id_docente = p_id_docente;

    IF v_es_docente = 0 THEN
        p_resultado := 'ERROR: El docente no está asignado a este grupo.';
        RETURN;
    END IF;

    -- Validar estado permitido
    IF p_nuevo_estado NOT IN ('Aprobado', 'Rechazado') THEN
        p_resultado := 'ERROR: Estado inválido. Use Aprobado o Rechazado.';
        RETURN;
    END IF;

    -- Actualizar actividad
    UPDATE registro_actividad
    SET    estado_validacion  = p_nuevo_estado,
           id_docente_valida  = p_id_docente,
           observacion_doc    = p_observacion
    WHERE  id = p_id_actividad;

    COMMIT;
    p_resultado := 'OK: Actividad ' || p_nuevo_estado || ' correctamente.';

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_resultado := 'ERROR: Actividad no encontrada.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_resultado := 'ERROR: ' || SQLERRM;
END PR_VALIDAR_ACTIVIDAD;
/

-- ------------------------------------------------------------
-- PR_04: Registrar evaluación final con rúbrica
-- Calcula nota automáticamente y determina si aprueba
-- Uso: EXEC PR_EVAL_FINAL(1,1,2,4.5,4.5,'Excelente desempenho','OK');
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_EVAL_FINAL(
    p_id_grupo_est      IN  NUMBER,
    p_id_rubrica        IN  NUMBER,
    p_id_docente        IN  NUMBER,
    p_nota_calculada    IN  NUMBER,
    p_nota_definitiva   IN  NUMBER,
    p_observacion       IN  CLOB,
    p_resultado         OUT VARCHAR2
)
IS
    v_ya_evaluado   NUMBER := 0;
    v_escala_min    NUMBER(5,2);
    v_aprobado      NUMBER(1);
    v_horas_ok      NUMBER;
    v_horas_min     NUMBER;
BEGIN
    -- Verificar si ya tiene evaluación final
    SELECT COUNT(*)
    INTO   v_ya_evaluado
    FROM   evaluacion_final
    WHERE  id_grupo_est = p_id_grupo_est;

    IF v_ya_evaluado > 0 THEN
        p_resultado := 'ERROR: El estudiante ya tiene evaluación final registrada.';
        RETURN;
    END IF;

    -- Verificar que haya cumplido las horas mínimas
    SELECT pr.horas_minimas
    INTO   v_horas_min
    FROM   grupo_estudiante ge
    JOIN   grupo           g  ON ge.id_grupo   = g.id
    JOIN   practica        pr ON g.id_practica = pr.id
    WHERE  ge.id = p_id_grupo_est;

    v_horas_ok := FN_HORAS_CUMPLIDAS(p_id_grupo_est);

    IF v_horas_ok < v_horas_min THEN
        p_resultado := 'ADVERTENCIA: El estudiante no ha cumplido las horas mínimas ('
                       || v_horas_ok || '/' || v_horas_min
                       || '). Se registra la evaluación con observación.';
    END IF;

    -- Obtener escala mínima de la rúbrica
    SELECT escala_min
    INTO   v_escala_min
    FROM   rubrica
    WHERE  id = p_id_rubrica;

    -- Determinar si aprobó
    IF p_nota_definitiva >= v_escala_min THEN
        v_aprobado := 1;
    ELSE
        v_aprobado := 0;
    END IF;

    -- Insertar evaluación final
    INSERT INTO evaluacion_final (
        id, id_grupo_est, id_rubrica, id_docente,
        nota_calculada, nota_definitiva, observacion_general, aprobado
    ) VALUES (
        SEQ_EVAL_FINAL.NEXTVAL, p_id_grupo_est, p_id_rubrica, p_id_docente,
        p_nota_calculada, p_nota_definitiva, p_observacion, v_aprobado
    );

    -- Actualizar estado del grupo_estudiante a Finalizado
    UPDATE grupo_estudiante
    SET    estado = 'Finalizado'
    WHERE  id = p_id_grupo_est;

    COMMIT;

    IF v_aprobado = 1 THEN
        p_resultado := 'OK: Evaluación registrada. Nota: ' || p_nota_definitiva
                       || '. Estado: APROBADO.';
    ELSE
        p_resultado := 'OK: Evaluación registrada. Nota: ' || p_nota_definitiva
                       || '. Estado: REPROBADO (mínimo: ' || v_escala_min || ').';
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_resultado := 'ERROR: Datos no encontrados (inscripción o rúbrica inválida).';
    WHEN OTHERS THEN
        ROLLBACK;
        p_resultado := 'ERROR: ' || SQLERRM;
END PR_EVAL_FINAL;
/

-- ------------------------------------------------------------
-- PR_05: Generar reporte de cumplimiento de horas por grupo
-- Imprime resultado por DBMS_OUTPUT y devuelve un cursor
-- Uso desde Java: CallableStatement con cursor de salida
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_REPORTE_HORAS_GRUPO(
    p_id_grupo    IN  NUMBER,
    p_cursor      OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_cursor FOR
        SELECT
            u.nombres || ' ' || u.apellidos        AS estudiante,
            ge.id                                  AS id_inscripcion,
            FN_HORAS_CUMPLIDAS(ge.id)              AS horas_cumplidas,
            pr.horas_minimas                       AS horas_requeridas,
            FN_PORCENTAJE_HORAS(ge.id)             AS porcentaje,
            CASE
                WHEN FN_HORAS_CUMPLIDAS(ge.id) >= pr.horas_minimas
                THEN 'CUMPLE'
                ELSE 'PENDIENTE'
            END                                    AS estado_horas,
            ge.estado                              AS estado_inscripcion
        FROM   grupo_estudiante ge
        JOIN   usuario          u  ON ge.id_estudiante = u.id
        JOIN   grupo            g  ON ge.id_grupo      = g.id
        JOIN   practica         pr ON g.id_practica    = pr.id
        WHERE  ge.id_grupo = p_id_grupo
        AND    ge.estado  <> 'Retirado'
        ORDER  BY u.apellidos, u.nombres;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Error generando reporte de horas: ' || SQLERRM);
END PR_REPORTE_HORAS_GRUPO;
/

-- ------------------------------------------------------------
-- PR_06: Cambiar estado de una práctica con validación
-- Flujo válido: Planificada→Activa→Finalizada o Cancelada
-- Uso: EXEC PR_CAMBIAR_ESTADO_PRACTICA(1, 'Activa', 'OK');
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_CAMBIAR_ESTADO_PRACTICA(
    p_id_practica   IN  NUMBER,
    p_nuevo_estado  IN  VARCHAR2,
    p_resultado     OUT VARCHAR2
)
IS
    v_estado_actual VARCHAR2(20);
    v_transicion_ok NUMBER := 0;
BEGIN
    SELECT estado
    INTO   v_estado_actual
    FROM   practica
    WHERE  id     = p_id_practica
    AND    activo = 1;

    -- Validar transiciones permitidas
    IF (v_estado_actual = 'Planificada' AND p_nuevo_estado = 'Activa')       OR
       (v_estado_actual = 'Activa'      AND p_nuevo_estado = 'Finalizada')   OR
       (v_estado_actual = 'Activa'      AND p_nuevo_estado = 'Cancelada')
    THEN
        v_transicion_ok := 1;
    END IF;

    IF v_transicion_ok = 0 THEN
        p_resultado := 'ERROR: Transición no permitida: '
                       || v_estado_actual || ' → ' || p_nuevo_estado;
        RETURN;
    END IF;

    UPDATE practica
    SET    estado = p_nuevo_estado
    WHERE  id     = p_id_practica;

    COMMIT;
    p_resultado := 'OK: Estado cambiado de ' || v_estado_actual
                   || ' a ' || p_nuevo_estado;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_resultado := 'ERROR: Práctica no encontrada o inactiva.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_resultado := 'ERROR: ' || SQLERRM;
END PR_CAMBIAR_ESTADO_PRACTICA;
/

-- ------------------------------------------------------------
-- PR_07: Registrar entrada en el log de auditoría
-- Llamado internamente por los triggers
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_LOG_AUDITORIA(
    p_id_usuario      IN NUMBER,
    p_accion          IN VARCHAR2,
    p_tabla           IN VARCHAR2,
    p_id_registro     IN NUMBER,
    p_descripcion     IN VARCHAR2,
    p_valor_anterior  IN CLOB DEFAULT NULL,
    p_valor_nuevo     IN CLOB DEFAULT NULL
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO log_auditoria (
        id, id_usuario, accion, tabla_afectada,
        id_registro, descripcion, valor_anterior, valor_nuevo, fecha_accion
    ) VALUES (
        SEQ_LOG.NEXTVAL, p_id_usuario, p_accion, p_tabla,
        p_id_registro, p_descripcion, p_valor_anterior, p_valor_nuevo, SYSDATE
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- El log no debe interrumpir operaciones principales
END PR_LOG_AUDITORIA;
/


-- ============================================================
--  SECCIÓN 3: DISPARADORES (TRIGGERS)
-- ============================================================

-- ------------------------------------------------------------
-- TRG_01: Auditoría automática al modificar evaluación_final
-- Registra en log_auditoria cualquier UPDATE sobre notas
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDIT_EVALUACION
AFTER UPDATE ON evaluacion_final
FOR EACH ROW
BEGIN
    PR_LOG_AUDITORIA(
        p_id_usuario     => :NEW.id_docente,
        p_accion         => 'UPDATE',
        p_tabla          => 'evaluacion_final',
        p_id_registro    => :NEW.id,
        p_descripcion    => 'Modificación de evaluación final. '
                            || 'Nota anterior: ' || :OLD.nota_definitiva
                            || ' → Nueva nota: ' || :NEW.nota_definitiva,
        p_valor_anterior => 'nota_definitiva=' || :OLD.nota_definitiva
                            || ',aprobado=' || :OLD.aprobado,
        p_valor_nuevo    => 'nota_definitiva=' || :NEW.nota_definitiva
                            || ',aprobado=' || :NEW.aprobado
    );
END TRG_AUDIT_EVALUACION;
/

-- ------------------------------------------------------------
-- TRG_02: Auditoría al eliminar (desactivar) usuarios
-- Previene la desactivación del último Director activo
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDIT_USUARIO
BEFORE UPDATE OF activo ON usuario
FOR EACH ROW
DECLARE
    v_directores_activos NUMBER := 0;
BEGIN
    -- Si se intenta desactivar un Director, verificar que quede al menos uno
    IF :OLD.rol = 'Director' AND :NEW.activo = 0 THEN
        SELECT COUNT(*)
        INTO   v_directores_activos
        FROM   usuario
        WHERE  rol    = 'Director'
        AND    activo = 1
        AND    id    <> :OLD.id;

        IF v_directores_activos = 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'No se puede desactivar: debe existir al menos un Director activo.');
        END IF;
    END IF;

    -- Registrar en auditoría
    IF :OLD.activo = 1 AND :NEW.activo = 0 THEN
        PR_LOG_AUDITORIA(
            p_id_usuario  => :OLD.id,
            p_accion      => 'DELETE',
            p_tabla       => 'usuario',
            p_id_registro => :OLD.id,
            p_descripcion => 'Usuario desactivado: ' || :OLD.nombres
                             || ' ' || :OLD.apellidos || ' [' || :OLD.rol || ']'
        );
    END IF;
END TRG_AUDIT_USUARIO;
/

-- ------------------------------------------------------------
-- TRG_03: Actualizar estado del convenio al vencer
-- Se dispara al consultar/modificar la tabla convenio
-- Marca como 'Vencido' los convenios con fecha pasada
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ESTADO_CONVENIO
BEFORE INSERT OR UPDATE ON convenio
FOR EACH ROW
BEGIN
    -- Actualizar automáticamente el estado según la fecha
    IF :NEW.fecha_vencimiento < SYSDATE AND :NEW.estado = 'Vigente' THEN
        :NEW.estado := 'Vencido';
    END IF;
END TRG_ESTADO_CONVENIO;
/

-- ------------------------------------------------------------
-- TRG_04: Validar cupo antes de inscribir estudiante
-- Evita superar el cupo máximo del grupo
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDAR_CUPO
BEFORE INSERT ON grupo_estudiante
FOR EACH ROW
DECLARE
    v_cupo_max  NUMBER;
    v_inscritos NUMBER;
BEGIN
    -- Obtener cupo máximo del grupo
    SELECT cupo_maximo
    INTO   v_cupo_max
    FROM   grupo
    WHERE  id = :NEW.id_grupo;

    -- Contar estudiantes activos actuales
    SELECT COUNT(*)
    INTO   v_inscritos
    FROM   grupo_estudiante
    WHERE  id_grupo = :NEW.id_grupo
    AND    estado   = 'Activo';

    -- Rechazar si se supera el cupo
    IF v_inscritos >= v_cupo_max THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Cupo máximo alcanzado para este grupo ('
            || v_inscritos || '/' || v_cupo_max || ').');
    END IF;
END TRG_VALIDAR_CUPO;
/

-- ------------------------------------------------------------
-- TRG_05: Validar número de prácticas por programa
-- Impide insertar más de 8 prácticas activas por programa
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_MAX_PRACTICAS
BEFORE INSERT ON practica
FOR EACH ROW
DECLARE
    v_total NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO   v_total
    FROM   practica
    WHERE  id_programa = :NEW.id_programa
    AND    activo      = 1;

    IF v_total >= 8 THEN
        RAISE_APPLICATION_ERROR(-20004,
            'El programa ya tiene el máximo de 8 prácticas registradas.');
    END IF;
END TRG_MAX_PRACTICAS;
/

-- ------------------------------------------------------------
-- TRG_06: Auditoría de cambios en práctica (estado)
-- Registra cada cambio de estado de una práctica
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDIT_PRACTICA
AFTER UPDATE OF estado ON practica
FOR EACH ROW
BEGIN
    IF :OLD.estado <> :NEW.estado THEN
        PR_LOG_AUDITORIA(
            p_id_usuario  => NULL,
            p_accion      => 'UPDATE',
            p_tabla       => 'practica',
            p_id_registro => :NEW.id,
            p_descripcion => 'Cambio de estado: ' || :OLD.estado
                             || ' → ' || :NEW.estado
                             || ' | Práctica: ' || :NEW.nombre
        );
    END IF;
END TRG_AUDIT_PRACTICA;
/

-- ------------------------------------------------------------
-- TRG_07: Registrar fecha_registro automáticamente en programa
-- Oracle 10g: DEFAULT SYSDATE no siempre aplica con INSERT
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_FECHA_PROGRAMA
BEFORE INSERT ON programa
FOR EACH ROW
BEGIN
    IF :NEW.fecha_registro IS NULL THEN
        :NEW.fecha_registro := SYSDATE;
    END IF;
    IF :NEW.activo IS NULL THEN
        :NEW.activo := 1;
    END IF;
END TRG_FECHA_PROGRAMA;
/

-- ------------------------------------------------------------
-- TRG_08: Registrar fecha_creacion automáticamente en usuario
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_FECHA_USUARIO
BEFORE INSERT ON usuario
FOR EACH ROW
BEGIN
    IF :NEW.fecha_creacion IS NULL THEN
        :NEW.fecha_creacion := SYSDATE;
    END IF;
    IF :NEW.activo IS NULL THEN
        :NEW.activo := 1;
    END IF;
END TRG_FECHA_USUARIO;
/


-- ============================================================
--  SECCIÓN 4: VISTAS ÚTILES PARA REPORTES
-- ============================================================

-- Vista resumen de estudiantes por práctica
CREATE OR REPLACE VIEW VW_ESTUDIANTES_PRACTICA AS
SELECT
    pr.id                                          AS id_practica,
    pr.nombre                                      AS practica,
    pr.numero                                      AS numero_practica,
    g.nombre                                       AS grupo,
    u.nombres || ' ' || u.apellidos                AS estudiante,
    u.numero_documento                             AS documento,
    ge.id                                          AS id_inscripcion,
    ge.estado                                      AS estado_inscripcion,
    FN_HORAS_CUMPLIDAS(ge.id)                      AS horas_cumplidas,
    pr.horas_minimas                               AS horas_requeridas,
    FN_PORCENTAJE_HORAS(ge.id)                     AS porcentaje_cumplimiento,
    FN_APROBO_PRACTICA(ge.id)                      AS aprobo
FROM   grupo_estudiante ge
JOIN   usuario          u  ON ge.id_estudiante = u.id
JOIN   grupo            g  ON ge.id_grupo      = g.id
JOIN   practica         pr ON g.id_practica    = pr.id
WHERE  ge.estado <> 'Retirado'
AND    pr.activo  = 1
AND    g.activo   = 1;
/

-- Vista de convenios próximos a vencer (30 días)
CREATE OR REPLACE VIEW VW_CONVENIOS_POR_VENCER AS
SELECT
    c.id                    AS id_convenio,
    c.numero_convenio,
    i.nombre                AS institucion,
    i.municipio,
    c.fecha_vencimiento,
    c.estado,
    ROUND(c.fecha_vencimiento - SYSDATE) AS dias_para_vencer
FROM   convenio            c
JOIN   institucion_receptora i ON c.id_institucion = i.id
WHERE  c.estado           = 'Vigente'
AND    c.fecha_vencimiento <= SYSDATE + 30
ORDER  BY c.fecha_vencimiento;
/


-- ============================================================
--  SECCIÓN 5: PRUEBAS DE VERIFICACIÓN
-- ============================================================

-- Verificar objetos creados
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_type IN ('FUNCTION','PROCEDURE','TRIGGER','VIEW')
ORDER  BY object_type, object_name;

-- ============================================================
--  FIN DEL SCRIPT
-- ============================================================
