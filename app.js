(() => {
  const sidebar = document.getElementById('sidebar');
  const toast = document.getElementById('toast');
  let toastTimer;
  function notify(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3000);
  }
  const labels = {
    inicio:'Visão geral', clientes:'Clientes', revendedores:'Revendedores',
    planos:'Planos e serviços', financeiro:'Financeiro', relatorios:'Relatórios',
    automacoes:'Automações', integracoes:'Integrações', seguranca:'Segurança',
    configuracoes:'Configurações'
  };
  function navigate(page) {
    const label = labels[page] || labels.inicio;
    document.getElementById('crumbCurrent').textContent = label;
    document.querySelectorAll('.nav-link').forEach(link => {
      link.classList.toggle('active', link.dataset.page === page);
    });
    sidebar.classList.remove('open');
    if (page !== 'inicio') {
      notify(label + ': módulo reservado para implementação. O banco de dados ainda não está conectado.');
    }
  }
  document.querySelectorAll('[data-page]').forEach(link => {
    link.addEventListener('click', event => {
      event.preventDefault();
      navigate(link.dataset.page);
    });
  });
  document.querySelectorAll('[data-action]').forEach(button => {
    button.addEventListener('click', () => navigate(button.dataset.action));
  });
  document.getElementById('menuToggle').addEventListener('click', () => sidebar.classList.toggle('open'));
  document.getElementById('quickAction').addEventListener('click', () => {
    notify('Ações rápidas serão ativadas após configurar os módulos e o banco de dados.');
  });
  document.getElementById('refreshButton').addEventListener('click', () => {
    notify('Interface atualizada. Os indicadores reais aguardam conexão com o Supabase.');
  });
  document.querySelector('.notice-close').addEventListener('click', () => {
    document.querySelector('.notice').remove();
  });
})();