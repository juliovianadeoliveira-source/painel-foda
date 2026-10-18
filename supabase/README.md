# Painel FODA — banco de dados

O esquema inicial está em `schema.sql`. Ele cria perfis, planos, clientes, pagamentos, renovações e auditoria, com RLS habilitado.

## Como aplicar
1. Abra o projeto Supabase do Painel FODA.
2. Entre em **SQL Editor**.
3. Cole o conteúdo de `schema.sql` e execute.
4. Crie o primeiro administrador com uma conta Auth já criada: em SQL Editor, execute:
   `update public.profiles set role = 'admin' where id = 'UUID-DO-USUARIO';`
   Se ainda não houver perfil, crie-o para esse usuário Auth com:
   `insert into public.profiles (id, full_name, role) values ('UUID-DO-USUARIO', 'Administrador', 'admin');`
5. Não coloque senha do banco, `service_role` nem chaves secretas no frontend ou no GitHub.

## Nota de segurança
RLS restringe linhas, mas as políticas devem ser validadas contra os papéis reais e os fluxos de uso antes de operar com dados reais. Pagamentos pendentes não devem ser contabilizados como receita recebida; use apenas status `confirmed`.
