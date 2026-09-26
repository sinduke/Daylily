#!/usr/bin/env python3
"""Run real independent Codex edits; never copy a reference implementation.

Requires an existing ChatGPT Codex login; no API keys or paid services provisioned.
Raw transcripts stay in the requested result directory. Review before publication.
"""
import argparse
import concurrent.futures
import datetime
import difflib
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_one(task, repetition, args, output):
    trial = output / (task.name + '-run-' + str(repetition))
    trial.mkdir()
    workspace = trial / 'workspace'
    shutil.copytree(task, workspace)
    (workspace / 'docs').mkdir()
    for filename in ('runtime-contracts.md', 'api-registry.md'):
        shutil.copy2(ROOT / 'ai/aidev' / filename, workspace / 'docs' / filename)
    manifest = '''// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "IndependentChangeTrial", platforms: [.macOS(.v14)], dependencies: [
    .package(name: "Daylily", path: %s)
], targets: [
    .target(name: "TrialApp", dependencies: [.product(name: "DaylilyCore", package: "Daylily"), .product(name: "DaylilyJSON", package: "Daylily"), .product(name: "DaylilyOpenAPI", package: "Daylily")]),
    .testTarget(name: "TrialAcceptanceTests", dependencies: ["TrialApp", .product(name: "DaylilyTesting", package: "Daylily"), .product(name: "DaylilyCore", package: "Daylily"), .product(name: "DaylilyOpenAPI", package: "Daylily")])
])
''' % json.dumps(str(ROOT))
    (workspace / 'Package.swift').write_text(manifest)
    immutable = {str(p.relative_to(workspace)): digest(p) for p in workspace.rglob('*') if p.is_file() and 'Sources' not in p.parts}
    original = {str(p.relative_to(workspace)): p.read_text() for p in (workspace / 'Sources').rglob('*.swift')}
    prompt = '''Implement the application change described in TASK.md in this isolated Swift package.
Read TASK.md, Sources, the immutable acceptance tests, and provided docs as needed.
Edit only files under Sources/. Do not modify Package.swift, Tests/, TASK.md, or docs/.
Do not inspect any directories outside this workspace, other attempts, completed reference solutions, or the framework checkout. Use no web, connectors, or external services. Do not create commits.
Implement the change yourself; no reference result is available in this workspace.
Do not run swift build/test/package: an independent harness runs the fixed acceptance tests after you finish. This keeps dependency resolution and verification outside model wall time.
When done, briefly state the change.\n'''
    (trial / 'prompt.txt').write_text(prompt)
    command = [args.codex, 'exec', '--ignore-user-config', '--json', '--ephemeral', '--skip-git-repo-check',
               '--sandbox', 'workspace-write', '-c', 'approval_policy="never"', '-c', 'model_reasoning_effort="low"',
               '--model', args.model, '-C', str(workspace), '-']
    started = time.time()
    with (trial / 'events.jsonl').open('w') as events, (trial / 'stderr.log').open('w') as errors:
        try:
            process = subprocess.run(command, input=prompt, text=True, stdout=events, stderr=errors, timeout=args.timeout)
            exit_code = process.returncode
        except subprocess.TimeoutExpired:
            exit_code = 124
    model_seconds = time.time() - started
    usages = []
    changed = []
    completed_turn = False
    for line in (trial / 'events.jsonl').read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'turn.completed':
            completed_turn = True
            if isinstance(event.get('usage'), dict):
                usages.append(event['usage'])
        if event.get('type') == 'item.completed' and event.get('item', {}).get('type') == 'file_change':
            changed.extend(change.get('path') for change in event['item'].get('changes', []))
    usage = {key: sum(value.get(key, 0) for value in usages) for key in {k for u in usages for k in u}} if usages else None
    protected_intact = all((workspace / name).is_file() and digest(workspace / name) == value for name, value in immutable.items())
    for file in workspace.rglob('*'):
        if file.is_file() and str(file.relative_to(workspace)) not in immutable and file.relative_to(workspace).parts[0] != 'Sources':
            protected_intact = False
    patch = []
    for file in sorted((workspace / 'Sources').rglob('*.swift')):
        relative = str(file.relative_to(workspace))
        patch.extend(difflib.unified_diff(original.get(relative, '').splitlines(True), file.read_text().splitlines(True), fromfile='before/' + relative, tofile='after/' + relative))
    (trial / 'change.patch').write_text(''.join(patch))
    acceptance_started = time.time()
    # Reinstall immutable acceptance input before running it, even if the agent altered it.
    shutil.rmtree(workspace / 'Tests', ignore_errors=True)
    shutil.copytree(task / 'Tests', workspace / 'Tests')
    (workspace / 'Package.swift').write_text(manifest)
    with (trial / 'acceptance.log').open('w') as log:
        try:
            acceptance = subprocess.run(['swift', 'test', '--package-path', str(workspace)], stdout=log, stderr=subprocess.STDOUT, timeout=args.acceptance_timeout)
            acceptance_code = acceptance.returncode
        except subprocess.TimeoutExpired:
            acceptance_code = 124
    record = dict(task=task.name, repetition=repetition, model=args.model, reasoning_effort='low',
                  runner='codex exec --json --ephemeral', source='independent-model-edit',
                  started_at=datetime.datetime.fromtimestamp(started, datetime.timezone.utc).isoformat(),
                  model_exit_code=exit_code, model_completed_turn=completed_turn,
                  model_wall_seconds=round(model_seconds, 3), acceptance_wall_seconds=round(time.time() - acceptance_started, 3),
                  total_wall_seconds=round(time.time() - started, 3), usage=usage,
                  cost_usd=None, cost_status='unknown: ChatGPT CLI does not report a billed per-run cost',
                  protected_inputs_unchanged=protected_intact, nonempty_patch=bool(patch),
                  reported_file_changes=changed, acceptance_exit_code=acceptance_code,
                  success=bool(exit_code == 0 and completed_turn and protected_intact and patch and acceptance_code == 0),
                  provided_docs_sha256={str(p.relative_to(workspace)): digest(p) for p in (workspace / 'docs').rglob('*.md')},
                  fixture_sha256={name: hashlib.sha256(text.encode()).hexdigest() for name, text in original.items()},
                  evidence=dict(transcript='events.jsonl', patch='change.patch', acceptance='acceptance.log'))
    (trial / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({k: record[k] for k in ('task', 'repetition', 'success', 'model_wall_seconds', 'usage')}), flush=True)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--repetitions', type=int, default=2)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--model', default='gpt-6-astra')
    parser.add_argument('--codex', default='codex')
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--acceptance-timeout', type=int, default=600)
    args = parser.parse_args()
    if args.repetitions < 1 or args.jobs < 1:
        parser.error('repetitions and jobs must be positive')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error('output must be empty')
    tasks = sorted(p for p in (HERE / 'fixtures').iterdir()
                   if p.is_dir() and (p / 'TASK.md').is_file() and (p / 'Tests').is_dir())
    version = subprocess.check_output([args.codex, '--version'], text=True).strip()
    started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_one, task, repetition, args, output) for task in tasks for repetition in range(1, args.repetitions + 1)]
        records = [future.result() for future in concurrent.futures.as_completed(futures)]
    summary = dict(recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(), runner_version=version,
                   framework_revision=subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
                   framework_working_tree_changes=bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True)),
                   wall_seconds=round(time.time() - started, 3), attempts=len(records), accepted=sum(r['success'] for r in records),
                   cost_usd=None, cost_status='unknown; no usage-to-price estimate was substituted',
                   limitations=['Six narrow fixed tasks are not a general capability benchmark.', 'Acceptance uses in-memory Daylily TestClient.', 'No model retries or copied reference solution.', 'Local framework dependency includes working-tree changes; this is not release-pin evidence.'],
                   results=sorted(records, key=lambda r: (r['task'], r['repetition'])))
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print('Summary:', output / 'summary.json', flush=True)
    return 0 if summary['accepted'] == summary['attempts'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
