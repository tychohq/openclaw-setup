import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { readFileSync } from 'fs';
import { GlobalRegistrator } from '@happy-dom/global-registrator';

try { GlobalRegistrator.register(); } catch { /* already registered */ }

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
    <div id="cron-readme" class="hidden"></div>
    <div id="skills-grid"></div>
    <div id="bundled-grid"></div>
    <div id="bundled-count"></div>
    <div id="download-bar" class="translate-y-full"></div>
    <span id="selected-count"></span>
    <div id="loading"></div>
    <div id="cron-loading"></div>
    <div id="skills-loading"></div>
    <select id="cron-tz"><option value="America/New_York">America/New_York</option><option value="UTC">UTC</option></select>
    <input type="radio" name="cron-delivery" value="none" checked />
    <input type="text" id="cron-channel-id" class="hidden" />
    <select id="cron-model"><option value="">Default</option><option value="anthropic/claude-opus-4-6">Opus</option></select>
  `;

  (globalThis as any).jsyaml = { load: (t: string) => t };
  const origFetch = globalThis.fetch;
  (globalThis as any).fetch = () => Promise.resolve({ ok: false, status: 404 });

  const safeScript = scriptContent
    .replace(/\binit\(\);/, '// init() removed')
    .replace(/^const params = .*$/m, 'const params = new URLSearchParams("");')
    .replace(/^const LOCAL = .*$/m, 'const LOCAL = true;');

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

// ── Sample cron job fixtures ──
function makeCronJob(overrides: Record<string, any> = {}) {
  return {
    name: 'test-job',
    description: 'A test cron job.',
    enabled: true,
    requires: { skills: ['test-skill'] },
    schedule: { kind: 'cron', expr: '0 * * * *', tz: 'America/New_York' },
    sessionTarget: 'isolated',
    payload: { kind: 'agentTurn', message: 'Do the thing.\nLine 2.', timeoutSeconds: 120 },
    delivery: { mode: 'none' },
    ...overrides,
  };
}

// ── HTML structure ──
describe('Cron Jobs tab - HTML structure', () => {
  test('tab button exists in source HTML', () => {
    expect(htmlSource).toContain('id="tab-cron"');
    expect(htmlSource).toContain('Cron Jobs');
  });

  test('panel exists in source HTML', () => {
    expect(htmlSource).toContain('id="panel-cron"');
  });

  test('cron grid exists in source HTML', () => {
    expect(htmlSource).toContain('id="cron-grid"');
  });

  test('cron-readme element exists in source HTML', () => {
    expect(htmlSource).toContain('id="cron-readme"');
  });

  test('select all / deselect all buttons exist', () => {
    expect(htmlSource).toContain('selectAllCron()');
    expect(htmlSource).toContain('deselectAllCron()');
  });

  test('settings bar exists with timezone, delivery, model', () => {
    expect(htmlSource).toContain('id="cron-tz"');
    expect(htmlSource).toContain('name="cron-delivery"');
    expect(htmlSource).toContain('id="cron-model"');
  });
});

// ── renderCronReadme ──
describe('renderCronReadme', () => {
  test('renders first paragraph after heading', () => {
    const md = '# Cron Job Templates\n\nReady-to-use cron job definitions for OpenClaw.\n\n## How to Install\n';
    (globalThis as any).renderCronReadme(md);
    const el = document.getElementById('cron-readme')!;
    expect(el.textContent).toBe('Ready-to-use cron job definitions for OpenClaw.');
    expect(el.classList.contains('hidden')).toBe(false);
  });

  test('stays hidden when markdown is null', () => {
    (globalThis as any).renderCronReadme(null);
    const el = document.getElementById('cron-readme')!;
    expect(el.classList.contains('hidden')).toBe(true);
  });

  test('stays hidden when no intro paragraph found', () => {
    (globalThis as any).renderCronReadme('## Only subheadings\n\nSome text.');
    const el = document.getElementById('cron-readme')!;
    expect(el.classList.contains('hidden')).toBe(true);
  });

  test('stops at next heading', () => {
    const md = '# Title\n\nFirst paragraph.\n\n## Section\n\nSecond paragraph.';
    (globalThis as any).renderCronReadme(md);
    const el = document.getElementById('cron-readme')!;
    expect(el.textContent).toBe('First paragraph.');
  });
});

// ── renderAllCronJobs ──
describe('renderAllCronJobs', () => {
  test('renders cards for each cron job', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'job-a' }),
      makeCronJob({ name: 'job-b' }),
    ];
    (globalThis as any).renderAllCronJobs();
    const grid = document.getElementById('cron-grid')!;
    expect(grid.children.length).toBe(2);
  });

  test('each card has an unchecked checkbox by default', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'my-job' })];
    (globalThis as any).renderAllCronJobs();
    const checkboxes = document.querySelectorAll('#cron-grid input[type="checkbox"]');
    expect(checkboxes.length).toBe(1);
    expect((checkboxes[0] as HTMLInputElement).checked).toBe(false);
  });

  test('card displays humanized name', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'daily-workspace-commit' })];
    (globalThis as any).renderAllCronJobs();
    const card = document.getElementById('cron-daily-workspace-commit')!;
    expect(card.textContent).toContain('Daily Workspace Commit');
  });

  test('card displays description', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'my-job', description: 'Does a thing' })];
    (globalThis as any).renderAllCronJobs();
    const card = document.getElementById('cron-my-job')!;
    expect(card.textContent).toContain('Does a thing');
  });

  test('card shows schedule badge', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'hourly-job', schedule: { kind: 'cron', expr: '0 * * * *', tz: 'UTC' } })];
    (globalThis as any).renderAllCronJobs();
    const card = document.getElementById('cron-hourly-job')!;
    expect(card.textContent).toContain('Every hour');
  });

  test('card shows requires badges', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'skill-job', requires: { skills: ['self-reflection'], scripts: ['health.sh'] } })];
    (globalThis as any).renderAllCronJobs();
    const card = document.getElementById('cron-skill-job')!;
    expect(card.textContent).toContain('skill: self-reflection');
    expect(card.textContent).toContain('script: health.sh');
  });
});

// ── toggleCronSelect ──
describe('toggleCronSelect', () => {
  test('selects and deselects a cron job', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'toggle-job' })];
    (globalThis as any).renderAllCronJobs();

    (globalThis as any).toggleCronSelect('toggle-job');
    expect((globalThis as any).state.cronSelected.has('toggle-job')).toBe(true);

    (globalThis as any).toggleCronSelect('toggle-job');
    expect((globalThis as any).state.cronSelected.has('toggle-job')).toBe(false);
  });

  test('updates checkbox state', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'cb-job' })];
    (globalThis as any).renderAllCronJobs();

    (globalThis as any).toggleCronSelect('cb-job');
    const card = document.getElementById('cron-cb-job')!;
    const cb = card.querySelector('input[type="checkbox"]') as HTMLInputElement;
    expect(cb.checked).toBe(true);

    (globalThis as any).toggleCronSelect('cb-job');
    expect(cb.checked).toBe(false);
  });
});

// ── selectAllCron / deselectAllCron ──
describe('selectAllCron / deselectAllCron', () => {
  test('selectAllCron selects all jobs', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'a' }),
      makeCronJob({ name: 'b' }),
      makeCronJob({ name: 'c' }),
    ];
    (globalThis as any).renderAllCronJobs();
    (globalThis as any).selectAllCron();
    expect((globalThis as any).state.cronSelected.size).toBe(3);
  });

  test('deselectAllCron clears all', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'a' }),
      makeCronJob({ name: 'b' }),
    ];
    (globalThis as any).renderAllCronJobs();
    (globalThis as any).selectAllCron();
    (globalThis as any).deselectAllCron();
    expect((globalThis as any).state.cronSelected.size).toBe(0);
  });

  test('selectAll checks all checkboxes in DOM', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'x' }),
      makeCronJob({ name: 'y' }),
    ];
    (globalThis as any).renderAllCronJobs();
    (globalThis as any).selectAllCron();
    const checkboxes = document.querySelectorAll('#cron-grid input[type="checkbox"]');
    for (const cb of checkboxes) {
      expect((cb as HTMLInputElement).checked).toBe(true);
    }
  });
});

// ── humanizeSchedule ──
describe('humanizeSchedule', () => {
  test('hourly', () => {
    expect((globalThis as any).humanizeSchedule('0 * * * *')).toBe('Every hour');
  });

  test('every N hours', () => {
    expect((globalThis as any).humanizeSchedule('0 */6 * * *')).toBe('Every 6h');
  });

  test('daily at specific hour (AM)', () => {
    expect((globalThis as any).humanizeSchedule('0 4 * * *')).toBe('Daily 4 AM');
  });

  test('daily at specific hour (PM)', () => {
    expect((globalThis as any).humanizeSchedule('0 14 * * *')).toBe('Daily 2 PM');
  });

  test('midnight shows as 12 AM', () => {
    expect((globalThis as any).humanizeSchedule('0 0 * * *')).toBe('Daily 12 AM');
  });

  test('returns raw expr for non-standard', () => {
    expect((globalThis as any).humanizeSchedule('30 2 15 * *')).toBe('30 2 15 * *');
  });
});

// ── ALERT_JOBS ──
describe('ALERT_JOBS', () => {
  test('contains the 3 alert-capable jobs', () => {
    const alertJobs = (globalThis as any).ALERT_JOBS as Set<string>;
    expect(alertJobs.has('system-watchdog')).toBe(true);
    expect(alertJobs.has('error-log-digest')).toBe(true);
    expect(alertJobs.has('cron-health-watchdog')).toBe(true);
  });

  test('does not include non-alert jobs', () => {
    const alertJobs = (globalThis as any).ALERT_JOBS as Set<string>;
    expect(alertJobs.has('self-reflection')).toBe(false);
    expect(alertJobs.has('daily-workspace-commit')).toBe(false);
  });
});

// ── switchTab to cron ──
describe('switchTab to cron', () => {
  test('shows cron panel and hides others', () => {
    (globalThis as any).switchTab('cron');

    expect(document.getElementById('panel-cron')!.classList.contains('hidden')).toBe(false);
    expect(document.getElementById('panel-patches')!.classList.contains('hidden')).toBe(true);
    expect(document.getElementById('panel-skills')!.classList.contains('hidden')).toBe(true);
    expect(document.getElementById('panel-bundled')!.classList.contains('hidden')).toBe(true);
  });

  test('activates cron tab button', () => {
    (globalThis as any).switchTab('cron');
    expect(document.getElementById('tab-cron')!.className).toContain('tab-active');
    expect(document.getElementById('tab-patches')!.className).toContain('tab-inactive');
  });
});

// ── updateDownloadBar with cron ──
describe('updateDownloadBar with cron jobs', () => {
  test('shows cron count in download bar', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'j1' }),
      makeCronJob({ name: 'j2' }),
    ];
    (globalThis as any).renderAllCronJobs();
    (globalThis as any).toggleCronSelect('j1');
    (globalThis as any).toggleCronSelect('j2');

    const countEl = document.getElementById('selected-count')!;
    expect(countEl.textContent).toContain('2 cron jobs');
  });

  test('shows singular for 1 cron job', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'solo' })];
    (globalThis as any).renderAllCronJobs();
    (globalThis as any).toggleCronSelect('solo');

    const countEl = document.getElementById('selected-count')!;
    expect(countEl.textContent).toContain('1 cron job');
    expect(countEl.textContent).not.toContain('cron jobs');
  });
});

// ── buildBundleFiles with cron ──
describe('buildBundleFiles cron selections', () => {
  test('cron-selections.json includes selected cron jobs', () => {
    (globalThis as any).state.cronJobs = [
      makeCronJob({ name: 'job-a' }),
      makeCronJob({ name: 'job-b' }),
    ];
    (globalThis as any).state.cronSelected.add('job-a');

    const files = (globalThis as any).buildBundleFiles();
    const crons = JSON.parse(files['cron-selections.json']);
    expect(crons).toHaveLength(1);
    expect(crons[0].name).toBe('job-a');
  });

  test('cron-selections.json is empty array when none selected', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'unused' })];

    const files = (globalThis as any).buildBundleFiles();
    const crons = JSON.parse(files['cron-selections.json']);
    expect(crons).toHaveLength(0);
  });

  test('manifest includes selectedCronJobs', () => {
    (globalThis as any).state.cronJobs = [makeCronJob({ name: 'sel-job' })];
    (globalThis as any).state.cronSelected.add('sel-job');

    const files = (globalThis as any).buildBundleFiles();
    const config = JSON.parse(files['config-bundle.json']);
    expect(config.manifest.selectedCronJobs).toContain('sel-job');
  });
});

// ── loadCronReadme ──
describe('loadCronReadme', () => {
  test('returns markdown text on success', async () => {
    const origFetch = globalThis.fetch;
    (globalThis as any).fetch = async (url: string) => {
      if (url.includes('README.md')) {
        return { ok: true, text: async () => '# Cron Jobs\n\nIntro text.' };
      }
      return { ok: false, status: 404 };
    };

    const result = await (globalThis as any).loadCronReadme();
    expect(result).toBe('# Cron Jobs\n\nIntro text.');

    (globalThis as any).fetch = origFetch;
  });

  test('returns null on fetch failure', async () => {
    const origFetch = globalThis.fetch;
    (globalThis as any).fetch = async () => ({ ok: false, status: 404 });

    const result = await (globalThis as any).loadCronReadme();
    expect(result).toBeNull();

    (globalThis as any).fetch = origFetch;
  });

  test('returns null on network error', async () => {
    const origFetch = globalThis.fetch;
    (globalThis as any).fetch = async () => { throw new Error('Network error'); };

    const result = await (globalThis as any).loadCronReadme();
    expect(result).toBeNull();

    (globalThis as any).fetch = origFetch;
  });
});
