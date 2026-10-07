import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { toolEnvironment } from '../../.github/tatagate/tools.mjs';
import { jobIdentity as android, workflowSteps as androidSteps } from './android.mjs';
import { jobIdentity as ios, workflowSteps as iosSteps } from './ios.mjs';

test('CitizenApp两个Release Job保留准确身份且共用唯一版本实现', () => {
  assert.deepEqual([android, ios].map(value => `${value.pipeline}:${value.job}`).sort(), [
    'citizenapp.android.release:android', 'citizenapp.ios.release:ios',
  ]);
  // 所属仓一次验真四份正式工具，Shell语法校验只使用交付的GNU Bash及封闭环境。
  const environment = toolEnvironment();
  for (const steps of [androidSteps, iosSteps]) {
    assert.ok(Object.values(steps).some(step => step.source.includes('scripts/release/version.mjs')));
    for (const step of Object.values(steps)) {
      const result = spawnSync(environment.PRODUCT_BASH_BIN, ['--noprofile', '--norc', '-n'], {
        input: step.source, env: environment, encoding: 'utf8', timeout: 20_000,
      });
      assert.equal(result.error, undefined);
      assert.equal(result.signal, null);
      assert.equal(result.status, 0, result.stderr);
    }
  }
});

test('CitizenApp Release Workflow只引用两个扁平平台Job', () => {
  for (const platform of ['android', 'ios']) {
    const workflow = readFileSync(new URL(`../../.github/workflows/citizenapp-${platform}-release.yml`, import.meta.url), 'utf8');
    assert.match(workflow, new RegExp(`scripts/release/${platform}[.]mjs`, 'u'));
    assert.doesNotMatch(workflow, /scripts\/release\/(?:android|ios)\//u);
  }
  const sources = ['./android.mjs', './ios.mjs'].map(path => readFileSync(new URL(path, import.meta.url), 'utf8'));
  for (const source of sources) assert.doesNotMatch(source, /github-release|function runExactWorkflowStep/u);
});


test('Android Release的Pub、Gradle与产物回读消费同一轮目录', () => {
  assert.match(androidSteps['6'].source, /create-android/u);
  assert.match(androidSteps['7'].source, /project="\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['7'].source, /CITIZENAPP_PROJECT_ROOT/u);
  assert.match(androidSteps['7'].source, /CITIZENAPP_BUILD_DIR/u);
  assert.match(androidSteps['7'].source, /ln -s "\$build" "\$project\/build"/u);
  assert.match(androidSteps['8'].source, /^cd "\$CITIZENAPP_PROJECT_ROOT"/u);
  assert.match(androidSteps['9'].source, /verify_archive build\/app\/outputs/u);
  assert.match(iosSteps['5'].source, /citizenapp-view\.mjs/u);
});

// 准确入口缺失或漂移必须在执行Release脚本正文前失败，不借用系统PATH。
test('Release合同Shell拒绝缺失相对路径与错误Bash版本', () => {
  for (const path of [undefined, '', 'bash', './bash', process.execPath]) {
    assert.throws(() => toolEnvironment({ ...process.env, PRODUCT_BASH_BIN: path }), /App门禁工具/u);
  }
});

// 用真实交付的GNU Bash执行语法失败分支，确保坏正文无法记为成功。
test('Release合同Shell的无效正文由真实GNU Bash拒绝', () => {
  const environment = toolEnvironment();
  const result = spawnSync(environment.PRODUCT_BASH_BIN, ['--noprofile', '--norc', '-n'], {
    input: 'if then\n', env: environment, encoding: 'utf8', timeout: 20_000,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /syntax error/u);
});
