# SIGE — Recuperação de Acesso e Password

## Princípio

A Secretaria nunca consulta, revela ou define manualmente a password antiga de um utilizador.

Recuperar acesso significa provar a identidade, invalidar o acesso anterior e emitir um novo mecanismo de autenticação.

Este desenho segue as recomendações de recuperação de contas da OWASP: mensagens genéricas para evitar enumeração, tokens/códigos aleatórios, expiração, uso único, rate limiting e invalidação de sessões. citeturn0search0turn0search2

## 1. Caminho normal — utilizador ainda controla o email

Na página de login: **Esqueci-me da password**.

1. Utilizador informa email institucional.
2. SIGE responde sempre de forma genérica.
3. Supabase envia o mecanismo de recuperação.
4. Utilizador abre o link.
5. SIGE permite definir nova password.
6. A sessão de recuperação é limitada à alteração de credencial.
7. Após alteração, o utilizador volta ao login normal.
8. Sessões anteriores são invalidadas quando aplicável.
9. Evento é auditado.

Supabase documenta `resetPasswordForEmail()` e o fluxo de página de recuperação; a operação administrativa de convite deve ocorrer apenas em ambiente confiável. citeturn0search8turn0search1

## 2. Perdeu a password e também não consegue usar o email

Neste caso existe recuperação assistida.

### Professor / Funcionário

O utilizador dirige-se à **Secretaria**.

A Secretaria:
1. localiza a pessoa pelo código institucional;
2. confirma identidade com os dados/documentos definidos pela escola;
3. confirma que o vínculo institucional continua activo;
4. abre um caso de recuperação;
5. regista o método de verificação;
6. para funções comuns, pode concluir a recuperação conforme a permissão;
7. para contas privilegiadas, exige aprovação adicional;
8. invalida as sessões existentes;
9. emite uma nova activação temporária;
10. marca `first_access_required = true`;
11. entrega o mecanismo temporário directamente ao titular;
12. o titular define a nova password no primeiro acesso.

### Regra

A Secretaria **não recebe a password final**.

## 3. Contas críticas

Para Direção, Direção Pedagógica, Financeiro e administradores técnicos, uma recuperação assistida usa **duplo controlo**:

Pedido → Verificação de identidade → Operador 1 → Aprovação Operador 2 → Reset → Sessões invalidadas → Primeiro acesso obrigatório

O mesmo funcionário não deve conseguir criar e aprovar sozinho uma recuperação de conta crítica.

## 4. Se o email institucional estiver perdido

A recuperação não altera o email imediatamente.

Primeiro verifica-se identidade, vínculo e autorização; depois regista-se a alteração, confirma-se o novo endereço e só então se conclui a mudança.

Alterações de email são eventos de segurança e devem ser auditadas.

## 5. Se o utilizador perdeu o código de utilizador

O código institucional pode ser recuperado pela Secretaria após verificação de identidade. O código não é a password.

## 6. Primeiro acesso

O fluxo preferencial é convite/activação, em vez de password permanente. Supabase permite convite por email e a configuração inicial da password pelo utilizador. citeturn0search1

Quando a instituição não dispõe de email funcional, usa-se uma credencial temporária de uso único, entregue de forma controlada, seguida de troca obrigatória.

## 7. Expiração

Toda recuperação/activação temporária possui validade curta, uso único, invalidação após utilização e auditoria. Um pedido novo deve invalidar mecanismos temporários anteriores.

## 8. Tentativas abusivas

O sistema deve aplicar rate limiting e respostas que não revelem se determinada conta existe. OWASP recomenda precisamente respostas consistentes para evitar enumeração. citeturn0search0turn0search2

## 9. Saída da escola

A saída institucional não é recuperação:

Vínculo terminado → Afectações terminadas → Conta suspensa → Sessões invalidadas → Histórico preservado

## 10. Alunos

Para alunos, a recuperação deve respeitar a idade e o modelo de identidade da escola. Quando existir encarregado confirmado, este pode participar do processo conforme as regras institucionais.

## 11. Auditoria

Cada recuperação deve guardar conta alvo, escola, actor, método de verificação, motivo, data/hora, aprovação, conclusão, invalidação de sessões e resultado.

Nunca guardar password, token de recuperação ou segredo temporário em texto puro ou nos logs.

## 12. Estados

`REQUESTED → VERIFIED → APPROVED → COMPLETED`

Alternativas: `REQUESTED → REJECTED`, `REQUESTED → CANCELLED`, `APPROVED → EXPIRED`.

A entidade `account_recovery_cases` representa este processo no domínio.

## 13. UX

Na recuperação pública: **Se os dados corresponderem a uma conta institucional, serão enviadas instruções de recuperação.**

Na recuperação presencial: **Dirija-se à Secretaria da instituição com a identificação necessária para validar a sua conta.**

Não revelar se um email existe ou se uma conta está bloqueada.

## 14. Regra de ouro

**Nenhum funcionário do SIGE precisa conhecer a password do utilizador.**

A Secretaria recupera a identidade e autoriza a emissão de uma nova credencial; o titular cria a password final.