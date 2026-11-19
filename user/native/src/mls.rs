use openmls::prelude::{tls_codec::Serialize as TlsSerialize, Ciphersuite, SignContent, VLBytes};
use openmls_basic_credential::SignatureKeyPair;
use openmls_memory_storage::MemoryStorage;
use openmls_rust_crypto::RustCrypto;
use openmls_traits::{crypto::OpenMlsCrypto, signatures::Signer, types::HashType};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    ffi::CStr,
    fs,
    os::raw::c_char,
    path::{Path, PathBuf},
};

const GMB_MLS_CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
const ERROR_STORAGE_READ: &str = "DEVICE_MLS_STORAGE_READ_FAILED";
const ERROR_STATE_MISSING: &str = "DEVICE_MLS_STATE_MISSING";
const ERROR_STATE_INVALID: &str = "DEVICE_MLS_STATE_INVALID";
const ERROR_SIGNER_MISSING: &str = "DEVICE_MLS_SIGNER_MISSING";
// RFC9420应用认证扩展域；调用方不能自选标签，也不能签任意原始字节。
const AUTHENTICATION_LABEL: &str = "CitizenRequestV2";
const MAX_AUTHENTICATION_BODY_BYTES: usize = 1024 * 1024;
const MAX_JSON_INTEGER: u64 = (1 << 53) - 1;
const AUTHENTICATION_LIFETIME_MILLIS: u64 = 5 * 60 * 1000;
/// 错误只携带稳定阶段码，禁止包含状态中的秘密。
fn state_error(code: &str, message: impl std::fmt::Display) -> String {
    format!("{code}:{message}")
}

#[derive(Deserialize)]
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
enum IdentityRequest {
    Prepare {
        state_store_dir: String,
        user_id: String,
    },
    Read {
        state_store_dir: String,
        user_id: String,
    },
    SignAuthentication {
        state_store_dir: String,
        user_id: String,
        account_id: String,
        bind_rev: u64,
        request: AuthenticationRequest,
    },
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AuthenticationRequest {
    token_purpose: String,
    session_hash: Option<String>,
    service_origin: String,
    nonce_id: String,
    expires_at: u64,
    http_method: String,
    request_target: String,
    body_hex: String,
}

/// 只返回公开证明；正文和私钥均不进入响应或持久化结果。
#[derive(Clone, Serialize)]
struct AuthenticationProof {
    token_purpose: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    session_hash: Option<String>,
    user_id: String,
    device_id: String,
    public_key: String,
    account_id: String,
    bind_rev: u64,
    service_origin: String,
    nonce_id: String,
    expires_at: u64,
    http_method: String,
    request_target: String,
    body_hash: String,
    signature: String,
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct DeviceRecord {
    user_id: String,
    device_id: String,
    public_key: String,
}

/// 签名状态只读取设备记录和原存储条目，只解释签名身份所需字段。
#[derive(Serialize, Deserialize)]
struct DeviceSnapshot {
    device: DeviceRecord,
    values: HashMap<String, String>,
}

struct DeviceState {
    crypto: RustCrypto,
    storage: MemoryStorage,
    device: DeviceRecord,
}

/// 仅提供设备身份和固定请求签名。
///
/// # Safety
/// 输入须为有效的空字符结尾 C 字符串，错误输出须为空或指向可写指针。
#[no_mangle]
pub unsafe extern "C" fn mls_identity_json(
    input: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match identity_json(input) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}
fn identity_json(input: *const c_char) -> Result<String, String> {
    let request: IdentityRequest = parse_request(input)?;
    let (state_store_dir, user_id) = match &request {
        IdentityRequest::Prepare {
            state_store_dir,
            user_id,
        }
        | IdentityRequest::Read {
            state_store_dir,
            user_id,
        }
        | IdentityRequest::SignAuthentication {
            state_store_dir,
            user_id,
            ..
        } => (state_store_dir, user_id),
    };
    require_identity_component(user_id)?;
    let dir = Path::new(state_store_dir);
    let lock = lock_store(dir)?;
    let phase = read_identity_phase(&lock, user_id)?;
    let has_snapshot = match fs::symlink_metadata(storage_path(dir)) {
        Ok(_) => true,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => false,
        Err(_) => return Err(state_error(ERROR_STORAGE_READ, "MLS状态元数据不可读")),
    };
    let provider = if has_snapshot {
        // 完整快照优先；提交后回执丢失或阶段写入中断也只能返回同一身份。
        load_provider(dir)?
    } else {
        if phase == 2 {
            return Err(state_error(ERROR_STATE_MISSING, "已提交的MLS身份文件缺失"));
        }
        if phase == 3 {
            return Err(state_error(ERROR_STATE_INVALID, "MLS初始化阶段损坏"));
        }
        // 合法空目录和未交付阶段由同一prepare自动完成；目录创建时间不是权限事实。
        if !matches!(&request, IdentityRequest::Prepare { .. }) {
            return Err(state_error(ERROR_STATE_MISSING, "本机MLS身份尚未准备"));
        }
        validate_initialization_directory(dir, phase == 1)?;
        // 在任何密钥生成前持久提交阶段；只有未交付过身份的阶段允许自动续行。
        write_identity_phase(&lock, dir, b"initializing\n", user_id)?;
        let storage = MemoryStorage::default();
        let signer = SignatureKeyPair::new(GMB_MLS_CIPHERSUITE.signature_algorithm())
            .map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份生成失败"))?;
        signer
            .store(&storage)
            .map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份保存失败"))?;
        let public = hex::encode(signer.to_public_vec());
        let provider = DeviceState {
            crypto: RustCrypto::default(),
            storage,
            device: DeviceRecord {
                user_id: user_id.clone(),
                device_id: public.clone(),
                public_key: format!("0x{public}"),
            },
        };
        save_provider(dir, &provider)?;
        provider
    };
    let signer = read_device_signer(&provider, user_id, &provider.device.device_id)?;
    // 先验证归属，再提交已交付阶段；完整身份和阶段都同步成功后才返回公开身份/证明。
    if phase != 2 {
        write_identity_phase(&lock, dir, b"committed\n", user_id)?;
    }
    if let IdentityRequest::SignAuthentication {
        account_id,
        bind_rev,
        request,
        ..
    } = &request
    {
        // 同一锁下只读已有身份，签名不重写持久状态。
        let proof = authentication_proof(&provider, &signer, account_id, *bind_rev, request)?;
        return serde_json::to_string(&proof).map_err(|_| authentication_error());
    }
    serde_json::to_string(&provider.device)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "公开身份序列化失败"))
}

