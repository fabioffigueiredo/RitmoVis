import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = new URL('./check-tracking-regression.mjs', import.meta.url);

function run(report, annotation) {
  const dir = mkdtempSync(join(tmpdir(), 'ritmovis-tracking-check-'));
  try {
    const reportPath = join(dir, 'report.json');
    const annotationPath = join(dir, 'annotation.json');
    writeFileSync(reportPath, JSON.stringify(report));
    writeFileSync(annotationPath, JSON.stringify(annotation));
    const result = spawnSync(process.execPath, [fileURLToPath(script), reportPath, annotationPath], {
      encoding: 'utf8'
    });
    return { status: result.status, output: JSON.parse(result.stdout) };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const box = { left: 0.2, top: 0.2, right: 0.4, bottom: 0.7 };
const annotation = { source: 'clip.mov', cases: [{ pts: 1.1, targetBox: box,
  requireCandidate: true, requireSelected: false }] };

test('selected rival fails even when the target is an available candidate', () => {
  const result = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [{ index: 0, centerX: 0.3, centerY: 0.4 },
      { index: 1, centerX: 0.7, centerY: 0.4 }],
    decision: 'selected(index: 1)' }] }, annotation);
  assert.equal(result.status, 1);
  assert.equal(result.output.metrics.wrongPersonSelections, 1);
  assert.equal(result.output.metrics.targetCandidateFrames, 1);
  assert.equal(result.output.failures[0].code, 'wrong-person-selection');
});

test('correct selection and safe abstention pass at exact annotated frames', () => {
  const result = run({ source: 'clip.mov', trace: [
    { pts: 1.1, candidates: [{ index: 3, centerX: 0.3, centerY: 0.4 }],
      decision: 'selected(index: 3)' },
    { pts: 1.133, candidates: [{ index: 0, centerX: 0.3, centerY: 0.4 }],
      decision: 'uncertain' }
  ] }, { source: 'clip.mov', cases: [
    { pts: 1.1, targetBox: box, requireCandidate: true, requireSelected: true },
    { pts: 1.133, targetBox: box, requireCandidate: true, requireSelected: false }
  ] });
  assert.equal(result.status, 0);
  assert.deepEqual(result.output.metrics, {
    annotatedFrames: 2, matchedFrames: 2, targetCandidateFrames: 2,
    correctSelections: 1, abstentions: 1, wrongPersonSelections: 0
  });
  assert.deepEqual(result.output.failures, []);
});

test('missing target candidate and required selection are distinct failures', () => {
  const result = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [{ index: 0, centerX: 0.8, centerY: 0.4 }],
    decision: 'uncertain' }] }, { source: 'clip.mov', cases: [{ pts: 1.1,
    targetBox: box, requireCandidate: true, requireSelected: true }] });
  assert.equal(result.status, 1);
  assert.deepEqual(result.output.failures.map(item => item.code),
    ['target-candidate-missing', 'target-not-selected']);
});

test('annotation must identify the same source and an actual frame', () => {
  const report = { source: 'clip.mov', trace: [{ pts: 1.1, candidates: [], decision: 'uncertain' }] };
  assert.equal(run(report, { source: 'other.mov', cases: annotation.cases })
    .output.failures[0].code, 'source-mismatch');
  const missing = run(report, { source: 'clip.mov', cases: [{ ...annotation.cases[0], pts: 1.11 }] });
  assert.equal(missing.status, 1);
  assert.deepEqual(missing.output.failures.map(item => item.code), ['frame-match', 'no-case-frames']);
});

test('unknown decision and selection without its indexed candidate fail', () => {
  const unknown = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [{ index: 0, centerX: 0.3, centerY: 0.4 }], decision: 'tracking' }] }, annotation);
  assert.equal(unknown.output.failures[0].code, 'unknown-decision');
  const absentIndex = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [{ index: 0, centerX: 0.3, centerY: 0.4 }],
    decision: 'selected(index: 5)' }] }, annotation);
  assert.equal(absentIndex.output.failures[0].code, 'selected-candidate-missing');
});

test('invalid report, annotation, and reported error fail closed', () => {
  assert.equal(run({ source: 'clip.mov', trace: null }, annotation)
    .output.failures[0].code, 'invalid-report');
  assert.equal(run({ source: 'clip.mov', error: 'decoding failed', trace: [] }, annotation)
    .output.failures[0].code, 'invalid-report');
  assert.equal(run({ source: 'clip.mov', trace: [{ pts: 1.1 }] },
    { source: 'clip.mov', cases: [] }).output.failures[0].code, 'invalid-annotation');
  assert.equal(run({ source: 'clip.mov', trace: [{ pts: 1.1 }] },
    { source: 'clip.mov', cases: [{ pts: 1.1, targetBox: { ...box, right: 1.2 } }] })
    .output.failures[0].code, 'invalid-annotation-case');
});

test('timestamp tolerance accepts one close frame but rejects ambiguous matches', () => {
  const close = run({ source: 'clip.mov', trace: [{ pts: 1.102,
    candidates: [{ index: 0, centerX: 0.3, centerY: 0.4 }],
    decision: 'selected(index: 0)' }] }, annotation);
  assert.equal(close.status, 0);
  const ambiguous = run({ source: 'clip.mov', trace: [
    { pts: 1.099, candidates: [], decision: 'uncertain' },
    { pts: 1.101, candidates: [], decision: 'uncertain' }
  ] }, annotation);
  assert.equal(ambiguous.status, 1);
  assert.equal(ambiguous.output.failures[0].code, 'frame-match');
  assert.equal(ambiguous.output.failures[0].matches, 2);
});

test('missing files and malformed candidates return structured errors', () => {
  const missing = spawnSync(process.execPath,
    [fileURLToPath(script), '/no/such/ritmovis-report.json', '/no/such/ritmovis-labels.json'],
    { encoding: 'utf8' });
  assert.equal(missing.status, 1);
  assert.equal(JSON.parse(missing.stdout).failures[0].code, 'invalid-report');
  const malformed = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [{ index: 0, centerX: '0.3', centerY: 0.4 }],
    decision: 'selected(index: 0)' }] }, annotation);
  assert.equal(malformed.status, 1);
  assert.equal(malformed.output.failures[0].code, 'invalid-report-frame');
});

test('duplicate candidate indices cannot make a selection look correct', () => {
  const result = run({ source: 'clip.mov', trace: [{ pts: 1.1,
    candidates: [
      { index: 0, centerX: 0.3, centerY: 0.4 },
      { index: 0, centerX: 0.8, centerY: 0.4 }
    ], decision: 'selected(index: 0)' }] }, annotation);
  assert.equal(result.status, 1);
  assert.equal(result.output.failures[0].code, 'invalid-report-frame');
});
