use std::fmt::Write as _;
use std::fs::{self, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::process::exit;

use sha2::{Digest, Sha256};

const PERIOD: usize = 251;

fn usage() -> ! {
    eprintln!("usage: mkcfb len out.cfb");
    exit(2);
}

fn fill(w: &mut impl Write, mut len: u64) -> io::Result<()> {
    let buf: Vec<u8> = (0..PERIOD * 64).map(|i| (i % PERIOD) as u8).collect();
    while len > 0 {
        let n = len.min(buf.len() as u64) as usize;
        w.write_all(&buf[..n])?;
        len -= n as u64;
    }
    Ok(())
}

fn quote(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            ' '..='~' => o.push(c),
            _ => write!(o, "\\u{{{:x}}}", c as u32).unwrap(),
        }
    }
    o.push('"');
    o
}

fn hash<F: Read + io::Seek>(cf: &mut cfb::CompoundFile<F>, p: &Path) -> io::Result<String> {
    let mut b = Vec::new();
    cf.open_stream(p)?.read_to_end(&mut b)?;
    Ok(Sha256::digest(&b)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect())
}

fn emit<F: Read + io::Seek>(
    cf: &mut cfb::CompoundFile<F>,
    p: &Path,
    depth: usize,
    o: &mut String,
) -> io::Result<()> {
    let e = cf.entry(p)?;
    let ind = "    ".repeat(depth);
    writeln!(o, "{ind}.{{").unwrap();
    writeln!(o, "{ind}    .name = {},", quote(e.name())).unwrap();
    if e.is_stream() {
        writeln!(o, "{ind}    .kind = .stream,").unwrap();
        writeln!(o, "{ind}    .len = {},", e.len()).unwrap();
        writeln!(o, "{ind}    .sha256 = \"{}\",", hash(cf, p)?).unwrap();
    } else {
        writeln!(o, "{ind}    .kind = .storage,").unwrap();
        writeln!(o, "{ind}    .children = .{{").unwrap();
        let kids: Vec<PathBuf> = cf.read_storage(p)?.map(|e| e.path().to_owned()).collect();
        for k in &kids {
            emit(cf, k, depth + 2, o)?;
        }
        writeln!(o, "{ind}    }},").unwrap();
    }
    write!(o, "{ind}}}").unwrap();
    o.push_str(if depth == 0 { "\n" } else { ",\n" });
    Ok(())
}

fn run(len: u64, out: &Path) -> io::Result<()> {
    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open(out)?;
    let mut cf = cfb::CompoundFile::create_with_version(cfb::Version::V3, f)?;
    let mut s = cf.create_stream("/data")?;
    fill(&mut s, len)?;
    s.flush()?;
    drop(s);
    cf.flush()?;
    drop(cf);

    let mut cf = cfb::open(out)?;
    let mut o = String::new();
    emit(&mut cf, Path::new("/"), 0, &mut o)?;
    fs::write(out.with_extension("zig.zon"), o)
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    if a.len() != 3 {
        usage();
    }
    let len: u64 = a[1].parse().unwrap_or_else(|_| usage());
    if let Err(e) = run(len, Path::new(&a[2])) {
        eprintln!("mkcfb: {}: {e}", a[2]);
        exit(1);
    }
}
