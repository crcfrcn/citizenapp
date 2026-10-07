import assert from 'node:assert/strict';
import test from 'node:test';
import { toolEnvironment, exactExecutable, validateToolSources, packageClosure, fetchOriginal, validateTar, prepareRunnerTools } from './tools.mjs';
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
test('公开链真源只读准确SHA，拒绝网络、重定向、超限及伪造坐标',async()=>{
  const sha='a'.repeat(40);
  const reference={ref:'refs/heads/main',object:{type:'commit',sha,url:'https://api.github.com/repos/crcfrcn/citizenchain/git/commits/'+sha}};
  assert.equal(await readPublicChain(null,null,async(url,options)=>{
    assert.equal(url,'https://api.github.com/repos/crcfrcn/citizenchain/git/ref/heads/main');
    assert.equal(options.redirect,'error'); assert.equal(options.credentials,'omit');
    assert.equal(options.headers.Authorization,undefined);
    return new Response(JSON.stringify(reference));
  }),sha);
  assert.equal(await readPublicChain('runtime/src/lib.rs',sha,async()=>new Response('source')),'source');
  for (const request of [
    async()=>{throw new Error('private response forbidden');},
    async()=>new Response('',{status:302}), async()=>new Response('',{status:404}),
    async()=>new Response(Buffer.alloc(2*1024*1024+1)),
    async()=>new Response(new Uint8Array([255])),
  ]) await assert.rejects(readPublicChain('runtime/src/lib.rs',sha,request),/准确提交真源读取失败/u);
  for (const value of [
    {...reference,ref:'refs/heads/other'}, {...reference,object:{...reference.object,sha:'main'}},
    {...reference,object:{...reference.object,type:'tag'}},
    {...reference,object:{...reference.object,url:'https://example.org/commit'}},
  ]) await assert.rejects(readPublicChain(null,null,async()=>new Response(JSON.stringify(value))));
  await assert.rejects(readPublicChain('../private',sha,()=>assert.fail('非法路径禁止联网')));
});

