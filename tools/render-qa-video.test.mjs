import assert from 'node:assert/strict';
import test from 'node:test';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { frameOverlaySvg, validateFrameTimeline, writeOverlayPng } from './render-qa-video.mjs';

test('rejects VFR or offset traces before an overlay can mislabel a person', () => {
  const trace = [0, 1 / 30, 2 / 30].map(pts => ({ pts }));
  assert.doesNotThrow(() => validateFrameTimeline(trace, [0, 1 / 30, 2 / 30], 30));
  assert.throws(() => validateFrameTimeline(trace, [0, 0.04, 2 / 30], 30), /non-uniform/);
  assert.throws(() => validateFrameTimeline(trace, [0.1, 0.1 + 1 / 30, 0.1 + 2 / 30], 30), /offset/);
  assert.throws(() => validateFrameTimeline(trace, [0, 1 / 30], 30), /count/);
});

test('selected box and count come from the diagnostic trace, not a simulated UI', () => {
  const svg = frameOverlaySvg({
    decision: 'selected(index: 2)',
    candidates: [{ index: 2, centerX: 0.5, centerY: 0.5, width: 0.2, height: 0.4 }],
    pts: 1.5
  }, [{ timestamp: 1.2 }], 1000, 500);
  assert.match(svg, /x="400" y="150" width="200" height="4" fill="#38f2a7"/);
  assert.match(svg, /CONTAGEM 1/);
  assert.match(svg, /ALVO SELECIONADO/);
  assert.match(svg, /SIMULADOR IPHONE 15/);
});

test('physical iPhone evidence is labelled as physical, never simulator', () => {
  const svg = frameOverlaySvg({ decision: 'selected(index: 0)', candidates: [], pts: 0 }, [],
    1280, 720, 'IPHONE DE FABIO (FÍSICO)');
  assert.match(svg, /IPHONE DE FABIO \(FÍSICO\)/);
  assert.doesNotMatch(svg, /SIMULADOR/);
});

test('ambiguous frame never paints an athlete as confirmed', () => {
  const svg = frameOverlaySvg({
    decision: 'uncertain',
    candidates: [{ index: 0, centerX: 0.5, centerY: 0.5, width: 0.2, height: 0.4 }],
    pts: 2
  }, [], 1000, 500);
  assert.match(svg, /IDENTIDADE INCERTA/);
  assert.doesNotMatch(svg, /ALVO SELECIONADO/);
});

test('rasterized overlay stays transparent over source footage', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ritmovis-svg-test-'));
  try {
    const path = join(dir, 'overlay.png');
    writeOverlayPng('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect x="0" y="0" width="10" height="10" fill="red"/></svg>', path);
    const pixel = execFileSync('magick', [path, '-format', '%[pixel:p{90,40}]', 'info:'], { encoding: 'utf8' });
    assert.match(pixel, /,0\)$/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('selected box remains visible after SVG rasterization', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ritmovis-box-test-'));
  try {
    const path = join(dir, 'overlay.png');
    const svg = frameOverlaySvg({ decision: 'selected(index: 1)', pts: 0,
      candidates: [{ index: 1, centerX: 0.5, centerY: 0.5, width: 0.2, height: 0.2 }] }, [], 100, 300);
    writeOverlayPng(svg, path);
    const pixel = execFileSync('magick', [path, '-format', '%[pixel:p{50,120}]', 'info:'], { encoding: 'utf8' });
    assert.doesNotMatch(pixel, /,0\)$/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
