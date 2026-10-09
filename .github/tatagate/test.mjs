import {gateResourcePlan} from '../../scripts/resources.mjs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { toolEnvironment, exactExecutable, fetchOriginal, validateTar, prepareRunnerTools } from '../../scripts/resources.mjs';
import { fileURLToPath } from 'node:url';
import { gateContract, validateWorkflow, validateWorkflowSource, validateVectorGroup, validatePalletRegistry, readPublicChain } from './index.mjs';

// 本仓登记必须准确闭合；路径、重复和未知工具版本不得被默默接受。
test('本仓门禁登记拒绝漂移和重复', () => {
  const contract = structuredClone(gateContract());
  assert.equal(gateContract(contract), contract);
  // 实际工作流和门禁校验器必须同轮一致，避免Node入口被旧Shell命令登记误拒绝。
  assert.deepEqual(validateWorkflow(fileURLToPath(new URL('../../', import.meta.url))).sort(),
    ['.github/workflows/tatagate.yml', ...contract.workflows.map(id => '.github/workflows/' + id.replaceAll('.', '-') + '.yml')].sort());
  for (const change of [
    value => { value.schema = 2; },
    value => { value.node_tests.push(value.node_tests[0]); },
    value => { value.node_tests = ['../outside.test.mjs']; },
    value => { value.tools.node = '0.0.0'; },
    value => { value.checks.push('undeclared'); },
    value => { value.workflows.push('other.ios.ci'); },
  ]) {
    const value = structuredClone(contract); change(value);
    assert.throws(() => gateContract(value));
  }
});
test('产品CI与Release仍只接受自己的三维手动入口', () => {
  const { repository } = gateContract();
  const id = repository + '.macos.ci';
  const workflow = 'name: ' + id + '\non:\n  workflow_dispatch:\nconcurrency:\n  group: ' + id
    + '\njobs:\n  flow:\n    steps:\n      - run: allowed=new Set(["' + id + '"])\n';
  assert.equal(validateWorkflowSource(workflow,repository+'-macos-ci.yml'),id);
  for (const invalid of [workflow.replace(repository+'.','other.'),workflow.replace('workflow_dispatch','push'),
    workflow.replace('group: '+id,'group: other'),workflow.replace('  flow:','  other:')]) {
    assert.throws(()=>validateWorkflowSource(invalid,repository+'-macos-ci.yml'));
  }
});
const group={ keys:['name'],values:['hex'],top:['domain'],complete:true };
const vectors={domain:'GMB',vectors:[{name:'a',hex:'AB'},{name:'b',hex:'CD'}]};
test('金标按语义键归一比较并阻断重复、缺项和漂移', () => {
  assert.equal(validateVectorGroup(vectors,{...vectors,vectors:[{name:'b',hex:'cd'},{name:'a',hex:'ab'}]},group),2);
  for (const mirror of [
    {...vectors,domain:'other'}, {...vectors,vectors:[vectors.vectors[0]]},
    {...vectors,vectors:[vectors.vectors[0],vectors.vectors[0]]},
    {...vectors,vectors:[{name:'a',hex:'EE'},vectors.vectors[1]]},
    {...vectors,vectors:[{name:'a'},vectors.vectors[1]]},
    {...vectors,vectors:[]},
  ]) assert.throws(()=>validateVectorGroup(vectors,mirror,group));
  assert.equal(validateVectorGroup(vectors,{...vectors,vectors:[vectors.vectors[0]]},{...group,complete:false}),1);
});
test('Pallet不得错指、为空或重复',()=>{
  const chain='#[runtime::pallet_index(1)]\n pub type Balances = PalletBalances;\n';
  assert.equal(validatePalletRegistry(chain,'static const int balancesPallet = 1;'),1);
  for (const dart of ['', 'static const int balancesPallet = 2;', 'static const int otherPallet = 1;',
    'static const int balancesPallet = 1;\nstatic const int balancesPallet = 1;']) {
    assert.throws(()=>validatePalletRegistry(chain,dart));
  }
  assert.throws(()=>validatePalletRegistry(chain+chain));
});
test('公开链真源只读准确SHA，拒绝main、网络、重定向、超限及伪造坐标',async()=>{
 const sha='a'.repeat(40),path='runtime/src/lib.rs';
 assert.equal(await readPublicChain(path,sha,async(url,options)=>{
  assert.equal(url,'https://raw.githubusercontent.com/crcfrcn/citizenchain/'+sha+'/'+path);
  assert.equal(options.redirect,'error');assert.equal(options.credentials,'omit');assert.equal(options.headers.Authorization,undefined);
  return new Response('source');
 }),'source');
 for(const [path,sha]of [[null,null],['../private','a'.repeat(40)],['runtime/src/lib.rs','main'],['runtime/src/lib.rs','a'.repeat(39)]]){
  await assert.rejects(readPublicChain(path,sha,()=>assert.fail('非法坐标禁止联网')));
 }
 for(const request of [async()=>{throw Error('synthetic network failure');},async()=>new Response('',{status:302}),async()=>new Response('',{status:404}),async()=>new Response(Buffer.alloc(2*1024**2+1)),async()=>new Response(new Uint8Array([255]))])await assert.rejects(readPublicChain(path,sha,request),/准确提交真源读取失败/u);
});

// 完整调用跨端校验，确保真实镜像位置也被覆盖；上游响应仅为隔离协议夹具。
test('跨端金标检查消费当前账户镜像路径并保持漂移拒绝', async () => {
  const { readFileSync } = await import('node:fs');
  const { checkCrossPlatform } = await import('./index.mjs');
  const root = fileURLToPath(new URL('../../', import.meta.url));
  const inputs = new Map([
    ['runtime/primitives/tests/fixtures/signing_domain_vectors.json', readFileSync(new URL('../../test/signing/fixtures/signing_domain_vectors.json', import.meta.url), 'utf8')],
    ['runtime/primitives/tests/fixtures/binary_prefix_domain_vectors.json', readFileSync(new URL('../../test/signing/fixtures/binary_prefix_domain_vectors.json', import.meta.url), 'utf8')],
    ['runtime/primitives/tests/fixtures/account_derive_vectors.json', readFileSync(new URL('../../test/citizen/shared/account_derive_vectors.json', import.meta.url), 'utf8')],
    ['runtime/src/lib.rs', ''],
  ]);
  const dart = readFileSync(new URL('../../lib/citizen/shared/pallet_registry.dart', import.meta.url), 'utf8');
  inputs.set('runtime/src/lib.rs', [...dart.matchAll(/static const int (\w+)Pallet = (\d+);/gu)]
    .map(([, name, index]) => `#[runtime::pallet_index(${index})]\n pub type ${name[0].toUpperCase() + name.slice(1)} = SyntheticPallet;\n`).join(''));
  const requested = [];
  const request = async url => {
    const prefix = 'https://raw.githubusercontent.com/crcfrcn/citizenchain/' + gateContract().chain_source.sha + '/';
    assert.ok(url.startsWith(prefix));
    const path = url.slice(prefix.length);
    assert.ok(inputs.has(path));
    requested.push(path);
    return new Response(inputs.get(path));
  };
  const reports = [];
  await checkCrossPlatform(root, { request, report: value => reports.push(value) });
  assert.deepEqual(requested, [...inputs.keys()]);
  assert.equal(reports.length, 1);
  const account = JSON.parse(inputs.get('runtime/primitives/tests/fixtures/account_derive_vectors.json'));
  account.vectors[0].account_id = '0'.repeat(64);
  inputs.set('runtime/primitives/tests/fixtures/account_derive_vectors.json', JSON.stringify(account));
  await assert.rejects(checkCrossPlatform(root, { request, report: () => assert.fail('漂移不得报告成功') }), /密码学值漂移/u);
});

