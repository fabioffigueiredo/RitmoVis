#!/usr/bin/env node
// Compare an immutable device report with independently labelled private footage.
// Label every event frame; sampled identity coverage is not continuous-time coverage.
import { readFileSync } from 'node:fs';

const frameTolerance = 0.003;
const failures = [];
const metrics = {
  annotatedFrames: 0, observableFrames: 0, correctSelectedFrames: 0,
  wrongSelectedFrames: 0, abstainedFrames: 0, coverage: null,
  creditedToOtherPerson: 0, ambiguousIdentityEvents: 0,
  truePositives: 0, falsePositives: 0,
  falseNegatives: 0, precision: null, recall: null
};
const fail = (code, details = {}) => failures.push({ code, ...details });
const finite = value => typeof value === 'number' && Number.isFinite(value);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);

function load(path, kind) {
  try { return JSON.parse(readFileSync(path, 'utf8')); }
  catch (error) { fail(`invalid-${kind}`, { reason: error.message }); return null; }
}

function strictlyAscending(values) {
  return values.every((value, index) => finite(value) && value >= 0 &&
    (index === 0 || value > values[index - 1]));
}

function validBox(box) {
  return object(box) && [box.left, box.top, box.right, box.bottom].every(finite) &&
    box.left >= 0 && box.top >= 0 && box.right <= 1 && box.bottom <= 1 &&
    box.left < box.right && box.top < box.bottom;
}

function inside(candidate, box) {
  return candidate.centerX >= box.left && candidate.centerX <= box.right &&
    candidate.centerY >= box.top && candidate.centerY <= box.bottom;
}

function atTime(items, time, field) {
  const matches = items.filter(item => Math.abs(item[field] - time) <= frameTolerance);
  return matches.length === 1 ? matches[0] : null;
}

function selection(frame, label) {
  // A target box alone cannot assign identity when two candidate centers overlap.
  // Reject this annotation even if the selected center also lies in the box.
  if (label.observability === 'observable' &&
      frame.candidates.filter(item => inside(item, label.targetBox)).length > 1) {
    return 'ambiguous';
  }
  const selected = /^selected\(index: (\d+)\)$/.exec(frame.decision);
  if (!selected) return 'abstained';
  const person = frame.candidates.find(item => item.index === Number(selected[1]));
  if (!person) return 'invalid';
  return label.observability === 'observable' && inside(person, label.targetBox)
    ? 'correct' : 'wrong';
}

