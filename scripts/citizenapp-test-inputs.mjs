#!/usr/bin/env node
// App金标读取链所有者已保存的不可变Git快照；不复制金标，不猜测邻仓。
import { spawnSync } from 'node:child_process';
import { readFileSync, lstatSync, realpathSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join, resolve, isAbsolute } from 'node:path';
const source = realpathSync(fileURLToPath(new URL('..', import.meta.url)));
const contract = JSON.parse(readFileSync(join(source, 'scripts/test-inputs.json'), 'utf8'));
const url = 'https://github.com/crcfrcn/citizenchain.git';
function fail(value) { throw Error(value); }
function directory(p) {
  const i = lstatSync(p);
  if (!i.isDirectory() || i.isSymbolicLink() || realpathSync(p) !== p) fail('链测试源目录无效');
}
function git(root, args) {
  const result = spawnSync('git', ['-c', 'credential.helper=', '-c', 'core.hooksPath=/dev/null',
    '-c', 'protocol.file.allow=never', '-c', 'gc.auto=0', '-C', root, ...args], {
    encoding: 'utf8', env: { ...process.env, GIT_TERMINAL_PROMPT: '0',
      GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null' },
  });
  if (result.error || result.status !== 0) fail('链测试源取得或验真失败');
  return result.stdout.trim();
}
try {
  if (process.argv.length !== 3 || contract.schema !== 1 || contract.citizenchain?.url !== url
      || contract.citizenchain.ref !== 'main'
      || contract.citizenchain.paths.join('\n') !==
      'runtime/primitives/tests/fixtures/scale_codec_vectors.json\nruntime/tests/fixtures/role_permission.json') fail('链测试输入合同无效');
  const work = process.argv[2];
  if (!isAbsolute(work) || resolve(work) !== work || work === source || work.startsWith(source + '/')) fail('链测试工作根必须是源码外绝对路径');
  directory(work);
  let root = process.env.CITIZENCHAIN_ROOT;
  let expected;
  if (root) {
    if (!isAbsolute(root) || resolve(root) !== root) fail('明确链测试源不是绝对路径');
    expected = git(root, ['rev-parse', 'HEAD']);
  } else {
    root = join(work, 'chain-test-source');
    if (existsSync(root)) fail('链测试源目录已存在，拒绝混入旧输入');
    const reference = git(work, ['ls-remote', '--refs', url, 'refs/heads/main']);
    const match = /^([0-9a-f]{40})\s+refs\/heads\/main$/.exec(reference);
    if (!match) fail('链测试main没有唯一实际提交');
    expected = match[1]; mkdirSync(root, { mode: 0o700 }); const owned = lstatSync(root);
    try {
      git(root, ['init', '--quiet']); git(root, ['remote', 'add', 'origin', url]);
      git(root, ['fetch', '--no-tags', '--depth=1', 'origin', expected]);
      git(root, ['checkout', '--quiet', '--detach', expected]);
    } catch (error) {
      const now = lstatSync(root, { throwIfNoEntry: false });
      if (now?.isDirectory() && !now.isSymbolicLink() && now.dev === owned.dev && now.ino === owned.ino) rmSync(root, { recursive: true });
      throw error;
    }
  }
  directory(root); directory(join(root, '.git'));
  if (!/^[0-9a-f]{40}$/.test(expected) || git(root, ['rev-parse', 'HEAD']) !== expected
      || git(root, ['rev-parse', '--abbrev-ref', 'HEAD']) !== 'HEAD'
      || resolve(git(root, ['rev-parse', '--show-toplevel'])) !== root
      || resolve(git(root, ['rev-parse', '--absolute-git-dir'])) !== join(root, '.git')
      || resolve(root, git(root, ['rev-parse', '--git-common-dir'])) !== join(root, '.git')
      || git(root, ['remote', 'get-url', 'origin']) !== url
      || git(root, ['status', '--porcelain=v1', '--untracked-files=all'])) fail('链测试Git快照身份无效');
  for (const rel of contract.citizenchain.paths) {
    const p = join(root, rel), info = lstatSync(p);
    if (!info.isFile() || info.isSymbolicLink() || !info.size || realpathSync(p) !== p) fail('链所有者金标缺失或类型无效');
  }
  process.stdout.write(root + '\n');
} catch (error) { process.stderr.write(error.message + '\n'); process.exitCode = 1; }
