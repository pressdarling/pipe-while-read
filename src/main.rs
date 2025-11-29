use std::io::{self, BufRead};
use std::process::{Command, Stdio};

use anyhow::Result;
use clap::{Arg, ArgAction, Command as Clap};

fn main() -> Result<()> {
    let matches = Clap::new("pipe-while-read")
        .version(env!("CARGO_PKG_VERSION"))
        .about("Read stdin line-by-line and run a command with each line appended.")
        .arg(
            Arg::new("dry-run")
                .long("dry-run")
                .short('n')
                .action(ArgAction::SetTrue)
                .help("Show commands without executing"),
        )
        .arg(
            Arg::new("command")
                .required(true)
                .num_args(1..)
                .help("Command to run plus its fixed args"),
        )
        .get_matches();

    let mut parts: Vec<String> = matches
        .get_many::<String>("command")
        .unwrap()
        .cloned()
        .collect();

    let dry_run = matches.get_flag("dry-run");
    let exe = parts.remove(0);
    let fixed_args = parts;

    let stdin = io::stdin();
    let mut last_status: Option<i32> = None;

    for line_res in stdin.lock().lines() {
        let line = line_res?;

        if dry_run {
            if fixed_args.is_empty() {
                println!("[DRY RUN] {} {}", exe, line);
            } else {
                println!("[DRY RUN] {} {} {}", exe, fixed_args.join(" "), line);
            }
            continue;
        }

        let status = Command::new(&exe)
            .args(&fixed_args)
            .arg(&line)
            .stdin(Stdio::null())
            .status()?;

        last_status = status.code();

        if !status.success() {
            eprintln!("command exited with {}", status);
        }
    }

    if let Some(code) = last_status {
        std::process::exit(code);
    }

    Ok(())
}
