import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { readFileSync } from 'fs';
import { GlobalRegistrator } from '@happy-dom/global-registrator';

GlobalRegistrator.register();

// Stub JSZip before evaluating the script
(globalThis as any).JSZip = class {
  _files: Record<string, string> = {};
  file(name: string, content: string) { this._files[name] = content; }
  async generateAsync() { return new Blob(['zip-content']); }
};

const htmlSource = readFileSync(new URL('./index.html', import.meta.url), 'utf-8');

// Extract just the <script> block content
const scriptMatch = htmlSource.match(/<script>\n\/\/ ── State ──[\s\S]*?<\/script>/);
if (!scriptMatch) throw new Error('Could not extract script block from index.html');
const scriptContent = scriptMatch[0].replace(/<\/?script>/g, '');

function setupEnv() {
  // Set up minimal DOM structure
  document.body.innerHTML = `
    <div id="mode-badge"></div>
    <button id="tab-patches"></button>
    <button id="tab-cron"></button>
    <button id="tab-skills"></button>
    <button id="tab-bundled"></button>
    <div id="panel-patches"></div>
    <div id="panel-cron" class="hidden"></div>
    <div id="panel-skills" class="hidden"></div>
    <div id="panel-bundled" class="hidden"></div>
    <div id="patch-grid"></div>
    <div id="cron-grid"></div>
    <div id="skills-grid"></div>
    <div id="bundled-grid"></div>
    <div id="bundled-count"></div>
    <div id="download-bar" class="translate-y-full"></div>
    <span id="selected-count"></span>
    <div id="loading"></div>
    <div id="cron-loading"></div>
    <div id="skills-loading"></div>
  `;

  // Stub globals
  (globalThis as any).jsyaml = { load: (t: string) => t };
  const origFetch = globalThis.fetch;
  (globalThis as any).fetch = () => Promise.resolve({ ok: false, status: 404 });

  // Remove init() call and fix URL params for test env
  const safeScript = scriptContent
    .replace(/\binit\(\);/, '// init() removed')
    .replace(/^const params = .*$/m, 'const params = new URLSearchParams("");')
    .replace(/^const LOCAL = .*$/m, 'const LOCAL = true;');

  // Wrap in a function that exposes everything on globalThis
  // We change `const` to `var` at the top level so they're accessible globally
  const globalized = safeScript
    .replace(/^const /gm, 'var ')
    .replace(/^function /gm, 'globalThis.__fn__ = function ')
    .replace(/^let /gm, 'var ');

  // Replace top-level declarations with globalThis assignments
  // and function declarations with globalThis.fn = function
  const evalScript = safeScript
    .replace(/^(const|let|var) (\w+)/gm, 'globalThis.$2')
    .replace(/^function (\w+)/gm, 'globalThis.$1 = function $1')
    .replace(/^async function (\w+)/gm, 'globalThis.$1 = async function $1');
  new Function(evalScript)();

  return () => {
    (globalThis as any).fetch = origFetch;
  };
}

let cleanup: () => void;

beforeEach(() => {
  cleanup = setupEnv();
});

afterEach(() => {
  cleanup();
  document.body.innerHTML = '';
});

describe('BUNDLED_SKILLS list', () => {
  test('contains exactly 52 skills', () => {
    expect((globalThis as any).BUNDLED_SKILLS).toHaveLength(52);
  });

  test('is sorted alphabetically', () => {
    const skills = (globalThis as any).BUNDLED_SKILLS as string[];
    const sorted = [...skills].sort();
    expect(skills).toEqual(sorted);
  });

  test('contains expected skills', () => {
    const skills = (globalThis as any).BUNDLED_SKILLS as string[];
    for (const name of ['1password', 'discord', 'github', 'slack', 'tmux', 'weather', 'xurl']) {
      expect(skills).toContain(name);
    }
  });

  test('has no duplicates', () => {
    const skills = (globalThis as any).BUNDLED_SKILLS as string[];
    expect(new Set(skills).size).toBe(skills.length);
  });
});

describe('Bundled Skills tab - HTML structure', () => {
  test('tab button exists in source HTML', () => {
    expect(htmlSource).toContain('id="tab-bundled"');
    expect(htmlSource).toContain('Bundled Skills');
  });

  test('panel exists in source HTML', () => {
    expect(htmlSource).toContain('id="panel-bundled"');
  });

  test('bundled grid exists in source HTML', () => {
    expect(htmlSource).toContain('id="bundled-grid"');
  });

  test('select all / deselect all buttons exist', () => {
    expect(htmlSource).toContain('selectAllBundled()');
    expect(htmlSource).toContain('deselectAllBundled()');
  });
});

