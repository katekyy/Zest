module cross

import strings
import os

pub fn cross_platform_path(path string) string {
	return normalize_path(path.replace(op_separator(), get_separator()))
}

pub fn normalize_path(path string) string {
	mut sb := strings.new_builder(path.len)
	sep := get_separator().bytes()[0]

	for i, ch in path {
		if ch == sep && !(i < 1) && path[i - 1] == sep {
			continue
		}
		if ch == ' '[0] {
			sb.write_u8('_'.bytes()[0])
			continue
		}
		sb.write_u8(ch)
	}
	return sb.str().trim_space()
}

pub fn get_file_name(path string) string {
	return cross_platform_path(path).all_after_last(get_separator())
}

pub fn walk_exact(path string, name string) string {
	mut out := []u8{}
	impl_walk_exact(path, name, mut out)
	return out.bytestr()
}

fn impl_walk_exact(path string, name string, mut out []u8) {
	files := os.ls(path) or { return }
	path_sep := cross_platform_path('/')

	separator := if cross_platform_path(path).ends_with(path_sep) { '' } else { path_sep }
	for file in files {
		p := path + separator + file
		if file == name {
			out = p.bytes()
		}

		if os.is_dir(file) && !os.is_link(p) {
			impl_walk_exact(p, name, mut out)
		}
	}
}

pub fn ls_dirs(path string) ![]string {
	return os.ls(path)!.filter(os.is_dir(it))
}

pub fn get_separator() string {
	mut sep := '/'
	$if windows {
		sep = '\\'
	}
	return sep
}

fn op_separator() string {
	mut sep := '\\'
	$if windows {
		sep = '/'
	}
	return sep
}

// mkdir_recurse recursively calls `os.mkdir()` to make all directories in a given path.
// If the last element in the path doesn't have a separator at the end, it'll create a file too.
pub fn mkdir_recurse(path string) ! {
	sep := get_separator()
	if !os.exists(path) {
		dirs := path.split(sep)
		if dirs.len > 1 {
			for i, dir in dirs {
				if i == dirs.len - 1 {
					break
				}
				full_path := dirs[..i].join(sep) + sep + dir
				if !os.exists(full_path) {
					os.mkdir(full_path)!
				}
			}
		}
		last := dirs[dirs.len - 1..]
		if last[last.len - 1].len > 0 {
			os.create(path)!
		}
	}
}
