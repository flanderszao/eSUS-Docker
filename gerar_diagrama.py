import csv
import sys

# Caminho do arquivo CSV
csv_file_path = '/workspaces/eSUS-Docker/esus_db_relationships.csv'

# FILTRO: Para evitar gerar um diagrama ilegível com 500 tabelas, 
# adicione partes do nome das tabelas que você quer focar.
# Deixe a lista vazia [] se quiser gerar TUDO (Cuidado: pode travar visualizadores online).
# Exemplo de foco clínico: ['tb_cidadao', 'tb_prontuario', 'tb_atend', 'tb_prof']
FILTROS = ['tb_cidadao', 'tb_prontuario', 'tb_atend', 'tb_prof', 'tb_lotacao', 'tb_unidade_saude']

# Se quiser tudo, descomente a linha abaixo:
# FILTROS = []

def should_include(table_name, referenced_table):
    if not FILTROS:
        return True
    
    # Verifica se a tabela principal OU a referenciada estão nos filtros
    msg_in_filter = any(f in table_name for f in FILTROS)
    ref_in_filter = any(f in referenced_table for f in FILTROS)
    
    # Estratégia: Só mostra se AMBAS estiverem no contexto, ou pelo menos a origem
    # Para diagramas mais limpos, exija que ambas estejam conectadas ao tema
    return msg_in_filter or ref_in_filter

def generate_mermaid():
    print("erDiagram")
    
    relations_count = 0
    tables_found = set()
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                table = row['table_name']
                ref_table = row['referenced_table']
                fk_col = row['foreign_key_column']
                
                # Pula linhas sem relacionamento ou que não passam no filtro
                if not ref_table or not should_include(table, ref_table):
                    continue
                
                # Adiciona ao conjunto de tabelas para controle
                tables_found.add(table)
                tables_found.add(ref_table)
                
                # Syntax Mermaid: REFERENCIADA ||--o{ ORIGEM : "fk"
                # Significa: Uma tabela referenciada tem muitos registros na tabela de origem
                print(f'    {ref_table} ||--o{{ {table} : "{fk_col}"')
                relations_count += 1

    except FileNotFoundError:
        print(f"Erro: Arquivo não encontrado em {csv_file_path}")
        return

    # Comentário no final para log
    print(f"\n%% Gerado com sucesso.")
    print(f"%% Tabelas envolvidas: {len(tables_found)}")
    print(f"%% Relacionamentos: {relations_count}")
    
    if not FILTROS:
        print("%% ATENÇÃO: Modo exaustivo (sem filtros). Este diagrama pode ser muito pesado.")

if __name__ == "__main__":
    generate_mermaid()