describe('renderAllBundled', () => {
  test('renders 52 cards into the grid', () => {
    (globalThis as any).renderAllBundled();
    const grid = document.getElementById('bundled-grid')!;
    expect(grid.children.length).toBe(52);
  });

  test('each card has an unchecked checkbox by default', () => {
    (globalThis as any).renderAllBundled();
    const checkboxes = document.querySelectorAll('#bundled-grid input[type="checkbox"]');
    expect(checkboxes.length).toBe(52);
    for (const cb of checkboxes) {
      expect((cb as HTMLInputElement).checked).toBe(false);
    }
  });

  test('card shows skill name', () => {
    (globalThis as any).renderAllBundled();
    const card = document.getElementById('bundled-discord');
    expect(card).not.toBeNull();
    expect(card!.textContent).toContain('discord');
  });
});

describe('toggleBundledSelect', () => {
  test('selects and deselects a skill', () => {
    (globalThis as any).renderAllBundled();

    (globalThis as any).toggleBundledSelect('discord');
    expect((globalThis as any).state.bundledSelected.has('discord')).toBe(true);

    (globalThis as any).toggleBundledSelect('discord');
    expect((globalThis as any).state.bundledSelected.has('discord')).toBe(false);
  });

  test('updates checkbox state', () => {
    (globalThis as any).renderAllBundled();

    (globalThis as any).toggleBundledSelect('slack');
    const card = document.getElementById('bundled-slack')!;
    const cb = card.querySelector('input[type="checkbox"]') as HTMLInputElement;
    expect(cb.checked).toBe(true);

    (globalThis as any).toggleBundledSelect('slack');
    expect(cb.checked).toBe(false);
  });
});

describe('selectAllBundled / deselectAllBundled', () => {
  test('selectAllBundled selects all 52', () => {
    (globalThis as any).renderAllBundled();
    (globalThis as any).selectAllBundled();
    expect((globalThis as any).state.bundledSelected.size).toBe(52);
  });

  test('deselectAllBundled clears all', () => {
    (globalThis as any).renderAllBundled();
    (globalThis as any).selectAllBundled();
    (globalThis as any).deselectAllBundled();
    expect((globalThis as any).state.bundledSelected.size).toBe(0);
  });

  test('selectAll checks all checkboxes in DOM', () => {
    (globalThis as any).renderAllBundled();
    (globalThis as any).selectAllBundled();
    const checkboxes = document.querySelectorAll('#bundled-grid input[type="checkbox"]');
    for (const cb of checkboxes) {
      expect((cb as HTMLInputElement).checked).toBe(true);
    }
  });
});

describe('switchTab', () => {
  test('shows bundled panel and hides others', () => {
    (globalThis as any).switchTab('bundled');

    expect(document.getElementById('panel-bundled')!.classList.contains('hidden')).toBe(false);
    expect(document.getElementById('panel-patches')!.classList.contains('hidden')).toBe(true);
    expect(document.getElementById('panel-cron')!.classList.contains('hidden')).toBe(true);
    expect(document.getElementById('panel-skills')!.classList.contains('hidden')).toBe(true);
  });

  test('activates bundled tab button', () => {
    (globalThis as any).switchTab('bundled');

    expect(document.getElementById('tab-bundled')!.className).toContain('tab-active');
    expect(document.getElementById('tab-patches')!.className).toContain('tab-inactive');
  });
});

describe('updateDownloadBar', () => {
  test('shows bundled count in download bar', () => {
    (globalThis as any).renderAllBundled();
    (globalThis as any).toggleBundledSelect('discord');
    (globalThis as any).toggleBundledSelect('slack');

    const countEl = document.getElementById('selected-count')!;
    expect(countEl.textContent).toContain('2 bundled skills');
  });

  test('hides bar when nothing selected', () => {
    (globalThis as any).updateDownloadBar();
    const bar = document.getElementById('download-bar')!;
    expect(bar.classList.contains('translate-y-full')).toBe(true);
  });

  test('shows bar when bundled selected', () => {
    (globalThis as any).renderAllBundled();
    (globalThis as any).toggleBundledSelect('tmux');
    const bar = document.getElementById('download-bar')!;
    expect(bar.classList.contains('translate-y-full')).toBe(false);
  });
});

