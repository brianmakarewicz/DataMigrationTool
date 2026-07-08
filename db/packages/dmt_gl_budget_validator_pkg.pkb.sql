-- PACKAGE BODY DMT_GL_BUDGET_VALIDATOR_PKG

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_GL_BUDGET_VALIDATOR_PKG" AS
    C_PKG CONSTANT VARCHAR2(50) := 'DMT_GL_BUDGET_VALIDATOR_PKG';
    PROCEDURE VALIDATE_PRE_TRANSFORM (p_run_id IN NUMBER, p_dependent_prefix IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'VALIDATE_PRE_TRANSFORM start (no rules yet).', C_PKG, 'VALIDATE_PRE_TRANSFORM');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_PRE_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_PRE_TRANSFORM');
            RAISE;
    END VALIDATE_PRE_TRANSFORM;
    PROCEDURE VALIDATE_POST_TRANSFORM (p_run_id IN NUMBER) IS
    BEGIN
        DMT_UTIL_PKG.LOG(p_run_id, 'VALIDATE_POST_TRANSFORM start (no rules yet).', C_PKG, 'VALIDATE_POST_TRANSFORM');
    EXCEPTION
        WHEN OTHERS THEN
            DMT_UTIL_PKG.LOG_ERROR(
                p_run_id => p_run_id,
                p_message        => 'VALIDATE_POST_TRANSFORM failed.',
                p_sqlerrm        => SQLERRM,
                p_package        => C_PKG,
                p_procedure      => 'VALIDATE_POST_TRANSFORM');
            RAISE;
    END VALIDATE_POST_TRANSFORM;
END DMT_GL_BUDGET_VALIDATOR_PKG;
/