/// state.lock同时持锁和记录阶段，不另建秘密或快照文件。未知旧空锁不代表首次初始化。
fn identity_phase_bytes(user: &str, phase: &[u8]) -> Result<Vec<u8>, String> {
    let owner = RustCrypto::default()
        .hash(HashType::Sha2_256, user.as_bytes())
        .map_err(|_| state_error(ERROR_STATE_INVALID, "初始化归属校验失败"))?;
    let mut bytes = phase.to_vec();
    bytes.extend_from_slice(hex::encode(owner).as_bytes());
    Ok(bytes)
}
fn read_identity_phase(mut file: &fs::File, user: &str) -> Result<u8, String> {
    use std::io::{Read, Seek, SeekFrom};
    file.seek(SeekFrom::Start(0))
        .map_err(|_| state_error(ERROR_STORAGE_READ, "初始化阶段不可读"))?;
    let mut bytes = Vec::new();
    file.take(128)
        .read_to_end(&mut bytes)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "初始化阶段不可读"))?;
    if bytes.is_empty() {
        return Ok(0);
    }
    for (phase, value) in [
        (b"initializing\n".as_slice(), 1),
        (b"committed\n".as_slice(), 2),
    ] {
        if bytes == identity_phase_bytes(user, phase)? {
            return Ok(value);
        }
        if bytes.starts_with(phase) && bytes.len() == phase.len() + 64 {
            return Err(state_error(
                "DEVICE_MLS_STATE_OWNER_MISMATCH",
                "初始化阶段属于其他用户",
            ));
        }
    }
    Ok(3)
}
fn write_identity_phase(
    mut file: &fs::File,
    dir: &Path,
    phase: &[u8],
    user: &str,
) -> Result<(), String> {
    use std::io::{Seek, SeekFrom, Write};
    let bytes = identity_phase_bytes(user, phase)?;
    file.seek(SeekFrom::Start(0))
        .and_then(|_| file.write_all(&bytes))
        .and_then(|_| file.set_len(bytes.len() as u64))
        .and_then(|_| file.sync_all())
        .and_then(|_| fs::File::open(dir)?.sync_all())
        .map_err(|_| state_error(ERROR_STORAGE_READ, "初始化阶段提交失败"))
}
fn validate_initialization_directory(dir: &Path, pending: bool) -> Result<(), String> {
    for entry in
        fs::read_dir(dir).map_err(|_| state_error(ERROR_STORAGE_READ, "初始化目录不可读"))?
    {
        let entry = entry.map_err(|_| state_error(ERROR_STORAGE_READ, "初始化目录不可读"))?;
        if entry.file_name() != "state.lock" && !(pending && entry.file_name() == "state.writing") {
            return Err(state_error(ERROR_STATE_INVALID, "目录含有未确认的MLS状态"));
        }
        require_regular_file(&entry.path())?;
    }
    Ok(())
}

