--
-- Script de criação do Data Warehouse da DREM - Parte 1: Configuração Base
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Configurações iniciais para Azure PostgreSQL
SET client_encoding = 'UTF8';
SET timezone = 'UTC';
SET search_path TO public;

-- Schema version control
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(50) PRIMARY KEY,
    installed_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    script_name TEXT,
    checksum TEXT
);

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Initial schema setup', 'parte_1_estrutura_base.sql');

-- Remover tipos existentes caso seja necessário recriar
DO $$ 
BEGIN
    DROP TYPE IF EXISTS dimensao_tipo CASCADE;
    DROP TYPE IF EXISTS periodicidade_tipo CASCADE;
    DROP TYPE IF EXISTS valor_tipo CASCADE;
    DROP TYPE IF EXISTS estado_indicador CASCADE;
EXCEPTION 
    WHEN OTHERS THEN 
        RAISE NOTICE 'Error dropping types: %', SQLERRM;
END $$;

-- Ativar extensões necessárias com tratamento de erro
DO $$ 
BEGIN
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- Geração de UUIDs
    CREATE EXTENSION IF NOT EXISTS "ltree";          -- Suporte a hierarquias
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- Funções criptográficas
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Monitorização de performance
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Busca textual eficiente
EXCEPTION 
    WHEN OTHERS THEN 
        RAISE NOTICE 'Error creating extensions: %', SQLERRM;
END $$;

-- Logging table for operations
CREATE TABLE IF NOT EXISTS dw_operation_log (
    log_id SERIAL PRIMARY KEY,
    operation_type TEXT NOT NULL,
    operation_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    operation_details JSONB,
    status TEXT,
    error_message TEXT
);

--
-- Definição dos tipos ENUM com validação
--

-- Tipo para categorias de dimensões
DO $$ 
BEGIN
    CREATE TYPE dimensao_tipo AS ENUM (
        'geografica',  -- Dimensões geográficas (países, regiões, municípios)
        'temporal',    -- Dimensões temporais (anos, trimestres, meses)
        'demografica', -- Dimensões demográficas (faixa etária, género)
        'economica',   -- Dimensões económicas (setores, atividades)
        'social',      -- Dimensões sociais (educação, saúde)
        'ambiental'    -- Dimensões ambientais (clima, recursos naturais)
    );
    
    COMMENT ON TYPE dimensao_tipo IS 'Categorias de dimensões disponíveis para análise';
EXCEPTION 
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Type dimensao_tipo already exists';
END $$;

-- Tipo para periodicidade de atualização
DO $$ 
BEGIN
    CREATE TYPE periodicidade_tipo AS ENUM (
        'diaria',     -- Atualização todos os dias
        'mensal',     -- Atualização uma vez por mês
        'trimestral', -- Atualização a cada três meses
        'semestral',  -- Atualização a cada seis meses
        'anual'       -- Atualização uma vez por ano
    );
    
    COMMENT ON TYPE periodicidade_tipo IS 'Frequência de atualização dos indicadores';
EXCEPTION 
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Type periodicidade_tipo already exists';
END $$;

-- Tipo para formato dos valores
DO $$ 
BEGIN
    CREATE TYPE valor_tipo AS ENUM (
        'numero',      -- Valores numéricos simples (ex: 42, 1000)
        'percentagem', -- Valores percentuais (ex: 25%, 75%)
        'moeda',      -- Valores monetários (ex: 1000€)
        'texto'       -- Valores textuais (ex: "Alto", "Baixo")
    );
    
    COMMENT ON TYPE valor_tipo IS 'Formato dos valores dos indicadores';
EXCEPTION 
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Type valor_tipo already exists';
END $$;

-- Tipo para estado dos indicadores
DO $$ 
BEGIN
    CREATE TYPE estado_indicador AS ENUM (
        'preliminar', -- Primeira versão dos dados, sujeita a revisões
        'provisorio', -- Dados revisados mas não finais
        'definitivo'  -- Dados finais e validados
    );
    
    COMMENT ON TYPE estado_indicador IS 'Estado atual dos dados do indicador';
EXCEPTION 
    WHEN duplicate_object THEN 
        RAISE NOTICE 'Type estado_indicador already exists';
END $$;

--
-- Funções de Manutenção Otimizadas para Azure
--

-- Função para atualização automática do timestamp com logging
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        
        -- Log the update
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details
        ) VALUES (
            'UPDATE_TIMESTAMP',
            jsonb_build_object(
                'table', TG_TABLE_NAME,
                'old_timestamp', OLD.updated_at,
                'new_timestamp', NEW.updated_at
            )
        );
        
        RETURN NEW;
    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO dw_operation_log (
            operation_type,
            status,
            error_message
        ) VALUES (
            'UPDATE_TIMESTAMP',
            'ERROR',
            SQLERRM
        );
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Função otimizada para criar partições com validação e logging
CREATE OR REPLACE FUNCTION create_partition_function()
RETURNS TRIGGER AS $$
DECLARE
    partition_date TEXT;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    BEGIN
        -- Validar data
        IF NEW.created_at IS NULL THEN
            RAISE EXCEPTION 'created_at cannot be null';
        END IF;

        -- Gerar nome da partição
        partition_date := to_char(NEW.created_at, 'YYYY');
        partition_name := 'dados_indicadores_' || partition_date;
        start_date := make_date(partition_date::INTEGER, 1, 1);
        end_date := start_date + interval '1 year';

        -- Criar partição se não existir
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = partition_name) THEN
            -- Log início da criação
            INSERT INTO dw_operation_log (
                operation_type,
                operation_details,
                status
            ) VALUES (
                'CREATE_PARTITION',
                jsonb_build_object(
                    'partition_name', partition_name,
                    'start_date', start_date,
                    'end_date', end_date
                ),
                'STARTED'
            );

            -- Criar a tabela particionada
            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS %I PARTITION OF dados_indicadores 
                FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );

            -- Configurar partição para Azure
            EXECUTE format(
                'ALTER TABLE %I SET (
                    autovacuum_vacuum_scale_factor = 0.1,
                    autovacuum_analyze_scale_factor = 0.05,
                    autovacuum_vacuum_threshold = 1000
                )', partition_name
            );

            -- Criar índices otimizados
            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I (id_indicador, created_at)',
                'idx_' || partition_name || '_indicador_data',
                partition_name
            );

            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I (valor) 
                WHERE valor IS NOT NULL',
                'idx_' || partition_name || '_valor',
                partition_name
            );

            -- Log sucesso
            UPDATE dw_operation_log 
            SET status = 'COMPLETED'
            WHERE operation_type = 'CREATE_PARTITION' 
            AND operation_details->>'partition_name' = partition_name
            AND status = 'STARTED';
        END IF;
        
        RETURN NEW;
    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details,
            status,
            error_message
        ) VALUES (
            'CREATE_PARTITION',
            jsonb_build_object(
                'partition_name', partition_name,
                'start_date', start_date,
                'end_date', end_date
            ),
            'ERROR',
            SQLERRM
        );
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Comentários e documentação
COMMENT ON FUNCTION update_updated_at_column() IS 'Atualiza automaticamente o campo updated_at com logging';
COMMENT ON FUNCTION create_partition_function() IS 'Cria automaticamente partições anuais para dados dos indicadores com otimizações para Azure';