# SIGE — Matrícula: fluxo operacional simplificado

## Decisão

A secretaria deve executar a matrícula como uma única tarefa operacional. A separação interna entre identidade, matrícula, percurso e colocação permanece no domínio, mas não deve aparecer como etapas administrativas independentes.

## Fluxo

1. Selecionar aluno — quando o aluno já existe.
2. Ano letivo — pré-selecionado para o ano OPEN.
3. Classe — única decisão obrigatória.
4. Grupo/curso — aparece somente quando a classe pertence ao 2.º ciclo.
5. Turma — aparece depois de classe/grupo e contém somente turmas compatíveis.
6. Tipo de entrada — Inicial por defeito; alterações ficam em "Mais opções".
7. Data — hoje por defeito.
8. Confirmar matrícula — uma única ação.

## Progressive disclosure

Não mostrar campos que ainda não são relevantes. A turma depende da classe; o grupo depende do ciclo. O sistema revela cada decisão somente quando a anterior torna a decisão aplicável.

## Regras de UI

- Uma única página e uma única ação primária.
- Título: "Nova matrícula".
- Subtítulo curto: "Registe o aluno para o ano letivo e coloque-o na turma."
- Ano letivo OPEN pré-selecionado.
- Data atual pré-preenchida.
- Tipo de entrada INITIAL por defeito e secundário.
- Grupo/curso oculto fora do 2.º ciclo.
- Turma filtrada por ano + classe + grupo/percurso.
- Nunca mostrar turmas de outra classe.
- Nunca mostrar uma lista vazia sem explicar o motivo.
- Resumo compacto antes da confirmação: Aluno · Ano · Classe · Grupo (se aplicável) · Turma.
- Botão primário: "Confirmar matrícula".
- Enquanto processa: "A guardar…"; impedir duplo envio.
- Sucesso: confirmação curta e acesso imediato ao perfil/matrícula.
- Erros de domínio devem explicar a ação necessária, não códigos técnicos.

## Regra de domínio

A simplificação da interface não remove as invariantes do servidor:

- matrícula pertence à escola/ano;
- classe deve existir e estar ativa;
- 2.º ciclo exige percurso/grupo;
- 1.º ciclo não aceita percurso;
- turma deve pertencer ao mesmo ano e classe;
- no 2.º ciclo, turma e matrícula devem possuir o mesmo percurso;
- capacidade e período devem ser validados no servidor;
- operação deve ser idempotente e auditada.

## Referência de design

O fluxo aplica progressive disclosure e minimização de entrada de dados: o sistema pré-preenche valores conhecidos e revela escolhas condicionais apenas quando necessárias. A abordagem segue as recomendações atuais da Apple para reduzir complexidade, organizar a hierarquia visual e validar dados durante a entrada.

## Anti-padrões proibidos

- formulário longo com todas as opções abertas;
- página de matrícula seguida obrigatoriamente por outra página de colocação;
- turma de classe diferente na mesma lista;
- pedir novamente dados que o sistema já conhece;
- mostrar grupo para 7.ª–10.ª;
- mostrar opções internas de domínio que a secretaria não precisa entender;
- dois botões primários concorrentes;
- modal dentro de modal;
- cards decorativos sem função.

## Arquitetura

Internamente continuam separados:
student -> enrollment -> pathway selection -> class placement.

Na experiência da secretaria:
Nova matrícula -> Confirmar matrícula.

A operação deve ser transacional no servidor para que a matrícula e a colocação não fiquem parcialmente concluídas quando a secretaria escolhe uma turma.