fn authentication_error() -> String {
    "DEVICE_MLS_AUTHENTICATION_INVALID".into()
}

/// 规范32字节公开值；禁止大小写、无前缀和宽松解码别名。
fn authentication_hex(value: &str) -> Result<Vec<u8>, String> {
    if value.len() != 66
        || !value.starts_with("0x")
        || !value[2..]
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(authentication_error());
    }
    hex::decode(&value[2..]).map_err(|_| authentication_error())
}

/// 目标是规范HTTPS源，不接受凭据/路径/查询/片段或默认端口别名。
fn validate_authentication_origin(origin: &str) -> Result<(), String> {
    let authority = origin
        .strip_prefix("https://")
        .ok_or_else(authentication_error)?;
    if authority.is_empty()
        || authority.len() > 260
        || !authority.bytes().all(|b| b.is_ascii_graphic())
        || authority.contains(['/', '\\', '@', '?', '#'])
    {
        return Err(authentication_error());
    }
    let (host, port) = if authority.starts_with('[') {
        let end = authority.find(']').ok_or_else(authentication_error)?;
        let address = &authority[1..end];
        let parsed = address
            .parse::<std::net::Ipv6Addr>()
            .map_err(|_| authentication_error())?;
        if address != parsed.to_string() {
            return Err(authentication_error());
        }
        let suffix = &authority[end + 1..];
        let port = if suffix.is_empty() {
            None
        } else {
            Some(suffix.strip_prefix(':').ok_or_else(authentication_error)?)
        };
        (&authority[..=end], port)
    } else {
        let (host, port) = match authority.split_once(':') {
            Some((host, port)) => (host, Some(port)),
            None => (authority, None),
        };
        if host.len() > 253
            || host.split('.').any(|label| {
                label.is_empty()
                    || label.len() > 63
                    || label.starts_with('-')
                    || label.ends_with('-')
                    || !label
                        .bytes()
                        .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            })
        {
            return Err(authentication_error());
        }
        (host, port)
    };
    if host.is_empty() {
        return Err(authentication_error());
    }
    if let Some(port) = port {
        let number = port.parse::<u16>().map_err(|_| authentication_error())?;
        if number == 0 || number == 443 || port != number.to_string() {
            return Err(authentication_error());
        }
    }
    Ok(())
}

fn validate_authentication_target(target: &str) -> Result<(), String> {
    if target.len() > 8192
        || !target.starts_with('/')
        || target.starts_with("//")
        || !target.bytes().all(|b| b.is_ascii_graphic())
        || target.contains(['#', '\\'])
    {
        return Err(authentication_error());
    }
    let bytes = target.as_bytes();
    for (index, byte) in bytes.iter().enumerate() {
        if *byte == b'%'
            && (index + 2 >= bytes.len()
                || !bytes[index + 1].is_ascii_hexdigit()
                || !bytes[index + 2].is_ascii_hexdigit())
        {
            return Err(authentication_error());
        }
    }
    Ok(())
}

