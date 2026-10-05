#!/usr/bin/env node
import { readFileSync } from 'node:fs';

// The input is a private app diagnostic. A selected state is not proof of identity.
function summarize(report) {
  if (!report || typeof report.source !== 'string' || !report.source ||
      !['first-pass-completed', 'selection-completed'].includes(report.stage) ||
      typeof report.selectionRequested !== 'boolean' ||
      report.selectionRequested !== (report.stage === 'selection-completed') ||
      !Number.isFinite(report.recordedAt) ||
      !Array.isArray(report.trace) || report.trace.length === 0) {
    throw new Error('invalid-report');
  }
  let previousTime = -Infinity;
  let previousDecision;
  let firstSelectedAt = null;
  let firstLoss = null;
  let firstReselectionAt = null;
  let reselectionTransitions = 0;
  let reselectionFrames = 0;
  for (const frame of report.trace) {
    if (!Number.isFinite(frame?.pts) || frame.pts < 0 || frame.pts <= previousTime ||
        !Array.isArray(frame.candidates) || frame.candidates.some(candidate =>
          !Number.isSafeInteger(candidate?.index) || candidate.index < 0) ||
        new Set(frame.candidates.map(candidate => candidate.index)).size !== frame.candidates.length ||
        !(/^(selected\(index: \d+\)|noSelection|uncertain|reselectionRequired)$/.test(frame.decision))) {
      throw new Error('invalid-trace');
    }
    const selected = /^selected\(index: (\d+)\)$/.exec(frame.decision);
    if (selected && !frame.candidates.some(candidate => candidate.index === Number(selected[1]))) {
      throw new Error('invalid-trace');
    }
    previousTime = frame.pts;
    if (frame.decision.startsWith('selected(') && firstSelectedAt === null) firstSelectedAt = frame.pts;
    if (firstSelectedAt !== null && firstLoss === null &&
        ['noSelection', 'uncertain', 'reselectionRequired'].includes(frame.decision)) {
      firstLoss = { pts: frame.pts, decision: frame.decision, candidateCount: frame.candidates.length };
    }
    if (frame.decision === 'reselectionRequired') {
      reselectionFrames++;
      if (previousDecision !== frame.decision) reselectionTransitions++;
      if (firstSelectedAt !== null && firstReselectionAt === null) firstReselectionAt = frame.pts;
    }
    previousDecision = frame.decision;
  }
  const recordedAtDate = new Date((report.recordedAt + 978307200) * 1000);
  if (!Number.isFinite(recordedAtDate.getTime())) throw new Error('invalid-report');
  return { status: 'ok', source: report.source, model: report.model ?? null,
    stage: report.stage, recordedAt: report.recordedAt,
    recordedAtISO8601: recordedAtDate.toISOString(),
    selectionCompleted: report.stage === 'selection-completed' && report.selectionRequested,
    selectionMode: report.selectionRequested ? 'explicit' : firstSelectedAt !== null ? 'automatic' : 'none',
    frames: report.trace.length, firstSelectedAt, firstLoss, firstReselectionAt,
    reselectionTransitions, reselectionFrames };
}

try {
  if (process.argv.length !== 3) throw new Error('usage: report.json');
  const report = JSON.parse(readFileSync(process.argv[2], 'utf8'));
  process.stdout.write(`${JSON.stringify(summarize(report))}\n`);
} catch (error) {
  process.stdout.write(`${JSON.stringify({ status: 'error', error: error.message })}\n`);
  process.exitCode = 1;
}
