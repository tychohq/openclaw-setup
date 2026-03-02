import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { readFileSync } from 'fs';
import { GlobalRegistrator } from '@happy-dom/global-registrator';

GlobalRegistrator.register();

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

describe('downloadBundle integration', () => {
  test('includes allowBundled sorted when skills selected', () => {
    (globalThis as any).state.bundledSelected.add('slack');
    (globalThis as any).state.bundledSelected.add('discord');
    (globalThis as any).state.bundledSelected.add('github');

    let capturedJson = '';
    const origBlob = globalThis.Blob;
    (globalThis as any).Blob = class { constructor(parts: string[]) { capturedJson = parts[0]; } };
    const origURL = globalThis.URL;
    (globalThis as any).URL = { createObjectURL: () => '#', revokeObjectURL: () => {} };

    (globalThis as any).downloadBundle();
    const bundle = JSON.parse(capturedJson);

    expect(bundle.manifest.selectedBundledSkills).toEqual(
      expect.arrayContaining(['discord', 'slack', 'github'])
    );
    expect(bundle.allowBundled).toEqual(['discord', 'github', 'slack']);

    globalThis.Blob = origBlob;
    (globalThis as any).URL = origURL;
  });

  test('omits allowBundled when none selected', () => {
    let capturedJson = '';
    const origBlob = globalThis.Blob;
    (globalThis as any).Blob = class { constructor(parts: string[]) { capturedJson = parts[0]; } };
    const origURL = globalThis.URL;
    (globalThis as any).URL = { createObjectURL: () => '#', revokeObjectURL: () => {} };

    (globalThis as any).downloadBundle();
    const bundle = JSON.parse(capturedJson);

    expect(bundle.allowBundled).toBeUndefined();

    globalThis.Blob = origBlob;
    (globalThis as any).URL = origURL;
  });
});
