/* Serve Godot's engine compressed, below the hosting per-file size limit. */
(function () {
  const originalFetch = window.fetch.bind(window);
  window.fetch = async function(input, init) {
    const url = new URL(typeof input === 'string' ? input : (input.url || String(input)), document.baseURI);
    if (!url.pathname.endsWith('/index.wasm')) return originalFetch(input, init);
    url.pathname += '.gz';
    const response = await originalFetch(url.toString(), init);
    if (!response.ok) return response;
    const bytes = new Uint8Array(await response.arrayBuffer());
    // Some hosts automatically decompress gzip resources; accept both forms.
    if (bytes[0] === 0 && bytes[1] === 97 && bytes[2] === 115 && bytes[3] === 109) {
      return new Response(bytes, {headers: {'Content-Type': 'application/wasm', 'Content-Length': String(bytes.length)}});
    }
    if (typeof DecompressionStream !== 'function') throw new Error('このブラウザはゲームデータの展開に対応していません。Chrome等で開いてください。');
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
    return new Response(stream, {headers: {'Content-Type': 'application/wasm'}});
  };
}());
