#!/usr/bin/env node
// Private diagnostic render only: overlays actual app trace, never fabricates detections.
import { execFileSync } from 'node:child_process';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { basename, join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';

function safeText(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

export function frameOverlaySvg(frame, events, width, height, deviceLabel = 'SIMULADOR IPHONE 15') {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) {
    throw new Error('Invalid video dimensions');
  }
  const match = /^selected\(index: (\d+)\)$/.exec(frame.decision);
  const selectedIndex = match ? Number(match[1]) : null;
  const count = events.filter((event) => event.timestamp <= frame.pts).length;
  const state = selectedIndex !== null ? 'ALVO SELECIONADO'
    : frame.decision === 'uncertain' ? 'IDENTIDADE INCERTA — PAUSADO'
    : frame.decision === 'reselectionRequired' ? 'TOQUE PARA SELECIONAR NOVAMENTE'
    : 'AGUARDANDO SELEÇÃO';
  const narrow = width < 600;
  const headerHeight = narrow ? 96 : Math.max(56, Math.round(height * 0.095));
  const fontSize = Math.max(18, Math.round(height * 0.035));
  const elements = [
    `<rect x="0" y="0" width="${width}" height="${headerHeight}" fill="#07161b" opacity="0.86"/>`,
    narrow
      ? `<text x="14" y="32" fill="#f7fbfc" font-family="Arial" font-size="26" font-weight="bold">CONTAGEM ${count}</text><text x="14" y="59" fill="#38f2a7" font-family="Arial" font-size="17">${safeText(state)}</text><text x="14" y="82" fill="#b5c6cc" font-family="Arial" font-size="14">${safeText(deviceLabel)}</text>`
      : `<text x="14" y="${Math.round(headerHeight * 0.42)}" fill="#f7fbfc" font-family="Arial" font-size="${fontSize}" font-weight="bold">CONTAGEM ${count} · ${safeText(state)}</text><text x="14" y="${Math.round(headerHeight * 0.76)}" fill="#b5c6cc" font-family="Arial" font-size="${Math.max(12, fontSize - 7)}">${safeText(deviceLabel)} · TRAÇO REAL DO APP</text>`
  ];
  for (const candidate of frame.candidates) {
    const x = Math.round((candidate.centerX - candidate.width / 2) * width);
    const y = Math.round((candidate.centerY - candidate.height / 2) * height);
    const boxWidth = Math.round(candidate.width * width);
    const boxHeight = Math.round(candidate.height * height);
    if (![x, y, boxWidth, boxHeight].every(Number.isFinite) || boxWidth <= 0 || boxHeight <= 0) continue;
    const selected = candidate.index === selectedIndex;
    const color = selected ? '#38f2a7' : '#f9aa44';
    // ImageMagick's SVG delegate omits stroke-only rectangles on some builds.
    // Four filled bars preserve the evidence overlay across renderers.
    for (const [barX, barY, barWidth, barHeight] of [
      [x, y, boxWidth, 4], [x, y + boxHeight - 4, boxWidth, 4],
      [x, y, 4, boxHeight], [x + boxWidth - 4, y, 4, boxHeight]
    ]) {
      elements.push(`<rect x="${barX}" y="${barY}" width="${barWidth}" height="${barHeight}" fill="${color}"/>`);
    }
  }
  const footerHeight = Math.max(38, Math.round(height * 0.06));
  elements.push(`<rect x="0" y="${height - footerHeight}" width="${width}" height="${footerHeight}" fill="#07161b" opacity="0.88"/>`);
  elements.push(`<text x="14" y="${height - Math.round(footerHeight * 0.34)}" fill="#f7fbfc" font-family="Arial" font-size="${Math.max(12, fontSize - 8)}">${narrow ? 'SEM REFERÊNCIA HUMANA' : 'SEM ANOTAÇÃO HUMANA · NÃO MEDE PRECISÃO'}</text>`);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${elements.join('')}</svg>`;
}

export function writeOverlayPng(svg, path) {
  execFileSync('magick', ['-background', 'none', 'svg:-', path],
    { input: svg, stdio: ['pipe', 'ignore', 'pipe'] });
}

function inspectVideo(source) {
  const raw = execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height,r_frame_rate,nb_read_frames', '-of', 'json', source],
  { encoding: 'utf8' });
  const stream = JSON.parse(raw).streams?.[0];
  if (!stream) throw new Error('Video has no image stream');
  const frameTimes = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'csv=p=0', source],
  { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean).map(Number.parseFloat);
  return { width: stream.width, height: stream.height, fps: stream.r_frame_rate,
    frameCount: Number(stream.nb_read_frames), frameTimes };
}

export function validateFrameTimeline(trace, sourceTimes, fps) {
  if (trace.length !== sourceTimes.length) throw new Error('Frame count mismatch');
  if (!Number.isFinite(fps) || fps <= 0) throw new Error('Invalid frame rate');
  const tolerance = 0.003;
  if (Math.abs(sourceTimes[0]) > tolerance || Math.abs(trace[0]?.pts) > tolerance) {
    throw new Error('Frame timeline offset is unsupported');
  }
  for (let index = 0; index < trace.length; index++) {
    const expected = index / fps;
    if (!Number.isFinite(sourceTimes[index]) ||
        Math.abs(sourceTimes[index] - expected) > tolerance) {
      throw new Error(`Source has non-uniform frame timing at ${index}`);
    }
    if (!Number.isFinite(trace[index].pts) ||
        Math.abs(trace[index].pts - sourceTimes[index]) > tolerance) {
      throw new Error(`Trace/source timestamp mismatch at ${index}`);
    }
  }
}

export function renderDiagnostic(reportPath, source, output, deviceLabel = 'SIMULADOR IPHONE 15') {
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  if (report.source !== basename(source)) throw new Error('Report and source filename differ');
  if (!Array.isArray(report.trace) || report.trace.length === 0) throw new Error('Report has no frame trace');
  const video = inspectVideo(source);
  if (report.trace.length !== video.frameCount) {
    throw new Error(`Frame trace mismatch: ${report.trace.length} vs ${video.frameCount}`);
  }
  const [numerator, denominator] = video.fps.split('/').map(Number);
  validateFrameTimeline(report.trace, video.frameTimes, numerator / denominator);
  const scratch = mkdtempSync(join(tmpdir(), 'ritmovis-qa-video-'));
  try {
    for (const [index, frame] of report.trace.entries()) {
      const svg = frameOverlaySvg(frame, report.events ?? [], video.width, video.height, deviceLabel);
      const image = join(scratch, `overlay-${String(index).padStart(6, '0')}.png`);
      writeOverlayPng(svg, image);
    }
    execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      '-i', source, '-framerate', video.fps, '-i', join(scratch, 'overlay-%06d.png'),
      '-filter_complex', '[0:v][1:v]overlay=shortest=1:format=auto,scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black',
      '-an', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', output],
    { stdio: 'inherit' });
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 5 && process.argv.length !== 6) {
    console.error('Usage: node tools/render-qa-video.mjs report.json source.mp4 output.mp4 [device-label]');
    process.exitCode = 2;
  } else {
    renderDiagnostic(process.argv[2], process.argv[3], process.argv[4], process.argv[5]);
  }
}
