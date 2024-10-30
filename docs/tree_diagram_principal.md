graph TD
    Root[Árvore da Informação Estatística] --> E[Economia]
    Root --> S[Social]
    Root --> R[A Região]
    Root --> M[Multitemas]
    
    %% Links
    click E href "tree_diagram_economia.md" "Ver detalhes Economia"
    click S href "tree_diagram_social.md" "Ver detalhes Social"
    click R href "tree_diagram_regiao.md" "Ver detalhes Região"
    click M href "tree_diagram_multitemas.md" "Ver detalhes Multitemas"

    %% Styling
    classDef default fill:#f9f9f9,stroke:#333,stroke-width:1px
    classDef root fill:#e6e6e6,stroke:#333,stroke-width:4px
    class Root root