// 用隔离的合成Git提交验证门禁读取真实初始内容；不修改产品仓或调用仓库保存/推送。
test('保留源码不按每文件汉字数量判定，真实第一方临时注释仍拒绝', async () => {
  const [{ mkdtempSync, mkdirSync, writeFileSync, rmSync }, { join }, { tmpdir }, { execFileSync }, { validateQuality }] = await Promise.all([
    import('node:fs'), import('node:path'), import('node:os'), import('node:child_process'), import('./index.mjs'),
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

// 执行本仓真实Shell增量防护，检查CLI/浏览器边界、拒绝断言、真实残留和大输入通道。
test('增量防护执行真实归属判断并支持超过argv单项限制的输入', async () => {
  const [{ mkdtempSync, mkdirSync, writeFileSync, rmSync }, { join, dirname }, { tmpdir }, { execFileSync, spawnSync }, { checkGuardrails }] = await Promise.all([
    import('node:fs'), import('node:path'), import('node:os'), import('node:child_process'), import('./index.mjs'),
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
    const metadataPath = ["test/transaction/citizenchain-revive-", "v", "15-metadata.hex"].join("");
    const metadataTest = "test/transaction/citizenchain_contract_read_service_test.dart";
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
  const owner = 'test/transaction/citizenchain_contract_read_service_test.dart';
  const filename = ['test/transaction/citizenchain-revive-', 'v', '15-metadata.hex'].join('');
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
  const { JsonRpc } = await import('../../scripts/generate_public_institution_bundle.mjs');
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
  for (const path of ['test/8964/square_feed_service_test.dart', 'test/security/chain_bootstrap_api_test.dart', 'test/chat/mls_boundary_test.dart', 'test/citizen/governance_tab_test.dart', 'test/wallet/widgets/wallet_onchain_balance_card_test.dart']) {
    const source = readFileSync(new URL('../../' + path, import.meta.url), 'utf8');
    assert.deepEqual(insecureTransportLines(path, source), []);
    assert.ok(insecureTransportLines(path, '/*' + source + '*/').length > 0);
    assert.ok(insecureTransportLines('test/unregistered.dart', source).length > 0);
    assert.ok(insecureTransportLines(path, source + '\nfetch("ht' + 'tp://example.invalid");').length > 0);
  }
});

// 中文注释：机构命名账户和个人多签使用各自真实派生输入，仍拒绝缺项、重复与密码学漂移。
test('账户派生金标覆盖机构与个人的真实语义键', async () => {
  const { readFileSync } = await import('node:fs');
  const canonical = JSON.parse(readFileSync(new URL("../../test/governance/shared/account_derive_vectors.json", import.meta.url), 'utf8'));
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
test('App 两段明文拒绝正文阻断伪装成功断言及额外地址', async () => {
  const { insecureTransportLines } = await import('./index.mjs');
  const { readFileSync } = await import('node:fs');
  for (const [path, title, rejection, success] of [
    ['test/8964/square_feed_service_test.dart', 'SquareApiConfig 仅允许 HTTPS，包括本机', 'throwsUnsupportedError', 'returnsNormally'],
    ['test/chat/mls_boundary_test.dart', 'SquareApiClient 拒绝非 HTTPS 聊天服务地址', 'throwsA(', 'returnsNormally('],
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
test('App 门禁四工具严格验真并封闭子进程环境', async () => {
  const {mkdtempSync,symlinkSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');const {tmpdir}=await import('node:os');
  const env=toolEnvironment();assert.equal(env.PRODUCT_GIT_BIN,process.env.PRODUCT_GIT_BIN);
  assert.equal(env.NODE_OPTIONS,undefined);assert.equal(env.BASH_ENV,undefined);
  const root=mkdtempSync(join(tmpdir(),'app-gate-tools-'));
  try{
    const link=join(root,'git');symlinkSync(env.PRODUCT_GIT_BIN,link);
    for(const bad of [link,'git','./git'])assert.throws(()=>exactExecutable(bad));
    for(const field of ['PRODUCT_GIT_BIN','PRODUCT_BASH_BIN','PRODUCT_GREP_BIN','PRODUCT_SED_BIN']){
      assert.throws(()=>toolEnvironment({...process.env,[field]:undefined}));
      assert.throws(()=>toolEnvironment({...process.env,[field]:process.execPath}),/版本漂移/u);
    }
  }finally{rmSync(root,{recursive:true,force:true});}
});
// 原件包与系统安装包身份分别核验，缺项、错版和不满足内部版本约束均须失败。
test('App 官方来源与Ubuntu包闭包拒绝漂移',()=>{
  const value=structuredClone(gateContract().tool_sources);assert.equal(validateToolSources(value),value);
  for(const mutate of [p=>{p.sources.git.version='0.0.0';},p=>{p.sources.bash.upstream_patches.pop();},p=>{p.sources.sed.url='https://wrong.invalid/sed';},p=>{p.bootstrap.artifacts[0].sha256='0'.repeat(64);}]){
    const p=structuredClone(value);mutate(p);assert.throws(()=>validateToolSources(p));
  }
  const installed=[{name:'a',version:'1',status:'install ok installed',depends:'b (= 2)'},{name:'b',version:'2',status:'install ok installed',depends:''}];
  assert.equal(packageClosure(installed,[{name:'a',version:'1'}],(a,op,b)=>a===b).length,2);
  for(const rows of [installed.slice(0,1),[installed[0],{...installed[1],version:'3'}],[{...installed[0],status:'deinstall ok config-files'},installed[1]]])assert.throws(()=>packageClosure(rows,[{name:'a',version:'1'}],(a,op,b)=>a===b));
  assert.throws(()=>packageClosure(installed,[{name:'a',version:'1'}],()=>true,[{name:'b',version:'2',origin:'staged',status:'install ok installed'}]));
});
// 合成网络响应仍必须通过完整摘要；错误来源与错摘要不能留下目标文件。
test('App 原件失败输入及tar边界不会获得准备身份',async()=>{
  const {mkdtempSync,readFileSync,existsSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');const {tmpdir}=await import('node:os');const {createHash}=await import('node:crypto');
  const root=mkdtempSync(join(tmpdir(),'app-gate-original-'));const bytes=Buffer.from('fixed official fixture');
  const record={...gateContract().tool_sources.sources.bash,sha256:createHash('sha256').update(bytes).digest('hex')};
  try{
    const file=join(root,'good');await fetchOriginal(record,file,async()=>new Response(bytes));assert.deepEqual(readFileSync(file),bytes);
    await assert.rejects(fetchOriginal({...record,sha256:'0'.repeat(64)},join(root,'bad'),async()=>new Response(bytes)));assert.equal(existsSync(join(root,'bad')),false);
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
  const {sourceMirrors, requestGNUOriginal} = await import("./tools.mjs");
  const {fetchOriginal:readOriginal} = await import('./tools.mjs');
  const {mkdtempSync, readFileSync, existsSync, rmSync} = await import('node:fs');
  const {join} = await import('node:path'); const {tmpdir} = await import('node:os');
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
    await assert.rejects(readOriginal({...record,sha256:'0'.repeat(64)}, rejected, async () => {corrupted++; return new Response(bytes);}));
    assert.equal(corrupted,1); assert.equal(existsSync(rejected),false);
  } finally {rmSync(root,{recursive:true,force:true});}
});

// awk等虚拟依赖必须由已安装真实包提供，闭包继续核验提供包自身的依赖与版本。
test('Ubuntu虚拟包按Provides核验，拒绝缺失、未安装与错误虚拟版本',()=>{
  const status='install ok installed',roots=[{name:'compiler',version:'1'}];
  const records=[{name:'compiler',version:'1',status,depends:'awk'},
    {name:'mawk',version:'99',status,provides:'awk',depends:'libc (>= 2)'},
    {name:'libc',version:'2',status}];
  const compare=(a,op,b)=>op==='='?a===b:op==='>='&&Number(a)>=Number(b);
  const names=rows=>packageClosure(rows,roots,compare).map(record=>record.name);
  assert.deepEqual(names(records),['compiler','libc','mawk']);
  assert.deepEqual(names([{...records[0],depends:'missing | awk:any'},...records.slice(1)]),['compiler','libc','mawk']);
  for(const rows of [records.slice(0,1),records.slice(0,2),
    [records[0],{...records[1],provides:''},records[2]],
    [records[0],{...records[1],status:'deinstall ok config-files'},records[2]],
    [records[0],{...records[1],provides:'awk (>= 2)'},records[2]],
    [records[0],{...records[1],provides:'awk, awk'},records[2]]])assert.throws(()=>names(rows));
  const versioned=[{...records[0],depends:'awk (>= 2)'},{...records[1],version:'1',provides:'awk (= 2)'},records[2]];
  assert.deepEqual(names(versioned),['compiler','libc','mawk']);
  assert.deepEqual(names([...versioned,{name:'awk',version:'1',status}]),['compiler','libc','mawk']);
  for(const provides of ['awk','awk (= 1)'])assert.throws(()=>names([versioned[0],{...records[1],provides},records[2]]));
  assert.throws(()=>packageClosure(records,[{name:'awk',version:'99'}],compare));
});

// 增量检查通过eval导入自身时argv仍指向文件；只有真实主入口才校验准备命令。
test('Runner准备模块导入无副作用，直接入口仍拒绝缺少准确参数',async()=>{
  const {spawnSync}=await import('node:child_process');
  const {fileURLToPath}=await import('node:url');
  const entry=fileURLToPath(new URL('./tools.mjs',import.meta.url));
  const source='await import((await import("node:url")).pathToFileURL(process.argv[1]).href);';
  const options={encoding:'utf8',timeout:10000,env:{PATH:'',NODE_OPTIONS:'',NODE_PATH:''}};
  for(const args of [['--input-type=module','-e',source,entry],['--input-type=module','--eval',source,entry],
    ['--input-type=module','--eval='+source,entry]]){
    const result=spawnSync(process.execPath,args,options);
    assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,0,result.stderr);
    assert.equal(result.stdout,'');assert.equal(result.stderr,'');
  }
  const direct=spawnSync(process.execPath,[entry],options);
  assert.equal(direct.error,undefined);assert.equal(direct.signal,null);assert.equal(direct.status,1);
  assert.match(direct.stderr,/准备参数无效/u);
});

// Ubuntu官方dpkg-dev与debhelper可为同一虚拟名提供不同版本；每个版本须独立满足约束。
test('Ubuntu同名不同版本Provides保留，完全重复声明仍拒绝',()=>{
  const status='install ok installed',roots=[{name:'compiler',version:'1'}];
  const records=[{name:'compiler',version:'1',status,depends:'dpkg-build-api (= 1), debhelper-compat (= 13)'},
    {name:'dpkg-dev',version:'99',status,provides:'dpkg-build-api (= 0), dpkg-build-api (= 1)'},
    {name:'debhelper',version:'99',status,provides:'debhelper-compat (= 9), debhelper-compat (= 10), debhelper-compat (= 11), debhelper-compat (= 12), debhelper-compat (= 13)'}];
  const compare=(a,op,b)=>op==='='&&a===b;
  const names=rows=>packageClosure(rows,roots,compare).map(record=>record.name);
  for(const api of ['0','1'])for(const compat of ['9','10','11','12','13']){
    assert.deepEqual(names([{...records[0],depends:'dpkg-build-api (= '+api+'), debhelper-compat (= '+compat+')'},...records.slice(1)]),
      ['compiler','debhelper','dpkg-dev']);
  }
  for(const depends of ['dpkg-build-api (= 2)','debhelper-compat (= 14)'])assert.throws(()=>names([{...records[0],depends},...records.slice(1)]));
  for(const provides of ['dpkg-build-api (= 0), dpkg-build-api (= 0)',
    'dpkg-build-api (=0), dpkg-build-api (= 0)','dpkg-build-api, dpkg-build-api']){
    assert.throws(()=>names([records[0],{...records[1],provides},records[2]]));
  }
});
