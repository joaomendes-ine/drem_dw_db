# Configuração do PostgreSQL

Este documento fornece as configurações recomendadas para otimização do PostgreSQL no ambiente Azure para o Data Warehouse (DREM). Este guia aborda configurações gerais, otimizações específicas para Azure, gestão de partições, e a configuração de índices.

## Índice

- [Configuração do PostgreSQL](#configuração-do-postgresql)
- [Otimizações para Azure](#otimizações-para-azure)
- [Gestão de Partições](#gestão-de-partições)
- [Configuração de Índices](#configuração-de-índices)

---

## Configuração do PostgreSQL

### Configurações a Nível de Base de Dados

As seguintes configurações são aplicadas ao nível de base de dados para otimizar o desempenho no ambiente Azure:

```sql
ALTER DATABASE drem_dw SET timezone TO 'UTC';
ALTER DATABASE drem_dw SET statement_timeout TO '3600000';  -- 1 hora
ALTER DATABASE drem_dw SET idle_in_transaction_session_timeout TO '3600000';
ALTER DATABASE drem_dw SET work_mem TO '64MB';
ALTER DATABASE drem_dw SET maintenance_work_mem TO '256MB';
ALTER DATABASE drem_dw SET random_page_cost TO 1.1;
ALTER DATABASE drem_dw SET effective_cache_size TO '4GB';
ALTER DATABASE drem_dw SET default_statistics_target TO 1000;
```

Estas configurações visam melhorar a alocação de memória e o tempo limite de transações, garantindo uma execução mais eficiente das consultas.

## Otimizações para Azure

### Tabela de Monitorização de Desempenho
Para monitorizar métricas de desempenho e ajudar no ajuste do sistema, foi criada a tabela azure_performance_metrics, que armazena diferentes métricas, tais como conexões e tamanho de tabelas.

```sql
CREATE TABLE azure_performance_metrics (
    metric_id SERIAL PRIMARY KEY,
    metric_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT,
    metric_value NUMERIC,
    metric_details JSONB
);
```

### Funções de Gestão de Recursos
A função monitor_azure_resources() recolhe informações sobre o número de conexões ativas, tamanho das tabelas e a razão de cache. Estas informações são armazenadas na tabela de métricas para facilitar a monitorização contínua.

``` sql
CREATE OR REPLACE FUNCTION monitor_azure_resources()
RETURNS void AS $$
BEGIN
    -- Monitorizar contagem de conexões
    INSERT INTO azure_performance_metrics (metric_type, metric_value, metric_details)
    SELECT 
        'connections', count(*),
        jsonb_build_object('active_connections', count(*), 'max_connections', current_setting('max_connections')::int)
    FROM pg_stat_activity;

    -- Monitorizar tamanhos de tabelas
    INSERT INTO azure_performance_metrics (metric_type, metric_value, metric_details)
    SELECT 
        'table_size', pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0,
        jsonb_build_object('table_name', schemaname || '.' || tablename, 'size_mb', pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0)
    FROM pg_stat_user_tables;
END;
$$ LANGUAGE plpgsql;```

### Gestão de Backups
A tabela azure_backup_control armazena informações sobre backups, incluindo tempo de início e término, tipo e status. Essa configuração facilita o controle e auditoria dos backups realizados.

``` sql
CREATE TABLE azure_backup_control (
    backup_id SERIAL PRIMARY KEY,
    backup_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    backup_end TIMESTAMP WITH TIME ZONE,
    backup_type TEXT,
    status TEXT,
    details JSONB
);
```


### Gestão de Conexões
A função manage_azure_connections() monitora o número de conexões e encerra as conexões inativas quando o limite de conexões está próximo.

``` sql
CREATE OR REPLACE FUNCTION manage_azure_connections()
RETURNS trigger AS $$
BEGIN
    IF (SELECT count(*) FROM pg_stat_activity) > current_setting('max_connections')::int * 0.9 THEN
        -- Encerra conexões inativas
        WITH idle_transactions AS (
            SELECT pid FROM pg_stat_activity WHERE state = 'idle in transaction'
            AND state_change < current_timestamp - interval '30 minutes'
        )
        SELECT pg_terminate_backend(pid) FROM idle_transactions;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

## Gestão de Partições

A gestão de partições é uma estratégia fundamental para otimizar o desempenho e a manutenção do Data Warehouse, especialmente quando se lida com grandes volumes de dados. A abordagem adotada nesta documentação envolve a criação automática de partições com base em datas, permitindo uma melhor organização dos dados e facilitando operações de consulta e manutenção.

### 1. Conceito de Particionamento

O particionamento de tabelas divide os dados em partes menores e mais gerenciáveis, chamadas partições. Cada partição pode ser tratada como uma tabela separada, mas ainda faz parte da tabela principal. Esta técnica melhora a performance de consultas e facilita a manutenção, como a remoção de dados antigos ou a reindexação.

### 2. Função de Criação de Partições

A função `create_partition_function` é responsável pela criação automática de partições anuais para a tabela `dados_indicadores`. Esta função é invocada sempre que novos dados são inseridos. 

#### 2.1 Funcionamento da Função

- **Validação de Data**: A função começa por verificar se a coluna `created_at` não é nula. Esta coluna é essencial, pois determina a data da partição.
  
- **Geração de Nome da Partição**: O nome da partição é gerado com base no ano da data de criação dos dados (`created_at`). Por exemplo, se a data for `2024-05-15`, o nome da partição será `dados_indicadores_2024`.

- **Criação da Partição**: Se a partição não existir, a função cria a tabela particionada e ajusta as configurações específicas para o Azure, como os fatores de vacum e de análise do autovacuum. 

- **Criação de Índices**: A função também cria índices otimizados para melhorar o desempenho de consultas, garantindo que as operações de leitura e escrita sejam eficientes.

#### 2.2 Logging e Tratamento de Erros

A função inclui um mecanismo de logging robusto. Todas as operações de criação de partições são registradas na tabela `dw_operation_log`, incluindo detalhes sobre o início e o término da operação, bem como qualquer erro que possa ocorrer. Isso facilita a auditoria e o diagnóstico de problemas.

### 3. Exemplos de Uso

Quando novos dados são inseridos na tabela `dados_indicadores`, a função `create_partition_function` é automaticamente invocada, assegurando que a partição correspondente seja criada se ainda não existir. 

#### 3.1 Exemplo de Criação de Partição

```sql
-- Exemplo de inserção de dados que aciona a criação de partição
INSERT INTO dados_indicadores (id_indicador, created_at, valor) 
VALUES (1, '2024-05-15', 100);
```

- Nesse caso, a partição dados_indicadores_2024 será criada automaticamente, caso ainda não exista, e os dados serão organizados nessa nova partição.



### Configuração de Índices
#### Otimização de Índices

A função optimize_azure_indexes() executa duas tarefas principais:

1. Identificação de índices não utilizados para consideração de exclusão.
2. Reindexação de índices com uso frequente.

```  sql
Copiar código
CREATE OR REPLACE FUNCTION optimize_azure_indexes()
RETURNS void AS $$
DECLARE
    v_index_name text;
    v_table_name text;
BEGIN
    -- Identificar índices não utilizados
    FOR v_index_name, v_table_name IN
        SELECT schemaname || '.' || indexrelname, schemaname || '.' || tablename
        FROM pg_stat_user_indexes
        WHERE idx_scan = 0 AND indexrelname NOT LIKE '%_pkey' AND indexrelname NOT LIKE '%_unique'
    LOOP
        -- Registar índice não utilizado
        INSERT INTO azure_performance_metrics (metric_type, metric_details)
        VALUES ('unused_index', jsonb_build_object('index_name', v_index_name, 'table_name', v_table_name, 'action', 'consider dropping'));
    END LOOP;

    -- Reindexar índices frequentemente usados
    FOR v_index_name IN
        SELECT schemaname || '.' || indexrelname
        FROM pg_stat_user_indexes
        WHERE idx_scan > 10000
    LOOP
        EXECUTE 'REINDEX INDEX CONCURRENTLY ' || v_index_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;``` 


### Criação de Views e Índices Otimizados
Views Materializadas

1. View Hierárquica: A mv_hierarquia_completa é uma view otimizada que fornece uma estrutura hierárquica completa dos temas, subtemas, áreas e indicadores.

``` sql
CREATE MATERIALIZED VIEW mv_hierarquia_completa AS
WITH RECURSIVE full_hierarchy AS (
    SELECT t.id_tema, t.nome_pt AS tema, st.nome_pt AS sub_tema, a.nome_pt AS area, i.nome_pt AS indicador
    FROM temas t
    JOIN sub_temas st ON st.id_tema = t.id_tema
    JOIN areas a ON a.id_sub_tema = st.id_sub_tema
    JOIN indicadores i ON i.id_area = a.id_area
)
SELECT *, array_to_string(array[t.nome_pt, st.nome_pt, a.nome_pt, i.nome_pt], ' > ') as caminho_completo
FROM full_hierarchy
WITH DATA; ```

2. View de Estatísticas: A mv_estatisticas_indicadores fornece estatísticas detalhadas para cada indicador.

``` sql
CREATE MATERIALIZED VIEW mv_estatisticas_indicadores AS
WITH indicador_stats AS (
    SELECT i.id_indicador, COUNT(di.id_dado) as total_registros, MAX(di.updated_at) as ultima_atualizacao
    FROM indicadores i
    LEFT JOIN dados_indicadores di ON di.id_indicador = i.id_indicador
    GROUP BY i.id_indicador
)
SELECT * FROM indicador_stats
WITH DATA;
```

### Índices Adicionais
Índices adicionais podem ser adicionados conforme a necessidade para melhorar o desempenho das consultas realizadas nas views materializadas e nas tabelas principais:

``` sql
CREATE INDEX idx_mv_hierarquia_completa_caminho ON mv_hierarquia_completa(caminho_completo);
CREATE INDEX idx_mv_estatisticas_indicadores_id ON mv_estatisticas_indicadores(id_indicador);
```


## Conclusão
As configurações fornecidas acima otimizam o desempenho do PostgreSQL para uso no ambiente Azure, com foco em uma gestão de recursos eficiente, monitorização de métricas e otimização de índices.

