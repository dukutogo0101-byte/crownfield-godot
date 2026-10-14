// A single sizing owner keeps CSS pixels and WebGL pixels in the same aspect
// ratio, including fullscreen/rotation transitions and high-DPI phones.
(() => {
  const canvas = document.getElementById('canvas');
  let scheduled = false;
  function sync() {
    const width = Math.max(1, Math.floor(window.innerWidth));
    const height = Math.max(1, Math.floor(window.innerHeight));
    const ratio = window.devicePixelRatio || 1;
    const backingWidth = Math.max(1, Math.round(width * ratio));
    const backingHeight = Math.max(1, Math.round(height * ratio));
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    if (canvas.width !== backingWidth) canvas.width = backingWidth;
    if (canvas.height !== backingHeight) canvas.height = backingHeight;
  }
  function schedule() {
    sync();
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => { scheduled = false; sync(); });
  }
  for (const event of ['resize', 'orientationchange', 'pageshow']) {
    window.addEventListener(event, schedule);
  }
  document.addEventListener('fullscreenchange', schedule);
  if (window.visualViewport) window.visualViewport.addEventListener('resize', schedule);
  window.crownfieldSyncViewport = schedule;
  sync();
})();
