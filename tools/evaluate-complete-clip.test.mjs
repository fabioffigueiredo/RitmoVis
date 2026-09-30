import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./evaluate-complete-clip.mjs', import.meta.url));
const target = { left: 0.2, top: 0.2, right: 0.4, bottom: 0.8 };
const candidate = (index, centerX) => ({ index, centerX, centerY: 0.5 });
const baseReport = {
  source: 'private-clip.mov',
  trace: [
    { pts: 0, candidates: [candidate(0, 0.3), candidate(1, 0.7)], decision: 'selected(index: 0)' },
    { pts: 1, candidates: [candidate(1, 0.7), candidate(0, 0.3)], decision: 'selected(index: 0)' },
    { pts: 2, candidates: [candidate(0, 0.3), candidate(1, 0.7)], decision: 'uncertain' }
  ],
  events: [{ timestamp: 1 }]
};
const baseLabels = {
  source: 'private-clip.mov', split: 'acceptance', toleranceSeconds: 0.2,
  frames: [
    { pts: 0, observability: 'observable', targetBox: target },
    { pts: 1, observability: 'observable', targetBox: target },
    { pts: 2, observability: 'observable', targetBox: target }
  ],
  attempts: [{ startSeconds: 0.2, endSeconds: 1, completed: true }]
};

function run(report = baseReport, labels = baseLabels) {
  const dir = mkdtempSync(join(tmpdir(), 'ritmovis-complete-clip-'));
  try {
    const reportPath = join(dir, 'report.json');
    const labelsPath = join(dir, 'labels.json');
    writeFileSync(reportPath, JSON.stringify(report));
    writeFileSync(labelsPath, JSON.stringify(labels));
    const result = spawnSync(process.execPath, [script, reportPath, labelsPath], { encoding: 'utf8' });
    return { status: result.status, output: JSON.parse(result.stdout) };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('evaluates full clip identity and repetitions without treating abstention as success', () => {
  const { status, output } = run();
  assert.equal(status, 0);
  assert.deepEqual(output.metrics, {
    annotatedFrames: 3, observableFrames: 3, correctSelectedFrames: 2,
    wrongSelectedFrames: 0, abstainedFrames: 1, coverage: 2 / 3,
    creditedToOtherPerson: 0, truePositives: 1, falsePositives: 0,
    falseNegatives: 0, precision: 1, recall: 1
  });
});

test('rejects a repetition credited to a rival even when its timestamp matches a real rep', () => {
  const report = structuredClone(baseReport);
  report.trace[1].decision = 'selected(index: 1)';
  const { status, output } = run(report);
  assert.equal(status, 1);
  assert.equal(output.metrics.wrongSelectedFrames, 1);
  assert.equal(output.metrics.creditedToOtherPerson, 1);
  assert.equal(output.failures[0].code, 'wrong-person-credit');
});

test('requires a manual identity label at every automatic event', () => {
  const report = structuredClone(baseReport);
  report.events = [{ timestamp: 1.5 }];
  const { status, output } = run(report);
  assert.equal(status, 1);
  assert.equal(output.failures[0].code, 'unlabelled-event');
});

test('fails closed for source mismatch, missing evidence and nonmonotonic events', () => {
  assert.equal(run(baseReport, { ...baseLabels, source: 'other.mov' }).output.failures[0].code,
    'source-mismatch');
  assert.equal(run(baseReport, { ...baseLabels, frames: [] }).output.failures[0].code,
    'invalid-annotation');
  const report = structuredClone(baseReport);
  report.events = [{ timestamp: 2 }, { timestamp: 1 }];
  assert.equal(run(report).output.failures[0].code, 'invalid-report-events');
});

test('reports false positives and misses from complete and incomplete attempts', () => {
  const report = structuredClone(baseReport);
  report.events = [{ timestamp: 0 }, { timestamp: 2 }];
  report.trace[2].decision = 'selected(index: 0)';
  const labels = structuredClone(baseLabels);
  labels.attempts.push({ startSeconds: 1.5, endSeconds: 2, completed: false });
  const { status, output } = run(report, labels);
  assert.equal(status, 0);
  assert.equal(output.metrics.truePositives, 0);
  assert.equal(output.metrics.falsePositives, 2);
  assert.equal(output.metrics.falseNegatives, 1);
  assert.equal(output.metrics.precision, 0);
  assert.equal(output.metrics.recall, 0);
});
