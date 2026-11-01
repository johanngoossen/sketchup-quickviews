/* Shared drawing for the README images: a simple SketchUp-like model view
   and the Quick Views frame overlay (same math as frame_math.rb). */
(function () {
  'use strict';
  const NS = 'http://www.w3.org/2000/svg';

  function el(name, attrs, parent) {
    const e = document.createElementNS(NS, name);
    Object.entries(attrs || {}).forEach(([k, v]) => e.setAttribute(k, v));
    if (parent) parent.appendChild(e);
    return e;
  }

  // Bilinear point on a quad [tl, tr, br, bl], u along, v down.
  function q(quad, u, v) {
    const [a, b, c, d] = quad;
    const top = [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u];
    const bot = [d[0] + (c[0] - d[0]) * u, d[1] + (c[1] - d[1]) * u];
    return [top[0] + (bot[0] - top[0]) * v, top[1] + (bot[1] - top[1]) * v];
  }
  const pts = (list) => list.map((p) => p.join(',')).join(' ');

  function windows(g, quad, cols, rows, opts) {
    const o = Object.assign({ mx: 0.08, my: 0.12, gap: 0.05, fill: '#cfcfcf' }, opts);
    const cw = (1 - 2 * o.mx - (cols - 1) * o.gap) / cols;
    const rh = (1 - 2 * o.my - (rows - 1) * o.gap) / rows;
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const u0 = o.mx + c * (cw + o.gap), v0 = o.my + r * (rh + o.gap);
        el('polygon', { points: pts([q(quad, u0, v0), q(quad, u0 + cw, v0), q(quad, u0 + cw, v0 + rh), q(quad, u0, v0 + rh)]),
                        fill: o.fill, stroke: '#111', 'stroke-width': 1.4 }, g);
      }
    }
  }

  // Model view in a 1600 x 1000 coordinate system.
  function scene(svg) {
    const defs = el('defs', {}, svg);
    const sky = el('linearGradient', { id: 'sky', x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
    el('stop', { offset: 0, 'stop-color': '#e9e9e9' }, sky);
    el('stop', { offset: 1, 'stop-color': '#fbfbfb' }, sky);
    el('rect', { x: 0, y: 0, width: 1600, height: 560, fill: 'url(#sky)' }, svg);
    el('rect', { x: 0, y: 560, width: 1600, height: 440, fill: '#e2e2e2' }, svg);
    const g = el('g', { 'stroke-linejoin': 'round' }, svg);

    // ground lines towards the vanishing points
    for (let i = -6; i <= 14; i++) {
      el('line', { x1: 760 + i * 180, y1: 1000, x2: -1400 + i * 10, y2: 560, stroke: '#d2d2d2', 'stroke-width': 1 }, g);
    }

    const left = [[260, 360], [760, 300], [760, 760], [260, 714]];
    const right = [[760, 300], [1300, 358], [1300, 716], [760, 760]];
    const roof = [[230, 352], [760, 286], [1336, 350], [790, 292]];
    // roof slab (seen from below the horizon line it is just a thin band)
    el('polygon', { points: pts([[226, 346], [760, 280], [1338, 344], [1338, 360], [760, 298], [226, 364]]), fill: '#3a3a3a', stroke: '#111', 'stroke-width': 2 }, g);
    el('polygon', { points: pts(left), fill: '#bdbdbd', stroke: '#111', 'stroke-width': 2.2 }, g);
    el('polygon', { points: pts(right), fill: '#f4f4f4', stroke: '#111', 'stroke-width': 2.2 }, g);
    windows(g, left, 4, 3, { fill: '#8f8f8f' });
    windows(g, right, 5, 3, { fill: '#d6d6d6', mx: 0.06 });
    // entrance
    const door = [q(right, 0.08, 0.72), q(right, 0.22, 0.72), q(right, 0.22, 1), q(right, 0.08, 1)];
    el('polygon', { points: pts(door), fill: '#222', stroke: '#111', 'stroke-width': 1.6 }, g);
    void roof;

    // trees
    [[150, 760, 70], [1440, 770, 80], [1180, 800, 46]].forEach(([x, y, r]) => {
      el('line', { x1: x, y1: y, x2: x, y2: y - r * 1.4, stroke: '#111', 'stroke-width': 3 }, g);
      el('circle', { cx: x, cy: y - r * 1.8, r, fill: '#9a9a9a', stroke: '#111', 'stroke-width': 2, 'fill-opacity': 0.85 }, g);
    });
    // person for scale
    el('circle', { cx: 980, cy: 690, r: 9, fill: '#111' }, g);
    el('path', { d: 'M972 702 h16 l4 40 h-7 l-2 38 h-6 l-2 -38 h-7 z', fill: '#111' }, g);
  }

  function inscribe(vw, vh, aspect) {
    let w = vw, h = vw / aspect;
    if (h > vh) { h = vh; w = vh * aspect; }
    return [(vw - w) / 2, (vh - h) / 2, w, h];
  }

  // Frame overlay: shade outside, black line, label top left.
  function overlay(svg, aspect, label, opacity) {
    const fs = parseFloat(svg.dataset.fontsize || 24);
    const [x, y, w, h] = inscribe(1600, 1000, aspect);
    const g = el('g', {}, svg);
    const shade = { fill: 'rgb(40,40,40)', 'fill-opacity': opacity == null ? 0.55 : opacity };
    if (y > 0.5) {
      el('rect', Object.assign({ x: 0, y: 0, width: 1600, height: y }, shade), g);
      el('rect', Object.assign({ x: 0, y: y + h, width: 1600, height: 1000 - y - h }, shade), g);
    }
    if (x > 0.5) {
      el('rect', Object.assign({ x: 0, y: 0, width: x, height: 1000 }, shade), g);
      el('rect', Object.assign({ x: x + w, y: 0, width: 1600 - x - w, height: 1000 }, shade), g);
    }
    el('rect', { x, y, width: w, height: h, fill: 'none', stroke: '#000', 'stroke-width': 3 }, g);
    if (label) {
      const t = el('text', { x: x + 16, y: y + fs * 1.5, 'font-size': fs, fill: '#000',
                             'font-family': '-apple-system, Helvetica, sans-serif' }, g);
      t.textContent = label;
    }
  }

  // <svg class="vp" data-aspect="1.778" data-label="..."> placeholders
  function render() {
    document.querySelectorAll('svg.vp').forEach((svg) => {
      svg.setAttribute('viewBox', svg.dataset.viewbox || '0 0 1600 1000');
      svg.setAttribute('preserveAspectRatio', 'xMidYMid slice');
      scene(svg);
      if (svg.dataset.aspect) overlay(svg, parseFloat(svg.dataset.aspect), svg.dataset.label, svg.dataset.opacity && parseFloat(svg.dataset.opacity));
    });
  }
  document.addEventListener('DOMContentLoaded', render);
})();