fn authentication_proof(
    provider: &DeviceState,
    signer: &SignatureKeyPair,
    account_id: &str,
    bind_rev: u64,
    request: &AuthenticationRequest,
) -> Result<AuthenticationProof, String> {
    let public = authentication_hex(&provider.device.public_key)?;
    if signer.signature_scheme() != GMB_MLS_CIPHERSUITE.signature_algorithm() {
        return Err(state_error(ERROR_STATE_INVALID, "MLS签名身份算法不符"));
    }
    authentication_hex(account_id)?;
    authentication_hex(&request.nonce_id)?;
    validate_authentication_origin(&request.service_origin)?;
    validate_authentication_target(&request.request_target)?;
    let now = now_millis()?;
    if !matches!(
        request.token_purpose.as_str(),
        "device" | "session" | "request"
    ) || (request.token_purpose == "request") != request.session_hash.is_some()
    {
        return Err(authentication_error());
    }
    if let Some(h) = &request.session_hash {
        authentication_hex(&format!("0x{h}"))?;
    }
    if bind_rev > MAX_JSON_INTEGER
        || request.expires_at > MAX_JSON_INTEGER
        || request.expires_at <= now
        || request.expires_at - now > AUTHENTICATION_LIFETIME_MILLIS
        || !matches!(
            request.http_method.as_str(),
            "GET" | "HEAD" | "POST" | "PUT" | "PATCH" | "DELETE" | "OPTIONS"
        )
        || request.body_hex.len() > MAX_AUTHENTICATION_BODY_BYTES * 2
        || request.body_hex.len() % 2 != 0
        || !request
            .body_hex
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(authentication_error());
    }
    let body = hex::decode(&request.body_hex).map_err(|_| authentication_error())?;
    let hash = provider
        .crypto
        .hash(HashType::Sha2_256, &body)
        .map_err(|_| authentication_error())?;
    let mut proof = AuthenticationProof {
        token_purpose: request.token_purpose.clone(),
        session_hash: request.session_hash.clone(),
        user_id: provider.device.user_id.clone(),
        device_id: provider.device.device_id.clone(),
        public_key: provider.device.public_key.clone(),
        account_id: account_id.into(),
        bind_rev,
        service_origin: request.service_origin.clone(),
        nonce_id: request.nonce_id.clone(),
        expires_at: request.expires_at,
        http_method: request.http_method.clone(),
        request_target: request.request_target.clone(),
        body_hash: format!("0x{}", hex::encode(hash)),
        signature: String::new(),
    };
    // 固定结构content由原生构造，外层SignContent使用OpenMLS的标准TLS编码。
    let content = authentication_content(&proof)?;
    let encoded = SignContent::new(AUTHENTICATION_LABEL, content.into())
        .tls_serialize_detached()
        .map_err(|_| authentication_error())?;
    let signature = signer.sign(&encoded).map_err(|_| authentication_error())?;
    // 可解析的私有材料也可能损坏；本机先验签，禁止交付与登记公钥不匹配的证明。
    provider
        .crypto
        .verify_signature(
            GMB_MLS_CIPHERSUITE.signature_algorithm(),
            &encoded,
            &public,
            &signature,
        )
        .map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份与公钥不匹配"))?;
    proof.signature = format!("0x{}", hex::encode(signature));
    // 签名完成后再次检查有效期，不能返回处理期间已经过期的证明。
    if proof.expires_at <= now_millis()? {
        return Err(authentication_error());
    }
    Ok(proof)
}

