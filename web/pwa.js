/* Chrome owns the native installation prompt; leave its automatic promotion enabled. */
(() => {
  'use strict';
  let installPrompt = null;
  const dialog = document.getElementById('app-dialog');
  const description = document.getElementById('app-description');
  const install = document.getElementById('app-install');
  const status = document.getElementById('app-status');
  const standalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const refresh = () => {
    install.hidden = !installPrompt || standalone();
    install.disabled = false;
    description.textContent = standalone()
      ? 'CROWNFIELDはアプリとして起動しています。進行とクリア記録はこの端末に保存されます。'
      : installPrompt
        ? 'ホーム画面に追加すると、ブラウザのアドレス欄がない横画面で起動できます。'
        : /iPhone|iPad|iPod/.test(navigator.userAgent)
          ? 'Safariの共有メニューから「ホーム画面に追加」を選んでください。'
          : 'Chromeでこのページを開き、右上の︙→「ホーム画面に追加」→「インストール」を選んでください。';
    status.textContent = '進行はゲーム内の「保存」で残せます。クリア記録は自動保存です。';
  };
  const open = () => {
    if (dialog.open) return;
    refresh();
    dialog.showModal();
  };
  window.CrownfieldInstall = Object.freeze({open});
  window.addEventListener('beforeinstallprompt', event => {
    installPrompt = event;
    if (dialog.open) refresh();
  });
  window.addEventListener('appinstalled', () => { installPrompt = null; refresh(); });
  document.getElementById('app-open').addEventListener('click', open);
  document.getElementById('app-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('close', () => document.getElementById('canvas').focus());
  install.addEventListener('click', async () => {
    if (!installPrompt) return;
    const prompt = installPrompt;
    installPrompt = null;
    install.disabled = true;
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      refresh();
      status.textContent = choice.outcome === 'accepted'
        ? 'インストールを受け付けました。ホーム画面をご確認ください。'
        : '今回は追加しませんでした。Chromeのメニューからも追加できます。';
    } catch (_) {
      refresh();
      status.textContent = 'Chromeの︙メニューから「ホーム画面に追加」をお試しください。';
    }
  });
  // Register independently of a successful WebGL/engine startup. Same URL and
  // scope as Godot, so there is only one worker and the existing cache survives.
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./index.service.worker.js', {scope: './', updateViaCache: 'none'})
        .catch(() => { if (dialog.open) status.textContent = '通信状態を確認してChromeで開き直してください。'; });
    });
  }
})();