describe('buildBundleFiles', () => {
  test('returns three file entries', () => {
    const files = (globalThis as any).buildBundleFiles();
    expect(Object.keys(files)).toEqual(['config-bundle.json', 'cron-selections.json', 'skills-list.json']);
  });

  test('config-bundle.json includes allowBundled sorted when bundled selected', () => {
    (globalThis as any).state.bundledSelected.add('slack');
    (globalThis as any).state.bundledSelected.add('discord');
    (globalThis as any).state.bundledSelected.add('github');

    const files = (globalThis as any).buildBundleFiles();
    const config = JSON.parse(files['config-bundle.json']);

    expect(config.manifest.selectedBundledSkills).toEqual(
      expect.arrayContaining(['discord', 'slack', 'github'])
    );
    expect(config.allowBundled).toEqual(['discord', 'github', 'slack']);
  });

  test('config-bundle.json omits allowBundled when none selected', () => {
    const files = (globalThis as any).buildBundleFiles();
    const config = JSON.parse(files['config-bundle.json']);
    expect(config.allowBundled).toBeUndefined();
  });

  test('config-bundle.json includes patches and configs', () => {
    (globalThis as any).state.patches = [
      { id: 'test-patch', description: 'test', steps: [{ type: 'config_patch', merge_file: 'test.json' }] },
    ];
    (globalThis as any).state.selected.add('test-patch');
    (globalThis as any).state.configs['test-patch-0'] = { key: 'value' };

    const files = (globalThis as any).buildBundleFiles();
    const config = JSON.parse(files['config-bundle.json']);
    expect(config.patches).toHaveLength(1);
    expect(config.patches[0].id).toBe('test-patch');
    expect(config.configs['test.json']).toEqual({ key: 'value' });
  });

  test('cron-selections.json includes selected cron jobs', () => {
    (globalThis as any).state.cronJobs = [
      { name: 'job-a', schedule: { expr: '0 9 * * *' }, payload: { message: 'hi' } },
      { name: 'job-b', schedule: { expr: '0 12 * * *' }, payload: { message: 'hello' } },
    ];
    (globalThis as any).state.cronSelected.add('job-a');

    const files = (globalThis as any).buildBundleFiles();
    const crons = JSON.parse(files['cron-selections.json']);
    expect(crons).toHaveLength(1);
    expect(crons[0].name).toBe('job-a');
  });

  test('skills-list.json includes selected skill info', () => {
    (globalThis as any).state.skills = [
      { slug: 'my-skill', displayName: 'My Skill', summary: 'desc', latestVersion: { version: '1.0.0' } },
    ];
    (globalThis as any).state.skillsSelected.add('my-skill');

    const files = (globalThis as any).buildBundleFiles();
    const skills = JSON.parse(files['skills-list.json']);
    expect(skills).toHaveLength(1);
    expect(skills[0].slug).toBe('my-skill');
    expect(skills[0].displayName).toBe('My Skill');
  });
});

describe('downloadBundle routing', () => {
  test('uses showDirectoryPicker when available', async () => {
    let pickerCalled = false;
    const writtenFiles: Record<string, string> = {};

    (globalThis as any).window.showDirectoryPicker = async () => {
      pickerCalled = true;
      return {
        getFileHandle: async (name: string) => ({
          createWritable: async () => ({
            write: async (content: string) => { writtenFiles[name] = content; },
            close: async () => {},
          }),
        }),
      };
    };

    await (globalThis as any).downloadBundle();
    expect(pickerCalled).toBe(true);
    expect(Object.keys(writtenFiles)).toEqual(['config-bundle.json', 'cron-selections.json', 'skills-list.json']);

    delete (globalThis as any).window.showDirectoryPicker;
  });

  test('falls back to zip when showDirectoryPicker unavailable', async () => {
    delete (globalThis as any).window.showDirectoryPicker;

    let downloadTriggered = false;
    const origURL = globalThis.URL;
    (globalThis as any).URL = {
      createObjectURL: () => '#',
      revokeObjectURL: () => {},
    };
    const origCreateElement = document.createElement.bind(document);
    document.createElement = ((tag: string) => {
      const el = origCreateElement(tag);
      if (tag === 'a') {
        el.click = () => { downloadTriggered = true; };
      }
      return el;
    }) as typeof document.createElement;

    await (globalThis as any).downloadBundle();
    expect(downloadTriggered).toBe(true);

    (globalThis as any).URL = origURL;
    document.createElement = origCreateElement;
  });

  test('handles AbortError silently when user cancels picker', async () => {
    const abortErr = new DOMException('User cancelled', 'AbortError');
    (globalThis as any).window.showDirectoryPicker = async () => { throw abortErr; };

    // Should not throw
    await (globalThis as any).downloadBundle();

    delete (globalThis as any).window.showDirectoryPicker;
  });
});