function evaluate(report, labels) {
  if (!object(report) || !report.source || !Array.isArray(report.trace) || !report.trace.length ||
      !Array.isArray(report.events) || 'error' in report ||
      !strictlyAscending(report.trace.map(frame => frame?.pts))) {
    fail('invalid-report'); return;
  }
  if (!strictlyAscending(report.events.map(event => event?.timestamp))) {
    fail('invalid-report-events'); return;
  }
  if (!object(labels) || !labels.source || !['adjustment', 'acceptance'].includes(labels.split) ||
      !finite(labels.toleranceSeconds) || labels.toleranceSeconds < 0 ||
      !Array.isArray(labels.frames) || !labels.frames.length ||
      !Array.isArray(labels.attempts) ||
      !strictlyAscending(labels.frames.map(frame => frame?.pts)) ||
      labels.frames.some(frame => !['observable', 'unobservable', 'absent'].includes(frame.observability) ||
        (frame.observability === 'observable' && !validBox(frame.targetBox)))) {
    fail('invalid-annotation'); return;
  }
  if (labels.source !== report.source) {
    fail('source-mismatch', { reportSource: report.source, labelSource: labels.source }); return;
  }
  const attempts = [...labels.attempts].sort((a, b) => a.startSeconds - b.startSeconds);
  if (attempts.some((attempt, index) => !finite(attempt.startSeconds) || !finite(attempt.endSeconds) ||
      attempt.startSeconds < 0 || attempt.endSeconds <= attempt.startSeconds ||
      typeof attempt.completed !== 'boolean' ||
      (index > 0 && attempt.startSeconds < attempts[index - 1].endSeconds))) {
    fail('invalid-attempts'); return;
  }

  metrics.annotatedFrames = labels.frames.length;
  for (const [index, label] of labels.frames.entries()) {
    const frame = atTime(report.trace, label.pts, 'pts');
    if (!frame || !Array.isArray(frame.candidates) ||
        !['noSelection', 'uncertain', 'reselectionRequired'].includes(frame.decision) &&
        !/^selected\(index: \d+\)$/.test(frame.decision) ||
        frame.candidates.some(candidate => !Number.isSafeInteger(candidate?.index) ||
          !finite(candidate.centerX) || !finite(candidate.centerY) ||
          candidate.centerX < 0 || candidate.centerX > 1 ||
          candidate.centerY < 0 || candidate.centerY > 1) ||
        new Set(frame.candidates.map(candidate => candidate.index)).size !== frame.candidates.length) {
      fail('invalid-or-unmatched-frame', { index, pts: label.pts }); continue;
    }
    if (label.observability === 'observable') metrics.observableFrames++;
    const state = selection(frame, label);
    if (state === 'correct') metrics.correctSelectedFrames++;
    else if (state === 'wrong') metrics.wrongSelectedFrames++;
    else if (state === 'abstained' && label.observability === 'observable') metrics.abstainedFrames++;
    else if (state === 'ambiguous') fail('ambiguous-target-label', { index, pts: label.pts });
    else if (state === 'invalid') fail('invalid-selected-candidate', { index, pts: label.pts });
  }
  metrics.coverage = metrics.observableFrames === 0 ? null :
    metrics.correctSelectedFrames / metrics.observableFrames;

  const validEvents = [];
  for (const [index, event] of report.events.entries()) {
    const label = atTime(labels.frames, event.timestamp, 'pts');
    const frame = atTime(report.trace, event.timestamp, 'pts');
    if (!label || !frame) {
      fail('unlabelled-event', { index, timestamp: event.timestamp }); continue;
    }
    const state = selection(frame, label);
    if (state === 'ambiguous') {
      metrics.ambiguousIdentityEvents++;
      fail('ambiguous-event-identity', { index, timestamp: event.timestamp });
    } else if (state !== 'correct') {
      metrics.creditedToOtherPerson++;
      fail('wrong-person-credit', { index, timestamp: event.timestamp });
    } else validEvents.push(event.timestamp);
  }

  const completions = attempts.filter(item => item.completed).map(item => item.endSeconds);
  let expected = 0;
  let actual = 0;
  while (expected < completions.length && actual < validEvents.length) {
    const delta = validEvents[actual] - completions[expected];
    if (delta < -labels.toleranceSeconds) { metrics.falsePositives++; actual++; }
    else if (delta > labels.toleranceSeconds) { metrics.falseNegatives++; expected++; }
    else { metrics.truePositives++; expected++; actual++; }
  }
  metrics.falseNegatives += completions.length - expected;
  metrics.falsePositives += validEvents.length - actual +
    metrics.creditedToOtherPerson + metrics.ambiguousIdentityEvents;
  const predicted = metrics.truePositives + metrics.falsePositives;
  const annotated = metrics.truePositives + metrics.falseNegatives;
  metrics.precision = predicted ? metrics.truePositives / predicted : null;
  metrics.recall = annotated ? metrics.truePositives / annotated : null;
}

if (process.argv.length !== 4) fail('usage', { expected: 'report.json labels.json' });
else evaluate(load(process.argv[2], 'report'), load(process.argv[3], 'annotation'));
process.stdout.write(`${JSON.stringify({ status: failures.length ? 'fail' : 'pass', metrics, failures })}\n`);
process.exitCode = failures.length ? 1 : 0;