fn authentication_content(proof: &AuthenticationProof) -> Result<Vec<u8>, String> {
    let mut content = vec![match proof.token_purpose.as_str() {
        "device" => 0,
        "session" => 1,
        "request" => 2,
        _ => return Err(authentication_error()),
    }];
    if let Some(h) = &proof.session_hash {
        content.extend(authentication_hex(&format!("0x{h}"))?);
    }
    fn text(content: &mut Vec<u8>, value: &str) -> Result<(), String> {
        VLBytes::from(value.as_bytes().to_vec())
            .tls_serialize(content)
            .map(|_| ())
            .map_err(|_| authentication_error())
    }
    text(&mut content, &proof.user_id)?;
    content.extend(authentication_hex(&format!("0x{}", proof.device_id))?);
    content.extend(authentication_hex(&proof.account_id)?);
    content.extend(proof.bind_rev.to_be_bytes());
    text(&mut content, &proof.service_origin)?;
    content.extend(authentication_hex(&proof.nonce_id)?);
    content.extend(proof.expires_at.to_be_bytes());
    text(&mut content, &proof.http_method)?;
    text(&mut content, &proof.request_target)?;
    content.extend(authentication_hex(&proof.body_hash)?);
    Ok(content)
}

fn parse_request<T>(request_json: *const c_char) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    if request_json.is_null() {
        return Err("request_json is null".to_string());
    }
    let request = unsafe { CStr::from_ptr(request_json) }
        .to_str()
        .map_err(|_| "request_json 不是合法 UTF-8".to_string())?;
    serde_json::from_str(request).map_err(|_| "解析request_json失败，字段或结构非法".to_string())
}

fn load_provider(dir: &Path) -> Result<DeviceState, String> {
    use base64::Engine;
    use std::io::Read;
    let path = storage_path(dir);
    require_regular_file(&path)?;
    let mut options = fs::OpenOptions::new();
    options.read(true);
    #[cfg(any(target_os = "ios", target_os = "macos"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(0x100);
    }
    #[cfg(any(target_os = "android", target_os = "linux"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(0x20000);
    }
    let mut file = options
        .open(&path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS状态读取失败"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if file
            .metadata()
            .map_err(|_| state_error(ERROR_STORAGE_READ, "文件权限不可读"))?
            .permissions()
            .mode()
            & 0o777
            != 0o600
        {
            return Err(state_error(ERROR_STORAGE_READ, "MLS文件权限不安全"));
        }
    }
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS状态读取失败"))?;
    let parsed = serde_json::from_slice::<DeviceSnapshot>(&bytes);
    bytes.fill(0);
    let snapshot = parsed.map_err(|_| state_error(ERROR_STATE_INVALID, "MLS状态结构损坏"))?;
    let storage = MemoryStorage::default();
    {
        let mut values = storage
            .values
            .write()
            .map_err(|_| state_error(ERROR_STATE_INVALID, "状态锁异常"))?;
        for (key, value) in snapshot.values {
            let key = base64::prelude::BASE64_STANDARD
                .decode(key)
                .map_err(|_| state_error(ERROR_STATE_INVALID, "状态键编码损坏"))?;
            let value = base64::prelude::BASE64_STANDARD
                .decode(value)
                .map_err(|_| state_error(ERROR_STATE_INVALID, "状态值编码损坏"))?;
            values.insert(key, value);
        }
    }
    Ok(DeviceState {
        crypto: RustCrypto::default(),
        storage,
        device: snapshot.device,
    })
}
fn save_provider(dir: &Path, provider: &DeviceState) -> Result<(), String> {
    use base64::Engine;
    let values = provider
        .storage
        .values
        .read()
        .map_err(|_| state_error(ERROR_STATE_INVALID, "状态读锁异常"))?
        .iter()
        .map(|(k, v)| {
            (
                base64::prelude::BASE64_STANDARD.encode(k),
                base64::prelude::BASE64_STANDARD.encode(v),
            )
        })
        .collect();
    let snapshot = DeviceSnapshot {
        device: provider.device.clone(),
        values,
    };
    let mut bytes = serde_json::to_vec(&snapshot)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "状态序列化失败"))?;
    let result = atomic_write(&storage_path(dir), &bytes);
    bytes.fill(0);
    result
}
fn read_device_signer(
    provider: &DeviceState,
    user: &str,
    device: &str,
) -> Result<SignatureKeyPair, String> {
    require_identity_component(user)?;
    require_identity_component(device)?;
    let record = &provider.device;
    if record.user_id != user || record.device_id != device {
        return Err("DEVICE_MLS_STATE_OWNER_MISMATCH:状态属于其他用户或设备".to_string());
    }
    if !record.public_key.starts_with("0x") || record.public_key.len() != 66 {
        return Err(state_error(ERROR_STATE_INVALID, "公钥结构损坏"));
    }
    let public = decode_hex_field("public_key", &record.public_key)?;
    if record.device_id != hex::encode(&public) {
        return Err(state_error(ERROR_STATE_INVALID, "设备标识与MLS公钥不一致"));
    }
    let signer = SignatureKeyPair::read(
        &provider.storage,
        &public,
        GMB_MLS_CIPHERSUITE.signature_algorithm(),
    )
    .ok_or_else(|| state_error(ERROR_SIGNER_MISSING, "签名身份缺失"))?;
    if signer.to_public_vec() != public {
        return Err(state_error(ERROR_STATE_INVALID, "公钥与签名身份不一致"));
    }
    Ok(signer)
}
fn now_millis() -> Result<u64, String> {
    Ok(std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "系统时钟无效"))?
        .as_millis() as u64)
}


