async function institutionsImplementation() {
// CitizenApp 公权机构 finalized 链快照生成器。
//
// 从节点 JSON-RPC 的同一 finalized 块读取 `PublicManage.Institutions` 与
// `PublicManage.InstitutionAccounts`，直接生成链快照索引。
// 生成结果只是 App 本地查询索引；身份、绑定、付款和权限仍在操作前精确读链。
//
// 用法:
//   CHAIN_RPC_URL=https://rpc.example.invalid node scripts/build.mjs generate institutions
//   node scripts/build.mjs generate institutions \
//     --rpc-url https://rpc.example.invalid --at 0x... \
//     --chainspec ../target/chainspec/chainspec.app.json \
//     --out-dir target/test/snapshot/institutions
//
// 正式冻结由 bake-chainspec.sh 显式传入块 0、轻形态 chainspec 和暂存目录；
// 默认路径只服务于人工刷新当前 App 缓存，不构成第二个创世真源。
// Cloudflare Access HTTP 入口可选从环境读取 `CF_ACCESS_CLIENT_ID` 和
// `CF_ACCESS_CLIENT_SECRET`，脚本不会把凭据写入产物或日志。

const { createHash } = await import("node:crypto");
const { writeFileSync, mkdirSync, readFileSync, existsSync } = await import("node:fs");
const { dirname, join, resolve } = await import("node:path");
const { fileURLToPath } = await import("node:url");

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = arg(
  '--out-dir',
  join(__dirname, '..', 'assets', 'institutions'),
);
const CHAIN_SPEC = arg(
  '--chainspec',
  join(__dirname, '..', 'assets', 'chainspec.json'),
);
const CHAIN_RPC_URL = arg(
  '--rpc-url',
  process.env.CHAIN_RPC_URL || '',
);
const PAGE_SIZE = 500;
const BATCH_SIZE = 200;

// twox128("PublicManage") + twox128(storage)。名称变化时必须同时更新链元数据契约。
const INSTITUTIONS_PREFIX =
  '0x3fdf0b7e6001a27b1f4c2913ca162bf72ef145c44f710c6fe55cae381219f7b2';
const ACCOUNTS_PREFIX =
  '0x3fdf0b7e6001a27b1f4c2913ca162bf7ca63afb529001c3370b9aa5ba2bd1fd7';

const PROVINCES = [
  ['ZS', '中枢省'], ['LN', '岭南省'], ['GD', '广东省'], ['GX', '广西省'],
  ['FJ', '福建省'], ['HN', '海南省'], ['YN', '云南省'], ['GZ', '贵州省'],
  ['HU', '湖南省'], ['JX', '江西省'], ['ZJ', '浙江省'], ['JS', '江苏省'],
  ['SD', '山东省'], ['SX', '山西省'], ['HE', '河南省'], ['HB', '河北省'],
  ['HI', '湖北省'], ['SI', '陕西省'], ['CQ', '重庆省'], ['SC', '四川省'],
  ['GS', '甘肃省'], ['BP', '北平省'], ['HA', '海滨省'], ['SJ', '松江省'],
  ['LJ', '龙江省'], ['JL', '吉林省'], ['LI', '辽宁省'], ['NX', '宁夏省'],
  ['QH', '青海省'], ['AH', '安徽省'], ['TW', '台湾省'], ['XZ', '西藏省'],
  ['XJ', '新疆省'], ['XK', '西康省'], ['AL', '阿里省'], ['CL', '葱岭省'],
  ['YL', '伊犁省'], ['HX', '河西省'], ['KL', '昆仑省'], ['HT', '河套省'],
  ['RH', '热河省'], ['XA', '兴安省'], ['HJ', '合江省'],
];
const RESERVED_ACCOUNT_NAMES = new Set([
  '主账户', '费用账户', '永久质押', '安全基金', '两和基金',
]);

function arg(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && index + 1 < process.argv.length
    ? process.argv[index + 1]
    : fallback;
}

function sha256Text(text) {
  return createHash('sha256').update(text).digest('hex');
}

function sha256File(path) {
  return existsSync(path) ? sha256Text(readFileSync(path)) : '';
}

function bytes(hex) {
  const clean = hex.startsWith('0x') ? hex.slice(2) : hex;
  return Buffer.from(clean, 'hex');
}

function readCompact(data, offset) {
  const first = data[offset];
  const mode = first & 3;
  if (mode === 0) return [first >> 2, 1];
  if (mode === 1) return [data.readUInt16LE(offset) >> 2, 2];
  if (mode === 2) return [data.readUInt32LE(offset) >>> 2, 4];
  throw new Error('不支持大整数 SCALE compact 长度');
}

function readVec(data, offset) {
  const [length, lengthBytes] = readCompact(data, offset);
  const start = offset + lengthBytes;
  const end = start + length;
  if (end > data.length) throw new Error('SCALE Vec 越界');
  return [data.subarray(start, end), end];
}

// SCALE Option:None=1 字节(0x00);Some=0x01 + 值。readInner(data, o) 返回值结束后的
// offset。仅用于跳过字段推进 offset（生成包不需要法定代表人字段值）。
function skipOption(data, offset, readInner) {
  const tag = data[offset];
  if (tag === 0) return offset + 1;
  if (tag === 1) return readInner(data, offset + 1);
  throw new Error(`非法 SCALE Option tag=${tag}`);
}

// 当前链上法定代表人是一个原子 Option；Some 内严格依次编码姓、名、公民 CID 和账户。
function skipLegalRepresentative(data, offset) {
  return skipOption(data, offset, (value, innerOffset) => {
    let next = readVec(value, innerOffset)[1];
    next = readVec(value, next)[1];
    next = readVec(value, next)[1];
    if (next + 32 > value.length) throw new Error('法定代表人账户 SCALE 越界');
    return next + 32;
  });
}

// 机构码真源:从 cid_number 核心段还原,与链上 parse_cid_number_parts 逐字一致,
// 免疫链上 InstitutionInfo 结构体字段漂移(primitives/cid/number.rs)。
// 格式 R5(5)-核心段(5)-N9(9)-D4(4);核心段 seg2[3] 为数字→3 字符码,为字母→4 字符码。
function institutionCodeFromCid(cidNumber) {
  const seg2 = cidNumber.split('-')[1] ?? '';
  if (seg2.length !== 5) throw new Error(`cid 核心段格式非法: ${cidNumber}`);
  const isDigit = seg2[3] >= '0' && seg2[3] <= '9';
  return isDigit ? seg2.slice(0, 3) : seg2.slice(0, 4);
}

function decodeInstitutionKey(keyHex) {
  const key = bytes(keyHex);
  const [cid] = readVec(key, 48);
  return cid.toString('utf8');
}

function decodeAccountKey(keyHex) {
  const key = bytes(keyHex);
  const [cid, afterCid] = readVec(key, 48);
  const [accountName] = readVec(key, afterCid + 16);
  return [cid.toString('utf8'), accountName.toString('utf8')];
}

function decodeInstitution(cidNumber, valueHex) {
  const value = bytes(valueHex);
  let offset = 0;
  const [fullName, afterFullName] = readVec(value, offset);
  offset = afterFullName;
  const [shortName, afterShortName] = readVec(value, offset);
  offset = afterShortName;
  const [townCode, afterTownCode] = readVec(value, offset);
  offset = afterTownCode;
  // town_code 与 institution_code 之间只有一个原子 legal_representative Option。
  // 必须按 entity-primitives 的字段顺序整体跳过，不能拆成多个独立 Option。
  offset = skipLegalRepresentative(value, offset);
  if (offset + 8 > value.length) throw new Error(`机构 ${cidNumber} 链值长度不足`);
  // 机构码不从 value blob 切(易随结构漂移),直接从 cid_number 核心段还原(方案B)。
  const institutionCode = institutionCodeFromCid(cidNumber);
  offset += 4; // 跳过 blob 里的 [u8;4] institution_code
  const createdAt = value.readUInt32LE(offset);
  offset += 4;
  // InstitutionInfo 已删除重复 lifecycle/status；Institutions 中存在即为当前有效机构，
  // 关闭时整条身份记录被清理。派生缓存不得继续猜测历史状态字节。
  if (offset !== value.length) {
    throw new Error(`机构 ${cidNumber} 存在未识别 SCALE 尾部字段`);
  }
  const match = /^([A-Z]{2})(\d{3})-/u.exec(cidNumber);
  if (!match) throw new Error(`机构号格式无效: ${cidNumber}`);
  return {
    cid_number: cidNumber,
    cid_full_name: fullName.toString('utf8'),
    cid_short_name: shortName.toString('utf8'),
    status: 'ACTIVE',
    province_code: match[1],
    city_code: match[2],
    town_code: townCode.toString('utf8'),
    institution_code: institutionCode,
    account_count: 0,
    custom_account_names: [],
    created_at_block: createdAt,
  };
}

class JsonRpc {
  constructor(url) {
    // 中文注释：显式配置 Cloudflare Edge 或受信任局域网入口；无明文与隐式回退。
    let endpoint;
    try { endpoint = new URL(url); } catch { throw new Error('链 RPC 必须配置完整 HTTPS/WSS 地址'); }
    if (!['https:', 'wss:'].includes(endpoint.protocol) || endpoint.username || endpoint.password || endpoint.hash) {
      throw new Error('链 RPC 必须配置完整 HTTPS/WSS 地址');
    }
    this.url = endpoint.href;
    this.nextId = 1;
    this.socket = null;
    this.pending = new Map();
  }

  async request(method, params = []) {
    if (this.url.startsWith('https://')) {
      return this.requestHttp(method, params);
    }
    return this.requestWebSocket(method, params);
  }

  async requestHttp(method, params) {
    const id = this.nextId++;
    const headers = { 'content-type': 'application/json' };
    if (process.env.CF_ACCESS_CLIENT_ID && process.env.CF_ACCESS_CLIENT_SECRET) {
      headers['CF-Access-Client-Id'] = process.env.CF_ACCESS_CLIENT_ID;
      headers['CF-Access-Client-Secret'] = process.env.CF_ACCESS_CLIENT_SECRET;
    }
    const response = await fetch(this.url, {
      method: 'POST',
      redirect: 'error',
      signal: AbortSignal.timeout(15_000),
      headers,
      body: JSON.stringify({ jsonrpc: '2.0', id, method, params }),
    });
    if (!response.ok) throw new Error(`${method} HTTP ${response.status}`);
    const payload = await response.json();
    if (payload.error) throw new Error(`${method}: ${JSON.stringify(payload.error)}`);
    return payload.result;
  }

  async requestWebSocket(method, params) {
    await this.ensureSocket();
    const id = this.nextId++;
    const result = new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    this.socket.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
    return result;
  }

  async ensureSocket() {
    if (this.socket?.readyState === WebSocket.OPEN) return;
    this.socket = new WebSocket(this.url);
    this.socket.addEventListener('message', (event) => {
      const payload = JSON.parse(event.data.toString());
      const pending = this.pending.get(payload.id);
      if (!pending) return;
      this.pending.delete(payload.id);
      if (payload.error) pending.reject(new Error(JSON.stringify(payload.error)));
      else pending.resolve(payload.result);
    });
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
    });
  }

  close() {
    this.socket?.close();
  }
}

