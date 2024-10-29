# Documentação das Funções de Manutenção

## Visão Geral

Esta documentação descreve as funções de manutenção criadas para o Data Warehouse DREM. As funções estão otimizadas para validação de dados, arquivamento, análise e exportação de dados.

## Objetivo

O principal objetivo deste script é criar funções de manutenção otimizadas que melhorem a integridade dos dados, facilitem o arquivamento de dados antigos, analisem o crescimento dos dados e permitam funcionalidades de exportação de dados.

## Funções

### 1. Funções de Validação de Dados

#### `validar_dados_indicador()`

Esta função valida os dados dos indicadores antes de serem inseridos ou atualizados na base de dados. Ela verifica se os tipos de valores estão corretos com base nas especificações do indicador.

**Trigger:** 
- Esta função deve ser definida como um trigger para a tabela `dados_indicadores`.

**Parâmetros:**
- Nenhum (utiliza o contexto do registo `NEW`)

**Valor de Retorno:**
- Retorna o registo `NEW` após a validação.

**Exceções:**
- Levanta exceções com mensagens de erro detalhadas se a validação falhar.

---

#### `validar_hierarquia_dimensao()`

Valida a hierarquia das dimensões para garantir que novas entradas mantêm relações corretas de pai-filho.

**Trigger:** 
- Esta função deve ser definida como um trigger para a tabela `dimensoes`.

**Parâmetros:**
- Nenhum (utiliza o contexto do registo `NEW`)

**Valor de Retorno:**
- Retorna o registo `NEW` após a validação.

**Exceções:**
- Levanta exceções para dimensões pai inválidas ou caminhos de hierarquia.

---

### 2. Funções de Manutenção

#### `arquivar_dados_antigos()`

Arquiva partições de dados antigos para um esquema especificado. Esta função ajuda na gestão do armazenamento e na manutenção do desempenho.

**Parâmetros:**
- `p_anos_retencao` (INTEGER, padrão: 5): O número de anos de retenção de dados antes do arquivamento.
- `p_schema_arquivo` (TEXT, padrão: 'arquivo'): O esquema onde os dados arquivados serão armazenados.
- `p_batch_size` (INTEGER, padrão: 10000): O número de registos a processar em cada lote.

**Valor de Retorno:**
- Uma tabela com as seguintes colunas:
  - `partitions_moved` (INTEGER): Número de partições movidas com sucesso.
  - `rows_archived` (BIGINT): Número total de linhas arquivadas.
  - `execution_time` (INTERVAL): Tempo necessário para executar o processo de arquivamento.

---

#### `analisar_crescimento_dw()`

Analisa o crescimento das tabelas do data warehouse durante um período especificado.

**Parâmetros:**
- `p_dias_analise` (INTEGER, padrão: 30): O número de dias a analisar.

**Valor de Retorno:**
- Uma tabela com as seguintes colunas:
  - `tabela` (TEXT): Nome da tabela.
  - `total_registros` (BIGINT): Número total de registos na tabela.
  - `tamanho_mb` (NUMERIC): Tamanho da tabela em megabytes.
  - `crescimento_diario_medio` (NUMERIC): Crescimento médio diário em registos.
  - `projecao_6_meses_gb` (NUMERIC): Tamanho projetado em gigabytes após seis meses.

---

### 3. Funções de Análise

#### `analisar_tendencia_indicador()`

Analisa as tendências de um indicador específico durante um período definido.

**Parâmetros:**
- `p_id_indicador` (UUID): O ID do indicador a analisar.
- `p_periodos` (INTEGER, padrão: 12): O número de períodos a analisar.
- `p_tipo_periodo` (TEXT, padrão: 'month'): O tipo de período (ex.: mês, semana).

**Valor de Retorno:**
- Uma tabela com as seguintes colunas:
  - `periodo` (DATE): O período da análise.
  - `valor` (NUMERIC): O valor médio para o período.
  - `tendencia` (NUMERIC): O valor da tendência calculado.
  - `variacao_percentual` (NUMERIC): Variação percentual em relação ao período anterior.
  - `sazonalidade` (NUMERIC): Valor do índice sazonal.
  - `predicao_proximo_periodo` (NUMERIC): Valor previsto para o próximo período.

---

### 4. Função de Exportação

#### `exportar_dados_indicador()`

Exporta dados para um indicador especificado num formato dado (CSV ou JSON).

**Parâmetros:**
- `p_id_indicador` (UUID): O ID do indicador a exportar.
- `p_formato` (TEXT, padrão: 'csv'): O formato dos dados exportados (CSV ou JSON).
- `p_data_inicio` (DATE, padrão: NULL): Data de início para a exportação de dados.
- `p_data_fim` (DATE, padrão: NULL): Data de fim para a exportação de dados.

**Valor de Retorno:**
- Retorna os dados exportados como TEXT no formato especificado.

**Exceções:**
- Levanta uma exceção se um formato não suportado for fornecido.

## Exemplo de Uso

Aqui está um exemplo de como usar a função `arquivar_dados_antigos()`:

```sql
SELECT * FROM arquivar_dados_antigos(p_anos_retencao => 5, p_schema_arquivo => 'archive', p_batch_size => 10000);
```
- Esta chamada irá armazenar dados com mais de cinco anos no esquema de arquivo, processando registos em lotes de 10.000.