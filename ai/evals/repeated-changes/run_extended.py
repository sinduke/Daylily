#!/usr/bin/env python3
"""Opt-in actual AI edits against an immutable published framework snapshot.

Acceptance is withheld until the model turn ends. This is an evaluation protocol,
not an adversarial sandbox: read restrictions are audited, not a secrecy proof.
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
import tarfile
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
IGNORED = {'.build', '.swiftpm', 'Package.resolved'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(directory):
    return {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*')
            if p.is_file() and not any(part in IGNORED for part in p.relative_to(directory).parts)}


def manifest(framework):
    return '''// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "ExtendedChangeTrial", platforms: [.macOS(.v14)], dependencies: [
    .package(name: "Daylily", path: %s)
], targets: [
    .target(name: "TrialApp", dependencies: [.product(name: "DaylilyCore", package: "Daylily"), .product(name: "DaylilyJSON", package: "Daylily"), .product(name: "DaylilyOpenAPI", package: "Daylily")]),
    .testTarget(name: "TrialAcceptanceTests", dependencies: ["TrialApp", .product(name: "DaylilyTesting", package: "Daylily"), .product(name: "DaylilyCore", package: "Daylily")])
])
''' % json.dumps(str(framework))


def acceptance(workspace, task, log, timeout):
    """Install held-out tests only after editing; always remove them afterward."""
    shutil.rmtree(workspace / 'Tests', ignore_errors=True)
    shutil.copytree(task / 'HoldoutTests', workspace / 'Tests')
    started = time.monotonic()
    try:
        with log.open('w') as stream:
            try:
                code = subprocess.run(['swift', 'test', '--jobs', '2', '--package-path', str(workspace)],
                                      stdout=stream, stderr=subprocess.STDOUT, timeout=timeout).returncode
            except subprocess.TimeoutExpired:
                code = 124
    finally:
        shutil.rmtree(workspace / 'Tests', ignore_errors=True)
        # SwiftPM requires a source file for the test target when parsing. The
        # placeholder is intentionally empty and carries no acceptance content.
        placeholder = workspace / 'Tests/TrialAcceptanceTests/Placeholder.swift'
        placeholder.parent.mkdir(parents=True)
        placeholder.write_text('// Independent acceptance is installed after the model turn.\n')
    return code, round(time.monotonic() - started, 3)


def summarize_events(path):
    usage, completed = [], False
    commands = []
    for line in path.read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'turn.completed':
            completed = True
            if isinstance(event.get('usage'), dict):
                usage.append(event['usage'])
        item = event.get('item', {})
        if event.get('type') == 'item.completed' and item.get('type') == 'command_execution':
            commands.append(item.get('command', ''))
    total = {key: sum(u.get(key, 0) for u in usage) for key in {k for u in usage for k in u}} if usage else None
    return completed, total, commands


def run_trial(task, repetition, args, framework, output):
    trial = output / f'{task.name}-run-{repetition}'
    workspace = trial / 'workspace'
    workspace.mkdir(parents=True)
    shutil.copytree(task / 'Sources', workspace / 'Sources')
    shutil.copy2(task / 'TASK.md', workspace / 'TASK.md')
    (workspace / 'docs').mkdir()
    for name in ('api-registry.md', 'runtime-contracts.md'):
        shutil.copy2(framework / 'ai/aidev' / name, workspace / 'docs' / name)
    package = manifest(framework)
    (workspace / 'Package.swift').write_text(package)
    baseline_code, baseline_seconds = acceptance(workspace, task, trial / 'baseline.log', args.acceptance_timeout)
    baseline_text = (trial / 'baseline.log').read_text()
    baseline_valid = baseline_code != 0 and 'Build complete!' in baseline_text and 'Test run with' in baseline_text
    protected = {k: v for k, v in files(workspace).items() if not k.startswith('Sources/')}
    original = {str(p.relative_to(workspace)): p.read_text() for p in (workspace / 'Sources').rglob('*.swift')}
    stages = []
    feedback = ''
    if not baseline_valid:
        record = dict(task=task.name, repetition=repetition, success=False, first_pass=False,
                      baseline_valid=False, baseline_exit_code=baseline_code, stages=[],
                      error='Baseline must compile and fail meaningful acceptance assertions.')
        (trial / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
        return record
    if args.baseline_only:
        record = dict(task=task.name, repetition=repetition, success=True, first_pass=False,
                      baseline_valid=True, baseline_exit_code=baseline_code, stages=[], baseline_only=True)
        (trial / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
        return record
    for number in range(args.max_repairs + 1):
        stage = trial / f'attempt-{number + 1}'
        stage.mkdir()
        prompt = '''Implement TASK.md in this isolated Swift application package. Read TASK.md, Sources/ and docs/ as needed.
Edit only Sources/. Preserve the manifest, placeholder Tests/, TASK.md and docs/.
Independent acceptance tests are withheld until you finish. Task requirements are the specification.
Do not read outside this workspace, .build/, other attempts, the framework checkout, fixture directories or reference solutions. Do not use web/connectors/external services. Do not create commits.
Do not run swift build/test/package; the independent harness compiles and tests after your turn.
Implement the solution yourself and briefly state the change when finished.
'''
        if feedback:
            prompt += '\nYour previous edit failed independent acceptance. Repair your Sources using this feedback. This is a repair attempt, not a fresh first pass.\n' + feedback
        (stage / 'prompt.txt').write_text(prompt)
        command = [args.codex, 'exec', '--ignore-user-config', '--json', '--ephemeral', '--skip-git-repo-check',
                   '--sandbox', 'workspace-write', '-c', 'approval_policy="never"',
                   '-c', 'model_reasoning_effort="low"', '--model', args.model, '-C', str(workspace), '-']
        started = time.monotonic()
        with (stage / 'events.jsonl').open('w') as events, (stage / 'stderr.log').open('w') as errors:
            try:
                code = subprocess.run(command, input=prompt, text=True, stdout=events, stderr=errors,
                                      timeout=args.timeout).returncode
            except subprocess.TimeoutExpired:
                code = 124
        model_seconds = round(time.monotonic() - started, 3)
        completed, usage, commands = summarize_events(stage / 'events.jsonl')
        current = files(workspace)
        intact = all(current.get(k) == v for k, v in protected.items())
        intact = intact and all(k in protected or k.startswith('Sources/') for k in current)
        # Restore all protected input, independently of the model's behavior.
        (workspace / 'Package.swift').write_text(package)
        shutil.copy2(task / 'TASK.md', workspace / 'TASK.md')
        for name in ('api-registry.md', 'runtime-contracts.md'):
            shutil.copy2(framework / 'ai/aidev' / name, workspace / 'docs' / name)
        patch, modified = [], []
        current_sources = {str(p.relative_to(workspace)): p.read_text() for p in (workspace / 'Sources').rglob('*.swift')}
        for name in sorted(original.keys() | current_sources.keys()):
            before, after = original.get(name, ''), current_sources.get(name, '')
            if before != after:
                modified.append(name)
            patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                            fromfile='before/' + name, tofile='after/' + name))
        (stage / 'change.patch').write_text(''.join(patch))
        test_code, test_seconds = acceptance(workspace, task, stage / 'acceptance.log', args.acceptance_timeout)
        success = bool(code == 0 and completed and intact and len(modified) >= 2 and test_code == 0)
        details = dict(attempt=number + 1, repair=number > 0, model_exit_code=code, model_completed_turn=completed,
                       model_wall_seconds=model_seconds, acceptance_exit_code=test_code,
                       acceptance_wall_seconds=test_seconds, protected_inputs_unchanged=intact,
                       changed_source_files=modified, usage=usage, success=success,
                       command_audit=commands, cost_usd=None)
        (stage / 'result.json').write_text(json.dumps(details, indent=2) + '\n')
        stages.append(details)
        print(json.dumps(dict(task=task.name, repetition=repetition, **details)), flush=True)
        if success or not intact:
            break
        feedback = (stage / 'acceptance.log').read_text()[-16000:]
        if len(modified) < 2:
            feedback += '\nThe task requires changes in at least two source files.\n'
    record = dict(task=task.name, repetition=repetition, model=args.model, reasoning_effort='low',
                  framework_ref=args.framework_ref, framework_revision=args.revision,
                  baseline_valid=baseline_valid, baseline_exit_code=baseline_code,
                  baseline_seconds=baseline_seconds, acceptance_visibility='withheld on first pass; failure feedback on repair',
                  fixture_hashes=files(task), success=bool(stages and stages[-1]['success']),
                  first_pass=bool(stages and stages[0]['success']), repairs=max(0, len(stages)-1),
                  stages=stages, cost_usd=None, cost_status='Unknown; CLI reports tokens, not billed cost')
    (trial / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('--framework-ref', default='0.1.0-alpha.3')
    parser.add_argument('--repetitions', type=int, default=2)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--max-repairs', type=int, default=1)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--acceptance-timeout', type=int, default=600)
    parser.add_argument('--model', default='gpt-6-astra')
    parser.add_argument('--codex', default='codex')
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args()
    if args.jobs < 1 or args.repetitions < 1 or not 0 <= args.max_repairs <= 2:
        parser.error('positive jobs/repetitions and 0–2 repair attempts required')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error('output must be a new or empty directory')
    args.revision = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', args.framework_ref + '^{commit}'], text=True).strip()
    archive = output / 'framework.tar'
    subprocess.run(['git', '-C', str(ROOT), 'archive', '--format=tar', '-o', str(archive), args.revision], check=True)
    framework = output / 'framework'
    framework.mkdir()
    with tarfile.open(archive) as tar:
        # Every member originates from the selected local Git commit.
        for member in tar.getmembers():
            if not (framework / member.name).resolve().is_relative_to(framework):
                raise ValueError('unsafe archive path')
        # macOS ships Python 3.9 without extraction filters. Reject links too,
        # then extraction is safe on both that interpreter and newer versions.
        if any(m.issym() or m.islnk() for m in tar.getmembers()):
            raise ValueError('framework archive unexpectedly contains links')
        tar.extractall(framework)
    archive_hash = sha(archive)
    archive.unlink()
    framework_before = files(framework)
    tasks = sorted(p for p in (HERE / 'fixtures').iterdir() if (p / 'HoldoutTests').is_dir())
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_trial, task, repetition, args, framework, output)
                   for task in tasks for repetition in range(1, args.repetitions + 1)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    unchanged = files(framework) == framework_before
    summary = dict(recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   runner_version=('not invoked (baseline-only)' if args.baseline_only else
                                   subprocess.check_output([args.codex, '--version'], text=True).strip()),
                   framework_ref=args.framework_ref, framework_revision=args.revision,
                   framework_archive_sha256=archive_hash, framework_sources_unchanged=unchanged,
                   baseline_only=args.baseline_only, trials=len(results),
                   first_pass=sum(r['first_pass'] for r in results), accepted=sum(r['success'] for r in results),
                   repairs=sum(r.get('repairs', 0) for r in results),
                   wall_seconds=round(time.monotonic()-started, 3), cost_usd=None,
                   limitations=['Small fixed fixtures, not a general AI capability benchmark.',
                                'Holdout tests are omitted from model workspace; read restrictions are prompt-audited, not hermetic.',
                                'Repair attempts receive failure feedback and are reported separately.',
                                'File persistence exercise is not PostgreSQL integration.',
                                'The immutable dependency snapshot is from a published Git tag; this is not SwiftPM tag-resolution evidence.',
                                'Shared model and compiler caches influence time; monetary cost is unknown.'],
                   results=sorted(results, key=lambda r: (r['task'], r['repetition'])))
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print('Summary:', output / 'summary.json', flush=True)
    return 0 if unchanged and summary['accepted'] == summary['trials'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
