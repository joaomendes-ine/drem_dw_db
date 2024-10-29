# Sistema Dimensional

## Tabela 6: dimensoes

Tabela de dimensões para categorizar os dados.

| Coluna         | Tipo                         | Obrigatório | Descrição                                  |
|----------------|------------------------------|-------------|--------------------------------------------|
| id_dimensao    | UUID                         | Sim         | Identificador único da dimensão.           |
| id_parent      | UUID                         | Não         | Identificador da dimensão pai, se houver.  |
| tipo           | dimensao_tipo                | Sim         | Tipo de dimensão (ex: geográfica, temporal).|
| codigo         | VARCHAR(50)                  | Sim         | Código único da dimensão.                  |
| nome_pt        | VARCHAR(255)                 | Sim         | Nome da dimensão em português.             |
| nome_en        | VARCHAR(255)                 | Não         | Nome da dimensão em inglês.                |
| valor          | VARCHAR(255)                 | Sim         | Valor específico da dimensão.              |
| hierarquia     | ltree                        | Sim         | Hierarquia da dimensão para análise.       |
| nivel          | INTEGER                      | Sim         | Nível hierárquico da dimensão.             |
| ordem          | INTEGER                      | Não         | Ordem de apresentação da dimensão.         |
| data_inicio    | DATE                         | Não         | Data de início da validade da dimensão.    |
| data_fim       | DATE                         | Não         | Data de fim da validade da dimensão.       |
| metadata       | JSONB                        | Não         | Informações adicionais sobre a dimensão.   |
| ativo          | BOOLEAN                      | Sim         | Indica se a dimensão está ativa ou não.    |
| created_at     | TIMESTAMP WITH TIME ZONE     | Sim         | Data de criação da dimensão.               |
| updated_at     | TIMESTAMP WITH TIME ZONE     | Sim         | Data de última atualização da dimensão.    |

Explicação: A tabela `dimensoes` organiza as formas de classificar os dados. Exemplos incluem dimensões de tempo e geografia.

---

## Tabela 7: indicador_dimensoes_bridge

Tabela de "ponte" para lidar com dimensões dinâmicas.

| Coluna             | Tipo                          | Obrigatório | Descrição                                      |
|--------------------|-------------------------------|-------------|------------------------------------------------|
| id_bridge          | UUID                          | Sim         | Identificador único da dimensão.               |
| id_dado            | UUID                          | Sim         | Identificador da dimensão pai, se houver.      |
| id_dimensao        | UUID                          | Sim         | Tipo da dimensão (geográfica, temporal, etc.). |
| tipo_dimensao      | ENUM(dimensao_tipo)           | Sim         | Código único da dimensão.                      |
| valor_dimensao     | VARCHAR(255)                  | Sim         | Nome da dimensão em português.                 |
| created_at         | TIMESTAMP WITH TIME ZONE      | Sim         | Data de criação da dimensão.                   |
| updated_at         | TIMESTAMP WITH TIME ZONE      | Sim         | Data de última atualização da dimensão.        |

Explicação: A tabela `indicador_dimensoes_bridge` permite flexibilidade na estrutura dimensional, possibilitando a adição de dimensões sem mudanças na estrutura da base de dados.

