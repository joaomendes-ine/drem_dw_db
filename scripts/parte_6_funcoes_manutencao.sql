```sql
--
-- Script de criação do Data Warehouse DREM - Parte 6: Funções e Manutenção
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Maintenance functions creation', 'parte_6_funcoes_manutencao.sql');

--
-- Funções de Validação Otimizadas
--

-- Função de validação com melhor tratamento de erros
CREATE OR REPLACE FUNCTION validar_dados_indicador()
RETURNS trigger AS $$
DECLARE
    tipo_valor_indicador valor_tipo;
    precisao_indicador INTEGER;
    v_indicador_info JSONB;
BEGIN
    -- Log validation start
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details
    ) VALUES (
        'VALIDATE_DATA',
        jsonb_build_object(
            'id_indicador', NEW.id_indicador,
            'valor_numerico', NEW.valor_numerico,
            'valor_texto', NEW.valor_texto
        )
    );

    -- Buscar informações do indicador
    SELECT 
        jsonb_build_object(
            'tipo_valor', tipo_valor,
            'precision_scale', precision_scale,
            'nome', nome_pt
        )
    INTO v_indicador_info
    FROM indicadores 
    WHERE id_indicador = NEW.id_indicador;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Indicador não encontrado: %', NEW.id_indicador;
    END IF;

    -- Extrair valores
    tipo_valor_indicador := (v_indicador_info->>'tipo_valor')::valor_tipo;
    precisao_indicador := (v_indicador_info->>'precision_scale')::integer;

    -- Validar tipo de valor
    CASE tipo_valor_indicador
        WHEN 'numero' THEN
            IF NEW.valor_texto IS NOT NULL THEN
                RAISE EXCEPTION 'Indicador % espera valor numérico', v_indicador_info->>'nome';
            END IF;
            -- Validar precisão
            IF NEW.valor_numerico IS NOT NULL THEN
                NEW.valor_numerico := round(NEW.valor_numerico::numeric, precisao_indicador);
            END IF;
        WHEN 'texto' THEN
            IF NEW.valor_numerico IS NOT NULL THEN
                RAISE EXCEPTION 'Indicador % espera valor textual', v_indicador_info->>'nome';
            END IF;
        WHEN 'percentagem' THEN
            IF NEW.valor_numerico > 100 OR NEW.valor_numerico < 0 THEN
                RAISE EXCEPTION 'Valor percentual deve estar entre 0 e 100';
            END IF;
        WHEN 'moeda' THEN
            IF NEW.valor_numerico < 0 THEN
                RAISE EXCEPTION 'Valor monetário não pode ser negativo';
            END IF;
    END CASE;

    -- Log validation success
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details,
        status
    ) VALUES (
        'VALIDATE_DATA',
        jsonb_build_object(
            'id_indicador', NEW.id_indicador,
            'validation', 'success'
        ),
        'SUCCESS'
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log validation error
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details,
        status,
        error_message
    ) VALUES (
        'VALIDATE_DATA',
        jsonb_build_object(
            'id_indicador', NEW.id_indicador,
            'validation', 'failed'
        ),
        'ERROR',
        SQLERRM
    );
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Função otimizada para validação de hierarquia
CREATE OR REPLACE FUNCTION validar_hierarquia_dimensao()
RETURNS trigger AS $$
DECLARE
    v_nivel_pai INTEGER;
    v_path_pai ltree;
BEGIN
    IF NEW.id_parent IS NOT NULL THEN
        -- Verificar pai
        SELECT nivel, hierarquia INTO v_nivel_pai, v_path_pai
        FROM dimensoes
        WHERE id_dimensao = NEW.id_parent;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Dimensão pai não encontrada';
        END IF;

        -- Validar hierarquia
        IF NEW.nivel <= v_nivel_pai THEN
            RAISE EXCEPTION 'Nível (%) deve ser maior que o do pai (%)', 
                NEW.nivel, v_nivel_pai;
        END IF;

        -- Validar path
        IF NOT (NEW.hierarquia <@ v_path_pai) THEN
            RAISE EXCEPTION 'Hierarquia inválida';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--
-- Funções de Manutenção Otimizadas
--

-- Função melhorada para arquivamento
CREATE OR REPLACE FUNCTION arquivar_dados_antigos(
    p_anos_retencao INTEGER DEFAULT 5,
    p_schema_arquivo TEXT DEFAULT 'arquivo',
    p_batch_size INTEGER DEFAULT 10000
)
RETURNS TABLE (
    partitions_moved INTEGER,
    rows_archived BIGINT,
    execution_time INTERVAL
) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_data_limite DATE;
    v_partition_name TEXT;
    v_partitions_moved INTEGER := 0;
    v_rows_archived BIGINT := 0;
BEGIN
    v_start_time := clock_timestamp();
    v_data_limite := current_date - (p_anos_retencao * interval '1 year');
    
    -- Criar schema de arquivo
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', p_schema_arquivo);
    
    -- Processar partições
    FOR v_partition_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'dados_indicadores_%'
        AND tablename ~ '^dados_indicadores_\d{4}$'
        ORDER BY tablename
    LOOP
        IF substring(v_partition_name FROM '\d{4}')::INTEGER < extract(year from v_data_limite) THEN
            BEGIN
                -- Mover partição
                EXECUTE format(
                    'ALTER TABLE %I SET SCHEMA %I',
                    v_partition_name,
                    p_schema_arquivo
                );
                
                -- Contar registros
                EXECUTE format(
                    'SELECT count(*) FROM %I.%I',
                    p_schema_arquivo,
                    v_partition_name
                ) INTO v_rows_archived;
                
                v_partitions_moved := v_partitions_moved + 1;
                
                -- Log archival
                INSERT INTO dw_operation_log (
                    operation_type,
                    operation_details,
                    status
                ) VALUES (
                    'ARCHIVE_PARTITION',
                    jsonb_build_object(
                        'partition', v_partition_name,
                        'schema', p_schema_arquivo,
                        'rows', v_rows_archived
                    ),
                    'SUCCESS'
                );
                
            EXCEPTION WHEN OTHERS THEN
                -- Log error
                INSERT INTO dw_operation_log (
                    operation_type,
                    operation_details,
                    status,
                    error_message
                ) VALUES (
                    'ARCHIVE_PARTITION',
                    jsonb_build_object(
                        'partition', v_partition_name,
                        'schema', p_schema_arquivo
                    ),
                    'ERROR',
                    SQLERRM
                );
            END;
        END IF;
    END LOOP;
    
    RETURN QUERY
    SELECT 
        v_partitions_moved,
        v_rows_archived,
        clock_timestamp() - v_start_time;
END;
$$ LANGUAGE plpgsql;

-- Função otimizada para análise de crescimento
CREATE OR REPLACE FUNCTION analisar_crescimento_dw(
    p_dias_analise INTEGER DEFAULT 30
)
RETURNS TABLE (
    tabela TEXT,
    total_registros BIGINT,
    tamanho_mb NUMERIC,
    crescimento_diario_medio NUMERIC,
    projecao_6_meses_gb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH metricas_tabelas AS (
        SELECT
            schemaname || '.' || tablename as tabela,
            n_live_tup as registros,
            pg_total_relation_size(schemaname || '.' || tablename) / (1024*1024.0) as tamanho,
            (n_tup_ins - n_tup_del)::NUMERIC / 
                GREATEST(1, EXTRACT(DAY FROM age(now(), stats_reset))) as crescimento_diario
        FROM pg_stat_user_tables
        WHERE schemaname = 'public'
    )
    SELECT 
        tabela::TEXT,
        registros::BIGINT,
        round(tamanho::NUMERIC, 2) as tamanho_mb,
        round(crescimento_diario::NUMERIC, 2),
        round((tamanho + (crescimento_diario * 180 * tamanho / GREATEST(registros, 1))) / 1024, 2)
    FROM metricas_tabelas
    ORDER BY tamanho DESC;
END;
$$ LANGUAGE plpgsql;

--
-- Funções de Análise Otimizadas
--

-- Função melhorada para análise de tendências
CREATE OR REPLACE FUNCTION analisar_tendencia_indicador(
    p_id_indicador UUID,
    p_periodos INTEGER DEFAULT 12,
    p_tipo_periodo TEXT DEFAULT 'month'
)
RETURNS TABLE (
    periodo DATE,
    valor NUMERIC,
    tendencia NUMERIC,
    variacao_percentual NUMERIC,
    sazonalidade NUMERIC,
    predicao_proximo_periodo NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH dados_periodo AS (
        SELECT 
            date_trunc(p_tipo_periodo, periodo_referencia)::DATE as periodo,
            avg(valor_numerico) as valor
        FROM dados_indicadores
        WHERE id_indicador = p_id_indicador
        AND valor_numerico IS NOT NULL
        GROUP BY date_trunc(p_tipo_periodo, periodo_referencia)
        ORDER BY periodo DESC
        LIMIT p_periodos
    ),
    analise_tendencia AS (
        SELECT
            periodo,
            valor,
            avg(valor) OVER (
                ORDER BY periodo 
                ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
            ) as tendencia,
            (valor - lag(valor) OVER (ORDER BY periodo)) / 
                nullif(lag(valor) OVER (ORDER BY periodo), 0) * 100 as variacao,
            valor / nullif(
                avg(valor) OVER (
                    ORDER BY periodo 
                    ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING
                ), 0
            ) as indice_sazonal
        FROM dados_periodo
    )
    SELECT
        periodo,
        round(valor::NUMERIC, 2),
        round(tendencia::NUMERIC, 2),
        round(variacao::NUMERIC, 2),
        round(indice_sazonal::NUMERIC, 2),
        round(
            (tendencia + (tendencia * coalesce(
                avg(variacao) OVER (ORDER BY periodo ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING), 
                0
            ) / 100))::NUMERIC,
            2
        ) as predicao
    FROM analise_tendencia
    ORDER BY periodo;
END;
$$ LANGUAGE plpgsql;

-- Função melhorada para exportação
CREATE OR REPLACE FUNCTION exportar_dados_indicador(
    p_id_indicador UUID,
    p_formato TEXT DEFAULT 'csv',
    p_data_inicio DATE DEFAULT NULL,
    p_data_fim DATE DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_resultado TEXT;
    v_query TEXT;
BEGIN
    -- Validar formato
    IF p_formato NOT IN ('csv', 'json') THEN
        RAISE EXCEPTION 'Formato não suportado: %. Use csv ou json', p_formato;
    END IF;

    -- Base query
    v_query := format('
        WITH dados_exportacao AS (
            SELECT 
                di.periodo_referencia,
                di.valor_numerico,
                di.valor_texto,
                di.variacao_percentual,
                i.unidade,
                i.tipo_valor,
                i.estado,
                string_agg(
                    d.tipo || '':'' || d.valor,
                    '';'' ORDER BY d.tipo
                ) as dimensoes
            FROM dados_indicadores di
            JOIN indicadores i ON i.id_indicador = di.id_indicador
            LEFT JOIN indicador_dimensoes_bridge idb ON di.id_dado = idb.id_dado
            LEFT JOIN dimensoes d ON idb.id_dimensao = d.id_dimensao
            WHERE di.id_indicador = %L
            %s
            GROUP BY 
                di.periodo_referencia,
                di.valor_numerico,
                di.valor_texto,
                di.variacao_percentual,
                i.unidade,
                i.tipo_valor,
                i.estado
            ORDER BY di.periodo_referencia
        )',
        p_id_indicador,
        CASE 
            WHEN p_data_inicio IS NOT NULL OR p_data_fim IS NOT NULL THEN
                format('AND di.periodo_referencia BETWEEN %L AND %L',
                    COALESCE(p_data_inicio, '1900-01-01'),
                    COALESCE(p_data_fim, 'infinity'::DATE)
                )
            ELSE ''
        END
    );

    -- Format-specific handling
    CASE p_formato
        WHEN 'csv' THEN
            v_query := v_query || '
                SELECT string_agg(linha, E''\n'')
                FROM (
                    SELECT ''periodo,valor,variacao,unidade,estado,dimensoes''
                    UNION ALL
                    SELECT 
                        periodo_referencia::TEXT || '','' ||
                        COALESCE(valor_numerico::TEXT, valor_texto) || '','' ||
                        COALESCE(variacao_percentual::TEXT, ''0'') || '','' ||
                        unidade || '','' ||
                        estado || '','' ||
                        ''"'' || dimensoes || ''"''
                    FROM dados_exportacao
                ) t(linha)';
        WHEN 'json' THEN
            v_query := v_query || '
                SELECT json_agg(row_to_json(dados_exportacao))::TEXT
                FROM dados_exportacao';
    END CASE;

    -- Execute query
    EXECUTE v_query INTO v_resultado;

    -- Log export
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details
    ) VALUES (
        'EXPORT_DATA',
        jsonb_build_object(
            'id_indicador', p_id_indicador,
            'formato', p_formato,
            'registros', json_array_length(v_resultado::json)
        )
    );

    RETURN v_resultado;
EXCEPTION