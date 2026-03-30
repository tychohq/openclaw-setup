import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { readFileSync, readdirSync } from 'fs';
import { resolve } from 'path';
import { GlobalRegistrator } from '@happy-dom/global-registrator';

try { GlobalRegistrator.register(); } catch { /* already registered */ }

// Stub JSZip
(globalThis as any).JSZip = class {
  _files: Record<string, string> = {};
  file(name: string, content: string) { this._files[name] = content; }
  async generateAsync() { return new Blob(['zip-content']); }
};

const htmlSource = readFileSync(new URL('./index.html', import.meta.url), 'utf-8');

const scriptMatch = htmlSource.match(/<script>\n\/\/ ── State ──[\s\S]*?<\/script>/);
if (!scriptMatch) throw new Error('Could not extract script block from index.html');
const scriptContent = scriptMatch[0].replace(/<\/?script>/g, '');

// ── Load real data from disk ──
const projectRoot = resolve(import.meta.dir, '..');

function loadYaml(id: string): string {
  return readFileSync(resolve(projectRoot, `shared/patches/patches/${id}.yaml`), 'utf-8');
}

function loadCronJob(id: string): Record<string, unknown> {
  return JSON.parse(readFileSync(resolve(projectRoot, `shared/cron-jobs/${id}.json`), 'utf-8'));
}

const patchCatalog: string[] = JSON.parse(readFileSync(resolve(projectRoot, 'web/catalog.json'), 'utf-8'));
const cronCatalog: string[] = JSON.parse(readFileSync(resolve(projectRoot, 'web/cron-catalog.json'), 'utf-8'));

