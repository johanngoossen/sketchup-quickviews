/* Quick Views dialog texts. The language comes from Ruby (state.lang, same
   as SketchUp's language); until then the browser language is used.
   Static texts: data-i18n (text), data-i18n-title, data-i18n-placeholder. */
(function () {
  'use strict';

  const STRINGS = {
    en: {
      preset: 'Preset',
      save: 'Save',
      saveTip: 'Save changes to your own preset',
      saveAs: 'Save as new …',
      saveAsTip: 'Save the current values as a new preset',
      rename: 'Rename …',
      delete: 'Delete',
      width: 'Width',
      height: 'Height',
      ratio: 'Ratio',
      format: 'Format',
      jpgQuality: 'JPG quality',
      lineScale: 'Line scale',
      lineScaleTip: 'Scales line widths and text (write_image :scale_factor)',
      antialias: 'Anti-aliasing',
      transparent: 'Transparent background',
      frame: 'Frame preview in viewport',
      frameUnsupported: 'Requires SketchUp 2023 or newer (Sketchup::Overlay).',
      coverOutside: 'Shade outside',
      fileName: 'File name',
      patternLabel: 'File name pattern',
      previewLabel: 'Preview:',
      existingFiles: 'Existing files',
      suffix: 'Add suffix',
      overwrite: 'Overwrite',
      scenes: 'Scenes',
      all: 'All',
      none: 'None',
      animOnly: 'Animation only',
      animOnlyTip: 'Only scenes with “Include in animation”',
      outputFolder: 'Output folder',
      noFolder: 'No folder chosen yet',
      choose: 'Choose …',
      cancel: 'Cancel',
      start: 'Start export',
      groupBuiltin: 'Built-in',
      groupOwn: 'My presets',
      hintBuiltinDirty: 'Built-in preset changed – the export uses the values above. Use “Save as new” to keep them.',
      hintBuiltin: 'Built-in preset (read-only, but you can save a copy).',
      hintDirty: 'Unsaved changes.',
      noScenes: 'This model has no scenes.',
      notInAnim: 'not in animation',
      sceneCount: '({n} of {total})',
      starting: 'Starting …',
      progress: '{n} of {total}: {scene}',
      cancelled: 'Cancelled.',
      done: 'Done.',
      summary: '<strong>{ok} of {total}</strong> images exported{cancelled} in {seconds} s.',
      summaryCancelled: ' (cancelled)',
      openFolder: 'Open folder',
      cancelling: 'Cancelling after the current scene …',
      landscape: 'landscape',
      portrait: 'portrait',
    },
    de: {
      preset: 'Preset',
      save: 'Speichern',
      saveTip: 'Änderungen im eigenen Preset speichern',
      saveAs: 'Als neues Preset …',
      saveAsTip: 'Aktuelle Werte als neues Preset speichern',
      rename: 'Umbenennen …',
      delete: 'Löschen',
      width: 'Breite',
      height: 'Höhe',
      ratio: 'Verhältnis',
      format: 'Format',
      jpgQuality: 'JPG-Qualität',
      lineScale: 'Linienskalierung',
      lineScaleTip: 'Skaliert Linienstärken und Text (write_image :scale_factor)',
      antialias: 'Antialiasing',
      transparent: 'Transparenter Hintergrund',
      frame: 'Rahmenvorschau im Viewport',
      frameUnsupported: 'Benötigt SketchUp 2023 oder neuer (Sketchup::Overlay).',
      coverOutside: 'Abdeckung außerhalb',
      fileName: 'Dateiname',
      patternLabel: 'Dateinamen-Muster',
      previewLabel: 'Vorschau:',
      existingFiles: 'Vorhandene Dateien',
      suffix: 'Suffix anhängen',
      overwrite: 'Überschreiben',
      scenes: 'Szenen',
      all: 'Alle',
      none: 'Keine',
      animOnly: 'Nur Animation',
      animOnlyTip: 'Nur Szenen mit „In Animation einbeziehen“',
      outputFolder: 'Ausgabeordner',
      noFolder: 'Noch kein Ordner gewählt',
      choose: 'Wählen …',
      cancel: 'Abbrechen',
      start: 'Export starten',
      groupBuiltin: 'Eingebaut',
      groupOwn: 'Eigene',
      hintBuiltinDirty: 'Eingebautes Preset geändert – für den Export gelten die Werte oben. Zum Behalten „Als neues Preset“ speichern.',
      hintBuiltin: 'Eingebautes Preset (nicht änderbar, aber als Kopie anpassbar).',
      hintDirty: 'Ungespeicherte Änderungen.',
      noScenes: 'Dieses Modell hat keine Szenen.',
      notInAnim: 'nicht in Animation',
      sceneCount: '({n} von {total})',
      starting: 'Starte …',
      progress: '{n} von {total}: {scene}',
      cancelled: 'Abgebrochen.',
      done: 'Fertig.',
      summary: '<strong>{ok} von {total}</strong> Bildern exportiert{cancelled} in {seconds} s.',
      summaryCancelled: ' (abgebrochen)',
      openFolder: 'Ordner öffnen',
      cancelling: 'Breche nach der aktuellen Szene ab …',
      landscape: 'quer',
      portrait: 'hoch',
    },
  };

  // Placeholder names shown as chips; Ruby understands both languages.
  const PLACEHOLDERS = {
    en: ['nr', 'scene', 'model', 'date', 'time', 'preset', 'width', 'height'],
    de: ['nr', 'szene', 'modell', 'datum', 'zeit', 'preset', 'breite', 'hoehe'],
  };

  let lang = /^de\b/i.test(navigator.language || '') ? 'de' : 'en';

  function t(key, vars) {
    const s = (STRINGS[lang] && STRINGS[lang][key]) || STRINGS.en[key] || key;
    return s.replace(/\{(\w+)\}/g, (m, k) => (vars && k in vars ? String(vars[k]) : m));
  }

  function apply(root) {
    document.documentElement.lang = lang;
    (root || document).querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    (root || document).querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
    (root || document).querySelectorAll('[data-i18n-placeholder]').forEach((el) => { el.placeholder = t(el.dataset.i18nPlaceholder); });
  }

  window.I18N = {
    t,
    apply,
    get lang() { return lang; },
    set lang(value) { lang = value === 'de' ? 'de' : 'en'; },
    placeholders() { return PLACEHOLDERS[lang]; },
  };
})();