fn decode_hex_field(field_name: &str, value: &str) -> Result<Vec<u8>, String> {
    let normalized = value.strip_prefix("0x").unwrap_or(value);
    if normalized.is_empty() {
        return Err(format!("{field_name} 不能为空"));
    }
    if !normalized.len().is_multiple_of(2) {
        return Err(format!("{field_name} hex 长度必须为偶数"));
    }
    hex::decode(normalized).map_err(|error| format!("{field_name} 不是合法 hex: {error}"))
}

fn storage_path(dir: &Path) -> PathBuf {
    dir.join("state.bin")
}
fn require_regular_file(path: &Path) -> Result<(), String> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS文件缺失或不可读"))?;
    if !metadata.file_type().is_file() {
        return Err(state_error(ERROR_STORAGE_READ, "MLS文件类型非法"));
    }
    Ok(())
}
#[cfg(unix)]
unsafe extern "C" {
    fn flock(fd: std::os::raw::c_int, operation: std::os::raw::c_int) -> std::os::raw::c_int;
}

/// Android的Rust标准库尚不支持File::lock；所有Unix目标共用系统flock。
/// 锁跟随描述符直到事务退出，只有系统调用被中断才重试，其他错误向上失败。
fn lock_file(file: &fs::File) -> std::io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::fd::AsRawFd;
        // Darwin和Android/Linux的系统头文件均定义LOCK_EX=2。
        loop {
            if unsafe { flock(file.as_raw_fd(), 2) } == 0 {
                return Ok(());
            }
            let error = std::io::Error::last_os_error();
            if error.kind() != std::io::ErrorKind::Interrupted {
                return Err(error);
            }
        }
    }
    #[cfg(not(unix))]
    file.lock()
}

