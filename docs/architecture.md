# Arquitetura Detalhada do Data Warehouse da DREM

## Visão Geral
O Data Warehouse (DW) do Portal de Estatística da DREM é projetado para gerir dados estatísticos da Região Autónoma da Madeira. A arquitetura do DW suporta análises multidimensionais complexas, integração com IA e apresenta dados em múltiplos idiomas.

### Objetivos Principais
- **Análise de Dados**: Capacitar análises detalhadas usando estruturas OLAP.
- **Flexibilidade e Escalabilidade**: Suporte modular para novos temas e indicadores.
- **Multilíngua**: Dados acessíveis em português e inglês.
- **Integração com IA**: Compatível com modelos de IA e chatbots.

## Modelos de Dados
O DW é projetado com um modelo híbrido, combinando esquemas de estrela e floco de neve, além de tabelas bridge para flexibilidade e desempenho.

### Componentes da Arquitetura

1. **Esquema Estrela**  
   - Usado para análises dimensionais rápidas.
   - Estrutura que une fatos e dimensões de forma simplificada.

2. **Esquema Floco de Neve**  
   - Utilizado para hierarquias de dados mais complexas.
   - As dimensões são normalizadas para armazenar informações hierárquicas detalhadas.

3. **Bridge Tables**  
   - Permitem a flexibilidade necessária para trabalhar com dimensões dinâmicas e relações complexas entre entidades.

## Hierarquia de Dados

- **Temas**  
  Os principais tópicos de dados, como Economia e Social.
  
  - **Sub-temas**  
    Divisões dentro de cada tema, detalhando tópicos específicos.
    
    - **Áreas**  
      Categorias dentro de cada sub-tema que contêm indicadores.
      
      - **Indicadores**  
        Métricas ou dados específicos que representam informações estatísticas.
        
        - **Dados dos Indicadores**  
          Valores reais coletados, com suporte a múltiplas dimensões via tabelas bridge.

## Suporte a IA e Multilíngua
- **IA**: Estrutura otimizada para integração com IA para análises avançadas e consultas automatizadas.
- **Multilíngua**: Dados estão disponíveis em português e inglês, permitindo uma experiência de consulta bilingue.
