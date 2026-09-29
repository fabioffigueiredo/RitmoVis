#!/usr/bin/env node
// Narrow, manually annotated frame regression. Boxes enclose the target pose center;
// this does not estimate identity accuracy or validate repetition counts.
import { readFileSync } from 'node:fs';

const toleranceSeconds = 0.003;
const failures = [];
const metrics = {
  annotatedFrames: 0,
  matchedFrames: 0,
  targetCandidateFrames: 0,
  correctSelections: 0,
  abstentions: 0,
  wrongPersonSelections: 0
};

function fail(code, details = {}) { failures.push({ code, ...details }); }
function object(value) { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function finite(value) { return typeof value === 'number' && Number.isFinite(value); }

function readJSON(path, kind) {
  try { return JSON.parse(readFileSync(path, 'utf8')); }
  catch (error) { fail(`invalid-${kind}`, { reason: error.message }); return null; }
}

function inside(candidate, box) {
  return candidate.centerX >= box.left && candidate.centerX <= box.right &&
    candidate.centerY >= box.top && candidate.centerY <= box.bottom;
}

function evaluate(report, annotation) {
  if (!object(report) || !Array.isArray(report.trace) || report.trace.length === 0 ||
      typeof report.source !== 'string' || !report.source || 'error' in report) {
    fail('invalid-report');
    return;
  }
  if (!object(annotation) || typeof annotation.source !== 'string' || !annotation.source ||
      !Array.isArray(annotation.cases) || annotation.cases.length === 0) {
    fail('invalid-annotation');
    return;
  }
  if (report.source !== annotation.source) {
    fail('source-mismatch', { reportSource: report.source, annotationSource: annotation.source });
    return;
  }
  metrics.annotatedFrames = annotation.cases.length;
  for (const [caseIndex, item] of annotation.cases.entries()) {
    const box = item?.targetBox;
    if (!finite(item?.pts) || item.pts < 0 || !object(box) ||
        ![box.left, box.top, box.right, box.bottom].every(finite) ||
        box.left < 0 || box.top < 0 || box.right > 1 || box.bottom > 1 ||
        box.left >= box.right || box.top >= box.bottom ||
        (item.requireCandidate !== undefined && typeof item.requireCandidate !== 'boolean') ||
        (item.requireSelected !== undefined && typeof item.requireSelected !== 'boolean')) {
      fail('invalid-annotation-case', { caseIndex });
      continue;
    }
    const matches = report.trace.filter(frame =>
      finite(frame?.pts) && Math.abs(frame.pts - item.pts) <= toleranceSeconds);
    if (matches.length !== 1) {
      fail('frame-match', { caseIndex, pts: item.pts, matches: matches.length });
      continue;
    }
    metrics.matchedFrames++;
    const frame = matches[0];
    if (!Array.isArray(frame.candidates) ||
        new Set(frame.candidates.map(candidate => candidate?.index)).size !== frame.candidates.length ||
        frame.candidates.some(candidate =>
      !object(candidate) || !Number.isSafeInteger(candidate.index) || candidate.index < 0 ||
      !finite(candidate.centerX) || !finite(candidate.centerY) ||
      candidate.centerX < 0 || candidate.centerX > 1 ||
      candidate.centerY < 0 || candidate.centerY > 1)) {
      fail('invalid-report-frame', { caseIndex, pts: item.pts });
      continue;
    }
    const available = frame.candidates.some(candidate => inside(candidate, box));
    if (available) metrics.targetCandidateFrames++;
    else if (item.requireCandidate !== false) fail('target-candidate-missing', { caseIndex, pts: item.pts });

    const selected = /^selected\(index: (\d+)\)$/.exec(frame.decision);
    if (selected) {
      const candidate = frame.candidates.find(candidate => candidate.index === Number(selected[1]));
      if (!candidate) fail('selected-candidate-missing', { caseIndex, pts: item.pts });
      else if (inside(candidate, box)) metrics.correctSelections++;
      else {
        metrics.wrongPersonSelections++;
        fail('wrong-person-selection', { caseIndex, pts: item.pts, selectedIndex: candidate.index });
      }
    } else if (['noSelection', 'uncertain', 'reselectionRequired'].includes(frame.decision)) {
      metrics.abstentions++;
      if (item.requireSelected === true) fail('target-not-selected', { caseIndex, pts: item.pts });
    } else fail('unknown-decision', { caseIndex, pts: item.pts, decision: frame.decision });
  }
}

if (process.argv.length !== 4) fail('usage', { expected: 'report.json annotation.json' });
else evaluate(readJSON(process.argv[2], 'report'), readJSON(process.argv[3], 'annotation'));
if (metrics.matchedFrames === 0 && metrics.annotatedFrames > 0) fail('no-case-frames');
process.stdout.write(`${JSON.stringify({ status: failures.length ? 'fail' : 'pass', metrics, failures })}\n`);
process.exitCode = failures.length ? 1 : 0;