// 用隔离的合成Git提交验证门禁读取真实初始内容；不修改产品仓或调用仓库保存/推送。
test('保留源码不按每文件汉字数量判定，真实第一方临时注释仍拒绝', async () => {
  const [{ mkdtempSync, mkdirSync, writeFileSync, rmSync }, { join }, { testRoot: tmpdir }, { execFileSync }, { validateQuality }] = await Promise.all([
    import('node:fs'), import('node:path'), import('../../scripts/build.mjs'), import('node:child_process'), import('./index.mjs'),
  ]);
  const root = mkdtempSync(join(tmpdir(), 'tatagate-quality-'));
  const env = { ...toolEnvironment(), HOME: process.env.HOME, LANG: 'C', LC_ALL: 'C',
    GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
    GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' };
  const git = (...args) => execFileSync(env.PRODUCT_GIT_BIN, ['-C', root, ...args], { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  try {
    git('init', '--quiet', '--initial-branch=main');
    mkdirSync(join(root, 'test'));
    writeFileSync(join(root, 'test', 'example.test.mjs'), 'export const fixture = true;\n');
    const base = git('hash-object', '-w', '-t', 'tree', '/dev/null');
    for (const [source, rejected] of [
      ['export const value = 1;\n', false],
      ['// Retained implementation explanation.\nexport const value = 1;\n', false],
      ['// Generated file; do not edit.\nexport const value = 1;\n', false],
      ['// HACK: unfinished first-party implementation.\nexport const value = 1;\n', true],
    ]) {
      writeFileSync(join(root, 'source.mjs'), source);
      git('add', '--all');
      const head = git('commit-tree', git('write-tree'), '-m', 'synthetic quality input');
      git('update-ref', 'refs/heads/main', head);
      const run = () => validateQuality(root, base, head, gateContract().repository);
      if (rejected) await assert.rejects(run(), /第一方|产品实现代码保留临时注释/u);
      else await assert.doesNotReject(run());
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// 候选文只作为合成测试数据；准确负向断言可识别，同文伪装和运行地址继续被阻断。
test('协议拒绝断言只归属本仓登记测试中的真实代码', async () => {
  const { protocolAssertionLines } = await import('./index.mjs');
  const path = gateContract().node_tests.find(value => /(?:test|tests)[./_-]/u.test(value) && value.endsWith('.mjs'));
  assert.ok(path);
  const statement = ['assert.doesNotMatch(source, /\\/', 'v', '1(?:\\/|\\b)/);'].join('');
  const line = '  ' + statement;
  assert.deepEqual(protocolAssertionLines(path, 'test(() => {\n' + line + '\n});\n'), [line]);
  for (const source of [
    '/*\n' + line + '\n*/', '`\n' + line + '\n`', JSON.stringify(statement),
    '/*\n' + line + '\n*/\ntest(() => {\n' + line + '\n});',
    statement.replace('doesNotMatch', 'match'), statement.replace('source', 'other'),
    'const endpoint = "https://example.invalid/' + 'v' + '9";',
  ]) assert.deepEqual(protocolAssertionLines(path, source), []);
  assert.deepEqual(protocolAssertionLines('source.mjs', line), []);
  assert.deepEqual(protocolAssertionLines('unregistered.test.mjs', line), []);
});

// 外部索引夹具保留实际字段与真实拒绝，完整字节或执行上下文改变均取消识别。
test('可选原件索引夹具仅按完整执行正文识别，伪装、漂移和其它协议仍拒绝', async () => {
  const [{ readFileSync }, { protocolAssertionLines }] = await Promise.all([import('node:fs'), import('./index.mjs')]);
  const path = 'scripts/resources.mjs', source = readFileSync(new URL('../../scripts/resources.mjs', import.meta.url), 'utf8');
  const field = ['schema', 'version'].join('_');
  // 只比较末尾真实资源测试的三处外部索引夹具；正式实现仍参与生产代码检查。
  const tests = source.slice(source.lastIndexOf('\nif(resourceTestInvocation){\n'));
  const lines = tests.split('\n').filter(line => line.includes(field));
  assert.equal(lines.length, 3);
  assert.deepEqual(protocolAssertionLines(path, source).filter(line => line.includes(field)), lines);
  for (const altered of [source.replace(/2,packages/gu, '3,packages').replace(/1,packages/gu, '2,packages'),
    source.replace("assert.rejects(readDependencySupply(f.objects),/协议/)", "assert.doesNotReject(readDependencySupply(f.objects))"),
    JSON.stringify(source)]) {
    const accepted = protocolAssertionLines(path, altered);
    assert.ok(accepted.filter(line => line.includes(field)).length < lines.length);
  }
  for (const line of lines) assert.ok(!protocolAssertionLines(path, source + '\n/*\n' + line + '\n*/').includes(line));
  assert.deepEqual(protocolAssertionLines('scripts/other.test.mjs', source), []);
  const foreign = 'const endpoint = "https://example.invalid/' + 'v' + '9";';
  assert.ok(!protocolAssertionLines(path, source + '\n' + foreign).includes(foreign));
});

// 合成JavaScript先校验语法，字符串/正则/模板正文不冒充注释，模板表达式中的真注释仍拒绝。
test('真实注释与字符串、正则和模板正文正确分离', async () => {
  const [{ Script }, { hasFirstPartyTemporaryComments }] = await Promise.all([import('node:vm'), import('./index.mjs')]);
  const marker = ['HA', 'CK'].join('');
  const cases = [
    ["const url = 'https://example.invalid/" + marker + "';", false],
    ['const embedded = ' + JSON.stringify('// ' + marker + ': embedded source') + ';', false],
    ['const pattern = /\\/\\/' + marker + '/;', false],
    ['const template = `// ' + marker + ': template text`;', false],
    ['// ' + marker + ': unfinished implementation\nconst value = 1;', true],
    ['const template = `value ${(() => { // ' + marker + ': real expression comment\nreturn 1; })()}`;', true],
  ];
  for (const [source, rejected] of cases) {
    assert.doesNotThrow(() => new Script(source));
    assert.equal(hasFirstPartyTemporaryComments('source.mjs', source), rejected);
  }
});

// 执行本仓真实Shell增量防护，检查CLI/浏览器边界、拒绝断言、真实残留和大输入通道。
test('增量防护执行真实归属判断并支持超过argv单项限制的输入', async () => {
  const [{ mkdtempSync, mkdirSync, writeFileSync, rmSync }, { join, dirname }, { testRoot: tmpdir }, { execFileSync, spawnSync }, { checkGuardrails }] = await Promise.all([
    import('node:fs'), import('node:path'), import('../../scripts/build.mjs'), import('node:child_process'), import('./index.mjs'),
  ]);
  const root = mkdtempSync(join(tmpdir(), 'tatagate-guard-'));
  const env = { ...toolEnvironment(), HOME: process.env.HOME, LANG: 'C', LC_ALL: 'C',
    GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
    GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' };
  const git = (...args) => execFileSync(env.PRODUCT_GIT_BIN, ['-C', root, ...args], { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  let output;
  const execute = (command, args, options) => {
    output = spawnSync(command, args, { ...options, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 4 * 1024 * 1024, timeout: 20_000 });
    return output;
  };
  try {
    git('init', '--quiet', '--initial-branch=main');
    const base = git('hash-object', '-w', '-t', 'tree', '/dev/null');
    const testPath = gateContract().node_tests.find(value => /(?:test|tests)[./_-]/u.test(value) && value.endsWith('.mjs'));
    assert.ok(testPath);
    const statement = ['assert.doesNotMatch(source, /\\/', 'v', '1(?:\\/|\\b)/);'].join('');
    const log = ['console', '.log("result");\n'].join('');
    const unfinished = '// ' + ['TO', 'DO'].join('') + ': unfinished\n';
    const metadataPath = ["test/transaction/contract/citizenchain-revive-", "v", "15-metadata.hex"].join("");
    const metadataTest = "test/transaction/contract/citizenchain_contract_read_service_test.dart";
    const metadataLiteral = "const metadata = " + String.fromCharCode(39) + metadataPath + String.fromCharCode(39) + ";\n";
    const protocol = 'const endpoint = "https://example.invalid/' + 'v' + '9";\n';
    for (const [path, source, rejected, message] of [
      ['scripts/fixture.mjs', log, false],
      [metadataTest, metadataLiteral, false],
      [metadataTest, metadataLiteral + protocol, true, "版本化标识"],
      [metadataTest, metadataLiteral.replace("15-metadata", "16-metadata"), true, "版本化标识"],
      [metadataTest, metadataLiteral.replace("test/transaction/", "other/"), true, "版本化标识"],
      ["scripts/fixture.mjs", metadataLiteral, true, "版本化标识"],
      ['android/app/build.gradle.kts', 'val mapping = "drawable-' + 'v21_launch_background.xml" to "drawable-' + 'v21/launch_background.xml";\n', false],
      ['android/app/build.gradle.kts', 'val mapping = "drawable-' + 'v22/launch_background.xml";\n', true, '版本化标识'],
      ['scripts/fixture.mjs', log + 'const large = "' + 'x'.repeat(256 * 1024) + '";\n', false],
      ['lib/browser.js', log, true, '开发残留'],
      ['scripts/fixture.mjs', ['debug', 'ger;\n'].join(''), true, '开发残留'],
      ['scripts/fixture.mjs', unfinished, true, '开发残留'],
      [testPath, 'test(() => {\n  ' + statement + '\n});\n', false],
      [testPath, 'test(() => {\n  ' + statement + '\n});\n' + protocol, true, '版本化标识'],
      [testPath, '`\n  ' + statement + '\n`\n', true, '版本化标识'],
      ['unregistered.test.mjs', '  ' + statement + '\n', true, '版本化标识'],
    ]) {
      for (const entry of ['scripts', 'lib', 'test', 'android', 'unregistered.test.mjs']) rmSync(join(root, entry), { recursive: true, force: true });
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), source);
      git('add', '--all');
      const head = git('commit-tree', git('write-tree'), '-m', 'synthetic guard input');
      git('update-ref', 'refs/heads/main', head);
      const run = () => checkGuardrails(root, { ...env, BASE_REF: base }, execute);
      if (rejected) {
        assert.throws(run, /增量防护未通过/u);
        assert.ok((output.stdout + output.stderr).includes(message));
      } else assert.doesNotThrow(run);
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// 直接执行真实Shell正文中的Node预处理片段；本用例不依赖本机尚缺的GNU工具。
test('上游metadata文件名只在准确测试路径移除完整字面量', async () => {
  const { checkGuardrails } = await import('./index.mjs');
  let shell;
  checkGuardrails(process.cwd(), {}, (_command, _args, options) => { shell = options.input; return {status:0}; },
    () => ({PRODUCT_BASH_BIN:process.execPath,PATH:''}));
  const start = shell.indexOf('let lines = readFileSync(0, "utf8")');
  const end = shell.indexOf('process.stdout.write(lines);', start);
  assert.ok(start >= 0 && end > start);
  const fragment = shell.slice(start, end + 'process.stdout.write(lines);'.length);
  const apply = (path, source) => {
    let output;
    Function('path', 'allowed', 'readFileSync', 'process', fragment)(path, new Set(), () => source,
      {stdout:{write(value){ output=value; }}});
    return output;
  };
  const owner = 'test/transaction/contract/citizenchain_contract_read_service_test.dart';
  const filename = ['test/transaction/contract/citizenchain-revive-', 'v', '15-metadata.hex'].join('');
  const literal = String.fromCharCode(39) + filename + String.fromCharCode(39);
  const protocol = 'const endpoint = "https://example.invalid/' + 'v' + '9";';
  assert.equal(apply(owner, literal), '');
  assert.equal(apply(owner, literal + '\n' + protocol), '\n' + protocol);
  for (const value of [literal.replace('15-metadata','16-metadata'), literal.replace('test/transaction/','other/'), JSON.stringify(filename)]) {
    assert.equal(apply(owner, value), value);
  }
  assert.equal(apply('scripts/fixture.mjs', literal), literal);
});

// 中文注释：执行实际 RPC 类校验与请求，拒绝明文、认证 URL 及重定向，保留真实负向测试。
test('App RPC 严格 HTTPS/WSS 且不跟随重定向', async () => {
  const { JsonRpc } = await import('../../scripts/build.mjs');
  for (const scheme of ['http', 'ws', 'file']) assert.throws(() => new JsonRpc(scheme + '://example.invalid'), /HTTPS\/WSS/u);
  assert.throws(() => new JsonRpc('https://user:pass@example.invalid'), /HTTPS\/WSS/u);
  assert.throws(() => new JsonRpc(''), /HTTPS\/WSS/u);
  assert.equal(new JsonRpc('wss://example.invalid').url, 'wss://example.invalid/');
  const previous = globalThis.fetch;
  try {
    globalThis.fetch = async (_url, options) => {
      assert.equal(options.redirect, 'error'); assert.ok(options.signal);
      return Response.json({ result: 'secure' });
    };
    assert.equal(await new JsonRpc('https://example.invalid').request('system_health'), 'secure');
  } finally { globalThis.fetch = previous; }
});

test('App 明文负向输入只属于准确拒绝测试', async () => {
  const { insecureTransportLines } = await import('./index.mjs');
  const { readFileSync } = await import('node:fs');
  for (const path of ['test/square/square_feed_service_test.dart', 'test/security/chain_bootstrap_api_test.dart', 'test/citizen/governance_tab_test.dart', 'test/wallet/widgets/wallet_onchain_balance_card_test.dart']) {
    const source = readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
    assert.deepEqual(insecureTransportLines(path, source), []);
    assert.ok(insecureTransportLines(path, '/*' + source + '*/').length > 0);
    assert.ok(insecureTransportLines('test/unregistered.dart', source).length > 0);
    assert.ok(insecureTransportLines(path, source + '\nfetch("ht' + 'tp://example.invalid");').length > 0);
  }
  // 旧聊天授权负例已退出；该文件不再获得任何明文样本例外。
  assert.ok(insecureTransportLines('test/chat/mls_boundary_test.dart', 'fetch("ht' + 'tp://extra.example.invalid");').length > 0);
});

// 中文注释：机构命名账户和个人多签使用各自真实派生输入，仍拒绝缺项、重复与密码学漂移。
test('账户派生金标覆盖机构与个人的真实语义键', async () => {
  const { readFileSync } = await import('node:fs');
  const canonical = JSON.parse(readFileSync(new URL("../../test/citizen/shared/account_derive_vectors.json", import.meta.url), 'utf8'));
  const options = { keys: {"InstitutionMain": ["kind", "cid_number"], "InstitutionFee": ["kind", "cid_number"], "InstitutionSafetyFund": ["kind", "cid_number"], "InstitutionHe": ["kind", "cid_number"], "InstitutionStake": ["kind", "cid_number"], "InstitutionClearing": ["kind", "cid_number"], "InstitutionNamed": ["kind", "cid_number", "account_name"], "Personal": ["kind", "creator_account_id", "account_name"]}, values: ['account_id'], top: ['domain','ss58_format'], complete: true };
  assert.equal(validateVectorGroup(canonical, structuredClone(canonical), options), canonical.vectors.length);
  for (const mutate of [
    d => { delete d.vectors.find(v => v.kind === 'Personal').creator_account_id; },
    d => { d.vectors.find(v => v.kind === 'InstitutionNamed').account_name = 'changed'; },
    d => { d.vectors.find(v => v.kind === 'Personal').account_id = '0x00'; },
    d => { d.vectors.push(structuredClone(d.vectors.find(v => v.kind === 'Personal'))); },
    d => { d.vectors[0].kind = 'Unknown'; },
  ]) { const mirror = structuredClone(canonical); mutate(mirror); assert.throws(() => validateVectorGroup(canonical, mirror, options)); }
});

// 准确坐标、首次提交、唯一无父根和带父覆盖分别验证，防止历史清理扩大强推范围。
test('历史清理仅接受唯一无父新根并完整检查全部内容', async () => {
  const { pushBaseSHA } = await import('./index.mjs');
  const headSHA = 'a'.repeat(40), before = 'b'.repeat(40), empty = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
  const reset = { forced: true, before, headSHA, parents: headSHA, commitCount: '1' };
  assert.equal(pushBaseSHA({ forced: false, before, headSHA }), before);
  assert.equal(pushBaseSHA({ forced: false, before: '0'.repeat(40), headSHA }), empty);
  assert.equal(pushBaseSHA(reset), empty);
  for (const invalid of [
    { ...reset, parents: headSHA + ' ' + before }, { ...reset, commitCount: '2' },
    { ...reset, parents: '' }, { ...reset, forced: 'true' },
    { ...reset, before: 'main' }, { ...reset, headSHA: 'main' },
    { ...reset, headSHA: '0'.repeat(40) }, { ...reset, before: '0'.repeat(40) },
  ]) assert.throws(() => pushBaseSHA(invalid));
});

// 准确正文必须保留实际拒绝断言；成功正文、引用或额外地址不能借用既有测试身份。
test('App 明文拒绝正文阻断伪装成功断言及额外地址', async () => {
  const { insecureTransportLines } = await import('./index.mjs');
  const { readFileSync } = await import('node:fs');
  for (const [path, title, rejection, success] of [
    ['test/square/square_feed_service_test.dart', 'SquareApiConfig 只允许HTTPS /api根，包括本机', 'throwsFormatException', 'returnsNormally'],
  ]) {
    const source = readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
    const start = source.indexOf("test('" + title + "'");
    const end = source.indexOf('\n  });', start);
    assert.ok(start >= 0 && end > start);
    const body = source.slice(start, end + '\n  });'.length);
    assert.ok(body.includes(rejection));
    assert.deepEqual(insecureTransportLines(path, body), []);
    for (const candidate of [
      '/*' + body + '*/',
      JSON.stringify(body),
      body.replace(rejection, success),
      body + '\nfetch("ht' + 'tp://extra.example.invalid");',
    ]) assert.ok(insecureTransportLines(path, candidate).length > 0);
    assert.ok(insecureTransportLines('test/unregistered.dart', body).length > 0);
  }
});

// 正式工具输入不得借用相对路径、链接、错误版本或外部预加载环境。
test('App 门禁四工具按交付路径形成子进程环境', async () => {
  const {mkdtempSync,symlinkSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');const {testRoot:tmpdir}=await import('../../scripts/build.mjs');
  const env=toolEnvironment();assert.equal(env.PRODUCT_GIT_BIN,process.env.PRODUCT_GIT_BIN);
  assert.equal(env.NODE_OPTIONS,undefined);assert.equal(env.BASH_ENV,undefined);
  const root=mkdtempSync(join(tmpdir(),'app-gate-tools-'));
  try{
    const link=join(root,'git');symlinkSync(env.PRODUCT_GIT_BIN,link);
    for(const bad of [link,'git','./git'])assert.throws(()=>exactExecutable(bad));
    for(const field of ['PRODUCT_GIT_BIN','PRODUCT_BASH_BIN','PRODUCT_GREP_BIN','PRODUCT_SED_BIN']){
      assert.throws(()=>toolEnvironment({...process.env,[field]:undefined}));
      assert.equal(toolEnvironment({...process.env,[field]:process.execPath})[field],process.execPath);
    }
  }finally{rmSync(root,{recursive:true,force:true});}
});
// 原件包与系统安装包身份分别核验，缺项、错版和不满足内部版本约束均须失败。

// 合成网络响应仍必须通过完整摘要；错误来源与错摘要不能留下目标文件。
test('App 原件失败输入及tar边界不会获得准备身份',async()=>{
  const {mkdtempSync,readFileSync,existsSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');const {testRoot:tmpdir}=await import('../../scripts/build.mjs');const {createHash}=await import('node:crypto');
  const root=mkdtempSync(join(tmpdir(),'app-gate-original-'));const bytes=Buffer.from('fixed official fixture');
  const record={...gateResourcePlan().sources.bash,sha256:createHash('sha256').update(bytes).digest('hex')};
  try{
    const file=join(root,'good');await fetchOriginal(record,file,async()=>new Response(bytes));assert.deepEqual(readFileSync(file),bytes);
    await fetchOriginal({...record,sha256:'0'.repeat(64)},join(root,'bad'),async()=>new Response(bytes));assert.deepEqual(readFileSync(join(root,'bad')),bytes);
    await assert.rejects(fetchOriginal(record,join(root,'redirect'),async()=>new Response(null,{status:302,headers:{location:'ht'+'tp://wrong.invalid'}})));assert.equal(existsSync(join(root,'redirect')),false);
    validateTar(Buffer.alloc(1024));for(const input of [Buffer.alloc(1),Buffer.alloc(1024,1)])assert.throws(()=>validateTar(input));
    const tar=(name,type='0',link='')=>{
      const header=Buffer.alloc(512);
      header.write(name,0,100,'utf8');header.write('0000000\0',124,12,'ascii');
      header[156]=type.charCodeAt(0);header.write(link,157,100,'utf8');
      header.fill(32,148,156);const sum=[...header].reduce((a,b)=>a+b,0);
      header.write(sum.toString(8).padStart(6,'0')+'\0 ',148,8,'ascii');
      return Buffer.concat([header,Buffer.alloc(1024)]);
    };
    validateTar(tar('usr/include/curl.h'));
    validateTar(tar('usr/lib/libcurl.so','2','libcurl.so.4'));
    for(const bytes of [tar('/escape'),tar('../escape'),tar('usr/lib/link','2','../../../../escape'),tar('pipe','6')])assert.throws(()=>validateTar(bytes));
    await assert.rejects(prepareRunnerTools(root,{bootstrap:false}),/身份无效/u);
  }finally{rmSync(root,{recursive:true,force:true});}
});

// 两个镜像必须保持同一原件身份；只模拟响应，真实获取仍由正常入口完整验真。
test('GNU固定镜像的连接恢复摘要失败与来源闭集', async () => {
  const {sourceMirrors, requestGNUOriginal} = await import("../../scripts/resources.mjs");
  const {fetchOriginal:readOriginal} = await import('../../scripts/resources.mjs');
  const {mkdtempSync, readFileSync, existsSync, rmSync} = await import('node:fs');
  const {join} = await import('node:path'); const {testRoot:tmpdir} = await import('../../scripts/build.mjs');
  const {createHash} = await import('node:crypto');
  const bytes = Buffer.from('same locked GNU fixture'), file = 'bash/bash-5.3.tar.gz';
  const record = {url:'https://ftp.gnu.org/gnu/' + file,
    sha256:createHash('sha256').update(bytes).digest('hex'),
    mirrors:['https://mirrors.ocf.berkeley.edu/gnu/','https://mirror.csclub.uwaterloo.ca/gnu/'].map(base => base + file)};
  const addresses = sourceMirrors(record);
  assert.equal(addresses.length, 3);
  for (const mirrors of [undefined, [], record.mirrors.slice(0,1), [...record.mirrors].reverse(),
    [record.mirrors[0],record.mirrors[0]], record.mirrors.map(url => url.replace('https:', 'ht'+'tp:')),
    record.mirrors.map(url => url + '?unregistered=1'), ['https://other.invalid/' + file,record.mirrors[1]]]) {
    assert.throws(() => sourceMirrors({...record,mirrors}));
  }
  const calls = [];
  const connected = await requestGNUOriginal(record, async (url, options) => {
    calls.push(url); assert.equal(options.redirect, 'manual');
    if (calls.length === 1) throw Object.assign(new TypeError('fixture connection timeout'), {cause:{code:'UND_ERR_CONNECT_TIMEOUT'}});
    return new Response(bytes);
  });
  assert.deepEqual(calls, addresses.slice(0,2)); assert.deepEqual(Buffer.from(await connected.response.arrayBuffer()), bytes);
  const unavailable = [];
  await requestGNUOriginal(record, async url => {
    unavailable.push(url); return unavailable.length < 3 ? new Response(null,{status:503}) : new Response(bytes);
  });
  assert.deepEqual(unavailable, addresses);
  let tlsCalls = 0;
  await assert.rejects(requestGNUOriginal(record, async () => {tlsCalls++; throw Object.assign(Error('fixture invalid TLS'),{cause:{code:'CERT_HAS_EXPIRED'}});}));
  assert.equal(tlsCalls,1);
  let redirectCalls = 0;
  await assert.rejects(requestGNUOriginal(record, async () => {redirectCalls++; return new Response(null,{status:302,headers:{location:'https://other.invalid/original'}});}));
  assert.equal(redirectCalls,1);
  const controller = new AbortController(); controller.abort();
  await assert.rejects(requestGNUOriginal(record, () => assert.fail('取消不得联网'), {signal:controller.signal}));
  const root = mkdtempSync(join(tmpdir(),'gnu-mirror-'));
  try {
    const path = join(root,'original'); let attempts = 0;
    await readOriginal(record, path, async () => ++attempts === 1 ? new Response(null,{status:503}) : new Response(bytes));
    assert.equal(attempts,2); assert.deepEqual(readFileSync(path),bytes);
    let corrupted = 0; const rejected = join(root,'rejected');
    await readOriginal({...record,sha256:'0'.repeat(64)}, rejected, async () => {corrupted++; return new Response(bytes);});
    assert.equal(corrupted,1); assert.deepEqual(readFileSync(rejected),bytes);
  } finally {rmSync(root,{recursive:true,force:true});}
});

// awk等虚拟依赖必须由已安装真实包提供，闭包继续核验提供包自身的依赖与版本。


// 增量检查通过eval导入自身时argv仍指向文件；只有真实主入口才校验准备命令。
test('工具转发模块导入无副作用，真实门禁入口仍拒绝缺少准确参数',async()=>{
  const {spawnSync}=await import('node:child_process');
  const {fileURLToPath}=await import('node:url');
  const entry=fileURLToPath(new URL('../../scripts/resources.mjs',import.meta.url));
  const source='await import((await import("node:url")).pathToFileURL(process.argv[1]).href);';
  const options={encoding:'utf8',timeout:10000,env:{PATH:'',NODE_OPTIONS:'',NODE_PATH:''}};
  for(const args of [['--input-type=module','-e',source,entry],['--input-type=module','--eval',source,entry],
    ['--input-type=module','--eval='+source,entry]]){
    const result=spawnSync(process.execPath,args,options);
    assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,0,result.stderr);
    assert.equal(result.stdout,'');assert.equal(result.stderr,'');
  }
  const direct=spawnSync(process.execPath,[fileURLToPath(new URL('./index.mjs',import.meta.url))],options);
  assert.equal(direct.error,undefined);assert.equal(direct.signal,null);assert.equal(direct.status,1);
  assert.match(direct.stderr,/本仓塔塔门禁参数或身份无效/u);
});

// Ubuntu官方dpkg-dev与debhelper可为同一虚拟名提供不同版本；每个版本须独立满足约束。


// 本仓target是唯一源码内生成边界；嵌套或链接旁路仍必须拒绝。
test('产品门禁允许自有根target并拒绝嵌套与链接输出', async () => {
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync, symlinkSync, unlinkSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { testRoot } = await import('../../scripts/build.mjs');
  const { assertNoProductOutputDirectories, gateContract } = await import('./index.mjs');
  const fixture = mkdtempSync(join(testRoot(), 'target-boundary-'));
  const root = join(fixture, 'source'), target = join(root, 'target');
  mkdirSync(root);
  try {
    mkdirSync(join(target, 'test', 'build'), { recursive: true });
    writeFileSync(join(target, 'test', 'build', 'generated.txt'), 'generated fixture');
    assert.doesNotThrow(() => assertNoProductOutputDirectories(root, gateContract().repository));
    const nested = join(root, 'source', 'target');
    mkdirSync(nested, { recursive: true });
    assert.throws(() => assertNoProductOutputDirectories(root, gateContract().repository), /生成状态目录/u);
    rmSync(join(root, 'source'), { recursive: true });
    rmSync(target, { recursive: true });
    const outside = join(fixture, 'outside'); mkdirSync(outside);
    symlinkSync(outside, target, 'dir');
    assert.throws(() => assertNoProductOutputDirectories(root, gateContract().repository), /生成状态目录/u);
    // 仅移除夹具链接自身，保留指向的普通目录，避免误清理目标。
    unlinkSync(target);
    writeFileSync(target, 'ordinary file');
    assert.throws(() => assertNoProductOutputDirectories(root, gateContract().repository), /生成状态目录/u);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});

// 所属根文档验收只读本仓，负向夹具在本产品target内，不借其它仓库资料。
test('所属根技术文档拒绝缺失、空文件、链接、副本与错误文件类型', async () => {
  const { validateProductDocuments } = await import('./index.mjs');
  const { mkdtempSync, writeFileSync, unlinkSync, symlinkSync, mkdirSync, rmSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { testRoot } = await import('../../scripts/build.mjs');
  const root = mkdtempSync(join(testRoot(), 'product-documents-'));
  const names = ["CitizenApp.md"];
  try {
    assert.throws(() => validateProductDocuments(root), /根技术文档/u);
    for (const name of names) writeFileSync(join(root, name), '产品技术文档\n');
    writeFileSync(join(root, 'README.md'), '产品简介\n');
    assert.equal(validateProductDocuments(root), true);
    const file = join(root, names[0]);
    writeFileSync(file, '');
    assert.throws(() => validateProductDocuments(root), /根技术文档/u);
    unlinkSync(file); symlinkSync(join(root, 'README.md'), file);
    assert.throws(() => validateProductDocuments(root), /根技术文档/u);
    unlinkSync(file); mkdirSync(file);
    assert.throws(() => validateProductDocuments(root), /根技术文档/u);
    rmSync(file, { recursive: true }); writeFileSync(file, '产品技术文档\n');
    writeFileSync(join(root, 'Extra.md'), '第二技术文档\n');
    assert.throws(() => validateProductDocuments(root), /额外技术文档/u);
    unlinkSync(join(root, 'Extra.md'));
    const readme = join(root, 'README.md'); unlinkSync(readme); symlinkSync(file, readme);
    assert.throws(() => validateProductDocuments(root), /非空普通原件/u);
    unlinkSync(readme); writeFileSync(readme, '产品简介\n');
    assert.equal(validateProductDocuments(root), true);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// 文档迁出后保留同等资料扫描，测试只使用合成材料。
test('根技术文档机密扫描保留正文、令牌和转义快照拒绝', async () => {
  const { hasSecretMaterial } = await import('./index.mjs');
  const header = type => '-----BEGIN ' + type + 'PRIVATE KEY-----';
  const footer = type => '-----END ' + type + 'PRIVATE KEY-----';
  for (const type of ['', 'RSA ', 'EC ', 'OPENSSH ']) {
    const begin = header(type), end = footer(type);
    assert.equal(hasSecretMaterial('识别格式 ' + JSON.stringify(begin)), false);
    assert.equal(hasSecretMaterial(begin + '\\n\\(fixtureData.base64EncodedString())\\n' + end), false);
    const shaped = begin + '\n' + 'A'.repeat(96) + '\n' + end;
    assert.equal(hasSecretMaterial(shaped), true);
    assert.equal(hasSecretMaterial(shaped.replaceAll('\n', '\\n')), true);
    assert.equal(hasSecretMaterial(JSON.stringify({ original: shaped })), true);
    const escaped = JSON.stringify({ original: shaped }).replace('BEGIN', '\\u0042EGIN');
    assert.equal(hasSecretMaterial(escaped), true);
    assert.equal(hasSecretMaterial(JSON.stringify({ original: JSON.stringify(shaped).replace('BEGIN', '\\u0042EGIN') })), true);
    assert.equal(hasSecretMaterial(JSON.stringify({ [shaped]: '合成键名' }).replace('BEGIN', '\\u0042EGIN')), true);
    const snapshot = '<!-- PATCH_DATA\n' + escaped + '\nPATCH_DATA -->';
    assert.equal(hasSecretMaterial(snapshot), true);
    assert.equal(hasSecretMaterial(begin + '\n' + 'A'.repeat(32)), true);
  }
  for (const [prefix, length] of [['AKIA', 16], ['github_pat_', 20], ['ghp_', 30], ['sk_live_', 16]]) {
    assert.equal(hasSecretMaterial(prefix + 'A'.repeat(length)), true);
    assert.equal(hasSecretMaterial(JSON.stringify({ example: prefix + 'A'.repeat(length) })), true);
  }
  assert.equal(hasSecretMaterial('格式说明，没有凭据正文'), false);
  assert.equal(hasSecretMaterial(header('') + '\nfixture-only\n' + footer('')), false);
  assert.throws(() => hasSecretMaterial('<!-- PATCH_DATA\n{}'), /快照结构/u);
  assert.throws(() => hasSecretMaterial('<!-- PATCH_DATA\ninvalid\nPATCH_DATA -->'), /快照结构/u);
  assert.throws(() => hasSecretMaterial(null), /输入必须/u);
});

// 真实资源只免除唯一官方归档字段；负向输入仍经完整Git跟踪文件扫描，现场归本产品。
test('官方Flutter归档字段不冒充旧平台标识，其它残留和伪造声明仍拒绝', async () => {
  const { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { execFileSync } = await import('node:child_process');
  const { testRoot } = await import('../../scripts/build.mjs');
  const { validatePlatformNaming } = await import('./index.mjs');
  const root = mkdtempSync(join(testRoot(), 'tatagate-platform-'));
  const gitBin = toolEnvironment().PRODUCT_GIT_BIN;
  const env = { ...toolEnvironment(), HOME: process.env.HOME, LANG: 'C', LC_ALL: 'C',
    GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
  const git = (...args) => execFileSync(gitBin, ['-C', root, ...args], { env, stdio: ['ignore','pipe','pipe'] });
  const source = readFileSync(new URL('../../scripts/resources.mjs', import.meta.url), 'utf8');
  const literal = source.match(/^const toolDefinitions=(\[.*\]);$/mu)[1];
  const tool = JSON.parse(literal).find(value => value.id === 'flutter');
  const legacy = ['macos','arm64'].join('_');
  const declaration = tools => 'const toolDefinitions=' + JSON.stringify(tools) + ';\n';
  try {
    git('init', '--quiet', '--initial-branch=main');
    mkdirSync(join(root, 'scripts')); mkdirSync(join(root, '.github', 'tatagate'), { recursive: true });
    const file = join(root, 'scripts', 'resources.mjs');
    writeFileSync(join(root, '.github', 'tatagate', 'contracts.json'), JSON.stringify(gateContract()));
    writeFileSync(file, source); git('add', '--all');
    assert.doesNotThrow(() => validatePlatformNaming(root));
    // 使用本仓真实补丁；即使伪造登记摘要，原上下文以外的旧平台文字仍须拒绝。
    const { createHash } = await import('node:crypto');
    const patch = JSON.parse(source.match(/^const flutterPatch=(".*");$/mu)[1]);
    const withPatch = (value, body=patch) => declaration([value]) + 'const flutterPatch=' + JSON.stringify(body) + ';\n';
    const altered = (change, metadata=()=>{}, refresh=false) => {
      const value=structuredClone(tool), body=change(patch);
      if (refresh) value.patch.sha256=createHash('sha256').update(body).digest('hex');
      metadata(value.patch);
      return withPatch(value,body);
    };
    writeFileSync(file, withPatch(tool));
    assert.doesNotThrow(() => validatePlatformNaming(root));
    const marker=['macos','arm64'].join(' ');
    const original=' /// ios device or '+marker+'.';
    for (const invalid of [
      altered(body=>body, value=>{value.source='https://example.invalid/commit/'+'a'.repeat(40);}),
      altered(body=>body, value=>{value.source=value.source.replace('https:','http:');}),
      altered(body=>body, value=>{value.source='https://github.com/flutter/flutter/commit/'+'0'.repeat(40);}),
      altered(body=>body, value=>{value.sha256='0'.repeat(64);}),
      altered(body=>body, value=>{value.path='other.patch';}),
      altered(body=>body, value=>{value.extra='unexpected';}),
      altered(body=>body+'\n'),
      altered(body=>body.replace('Future<void> lipoDylibs','Future<void> changed'),()=>{},true),
      altered(body=>body.replaceAll('native_assets_host.dart','other.dart'),()=>{},true),
      altered(body=>body.replace(original,'+/// ios device or '+marker+'.'),()=>{},true),
      altered(body=>body+'\n+// '+marker+'\n',()=>{},true),
      altered(body=>body+'\n'+body,()=>{},true),
      withPatch(tool)+'const flutterPatch='+JSON.stringify(patch)+';\n',
      withPatch(tool).replace('fixed source','fixed\\u0020source'),
      declaration([tool])+'const flutterPatch='+JSON.stringify(patch).slice(0,-1)+';\n',
      withPatch(tool)+'// '+marker+'\n',
    ]) {
      writeFileSync(file,invalid);
      assert.throws(() => validatePlatformNaming(root), /禁用平台命名/u);
    }
    writeFileSync(file, declaration([tool]));
    assert.doesNotThrow(() => validatePlatformNaming(root));
    const changed = change => { const value = structuredClone(tool); change(value); return declaration([value]); };
    for (const invalid of [
      changed(value => { value.archive.url = value.archive.url.replace('storage.googleapis.com','example.invalid'); }),
      changed(value => { value.archive.url = value.archive.url.replace('https:','http:'); }),
      changed(value => { value.version = '0.0.0'; }),
      changed(value => { value.archive.url = value.archive.url.replace('-stable.zip','-other.zip'); }),
      changed(value => { value.source = 'https://example.invalid/releases.json'; }),
      changed(value => { value.archive.root = 'other'; }),
      changed(value => { value.archive.executable = 'other'; }),
      changed(value => { value.title = legacy; }),
      changed(value => { value.archive.extra = legacy; }),
      declaration([tool, tool]),
      declaration([tool]) + declaration([tool]),
      declaration([tool]).replace('"version":', '"id":"other","version":'),
      declaration([tool]).replace('"flutter"', '"flutt\\u0065r"'),
      'const toolDefinitions=[invalid];\n// ' + legacy,
      declaration([tool]) + '// ' + legacy,
    ]) {
      writeFileSync(file, invalid);
      assert.throws(() => validatePlatformNaming(root), /禁用平台命名/u);
    }
    writeFileSync(file, declaration([tool]));
    const other = join(root, 'other.mjs');
    writeFileSync(other, declaration([tool])); git('add', '--all');
    assert.throws(() => validatePlatformNaming(root), /禁用平台命名/u);
    rmSync(other); git('add', '--all');
    for (const alias of gateContract().platform_forbidden_values) {
      writeFileSync(file, declaration([tool]) + '// ' + alias);
      assert.throws(() => validatePlatformNaming(root), /禁用平台命名/u);
    }
    writeFileSync(file, declaration([tool]));
    mkdirSync(join(root, legacy)); writeFileSync(join(root, legacy, 'source.mjs'), 'export const fixture=true;\n');
    git('add', '--all');
    assert.throws(() => validatePlatformNaming(root), /禁用平台目录/u);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// 用真实门禁函数检查登记与执行回执；这些用例在整项实现后统一运行。
test('本仓Git测试集合不得漏项、增项、重复或混入门禁自身', async () => {
  const { validateNodeInventory } = await import('./index.mjs');
  const paths = ['scripts/build.mjs', 'scripts/flow.mjs', 'test/api.spec.mjs', '.github/tatagate/test.mjs'];
  const registered = ['scripts/build.mjs', 'scripts/flow.mjs', 'test/api.spec.mjs'];
  assert.deepEqual(validateNodeInventory(paths, registered), registered);
  for (const listed of [registered.slice(1), [...registered, 'missing.test.mjs'], [...registered, registered[0]], []]) {
    assert.throws(() => validateNodeInventory(paths, listed));
  }
  assert.throws(() => validateNodeInventory([...paths, 'scripts/new.test.mjs'], registered));
  assert.throws(() => validateNodeInventory([...paths, paths[0]], registered));
});
test('成功退出但零用例、失败、取消或跳过不能作为完整测试回执', async () => {
  const { successfulTestSummary } = await import('./index.mjs');
  const counts = { tests: 2, passed: 2, failed: 0, skipped: 0, todo: 0, cancelled: 0 };
  assert.equal(successfulTestSummary({ success: true, counts }), true);
  for (const change of [{ tests: 0 }, { passed: 0 }, { failed: 1 }, { skipped: 1 }, { todo: 1 }, { cancelled: 1 }]) {
    assert.equal(Boolean(successfulTestSummary({ success: true, counts: { ...counts, ...change } })), false);
  }
  assert.equal(Boolean(successfulTestSummary({ success: false, counts })), false);
  assert.equal(Boolean(successfulTestSummary({ success: true })), false);
});
test('资源中的注释文本与正则字面量不是第一方代码注释', async () => {
  const { commentText, hasFirstPartyTemporaryComments } = await import('./index.mjs');
  const source = 'const patch = "// TODO upstream\\n/* FIXME original */";\nconst literal = /\\/\\/ XXX/;\n// 正常中文实现说明\n';
  assert.equal(hasFirstPartyTemporaryComments('scripts/resources.mjs', source), false);
  assert.match(commentText('module.mjs', source), /正常中文实现说明/u);
  assert.equal(hasFirstPartyTemporaryComments('module.mjs', source + '// TODO first party\n'), true);
  assert.equal(hasFirstPartyTemporaryComments('module.rs', 'let raw = r##"// TODO raw"##;\n// 中文说明\n'), false);
  assert.equal(hasFirstPartyTemporaryComments('module.rs', "fn bind<'a>() {} // FIXME actual\n"), true);
});

// 真实词法和消费者闭合，模板表达式中的真实注释仍参与检查。
test('注释检查区分模板正文、模板表达式、Python文串和真实行尾注释',async()=>{
 const {hasFirstPartyTemporaryComments}=await import('./index.mjs');
 assert.equal(hasFirstPartyTemporaryComments('module.mjs','const value=`// TODO text ${1}`;'),false);
 assert.equal(hasFirstPartyTemporaryComments('module.mjs','const value=`text ${(()=>{ // FIXME actual\n return 1; })()}`;'),true);
 assert.equal(hasFirstPartyTemporaryComments('module.py','value="""# TODO text"""\nvalue=1 # FIXME actual\n'),true);
 assert.equal(hasFirstPartyTemporaryComments('module.py','value="""# TODO text"""\n'),false);
});
// 使用真实Node运行器和实际门禁Reporter；不以伪造汇总对象代替最终执行回执。
test('实际NodeReporter拒绝漏文件、零用例、跳过和失败',async()=>{
 const [{mkdtempSync,writeFileSync,rmSync},{join},{testRoot},{spawnSync},{fileURLToPath}]=await Promise.all([import('node:fs'),import('node:path'),import('../../scripts/build.mjs'),import('node:child_process'),import('node:url')]);
 const work=mkdtempSync(join(testRoot(),'gate-reporter-')),file=join(work,'case.test.mjs'),reporter=fileURLToPath(new URL('./index.mjs',import.meta.url));
 try{
  for(const [body,extra,success]of [
   ['import test from "node:test";test("正常夹具",()=>{});',[],true],
   ['export const noTests=true;',[],false],
   ['import test from "node:test";test.skip("跳过夹具",()=>{});',[],false],
   ['import test from "node:test";test("失败夹具",()=>{throw Error("synthetic failure")});',[],false],
   ['import test from "node:test";test("漏项夹具",()=>{});',[join(work,'missing.test.mjs')],false],
  ]){
   // 子Node必须是独立运行器；保留产品工具输入，只移除父运行器的内部测试上下文。
   const childEnvironment={...process.env,TATAGATE_NODE_TESTS:JSON.stringify([file,...extra])};delete childEnvironment.NODE_TEST_CONTEXT;
   writeFileSync(file,body);const result=spawnSync(process.execPath,['--test','--test-reporter='+reporter,file],{env:childEnvironment,encoding:'utf8',timeout:30000,maxBuffer:2*1024**2});
   assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status===0,success,result.stdout+result.stderr);
  }
 }finally{rmSync(work,{recursive:true,force:true});}
});

test('实际语言回执拒绝零用例、跳过、失败及不完整终态',async()=>{
 const {validateLanguageResult}=await import('./index.mjs');
 const vitest={success:true,numTotalTests:2,numPassedTests:2,numFailedTests:0,numPendingTests:0,numTodoTests:0};assert.equal(validateLanguageResult('vitest',JSON.stringify(vitest)),true);
 for(const change of [{numTotalTests:0,numPassedTests:0},{numPassedTests:1},{numPendingTests:1},{success:false}])assert.throws(()=>validateLanguageResult('vitest',JSON.stringify({...vitest,...change})));
 const flutter=JSON.stringify({type:'testDone',result:'success',skipped:false,hidden:false})+'\n'+JSON.stringify({type:'done',success:true});assert.equal(validateLanguageResult('flutter',flutter),true);
 for(const invalid of ['',JSON.stringify({type:'done',success:true}),flutter.replace('"skipped":false','"skipped":true'),flutter.replace('"success":true','"success":false')])assert.throws(()=>validateLanguageResult('flutter',invalid));
 assert.equal(validateLanguageResult('cargo','test result: ok. 2 passed; 0 failed; 0 ignored;'),true);
 for(const invalid of ['', 'test result: ok. 0 passed; 0 failed; 0 ignored;', 'test result: ok. 2 passed; 0 failed; 1 ignored;'])assert.throws(()=>validateLanguageResult('cargo',invalid));
});

test('代码变化必须同步所属文档与非空回归差异',async()=>{
 const {validateChangeEvidence}=await import('./index.mjs');
 assert.equal(validateChangeEvidence(['src/main.mjs','Owned.md','scripts/main.test.mjs'],['Owned.md']),true);
 assert.equal(validateChangeEvidence(['Owned.md'],['Owned.md']),true);
 for(const paths of [['src/main.mjs'],['src/main.mjs','Owned.md'],['src/main.mjs','Foreign.md','scripts/main.test.mjs']])assert.throws(()=>validateChangeEvidence(paths,['Owned.md']));
 assert.throws(()=>validateChangeEvidence(['src/main.mjs','Owned.md','scripts/main.test.mjs'],['Owned.md'],{changed:path=>path!=='Owned.md'}));
});

// 调用真实结果核验接口；合成协议事件仅验证核验器，不能作为产品功能通过证据。
test('功能映射必须闭合，拒绝遗漏类型、重复来源和路径越界',async()=>{
 const {validateFunctionalContract,gateContract}=await import('./index.mjs');const list=structuredClone(gateContract().functions);
 assert.equal(validateFunctionalContract(list),true);
 for(const invalid of [[],[...list,list[0]],list.map((item,index)=>index?item:{...item,path:'../foreign.test.mjs'}),list.map((item,index)=>index?item:{...item,target:'/foreign/Cargo.toml'}),list.map((item,index)=>index?item:{...item,runner:'skip'}),list.map((item,index)=>index?item:{...item,unknown:true})])assert.throws(()=>validateFunctionalContract(invalid));
 const value=structuredClone(gateContract());value.functions=value.functions.filter(item=>item.path!==value.node_tests[0]);assert.throws(()=>gateContract(value));
});
test('Vitest必须逐一完成本仓具名文件，错路径、漏跑和重复结果均拒绝',async()=>{
 const {functionalFiles}=await import('./index.mjs');const root='/owned/source',paths=['test/one.test.ts','test/two.test.ts'];
 const suite=name=>({name:root+'/'+name,assertionResults:[{status:'passed'}]}),value={success:true,numTotalTests:2,numPassedTests:2,numFailedTests:0,numPendingTests:0,numTodoTests:0,testResults:paths.map(suite)};
 assert.deepEqual(functionalFiles('vitest',JSON.stringify(value),paths,[root]),paths.map(path=>({path,tests:1})));
 for(const change of [{testResults:[suite(paths[0])]},{testResults:[suite(paths[0]),suite(paths[0])]},{testResults:[suite(paths[0]),{...suite(paths[1]),name:'/foreign/'+paths[1]}]},{testResults:[suite(paths[0]),{...suite(paths[1]),assertionResults:[]}]},{testResults:[suite(paths[0]),{...suite(paths[1]),assertionResults:[{status:'skipped'}]}]}])assert.throws(()=>functionalFiles('vitest',JSON.stringify({...value,...change}),paths,[root]));
});
test('Flutter加载事件不能代替实际用例，每个本仓套件均需成功',async()=>{
 const {functionalFiles}=await import('./index.mjs');const path='test/feature_test.dart',events=[{type:'suite',suite:{id:1,path:'/owned/source/'+path}},{type:'testStart',test:{id:1,suiteID:1,name:'真实协议夹具',hidden:false}},{type:'testDone',testID:1,hidden:false,result:'success',skipped:false},{type:'done',success:true}];
 const text=value=>value.map(row=>JSON.stringify(row)).join('\n');
 assert.deepEqual(functionalFiles('flutter',text(events),[path],['/owned/source']),[{path,tests:1}]);
 for(const value of [events.filter(item=>item.type!=='testDone'),events.map(item=>item.type==='testDone'?{...item,skipped:true}:item),events.map(item=>item.type==='suite'?{...item,suite:{...item.suite,path:'/foreign/'+path}}:item),[events[0],events[1],events[2],events[2],events[3]]])assert.throws(()=>functionalFiles('flutter',text(value),[path],['/owned/source']));
 assert.throws(()=>functionalFiles('flutter',text(events),[path,'test/missing_test.dart'],['/owned/source']));
});
test('Rust功能结果必须属于准确包，完整摘要不等于具名用例执行',async()=>{
 const {functionalRustCases}=await import('./index.mjs'),items=[{path:'src/auth.rs',package:'owned-package',cases:['reject_expired']},{path:'tests/boundary.rs',package:'owned-package',cases:['reject_foreign']}];
 const value='test auth::reject_expired ... ok\ntest reject_foreign ... ok\ntest result: ok. 2 passed; 0 failed; 0 ignored;';
 assert.deepEqual(functionalRustCases(value,items),items.map(item=>({path:item.path,cases:item.cases})));
 for(const invalid of [value.replace('test reject_foreign ... ok\n',''),value.replace('0 ignored','1 ignored'),value.replace('2 passed','0 passed')])assert.throws(()=>functionalRustCases(invalid,items));
 assert.throws(()=>functionalRustCases(value,[items[0],{...items[1],package:'foreign-package'}]));
 assert.throws(()=>functionalRustCases(value,[items[0],{...items[1],cases:['reject_expired']} ]));
});

// 固定协调参数不承载产品产物；目录身份及空状态必须真实验证。
test('门禁请求协调目录拒绝相对、源码和无效目录',async()=>{
 const {validateGateRequestWork}=await import('./index.mjs');
 assert.throws(()=>validateGateRequestWork('/owned/source','relative/work'));
 assert.throws(()=>validateGateRequestWork('/owned/source','/nonexistent/owned/gate-work'));
});

// 回读本仓实际已跟踪测试来源；完整映射不可空跑、漏登记或混入不存在的入口。
test('本仓真实功能源码清单与登记准确闭合',async()=>{
 const [{validateFunctionalInventory},{fileURLToPath}]=await Promise.all([import('./index.mjs'),import('node:url')]);
 const root=fileURLToPath(new URL('../../',import.meta.url)).replace(/\/$/u,'');
 assert.equal(validateFunctionalInventory(root).length,gateContract().functions.length);
 assert.throws(()=>validateFunctionalInventory(root,gateContract().functions.slice(1)),/本仓功能测试存在遗漏/u);
 assert.throws(()=>validateFunctionalInventory(root,[...gateContract().functions,{function:'不存在的入口',path:'missing.test.mjs',runner:'node',target:'.'}]),/本仓功能测试存在遗漏/u);
});

// 三级目录约束检查实际当前输入，并用失败夹具覆盖深度、命名与单子项。
test('公民App三级源码布局保留广场名称且脚本入口闭合',async()=>{
 const {validateSourceLayout}=await import('./index.mjs');
 const root=new URL('../../',import.meta.url).pathname;
 const {existsSync}=await import('node:fs');
 const {execFileSync}=await import('node:child_process');
 const paths=[...new Set(execFileSync(toolEnvironment().PRODUCT_GIT_BIN,['-C',root,'ls-files','-z','--cached','--others','--exclude-standard'],{encoding:'utf8',env:toolEnvironment()}).split('\0').filter(path=>path&&existsSync(root+path)))];
 const result=validateSourceLayout(paths);assert.equal(result.depth,3);
 assert.ok(paths.some(path=>path.startsWith('lib/8964/')));assert.ok(!paths.some(path=>path.startsWith('lib/square/')));
 assert.ok(paths.includes('assets/logo/icon1024.png'),'应用图标只从统一Logo目录取得');
 assert.ok(paths.includes('ios/resources/icons.json'),'Xcode图标声明仍须保留');
 assert.ok(!paths.some(path=>/^(?:android|ios)\/resources\/.*[.]png$/u.test(path)),'原生源码不能保存Logo副本');
 assert.ok(!paths.some(path=>path.startsWith('assets/badges/')));
 assert.ok(paths.includes('assets/icons/institution_private.svg'));
 assert.ok(paths.includes('assets/icons/institution_public.svg'));
 assert.deepEqual(paths.filter(path=>path.startsWith('scripts/')).sort(),['scripts/build.mjs','scripts/ci/android.mjs','scripts/ci/ios.mjs','scripts/flow.mjs','scripts/flows.json','scripts/release/android.mjs','scripts/release/ios.mjs','scripts/resources.mjs']);
 for(const fixture of [['lib/one/a.dart','lib/one/b.dart','lib/one/two/three/c.dart'],['lib/bad_name/a.dart','lib/bad_name/b.dart'],['lib/one/a.dart']])assert.throws(()=>validateSourceLayout(fixture));
});
