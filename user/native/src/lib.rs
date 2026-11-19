//! 公民设备请求签名的原生入口。

use std::ffi::CString;
use std::os::raw::c_char;

mod mls;

pub(crate) fn set_error(error_out: *mut *mut c_char, message: &str) {
    if error_out.is_null() {
        return;
    }
    let sanitized = message.replace('\0', " ");
    let value = CString::new(sanitized).expect("sanitized FFI error");
    unsafe {
        *error_out = value.into_raw();
    }
}

pub(crate) fn string_into_raw(value: String, error_out: *mut *mut c_char) -> *mut c_char {
    match CString::new(value) {
        Ok(value) => {
            if !error_out.is_null() {
                unsafe {
                    *error_out = std::ptr::null_mut();
                }
            }
            value.into_raw()
        }
        Err(_) => {
            set_error(error_out, "FFI response contains an embedded null byte");
            std::ptr::null_mut()
        }
    }
}

/// 释放本库返回的字符串。
///
/// # Safety
///
/// `value` must be null or a pointer returned by this library that has not
/// already been released.
#[no_mangle]
pub unsafe extern "C" fn mls_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}