async function readKeys(rpc, prefix, blockHash) {
  const keys = [];
  let startKey = null;
  for (;;) {
    const page = await rpc.request('state_getKeysPaged', [
      prefix, PAGE_SIZE, startKey, blockHash,
    ]);
    if (!page?.length) break;
    keys.push(...page);
    if (page.length < PAGE_SIZE) break;
    startKey = page.at(-1);
  }
  return keys;
}

async function readValues(rpc, keys, blockHash) {
  const values = new Map();
  for (let start = 0; start < keys.length; start += BATCH_SIZE) {
    const batch = keys.slice(start, start + BATCH_SIZE);
    const result = await rpc.request('state_queryStorageAt', [batch, blockHash]);
    for (const [key, value] of result?.[0]?.changes ?? []) values.set(key, value);
  }
  return values;
}

async function main() {
  if (process.argv.includes('--self-test')) return runInstitutionSelfTest();
  if (!existsSync(CHAIN_SPEC)) {
    throw new Error(`chainspec 不存在: ${CHAIN_SPEC}`);
  }
  const requestedBlockHash = arg('--at', '').trim().toLowerCase();
  if (requestedBlockHash && !/^0x[0-9a-f]{64}$/.test(requestedBlockHash)) {
    throw new Error('--at 必须为 0x + 64 位十六进制块哈希');
  }
  const selectedNames = new Set(
    arg('--provinces', '').split(',').map((value) => value.trim()).filter(Boolean),
  );
  const provinces = selectedNames.size === 0
    ? PROVINCES
    : PROVINCES.filter(([, name]) => selectedNames.has(name));
  if (provinces.length === 0) throw new Error('没有匹配的省份');

  const rpc = new JsonRpc(CHAIN_RPC_URL);
  try {
    const snapshotBlockHash = requestedBlockHash
      || await rpc.request('chain_getFinalizedHead');
    const header = await rpc.request('chain_getHeader', [snapshotBlockHash]);
    const genesisHash = await rpc.request('chain_getBlockHash', [0]);
    if (!header) throw new Error(`找不到快照块头: ${snapshotBlockHash}`);
    if (requestedBlockHash && snapshotBlockHash !== requestedBlockHash) {
      throw new Error(`节点返回了非请求块: ${snapshotBlockHash}`);
    }
    const snapshotBlockNumber = Number.parseInt(header.number, 16);

    const institutionKeys = await readKeys(rpc, INSTITUTIONS_PREFIX, snapshotBlockHash);
    const institutionValues = await readValues(rpc, institutionKeys, snapshotBlockHash);
    const accountKeys = await readKeys(rpc, ACCOUNTS_PREFIX, snapshotBlockHash);

    const accountNames = new Map();
    for (const key of accountKeys) {
      const [cidNumber, accountName] = decodeAccountKey(key);
      if (!accountNames.has(cidNumber)) accountNames.set(cidNumber, []);
      accountNames.get(cidNumber).push(accountName);
    }

    const institutions = [];
    for (const key of institutionKeys) {
      const value = institutionValues.get(key);
      if (!value) continue;
      const institution = decodeInstitution(decodeInstitutionKey(key), value);
      const names = [...new Set(accountNames.get(institution.cid_number) ?? [])];
      institution.account_count = names.length;
      institution.custom_account_names = names
        .filter((name) => !RESERVED_ACCOUNT_NAMES.has(name))
        .sort();
      institutions.push(institution);
    }
    institutions.sort((a, b) => a.cid_number.localeCompare(b.cid_number));

    mkdirSync(OUT_DIR, { recursive: true });
    const shardHashes = {};
    const provinceVersions = [];
    const rootParts = [];
    let total = 0;
    for (const [provinceCode, provinceName] of provinces) {
      const rows = institutions.filter((row) => row.province_code === provinceCode);
      const manifestVersion = sha256Text(JSON.stringify(rows));
      const shard = {
        province_name: provinceName,
        manifest_version: manifestVersion,
        count: rows.length,
        institutions: rows,
      };
      const shardJson = `${JSON.stringify(shard)}\n`;
      writeFileSync(join(OUT_DIR, `${provinceName}.json`), shardJson);
      const shardHash = sha256Text(shardJson);
      shardHashes[provinceName] = shardHash;
      const item = {
        province_name: provinceName,
        manifest_version: manifestVersion,
        shard_hash: shardHash,
        count: rows.length,
      };
      provinceVersions.push(item);
      rootParts.push(item);
      total += rows.length;
      process.stdout.write(`  ${provinceName}: ${rows.length} 机构\n`);
    }

    const publicInstitutionRoot = sha256Text(JSON.stringify(rootParts));
    writeFileSync(
      join(OUT_DIR, 'manifest.json'),
      `${JSON.stringify({
        chain_id: arg('--chain-id', 'citizenchain'),
        snapshot_block_number: snapshotBlockNumber,
        snapshot_block_hash: snapshotBlockHash,
        genesis_hash: genesisHash,
        state_root: header.stateRoot,
        chainspec_hash: sha256File(CHAIN_SPEC),
        public_institution_root: publicInstitutionRoot,
        version: `${snapshotBlockHash}:${publicInstitutionRoot}`,
        shard_hashes: shardHashes,
        provinces: provinceVersions,
      }, null, 2)}\n`,
    );
    process.stdout.write(
      `snapshot #${snapshotBlockNumber}: ${provinces.length} 省，共 ${total} 机构；`
      + `public_institution_root=${publicInstitutionRoot}\n`,
    );
  } finally {
    rpc.close();
  }
}

