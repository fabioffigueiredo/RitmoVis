import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

function run(report) {
  const directory = mkdtempSync(join(tmpdir(), 'ritmovis-first-loss-'));
  try {
    const input = join(directory, 'report.json');
    writeFileSync(input, JSON.stringify(report));
    const result = spawnSync(process.execPath,
      ['tools/summarize-first-tracking-loss.mjs', input], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
  } finally { rmSync(directory, { recursive: true, force: true }); }
}

function report(trace, overrides = {}) {
  return { source: 'synthetic.mp4', stage: 'selection-completed',
    selectionRequested: true, recordedAt: 812000000, model: 'synthetic', trace, ...overrides };
}

test('reports the first loss and transitions instead of counting absorbing states as separate losses', () => {
  const result = run(report([
    { pts: 0, decision: 'noSelection', candidates: [] },
    { pts: 1, decision: 'selected(index: 1)', candidates: [{ index: 1 }] },
    { pts: 2, decision: 'uncertain', candidates: [{ index: 0 }, { index: 1 }] },
    { pts: 3, decision: 'reselectionRequired', candidates: [] },
    { pts: 4, decision: 'reselectionRequired', candidates: [] },
  ]));
  assert.equal(result.status, 'ok');
  assert.equal(result.selectionCompleted, true);
  assert.equal(result.selectionMode, 'explicit');
  assert.equal(result.firstSelectedAt, 1);
  assert.deepEqual(result.firstLoss, { pts: 2, decision: 'uncertain', candidateCount: 2 });
  assert.equal(result.firstReselectionAt, 3);
  assert.equal(result.reselectionTransitions, 1);
  assert.equal(result.reselectionFrames, 2);
});

test('a first pass without selection cannot be presented as a selected tracking failure', () => {
  const result = run(report([{ pts: 0, decision: 'noSelection', candidates: [] }],
    { stage: 'first-pass-completed', selectionRequested: false }));
  assert.equal(result.selectionCompleted, false);
  assert.equal(result.selectionMode, 'none');
  assert.equal(result.firstSelectedAt, null);
  assert.equal(result.firstLoss, null);
  assert.equal(result.firstReselectionAt, null);
});

test('a recovered uncertain interval does not invent a reselection', () => {
  const result = run(report([
    { pts: 1, decision: 'selected(index: 0)', candidates: [{ index: 0 }] },
    { pts: 2, decision: 'uncertain', candidates: [] },
    { pts: 3, decision: 'selected(index: 1)', candidates: [{ index: 1 }] },
  ]));
  assert.equal(result.firstLoss?.pts, 2);
  assert.equal(result.firstReselectionAt, null);
  assert.equal(result.reselectionTransitions, 0);
});

test('preserves the source and actual recording timestamp for provenance', () => {
  const result = run(report([{ pts: 0, decision: 'noSelection', candidates: [] }]));
  assert.equal(result.source, 'synthetic.mp4');
  assert.equal(result.recordedAt, 812000000);
  assert.equal(result.recordedAtISO8601, '2026-09-25T03:33:20.000Z');
});

function rejected(inputReport, expectedError) {
  const directory = mkdtempSync(join(tmpdir(), 'ritmovis-first-loss-invalid-'));
  try {
    const input = join(directory, 'report.json');
    writeFileSync(input, JSON.stringify(inputReport));
    const result = spawnSync(process.execPath,
      ['tools/summarize-first-tracking-loss.mjs', input], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stdout).error, expectedError);
  } finally { rmSync(directory, { recursive: true, force: true }); }
}

test('rejects nonmonotonic traces rather than reporting misleading first times', () => {
  rejected(report([
    { pts: 2, decision: 'noSelection', candidates: [] },
    { pts: 1, decision: 'noSelection', candidates: [] },
  ]), 'invalid-trace');
});

test('a selected decision must have exactly one candidate with that index', () => {
  for (const candidates of [[], [{ index: 0 }, { index: 0 }]]) {
    rejected(report([{ pts: 0, decision: 'selected(index: 0)', candidates }]), 'invalid-trace');
  }
});

test('a first-pass report cannot claim completed selection', () => {
  rejected(report([{ pts: 0, decision: 'noSelection', candidates: [] }],
    { stage: 'first-pass-completed', selectionRequested: true }), 'invalid-report');
});

test('a real single-person first pass can contain automatic selection without an explicit choice', () => {
  const result = run(report([
    { pts: 0, decision: 'selected(index: 0)', candidates: [{ index: 0 }] },
    { pts: 1, decision: 'noSelection', candidates: [] },
  ], { stage: 'first-pass-completed', selectionRequested: false, groupRequiresSelection: false }));
  assert.equal(result.selectionCompleted, false);
  assert.equal(result.selectionMode, 'automatic');
  assert.equal(result.firstSelectedAt, 0);
  assert.deepEqual(result.firstLoss, { pts: 1, decision: 'noSelection', candidateCount: 0 });
});
