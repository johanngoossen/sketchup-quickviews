/* Quick Views dialog. Talks to Ruby via sketchup.<callback>(json);
   Ruby answers by calling JV.<fn>(payload). */
(function () {
  'use strict';

  const FIELDS = ['width', 'height', 'format', 'jpg_quality', 'antialias', 'transparent', 'line_scale'];

  const $ = (id) => document.getElementById(id);
  const t = I18N.t;
  const state = {
    presets: [],
    activeId: null,
    form: null,      // current (possibly unsaved) settings
    dirty: false,
    scenes: [],
    checked: new Set(),
    viewport: [0, 0],
    running: false,
  };

  // --- bridge ---------------------------------------------------------

  function call(name, data) {
    const json = JSON.stringify(data || {});
    if (window.sketchup && typeof window.sketchup[name] === 'function') {
      window.sketchup[name](json);
    } else if (window.JVMock) {
      window.JVMock(name, data || {});
    }
  }

  function debounce(fn, ms) {
    let t = null;
    return function (...args) {
      clearTimeout(t);
      t = setTimeout(() => fn.apply(this, args), ms);
    };
  }

  // --- presets / form -------------------------------------------------

  function activePreset() {
    return state.presets.find((p) => p.id === state.activeId) || state.presets[0];
  }

  function renderPresetSelect() {
    const sel = $('preset');
    sel.innerHTML = '';
    const groups = [[t('groupBuiltin'), state.presets.filter((p) => p.builtin)],
                    [t('groupOwn'), state.presets.filter((p) => !p.builtin)]];
    groups.forEach(([label, list]) => {
      if (!list.length) return;
      const og = document.createElement('optgroup');
      og.label = label;
      list.forEach((p) => {
        const o = document.createElement('option');
        o.value = p.id;
        o.textContent = p.viewport ? p.name : `${p.name} – ${p.width} × ${p.height}`;
        og.appendChild(o);
      });
      sel.appendChild(og);
    });
    sel.value = state.activeId;
  }

  function loadForm(preset) {
    state.form = Object.assign({}, preset);
    state.dirty = false;
    writeForm();
  }

  function writeForm() {
    const f = state.form;
    const vp = f.viewport;
    $('width').value = vp ? state.viewport[0] : f.width;
    $('height').value = vp ? state.viewport[1] : f.height;
    $('width').disabled = vp;
    $('height').disabled = vp;
    $('format').value = f.format;
    $('jpg_quality').value = f.jpg_quality;
    $('antialias').checked = !!f.antialias;
    $('transparent').checked = !!f.transparent;
    $('line_scale').value = f.line_scale;
    updateFormUI();
  }

  function readForm() {
    const f = state.form;
    if (!f.viewport) {
      f.width = parseInt($('width').value, 10) || 1;
      f.height = parseInt($('height').value, 10) || 1;
    }
    f.format = $('format').value;
    f.jpg_quality = parseInt($('jpg_quality').value, 10);
    f.antialias = $('antialias').checked;
    f.transparent = f.format === 'png' && $('transparent').checked;
    f.line_scale = parseFloat($('line_scale').value) || 1;
  }

  function gcd(a, b) { return b ? gcd(b, a % b) : a; }

  function ratioText(w, h) {
    if (!w || !h) return '–';
    const g = gcd(w, h);
    const rw = w / g, rh = h / g;
    const dec = (w / h).toFixed(3).replace(/\.?0+$/, '');
    const r = w / h;
    if (Math.abs(r - Math.SQRT2) < 0.002) return `√2 ${t('landscape')} (${dec})`;
    if (Math.abs(r - Math.SQRT1_2) < 0.002) return `√2 ${t('portrait')} (${dec})`;
    return rw <= 32 && rh <= 32 ? `${rw}:${rh} (${dec})` : dec;
  }

  function updateFormUI() {
    const f = state.form;
    const w = f.viewport ? state.viewport[0] : f.width;
    const h = f.viewport ? state.viewport[1] : f.height;
    $('ratio').textContent = ratioText(w, h);
    const jpg = f.format === 'jpg';
    $('quality-wrap').hidden = !jpg;
    $('quality-val').textContent = jpg ? `${f.jpg_quality}` : '';
    $('transparent-wrap').hidden = jpg;

    const builtin = !!activePreset().builtin;
    $('btn-save').disabled = builtin || !state.dirty || state.running;
    $('btn-rename').disabled = builtin || state.running;
    $('btn-delete').disabled = builtin || state.running;
    let hint = '';
    if (builtin && state.dirty) hint = t('hintBuiltinDirty');
    else if (builtin) hint = t('hintBuiltin');
    else if (state.dirty) hint = t('hintDirty');
    $('preset-hint').textContent = hint;
  }

  function formSettings() {
    const f = Object.assign({}, state.form);
    f.name = activePreset().name;
    return f;
  }

  const notifyForm = debounce(() => {
    call('formChanged', { settings: formSettings() });
    requestPreview();
  }, 120);

  function onFieldChange() {
    readForm();
    state.dirty = true;
    updateFormUI();
    notifyForm();
  }

  // --- pattern / preview ---------------------------------------------

  function renderChips() {
    const box = $('chips');
    box.innerHTML = '';
    I18N.placeholders().forEach((ph) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = `{${ph}}`;
      b.addEventListener('click', () => insertAtCursor($('pattern'), `{${ph}}`));
      box.appendChild(b);
    });
  }

  function insertAtCursor(input, text) {
    const s = input.selectionStart ?? input.value.length;
    const e = input.selectionEnd ?? input.value.length;
    input.value = input.value.slice(0, s) + text + input.value.slice(e);
    input.focus();
    input.setSelectionRange(s + text.length, s + text.length);
    requestPreview();
  }

  const requestPreview = debounce(() => {
    const first = state.scenes.find((s) => state.checked.has(s.index));
    call('preview', {
      pattern: $('pattern').value,
      settings: formSettings(),
      sceneIndex: first ? first.index : 0,
    });
  }, 150);

  // --- scenes ----------------------------------------------------------

  function renderScenes() {
    const ul = $('scenes');
    ul.innerHTML = '';
    if (!state.scenes.length) {
      const li = document.createElement('li');
      li.className = 'empty';
      li.textContent = t('noScenes');
      ul.appendChild(li);
    }
    state.scenes.forEach((s) => {
      const li = document.createElement('li');
      const label = document.createElement('label');
      label.className = 'check';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = state.checked.has(s.index);
      cb.addEventListener('change', () => {
        if (cb.checked) state.checked.add(s.index); else state.checked.delete(s.index);
        updateSceneCount();
        requestPreview();
      });
      const nr = document.createElement('span');
      nr.className = 'nr';
      nr.textContent = String(s.index + 1).padStart(2, '0');
      const name = document.createElement('span');
      name.textContent = s.name;
      label.append(cb, nr, name);
      if (!s.animation) {
        const tag = document.createElement('span');
        tag.className = 'tag';
        tag.textContent = t('notInAnim');
        label.appendChild(tag);
      }
      li.appendChild(label);
      ul.appendChild(li);
    });
    updateSceneCount();
  }

  function updateSceneCount() {
    $('scene-count').textContent = t('sceneCount', { n: state.checked.size, total: state.scenes.length });
    $('btn-start').disabled = state.running || state.checked.size === 0;
  }

  function setChecked(filter) {
    state.checked = new Set(state.scenes.filter(filter).map((s) => s.index));
    renderScenes();
    requestPreview();
  }

  // --- export ---------------------------------------------------------

  function setRunning(running) {
    state.running = running;
    $('btn-start').hidden = running;
    $('btn-cancel').hidden = !running;
    $('btn-cancel').disabled = false;
    document.querySelectorAll('main input, main select, main button').forEach((el) => {
      if (running) {
        el.dataset.wasDisabled = el.disabled ? '1' : '';
        el.disabled = true;
      } else if (el.dataset.wasDisabled !== undefined) {
        el.disabled = el.dataset.wasDisabled === '1';
        delete el.dataset.wasDisabled;
      }
    });
    if (!running) updateFormUI();
    updateSceneCount();
  }

  function startExport() {
    readForm();
    hideError();
    $('summary').hidden = true;
    const scenes = state.scenes.filter((s) => state.checked.has(s.index)).map((s) => s.index);
    const existing = document.querySelector('input[name=existing]:checked');
    setRunning(true);
    $('progress-wrap').hidden = false;
    $('bar').style.width = '0';
    $('status').textContent = t('starting');
    call('start', {
      settings: formSettings(),
      pattern: $('pattern').value,
      existing: existing ? existing.value : 'suffix',
      scenes,
      directory: $('directory').value,
    });
  }

  function showError(msg) {
    $('error').textContent = msg;
    $('error').hidden = false;
  }

  function hideError() { $('error').hidden = true; }

  function esc(s) {
    return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  }

  // --- API for Ruby ----------------------------------------------------

  window.JV = {
    state(s) {
      if (s.lang && s.lang !== I18N.lang) {
        I18N.lang = s.lang;
        I18N.apply();
        renderChips();
      }
      state.presets = s.presets;
      state.activeId = s.activePresetId;
      state.viewport = s.viewport;
      state.scenes = s.scenes;
      state.checked = new Set(s.scenes.map((x) => x.index));
      renderPresetSelect();
      loadForm(activePreset());
      $('pattern').value = s.pattern || `{nr}_{${I18N.placeholders()[1]}}`;
      const ex = document.querySelector(`input[name=existing][value=${s.existing === 'overwrite' ? 'overwrite' : 'suffix'}]`);
      if (ex) ex.checked = true;
      $('directory').value = s.directory || '';
      $('version').textContent = s.version ? `v${s.version}` : '';
      JV.frameState(s.frame);
      renderScenes();
      requestPreview();
    },
    presets(s) {
      state.presets = s.presets;
      state.activeId = s.activePresetId;
      renderPresetSelect();
      loadForm(activePreset());
      requestPreview();
    },
    preview(p) { $('preview').textContent = p.text; },
    dir(p) { $('directory').value = p.path; },
    frameState(f) {
      $('frame').checked = !!f.enabled;
      $('frame').disabled = !f.supported;
      $('frame-wrap').title = f.supported ? '' : t('frameUnsupported');
      $('frame_opacity').disabled = !f.supported;
      if (f.opacity !== undefined) {
        $('frame_opacity').value = f.opacity;
        $('frame_opacity-val').textContent = `${f.opacity} %`;
      }
    },
    progress(p) {
      const pct = p.total ? Math.round((p.done / p.total) * 100) : 0;
      $('bar').style.width = `${pct}%`;
      $('status').textContent = t('progress', { n: p.done + 1, total: p.total, scene: p.scene });
    },
    finished(r) {
      setRunning(false);
      $('bar').style.width = r.cancelled ? $('bar').style.width : '100%';
      $('status').textContent = r.cancelled ? t('cancelled') : t('done');
      const errors = r.results.filter((x) => !x.ok);
      let html = '<p>' + t('summary', { ok: r.ok, total: r.total, seconds: r.seconds,
                                        cancelled: r.cancelled ? t('summaryCancelled') : '' }) + '</p>' +
                 `<p class="lbl">${esc(r.directory)}</p>`;
      if (errors.length) {
        html += '<ul>' + errors.map((e) => `<li>${esc(e.scene)}: ${esc(e.error)}</li>`).join('') + '</ul>';
      }
      html += `<div class="actions"><button type="button" id="btn-open">${esc(t('openFolder'))}</button></div>`;
      $('summary').innerHTML = html;
      $('summary').hidden = false;
      $('btn-open').addEventListener('click', () => call('openFolder', { path: r.directory }));
    },
    error(e) {
      if (state.running) setRunning(false);
      showError(e.message);
    },
  };

  // --- wiring ----------------------------------------------------------

  function init() {
    I18N.apply();
    renderChips();
    $('preset').addEventListener('change', (e) => {
      state.activeId = e.target.value;
      loadForm(activePreset());
      call('selectPreset', { id: state.activeId });
      requestPreview();
    });
    FIELDS.forEach((f) => {
      const el = $(f);
      el.addEventListener('input', onFieldChange);
      el.addEventListener('change', onFieldChange);
    });
    $('btn-save').addEventListener('click', () => {
      readForm();
      call('savePreset', { settings: Object.assign(formSettings(), { id: state.activeId }) });
    });
    $('btn-save-as').addEventListener('click', () => { readForm(); call('saveAsPreset', { settings: formSettings() }); });
    $('btn-rename').addEventListener('click', () => call('renamePreset', { id: state.activeId }));
    $('btn-delete').addEventListener('click', () => call('deletePreset', { id: state.activeId }));
    $('frame').addEventListener('change', (e) => call('toggleFrame', { enabled: e.target.checked }));
    const sendOpacity = debounce((v) => call('frameOpacity', { opacity: v }), 60);
    $('frame_opacity').addEventListener('input', (e) => {
      const v = parseInt(e.target.value, 10);
      $('frame_opacity-val').textContent = `${v} %`;
      sendOpacity(v);
    });
    $('pattern').addEventListener('input', requestPreview);
    $('sc-all').addEventListener('click', () => setChecked(() => true));
    $('sc-none').addEventListener('click', () => setChecked(() => false));
    $('sc-anim').addEventListener('click', () => setChecked((s) => s.animation));
    $('btn-dir').addEventListener('click', () => call('chooseDir'));
    // Open in the system browser, not inside the dialog.
    $('credit-link').addEventListener('click', (e) => {
      e.preventDefault();
      call('openUrl', { url: e.currentTarget.href });
    });
    $('btn-start').addEventListener('click', startExport);
    $('btn-cancel').addEventListener('click', () => {
      $('btn-cancel').disabled = true;
      $('status').textContent = t('cancelling');
      call('cancel');
    });
    call('ready');
  }

  // Browser preview without SketchUp: load the mock if present.
  if (!window.sketchup && /[?&]mock\b/.test(location.search)) {
    const s = document.createElement('script');
    s.src = 'dev_mock.js';
    s.onload = init;
    document.head.appendChild(s);
  } else {
    document.addEventListener('DOMContentLoaded', init);
    if (document.readyState !== 'loading') init();
  }
})();