return {JsonRpc,main,decodeInstitution};
}
const institutions = await institutionsImplementation();
export const {JsonRpc}=institutions;
async function generateDivisions() {
// 行政区字典数据包生成器(ADR-021 §A2)。
//
// 唯一真源 = citizenchain/onchina/src/cid/china/china.sqlite。本生成器**直接 dump 三表,零映射**:
// 任何「修正名字」逻辑禁止进此文件——改名只改 china.sqlite,这里纯搬运。
// 铁律：china.sqlite 行政区 code 不可变、不复用，生成器禁止改写源数据。
//
// 产物(按省分片,客户端按需懒加载;首启灌 Isar AdminDivisionEntity 作字典):
//   assets/divisions/manifest.json
//     = { version, generated_at, china_sqlite_sha256, province_count, city_count, town_count }
//   assets/divisions/provinces.json          = [{ code, name }]
//   assets/divisions/cities/<省code>.json    = [{ code, name }]
//   assets/divisions/towns/<省code>.json     = [{ city_code, code, name }]
//
// manifest 带 china_sqlite_sha256 + version,与机构包同批生成、版本耦合:客户端可校验
// 机构包与字典是否同一份 china.sqlite 派生(hash 不一致即提示需更新)。
//
// 用法:
//   node scripts/build.mjs generate divisions [--version 2] [--db <路径>]

const { DatabaseSync } = await import("node:sqlite");
const { writeFileSync, mkdirSync, readFileSync, rmSync } = await import("node:fs");
const { createHash } = await import("node:crypto");
const { dirname, join, resolve } = await import("node:path");
const { fileURLToPath } = await import("node:url");

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, '..', 'assets', 'divisions');
const DEFAULT_DB = resolve(
  __dirname,
  '..',
  '..',
  'citizenchain',
  'onchina',
  'src',
  'cid',
  'china',
  'china.sqlite',
);

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && i + 1 < process.argv.length ? process.argv[i + 1] : fallback;
}