/// 独占文件锁覆盖读取、签名与身份提交整个事务，不能以空锁或进程内互斥替代。
fn lock_store(dir: &Path) -> Result<fs::File, String> {
    if !dir.is_absolute()
        || fs::canonicalize(dir).map_err(|_| state_error(ERROR_STORAGE_READ, "目录不可用"))? != dir
    {
        return Err(state_error(
            ERROR_STORAGE_READ,
            "目录必须是无符号链接绝对路径",
        ));
    }
    let path = dir.join("state.lock");
    if fs::symlink_metadata(&path).is_ok() {
        require_regular_file(&path)?;
    }
    let mut options = fs::OpenOptions::new();
    options.read(true).write(true).create(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
        #[cfg(any(target_os = "ios", target_os = "macos"))]
        options.custom_flags(0x100);
        #[cfg(any(target_os = "android", target_os = "linux"))]
        options.custom_flags(0x20000);
    }
    let file = options
        .open(path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "存储锁不可用"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        // 阶段写入不能借硬链接修改设备目录以外的同一文件。
        if file
            .metadata()
            .map_err(|_| state_error(ERROR_STORAGE_READ, "存储锁元数据不可读"))?
            .nlink()
            != 1
        {
            return Err(state_error(ERROR_STORAGE_READ, "存储锁存在硬链接"));
        }
    }
    lock_file(&file).map_err(|_| state_error(ERROR_STORAGE_READ, "存储锁失败"))?;
    Ok(file)
}
/// 先核验保护再写秘密；rename提交后同步父目录，保证身份提交持久化。
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    let tmp = path.with_extension("writing");
    if fs::symlink_metadata(&tmp).is_ok() {
        require_regular_file(&tmp)?;
    }
    if fs::symlink_metadata(path).is_ok() {
        require_regular_file(path)?;
    }
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
        #[cfg(any(target_os = "ios", target_os = "macos"))]
        options.custom_flags(0x100);
        #[cfg(any(target_os = "android", target_os = "linux"))]
        options.custom_flags(0x20000);
    }
    let mut file = options
        .open(&tmp)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "临时状态创建失败"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        file.set_permissions(fs::Permissions::from_mode(0o600))
            .map_err(|_| state_error(ERROR_STORAGE_READ, "权限设置失败"))?;
    }
    #[cfg(target_os = "ios")]
    {
        use std::os::fd::AsRawFd;
        unsafe extern "C" {
            fn fcntl(fd: i32, command: i32, ...) -> i32;
        }
        // Apple文件保护class C，写入前设置并回读。
        if unsafe { fcntl(file.as_raw_fd(), 64, 3) } != 0
            || unsafe { fcntl(file.as_raw_fd(), 63) } != 3
        {
            return Err(state_error(ERROR_STORAGE_READ, "文件保护不可用"));
        }
    }
    file.write_all(bytes)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "状态写入失败"))?;
    file.sync_all()
        .map_err(|_| state_error(ERROR_STORAGE_READ, "状态同步失败"))?;
    fs::rename(&tmp, path).map_err(|_| state_error(ERROR_STORAGE_READ, "状态提交失败"))?;
    fs::File::open(path.parent().ok_or("状态缺少父目录")?)
        .and_then(|f| f.sync_all())
        .map_err(|_| state_error(ERROR_STORAGE_READ, "目录同步失败"))?;
    Ok(())
}
fn require_identity_component(value: &str) -> Result<(), String> {
    if value.trim().is_empty() || value.contains(':') || value.len() > 4096 {
        return Err("MLS身份标识无效".to_string());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn preserves_registered_signer_when_state_contains_previous_payload() {
        let dir = std::env::temp_dir().join(format!(
            "citizen-device-{}-{}",
            std::process::id(),
            now_millis().unwrap()
        ));
        fs::create_dir(&dir).unwrap();
        let dir = dir.canonicalize().unwrap();
        let user = "CN101";
        let invoke = |value: serde_json::Value| {
            let request = CString::new(value.to_string()).unwrap();
            serde_json::from_str::<serde_json::Value>(&identity_json(request.as_ptr()).unwrap())
                .unwrap()
        };
        let prepare = serde_json::json!({
            "state_store_dir": dir,
            "user_id": user,
            "action": "prepare",
        });
        let identity = invoke(prepare.clone());
        let sign = serde_json::json!({
            "state_store_dir": dir,
            "user_id": user,
            "action": "sign_authentication",
            "account_id": format!("0x{}", "ab".repeat(32)),
            "bind_rev": 7,
            "request": {
                "token_purpose": "request",
                "session_hash": "cd".repeat(32),
                "service_origin": "https://registration.example.test",
                "nonce_id": format!("0x{}", "01".repeat(32)),
                "expires_at": now_millis().unwrap() + 30_000,
                "http_method": "GET",
                "request_target": "/api/membergate",
                "body_hex": "",
            },
        });
        let first = invoke(sign.clone());
        let mut previous: serde_json::Value =
            serde_json::from_slice(&fs::read(storage_path(&dir)).unwrap()).unwrap();
        previous["results"] = serde_json::json!({});
        previous["attachments"] = serde_json::json!({});
        previous["pending_inbound"] = serde_json::json!([]);
        let bytes = serde_json::to_vec(&previous).unwrap();
        atomic_write(&storage_path(&dir), &bytes).unwrap();
        assert_eq!(invoke(prepare), identity);
        assert_eq!(invoke(sign), first);
        assert_eq!(fs::read(storage_path(&dir)).unwrap(), bytes);
        fs::remove_dir_all(dir).unwrap();
    }
}