// ── Test env setup ──
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
    <input type="radio" name="cron-delivery" value="discord" />
    <input type="text" id="cron-channel-id" class="hidden" />
    <select id="cron-model"><option value="">Default</option><option value="anthropic/claude-opus-4-6">Opus</option></select>
  `;

  // Stub js-yaml with a real-ish YAML parser for simple YAML
  (globalThis as any).jsyaml = {
    load: (text: string) => {
      // Parse the simple YAML format used by patches
      const lines = text.split('\n');
      const result: Record<string, any> = {};
      let currentSteps: any[] | null = null;
      let currentStep: Record<string, any> | null = null;

      for (const line of lines) {
        if (line.startsWith('id: ')) result.id = line.slice(4).trim();
        else if (line.startsWith('description: '))
          result.description = line.slice(13).trim().replace(/^"|"$/g, '');
        else if (line.startsWith('targets: '))
          result.targets = JSON.parse(line.slice(9).trim());
        else if (line.startsWith('created: '))
          result.created = line.slice(9).trim();
        else if (line.startsWith('requires:')) {
          result.requires = [];
        } else if (result.requires && !result.steps && line.match(/^\s+- /)) {
          result.requires.push(line.trim().slice(2));
        } else if (line.startsWith('steps:')) {
          result.steps = [];
          currentSteps = result.steps;
        } else if (currentSteps && line.match(/^\s+- type: /)) {
          currentStep = { type: line.trim().slice(8) };
          currentSteps.push(currentStep);
        } else if (currentStep && line.match(/^\s+plugin: /)) {
          currentStep.plugin = line.trim().slice(8);
        } else if (currentStep && line.match(/^\s+name: /)) {
          currentStep.name = line.trim().slice(6);
        } else if (currentStep && line.match(/^\s+enable: /)) {
          currentStep.enable = line.trim().slice(8) === 'true';
        } else if (currentStep && line.match(/^\s+path: /)) {
          currentStep.path = line.trim().slice(6);
        } else if (currentStep && line.match(/^\s+value: /)) {
          currentStep.value = line.trim().slice(7).replace(/^'|'$/g, '');
        } else if (currentStep && line.match(/^\s+command: /)) {
          currentStep.command = line.trim().slice(9);
        }
      }
      return result;
    },
  };

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

// ── Helpers ──
function g(name: string): any {
  return (globalThis as any)[name];
}

function loadPatchesIntoState(ids: string[]) {
  const state = g('state');
  state.patches = [];

  for (const id of ids) {
    const yamlText = loadYaml(id);
    const parsed = (globalThis as any).jsyaml.load(yamlText);
    state.patches.push(parsed);
  }
}

function loadCronJobsIntoState(ids: string[]) {
  const state = g('state');
  state.cronJobs = ids.map(id => loadCronJob(id));
}

// ── End-to-end bundle generation tests ──
describe('E2E: full bundle with real data', () => {
  test('catalog.json matches actual patch files on disk', () => {
    const patchDir = resolve(projectRoot, 'shared/patches/patches');
    const yamlFiles = readdirSync(patchDir)
      .filter(f => f.endsWith('.yaml'))
      .map(f => f.replace('.yaml', ''))
      .sort();

    // inject-datetime is an extension patch not included in the web catalog
    // (catalog only has config-type patches)
    for (const id of patchCatalog) {
      expect(yamlFiles).toContain(id);
    }
  });

  test('cron-catalog.json matches actual cron job files on disk', () => {
    const cronDir = resolve(projectRoot, 'shared/cron-jobs');
    const jsonFiles = readdirSync(cronDir)
      .filter(f => f.endsWith('.json'))
      .map(f => f.replace('.json', ''))
      .sort();

    for (const id of cronCatalog) {
      expect(jsonFiles).toContain(id);
    }
  });

  test('files/configs/ directory does not exist (fully removed)', () => {
    const configsDir = resolve(projectRoot, 'shared/patches/files/configs');
    let exists = true;
    try { readdirSync(configsDir); } catch { exists = false; }
    expect(exists).toBe(false);
  });

  test('no runtime source files reference files/configs/', () => {
    const runtimeFiles = [
      resolve(projectRoot, 'web/index.html'),
      resolve(projectRoot, 'aws/scripts/post-clone-setup.sh'),
      resolve(projectRoot, 'shared/patches/scripts/openclaw-patch'),
    ];
    for (const file of runtimeFiles) {
      const content = readFileSync(file, 'utf-8');
      expect(content).not.toContain('files/configs');
    }
  });
});

describe('E2E: select patches + bundled skills → config-bundle.json', () => {
  test('config-bundle.json contains merged patches AND allowBundled array', () => {
    // Load real patches
    loadPatchesIntoState(['agent-defaults', 'discord-channel', 'session-config']);

    const state = g('state');

    // Select some patches
    state.selected.add('agent-defaults');
    state.selected.add('discord-channel');

    // Select some bundled skills
    state.bundledSelected.add('discord');
    state.bundledSelected.add('slack');
    state.bundledSelected.add('github');

    const files = g('buildBundleFiles')();
    const config = JSON.parse(files['config-bundle.json']);

    // Manifest checks
    expect(config.manifest.version).toBe('2.0.0');
    expect(config.manifest.source).toBe('local');
    expect(config.manifest.generated).toBeTruthy();
    expect(config.manifest.selectedPatches).toContain('agent-defaults');
    expect(config.manifest.selectedPatches).toContain('discord-channel');
    expect(config.manifest.selectedPatches).not.toContain('session-config');
    expect(config.manifest.selectedBundledSkills).toEqual(
      expect.arrayContaining(['discord', 'slack', 'github']),
    );

    // Patches array: only selected patches
    expect(config.patches).toHaveLength(2);
    const patchIds = config.patches.map((p: any) => p.id);
    expect(patchIds).toContain('agent-defaults');
    expect(patchIds).toContain('discord-channel');

    // No configs map in v2.0.0 bundle format
    expect(config.configs).toBeUndefined();

    // allowBundled: sorted array of selected bundled skills
    expect(config.allowBundled).toEqual(['discord', 'github', 'slack']);
  });

  test('config-bundle.json omits allowBundled when no bundled skills selected', () => {
    loadPatchesIntoState(['agent-defaults']);
    g('state').selected.add('agent-defaults');

    const files = g('buildBundleFiles')();
    const config = JSON.parse(files['config-bundle.json']);

    expect(config.allowBundled).toBeUndefined();
    expect(config.patches).toHaveLength(1);
  });

  test('config_set and config_append steps carry path and value directly', () => {
    loadPatchesIntoState(['memory-config', 'skills-config']);
    const state = g('state');
    state.selected.add('memory-config');
    state.selected.add('skills-config');

    const files = g('buildBundleFiles')();
    const config = JSON.parse(files['config-bundle.json']);

    // memory-config has config_set steps
    const memoryPatch = config.patches.find((p: any) => p.id === 'memory-config');
    const setStep = memoryPatch.steps.find((s: any) => s.type === 'config_set');
    expect(setStep.path).toBe('agents.defaults.memorySearch');
    expect(setStep.value).toBeTruthy();

    // skills-config has a config_append step
    const skillsPatch = config.patches.find((p: any) => p.id === 'skills-config');
    const appendStep = skillsPatch.steps.find((s: any) => s.type === 'config_append');
    expect(appendStep.path).toBe('skills.load.extraDirs');
    expect(appendStep.value).toBeTruthy();
  });

  test('all catalog patches can be loaded and selected', () => {
    loadPatchesIntoState(patchCatalog);
    const state = g('state');

    expect(state.patches).toHaveLength(patchCatalog.length);

    // Select all
    for (const p of state.patches) state.selected.add(p.id);

    const files = g('buildBundleFiles')();
    const config = JSON.parse(files['config-bundle.json']);

    expect(config.patches).toHaveLength(patchCatalog.length);
    expect(config.manifest.selectedPatches).toHaveLength(patchCatalog.length);

    // No configs map in v2.0.0 bundle format
    expect(config.configs).toBeUndefined();

    // Every config_set/config_append step must have path and value
    for (const patch of config.patches) {
      for (const step of patch.steps) {
        if (step.type === 'config_set' || step.type === 'config_append') {
          expect(step.path).toBeTruthy();
          expect(step.value).toBeDefined();
        }
      }
    }
  });
});

describe('E2E: select cron jobs → cron-selections.json', () => {
  test('cron-selections.json contains full cron job definitions', () => {
    loadCronJobsIntoState(cronCatalog);
    const state = g('state');

    // Select self-reflection and system-watchdog
    state.cronSelected.add('self-reflection');
    state.cronSelected.add('system-watchdog');

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    expect(crons).toHaveLength(2);

    // Verify full job definitions, not just IDs
    const reflection = crons.find((c: any) => c.name === 'self-reflection');
    expect(reflection).toBeDefined();
    expect(reflection.schedule.kind).toBe('cron');
    expect(reflection.schedule.expr).toBe('0 * * * *');
    expect(reflection.payload.kind).toBe('agentTurn');
    expect(reflection.payload.message).toContain('self-reflection agent');
    expect(reflection.delivery.mode).toBe('none');

    const watchdog = crons.find((c: any) => c.name === 'system-watchdog');
    expect(watchdog).toBeDefined();
    expect(watchdog.schedule.expr).toBe('0 4 * * *');
    expect(watchdog.requires.skills).toContain('system-watchdog');
  });

  test('cron-selections.json is empty array when none selected', () => {
    loadCronJobsIntoState(cronCatalog);

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    expect(crons).toEqual([]);
  });

  test('all cron jobs can be loaded and selected', () => {
    loadCronJobsIntoState(cronCatalog);
    const state = g('state');

    expect(state.cronJobs).toHaveLength(cronCatalog.length);

    for (const job of state.cronJobs) state.cronSelected.add(job.name);

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    expect(crons).toHaveLength(cronCatalog.length);
    const names = crons.map((c: any) => c.name);
    for (const id of cronCatalog) {
      expect(names).toContain(id);
    }
  });

  test('manifest.selectedCronJobs matches selected cron job names', () => {
    loadCronJobsIntoState(cronCatalog);
    g('state').cronSelected.add('daily-workspace-commit');
    g('state').cronSelected.add('error-log-digest');

    const files = g('buildBundleFiles')();
    const config = JSON.parse(files['config-bundle.json']);

    expect(config.manifest.selectedCronJobs).toContain('daily-workspace-commit');
    expect(config.manifest.selectedCronJobs).toContain('error-log-digest');
    expect(config.manifest.selectedCronJobs).toHaveLength(2);
  });
});

describe('E2E: select skills → skills-list.json', () => {
  test('skills-list.json contains skill ID strings (slug, displayName, summary, version)', () => {
    const state = g('state');
    // Simulate loaded ClawHub skills
    state.skills = [
      {
        slug: 'research-agent',
        displayName: 'Research Agent',
        summary: 'Runs deep research',
        latestVersion: { version: '2.1.0' },
        tags: {},
        stats: {},
      },
      {
        slug: 'cron-setup',
        displayName: 'Cron Setup',
        summary: 'Sets up cron jobs',
        latestVersion: { version: '1.0.0' },
        tags: {},
        stats: {},
      },
    ];
    state.skillsSelected.add('research-agent');

    const files = g('buildBundleFiles')();
    const skills = JSON.parse(files['skills-list.json']);

    expect(skills).toHaveLength(1);
    expect(skills[0].slug).toBe('research-agent');
    expect(skills[0].displayName).toBe('Research Agent');
    expect(skills[0].summary).toBe('Runs deep research');
    expect(skills[0].version).toBe('2.1.0');
  });

  test('skills-list.json is empty array when none selected', () => {
    const state = g('state');
    state.skills = [
      { slug: 'some-skill', displayName: 'S', summary: 's', latestVersion: { version: '1.0.0' } },
    ];

    const files = g('buildBundleFiles')();
    const skills = JSON.parse(files['skills-list.json']);

    expect(skills).toEqual([]);
  });
});

describe('E2E: full combined bundle (all 4 types selected)', () => {
  test('all three files have correct content when patches + cron + skills + bundled are selected', () => {
    // Load real patches and cron jobs
    loadPatchesIntoState(['agent-defaults', 'memory-config', 'skills-config']);
    loadCronJobsIntoState(['self-reflection', 'daily-workspace-commit']);

    const state = g('state');

    // Select patches
    state.selected.add('agent-defaults');
    state.selected.add('skills-config');

    // Select cron jobs
    state.cronSelected.add('self-reflection');

    // Simulate skills
    state.skills = [
      {
        slug: 'tmux-controller',
        displayName: 'Tmux Controller',
        summary: 'Controls tmux',
        latestVersion: { version: '3.0.0' },
      },
    ];
    state.skillsSelected.add('tmux-controller');

    // Select bundled skills
    state.bundledSelected.add('tmux');
    state.bundledSelected.add('weather');

    const files = g('buildBundleFiles')();

    // ── config-bundle.json ──
    const config = JSON.parse(files['config-bundle.json']);
    expect(config.manifest.selectedPatches).toHaveLength(2);
    expect(config.manifest.selectedCronJobs).toHaveLength(1);
    expect(config.manifest.selectedSkills).toContain('tmux-controller');
    expect(config.manifest.selectedBundledSkills).toEqual(
      expect.arrayContaining(['tmux', 'weather']),
    );
    expect(config.patches).toHaveLength(2);
    expect(config.configs).toBeUndefined();
    expect(config.allowBundled).toEqual(['tmux', 'weather']);

    // ── cron-selections.json ──
    const crons = JSON.parse(files['cron-selections.json']);
    expect(crons).toHaveLength(1);
    expect(crons[0].name).toBe('self-reflection');
    expect(crons[0].schedule).toBeDefined();
    expect(crons[0].payload).toBeDefined();

    // ── skills-list.json ──
    const skills = JSON.parse(files['skills-list.json']);
    expect(skills).toHaveLength(1);
    expect(skills[0].slug).toBe('tmux-controller');
    expect(skills[0].version).toBe('3.0.0');
  });

  test('download bar text reflects combined selections', () => {
    loadPatchesIntoState(['agent-defaults']);
    loadCronJobsIntoState(['self-reflection']);

    const state = g('state');
    state.selected.add('agent-defaults');
    state.cronSelected.add('self-reflection');
    state.bundledSelected.add('discord');

    g('renderAllBundled')();
    g('updateDownloadBar')();

    const bar = document.getElementById('download-bar')!;
    expect(bar.classList.contains('translate-y-full')).toBe(false);

    const countEl = document.getElementById('selected-count')!;
    expect(countEl.textContent).toContain('1 patch');
    expect(countEl.textContent).toContain('1 cron job');
    expect(countEl.textContent).toContain('1 bundled skill');
  });
});

describe('E2E: cron settings applied to bundle output', () => {
  test('timezone setting is reflected in cron-selections.json', () => {
    loadCronJobsIntoState(['self-reflection', 'system-watchdog']);
    const state = g('state');

    // Change timezone
    (document.getElementById('cron-tz') as HTMLSelectElement).value = 'UTC';
    g('applyCronSettings')();

    // Select all after settings applied
    state.cronSelected.add('self-reflection');
    state.cronSelected.add('system-watchdog');

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    for (const job of crons) {
      expect(job.schedule.tz).toBe('UTC');
    }
  });

  test('model override is reflected in cron-selections.json', () => {
    loadCronJobsIntoState(['self-reflection']);
    const state = g('state');

    (document.getElementById('cron-model') as HTMLSelectElement).value =
      'anthropic/claude-opus-4-6';
    g('applyCronSettings')();

    state.cronSelected.add('self-reflection');

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    expect(crons[0].payload.model).toBe('anthropic/claude-opus-4-6');
  });

  test('delivery setting applied only to alert-capable jobs', () => {
    loadCronJobsIntoState(['self-reflection', 'system-watchdog', 'cron-health-watchdog']);
    const state = g('state');

    // Set delivery to discord
    const discordRadio = document.querySelectorAll(
      'input[name="cron-delivery"]',
    )[1] as HTMLInputElement;
    discordRadio.checked = true;
    (document.getElementById('cron-channel-id') as HTMLInputElement).value = '123456';
    g('applyCronSettings')();

    for (const job of state.cronJobs) state.cronSelected.add(job.name);

    const files = g('buildBundleFiles')();
    const crons = JSON.parse(files['cron-selections.json']);

    const reflection = crons.find((c: any) => c.name === 'self-reflection');
    // self-reflection is NOT an alert job, so delivery should stay as-is
    expect(reflection.delivery.mode).toBe('none');

    const watchdog = crons.find((c: any) => c.name === 'system-watchdog');
    expect(watchdog.delivery.mode).toBe('announce');
    expect(watchdog.delivery.channel).toBe('discord');
    expect(watchdog.delivery.to).toBe('123456');

    const healthWatchdog = crons.find((c: any) => c.name === 'cron-health-watchdog');
    expect(healthWatchdog.delivery.mode).toBe('announce');
    expect(healthWatchdog.delivery.channel).toBe('discord');
  });
});

describe('E2E: File System Access API save path', () => {
  test('saveToDirectory writes all 3 files via File System Access API', async () => {
    loadPatchesIntoState(['agent-defaults']);
    loadCronJobsIntoState(['self-reflection']);

    const state = g('state');
    state.selected.add('agent-defaults');
    state.cronSelected.add('self-reflection');
    state.bundledSelected.add('discord');

    const writtenFiles: Record<string, string> = {};

    (globalThis as any).window.showDirectoryPicker = async () => ({
      getFileHandle: async (name: string) => ({
        createWritable: async () => ({
          write: async (content: string) => {
            writtenFiles[name] = content;
          },
          close: async () => {},
        }),
      }),
    });

    await g('downloadBundle')();

    expect(Object.keys(writtenFiles).sort()).toEqual([
      'config-bundle.json',
      'cron-selections.json',
      'skills-list.json',
    ]);

    // Verify each file is valid JSON
    const config = JSON.parse(writtenFiles['config-bundle.json']);
    expect(config.manifest).toBeDefined();
    expect(config.patches).toHaveLength(1);
    expect(config.allowBundled).toEqual(['discord']);

    const crons = JSON.parse(writtenFiles['cron-selections.json']);
    expect(crons).toHaveLength(1);
    expect(crons[0].name).toBe('self-reflection');

    const skills = JSON.parse(writtenFiles['skills-list.json']);
    expect(skills).toEqual([]);

    delete (globalThis as any).window.showDirectoryPicker;
  });
});