function main() {
  const dbPath = arg('--db', DEFAULT_DB);
  const sha256 = createHash('sha256').update(readFileSync(dbPath)).digest('hex');

  const db = new DatabaseSync(dbPath, { readOnly: true });
  const metadataVersion = db
    .prepare("SELECT value FROM metadata WHERE key = 'admin_division_version'")
    .get()?.value;
  const version = arg('--version', metadataVersion ? String(metadataVersion) : '0');

  // 省:全量一份
  const provinces = db
    .prepare('SELECT code, name FROM provinces ORDER BY sort_order, code')
    .all();

  // 市:按省分片
  const cities = db
    .prepare('SELECT province_code, code, name FROM cities ORDER BY province_code, sort_order, code')
    .all();
  const citiesByProv = new Map();
  for (const r of cities) {
    if (!citiesByProv.has(r.province_code)) citiesByProv.set(r.province_code, []);
    citiesByProv.get(r.province_code).push({ code: r.code, name: r.name });
  }

  // 镇:按省分片(最大头)
  const towns = db
    .prepare('SELECT province_code, city_code, code, name FROM towns ORDER BY province_code, city_code, code')
    .all();
  const townsByProv = new Map();
  for (const r of towns) {
    if (!townsByProv.has(r.province_code)) townsByProv.set(r.province_code, []);
    townsByProv.get(r.province_code).push({ city_code: r.city_code, code: r.code, name: r.name });
  }

  db.close();

  // 先清空分片目录,避免省 code 改名后旧分片继续留在安装包中。
  rmSync(join(OUT_DIR, 'cities'), { recursive: true, force: true });
  rmSync(join(OUT_DIR, 'towns'), { recursive: true, force: true });
  mkdirSync(join(OUT_DIR, 'cities'), { recursive: true });
  mkdirSync(join(OUT_DIR, 'towns'), { recursive: true });

  writeFileSync(join(OUT_DIR, 'provinces.json'), JSON.stringify(provinces, null, 0));
  for (const [pcode, list] of citiesByProv) {
    writeFileSync(join(OUT_DIR, 'cities', `${pcode}.json`), JSON.stringify(list, null, 0));
  }
  for (const [pcode, list] of townsByProv) {
    writeFileSync(join(OUT_DIR, 'towns', `${pcode}.json`), JSON.stringify(list, null, 0));
  }

  // 省级内容版本(增量同步用):客户端按 ver 跳过没变的省,只 reconcile 变了的省。
  // ver = 该省"市分片 + 镇分片"内容的 sha256 前 16 位,内容(含改名/删码/重排)一变即变。
  const provinceVersions = provinces.map((p) => {
    const payload =
      JSON.stringify(citiesByProv.get(p.code) ?? []) +
      JSON.stringify(townsByProv.get(p.code) ?? []);
    return { code: p.code, ver: createHash('sha256').update(payload).digest('hex').slice(0, 16) };
  });

  writeFileSync(
    join(OUT_DIR, 'manifest.json'),
    JSON.stringify(
      {
        version,
        generated_at: version,
        china_sqlite_sha256: sha256,
        province_count: provinces.length,
        city_count: cities.length,
        town_count: towns.length,
        // 省级版本表:[{ code, ver }],客户端逐省比对,只重灌 ver 变了的省。
        provinces: provinceVersions,
      },
      null,
      2,
    ),
  );

  // 命令行生成器的正式结果直接写入标准输出，不使用会被开发残留门禁禁止的调试日志接口。
  process.stdout.write(
    `行政区字典生成完成:省 ${provinces.length} / 市 ${cities.length} / 镇 ${towns.length}` +
      `\n  version=${version}\n  china_sqlite_sha256=${sha256.slice(0, 16)}…\n  out=${OUT_DIR}\n`,
  );
}

