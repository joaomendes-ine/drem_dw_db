```mermaid
graph TD
    Root[Árvore da Informação Estatística] --> E[Economia<br>12 sub-temas]
    Root --> S[Social<br>5 sub-temas]
    Root --> R[A Região<br>1 sub-tema]
    Root --> M[Multitemas]

    %% Styling
    classDef default fill:#f9f9f9,stroke:#333,stroke-width:1px
    classDef root fill:#e6e6e6,stroke:#333,stroke-width:4px
    classDef tema fill:#d4e6f1,stroke:#2874a6,stroke-width:2px
    
    class Root root
    class E,S,R,M tema

    %% Links
    click E "https://github.com/joaomendes-ine/drem_dw_db/blob/main/docs/tree_diagram_economia.md"
    click S "https://github.com/joaomendes-ine/drem_dw_db/blob/main/docs/tree_diagram_social.md"
    click R "https://github.com/joaomendes-ine/drem_dw_db/blob/main/docs/tree_diagram_regiao.md"
    click M "https://github.com/joaomendes-ine/drem_dw_db/blob/main/docs/tree_diagram_multitemas.md"
```