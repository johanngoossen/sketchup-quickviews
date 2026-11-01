/* Development only (not packaged): fakes the Ruby side so the dialog can be
   opened in a browser as dialog.html?mock (or ?mock&lang=de). */
(function () {
  'use strict';
  const lang = (/[?&]lang=(\w+)/.exec(location.search) || [])[1] === 'de' ? 'de' : 'en';
  const de = lang === 'de';
  const base = { format: 'png', jpg_quality: 90, antialias: true, transparent: false, line_scale: 1, builtin: true, viewport: false };
  const presets = [
    ['viewport', de ? 'Viewport (aktuelle Fenstergröße)' : 'Viewport (current window size)', null, null], ['hd', 'HD', 1280, 720],
    ['full_hd', 'Full HD', 1920, 1080], ['uhd_4k', '4K UHD', 3840, 2160],
    ['a4_landscape', de ? 'A4 quer, 300 dpi' : 'A4 landscape, 300 dpi', 3508, 2480],
    ['a4_portrait', de ? 'A4 hoch, 300 dpi' : 'A4 portrait, 300 dpi', 2480, 3508],
    ['a3_landscape', de ? 'A3 quer, 300 dpi' : 'A3 landscape, 300 dpi', 4961, 3508], ['square', de ? 'Quadrat' : 'Square', 2048, 2048],
    ['social_4x5', 'Social 4:5', 1080, 1350], ['social_story', 'Social Story 9:16', 1080, 1920],
  ].map(([id, name, width, height]) => Object.assign({}, base, { id, name, width, height, viewport: id === 'viewport' }));
  presets.push(Object.assign({}, base, { id: 'user_1', name: de ? 'Wettbewerb' : 'Competition', width: 3000, height: 2000, builtin: false, format: 'jpg' }));

  const sceneNames = de
    ? ['Lageplan', 'Ansicht Nord', 'Ansicht Süd', 'Perspektive Eingang', 'Detail: Fassade', 'Arbeitsstand']
    : ['Site plan', 'North elevation', 'South elevation', 'Entrance perspective', 'Detail: facade', 'Work in progress'];
  const scenes = sceneNames.map((name, index) => ({ index, name, animation: index !== 5 }));
  const model = de ? 'Haus am See' : 'Lake House';

  const later = (fn) => setTimeout(fn, 30);
  let timer = null;

  window.JVMock = function (name, data) {
    switch (name) {
      case 'ready':
        later(() => JV.state({
          presets, activePresetId: 'full_hd', scenes, pattern: de ? '{nr}_{szene}' : '{nr}_{scene}', existing: 'suffix',
          directory: '/Users/demo/Exports', model, viewport: [1600, 1000],
          frame: { enabled: true, supported: true, opacity: 55 }, version: '0.1.0', lang,
        }));
        break;
      case 'preview': {
        const s = scenes[data.sceneIndex] || scenes[0];
        const nr = String(s.index + 1).padStart(2, '0');
        const text = (data.pattern || '{nr}_{scene}').replace('{nr}', nr).replace(/\{(scene|szene)\}/, s.name)
          .replace(/\{(model|modell)\}/, model).replace(/[/\\:*?"<>|]/g, '_');
        later(() => JV.preview({ text: `${text}.${data.settings.format}` }));
        break;
      }
      case 'start': {
        let i = 0;
        const list = data.scenes;
        timer = setInterval(() => {
          if (i >= list.length) {
            clearInterval(timer);
            JV.finished({ cancelled: false, total: list.length, ok: list.length - 1, directory: data.directory, seconds: 2.4,
              results: [{ scene: scenes[4].name, ok: false,
                          error: de ? 'write_image ist fehlgeschlagen (Auflösung für die Grafikkarte zu hoch?)'
                                    : 'write_image failed (resolution too high for the graphics card?)' }] });
            return;
          }
          JV.progress({ done: i, total: list.length, scene: scenes[list[i]].name });
          i += 1;
        }, 400);
        break;
      }
      case 'cancel':
        clearInterval(timer);
        later(() => JV.finished({ cancelled: true, total: 6, ok: 2, directory: '/Users/demo/Exports', seconds: 0.9, results: [] }));
        break;
      default:
        console.log('JVMock', name, data);
    }
  };
})();