main();

}
async function generateRegistry() {
const { execFileSync } = await import("node:child_process");
const {default: fs} = await import("node:fs");
const {default: path} = await import("node:path");
const { fileURLToPath } = await import("node:url");

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cbPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_cb.rs');
const chPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_ch.rs');
const zfPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_zf.rs');
const sfPath = path.join(repoRoot, 'citizenchain/runtime/primitives/cid/china/china_sf.rs');
const outPath = path.join(
  repoRoot,
  'citizenapp/lib/citizen/institution/governance_registry.generated.dart',
);

function extractField(block, name) {
  const quoted = new RegExp(`${name}:\\s*"([^"]+)"`).exec(block);
  if (quoted) return quoted[1];
  const hex = new RegExp(`${name}:\\s*hex!\\("([0-9a-fA-F]+)"\\)`).exec(block);
  if (hex) return hex[1].toLowerCase();
  throw new Error(`missing ${name} in block:\n${block.slice(0, 240)}`);
}

function extractStructs(source, structName) {
  const blocks = [];
  const pattern = new RegExp(`${structName}\\s*\\{([\\s\\S]*?)\\n\\s*\\},`, 'g');
  let match;
  while ((match = pattern.exec(source)) !== null) {
    blocks.push(match[1]);
  }
  // 数据块必含带引号的 cid_number；懒惰正则会把 struct 定义体与后续
  // 非数据常量(如 FscGenesisAssignment)误捕成块,在此过滤。
  return blocks.filter((block) => /cid_number:\s*"/.test(block));
}

function dartString(value) {
  return `'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'`;
}

/// AccountId 规范形式（ADR-040）：小写 `0x` + 64 位十六进制。
/// china_*.rs 里是 `hex!("…")` 裸 hex，落到 Dart 必须补 `0x`，
/// 否则 `isAccountIdText()` 判定失败。
function dartAccountId(hex) {
  if (!/^[0-9a-f]{64}$/.test(hex)) {
    throw new Error(`invalid account id hex: ${hex}`);
  }
  return dartString(`0x${hex}`);
}

function dartInstitution(item) {
  const lines = [
    '  InstitutionInfo(',
    `    cidFullName: ${dartString(item.cidFullName)},`,
    `    cidShortName: ${dartString(item.cidShortName)},`,
    `    cidFullNameEn: ${dartString(item.cidFullNameEn)},`,
    `    cidShortNameEn: ${dartString(item.cidShortNameEn)},`,
    `    cidNumber: ${dartString(item.cidNumber)},`,
    `    orgType: OrgType.${item.orgType},`,
  ];
  if (item.adminAccountCode) {
    lines.push(`    adminAccountCode: ${dartString(item.adminAccountCode)},`);
  }
  lines.push(
    '    accounts: InstitutionAccounts(',
    `      mainAccountId: ${dartAccountId(item.mainAccount)},`,
    `      feeAccountId: ${dartAccountId(item.feeAccount)},`,
  );
  if (item.safetyFundAccount) {
    lines.push(`      safetyFundAccountId: ${dartAccountId(item.safetyFundAccount)},`);
  }
  if (item.heAccount) {
    lines.push(`      heAccountId: ${dartAccountId(item.heAccount)},`);
  }
  if (item.stakeAccount) {
    lines.push(`      stakeAccountId: ${dartAccountId(item.stakeAccount)},`);
  }
  lines.push('    ),', '  ),');
  return lines.join('\n');
}

const cbSource = fs.readFileSync(cbPath, 'utf8');
const chSource = fs.readFileSync(chPath, 'utf8');
const zfSource = fs.readFileSync(zfPath, 'utf8');
const sfSource = fs.readFileSync(sfPath, 'utf8');
const safetyFundMatch = /SAFETY_FUND_ACCOUNT:\s*\[u8;\s*32\]\s*=\s*hex!\("([0-9a-fA-F]+)"\)/.exec(
  cbSource,
);
if (!safetyFundMatch) throw new Error('missing SAFETY_FUND_ACCOUNT');
const safetyFundAccount = safetyFundMatch[1].toLowerCase();
const heFundMatch = /NRC_HE_ACCOUNT:\s*\[u8;\s*32\]\s*=\s*hex!\("([0-9a-fA-F]+)"\)/.exec(
  cbSource,
);
if (!heFundMatch) throw new Error('missing NRC_HE_ACCOUNT');
const heAccount = heFundMatch[1].toLowerCase();

const cbItems = extractStructs(cbSource, 'ChinaCb').map((block, index) => ({
  cidFullName: extractField(block, 'cid_full_name'),
  cidShortName: extractField(block, 'cid_short_name'),
  cidFullNameEn: extractField(block, 'cid_full_name_en'),
  cidShortNameEn: extractField(block, 'cid_short_name_en'),
  cidNumber: extractField(block, 'cid_number'),
  orgType: index === 0 ? 'nrc' : 'prc',
  mainAccount: extractField(block, 'main_account'),
  feeAccount: extractField(block, 'fee_account'),
  safetyFundAccount: index === 0 ? safetyFundAccount : null,
  heAccount: index === 0 ? heAccount : null,
  stakeAccount: null,
}));

const chItems = extractStructs(chSource, 'ChinaCh').map((block) => ({
  cidFullName: extractField(block, 'cid_full_name'),
  cidShortName: extractField(block, 'cid_short_name'),
  cidFullNameEn: extractField(block, 'cid_full_name_en'),
  cidShortNameEn: extractField(block, 'cid_short_name_en'),
  cidNumber: extractField(block, 'cid_number'),
  orgType: 'prb',
  mainAccount: extractField(block, 'main_account'),
  feeAccount: extractField(block, 'fee_account'),
  safetyFundAccount: null,
  heAccount: null,
  stakeAccount: extractField(block, 'stake_account'),
}));

function codeFromCidNumber(cidNumber) {
  const parts = cidNumber.split('-');
  if (parts.length < 2) throw new Error(`invalid cid_number: ${cidNumber}`);
  return parts[1].slice(0, 3);
}

function fixedGovernanceItemFrom(source, structName, code) {
  const block = extractStructs(source, structName).find(
    (item) => codeFromCidNumber(extractField(item, 'cid_number')) === code,
  );
  if (!block) throw new Error(`missing ${code} in ${structName}`);
  return {
    cidFullName: extractField(block, 'cid_full_name'),
    cidShortName: extractField(block, 'cid_short_name'),
    cidFullNameEn: extractField(block, 'cid_full_name_en'),
    cidShortNameEn: extractField(block, 'cid_short_name_en'),
    cidNumber: extractField(block, 'cid_number'),
    orgType: 'institution',
    adminAccountCode: code,
    mainAccount: extractField(block, 'main_account'),
    feeAccount: extractField(block, 'fee_account'),
    safetyFundAccount: null,
    heAccount: null,
    stakeAccount: null,
  };
}

const fixedGovernanceItems = [
  fixedGovernanceItemFrom(zfSource, 'ChinaZf', 'FRG'),
  fixedGovernanceItemFrom(sfSource, 'ChinaSf', 'NJD'),
];

if (cbItems.length !== 44) {
  throw new Error(`CHINA_CB count mismatch: ${cbItems.length}`);
}
if (chItems.length !== 43) {
  throw new Error(`CHINA_CH count mismatch: ${chItems.length}`);
}

const content = [
  "part of 'governance_registry.dart';",
  '',
  '// 本文件由 node scripts/build.mjs generate registry 自动生成。',
  '// 中文注释：创世治理机构中英全称/简称、cid_number 和制度账户来自 runtime primitives；管理员必须动态读取链上 AdminAccounts。',
  '',
  '/// 国储会（1 个）。',
  'const List<InstitutionInfo> kNrc = [',
  dartInstitution(cbItems[0]),
  '];',
  '',
  '/// 省储会（43 个）。',
  'const List<InstitutionInfo> kPrcs = [',
  cbItems.slice(1).map(dartInstitution).join('\n'),
  '];',
  '',
  '/// 省储行（43 个）。',
  'const List<InstitutionInfo> kProvincialBanks = [',
  chItems.map(dartInstitution).join('\n'),
  '];',
  '',
  '/// 其它固定治理机构（不进入治理 tab 联合投票列表）。',
  'const List<InstitutionInfo> kFixedGovernanceInstitutions = [',
  fixedGovernanceItems.map(dartInstitution).join('\n'),
  '];',
  '',
].join('\n');

fs.writeFileSync(outPath, content, 'utf8');
// 生成物必须是 dart format 稳定态，否则每次重生都在格式上打架。
execFileSync('dart', ['format', outPath], { stdio: 'inherit' });
console.log(`generated ${path.relative(repoRoot, outPath)} (${cbItems.length + chItems.length + fixedGovernanceItems.length} institutions)`);

}

// 数据生成器原有SCALE自检也放在正式代码之后。
function runInstitutionSelfTest(){
 const {decodeInstitution}=institutions;

    const compactSmall = (length) => {
      if (!Number.isInteger(length) || length < 0 || length >= 64) {
        throw new Error('self-test 只编码单字节 compact');
      }
      return Buffer.from([length << 2]);
    };
    const vec = (value) => {
      const data = Buffer.from(value, 'utf8');
      return Buffer.concat([compactSmall(data.length), data]);
    };
    const rawNone = Buffer.concat([
      vec('测试公权机构'),
      vec('测试机构'),
      vec(''),
      Buffer.from([0]), // 原子 legal_representative=None
      Buffer.from('CAGR', 'ascii'),
      Buffer.from([7, 0, 0, 0]),
    ]);
    const decodedNone = decodeInstitution(
      'HE036-CAGRA-251174662-2026',
      `0x${rawNone.toString('hex')}`,
    );
    const rawSome = Buffer.concat([
      vec('测试公权机构'),
      vec('测试机构'),
      vec(''),
      Buffer.from([1]),
      vec('管'),
      vec('理员'),
      vec('HE000-CTZN0-198805200-2026'),
      Buffer.alloc(32, 9),
      Buffer.from('CAGR', 'ascii'),
      Buffer.from([8, 0, 0, 0]),
    ]);
    const decodedSome = decodeInstitution(
      'HE036-CAGRA-251174662-2026',
      `0x${rawSome.toString('hex')}`,
    );
    if (decodedNone.status !== 'ACTIVE' || decodedNone.created_at_block !== 7
        || decodedNone.institution_code !== 'CAGR'
        || decodedSome.created_at_block !== 8
        || decodedSome.institution_code !== 'CAGR') {
      throw new Error(
        `InstitutionInfo SCALE self-test 失败:${JSON.stringify({ decodedNone, decodedSome })}`,
      );
    }
    process.stdout.write('public institution SCALE self-test ok\n');
    return;

}


export async function runDataGeneration(kind) {
  if (kind === 'divisions') return generateDivisions();
  if (kind === 'institutions') return institutions.main();
  if (kind === 'registry') return generateRegistry();
  throw Error('数据生成类型无效');
}
