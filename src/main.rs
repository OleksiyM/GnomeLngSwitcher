mod config;
mod daemon;
mod gui;
mod update;

use adw::prelude::*;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.iter().any(|arg| arg == "--daemon" || arg == "-d") {
        if let Err(e) = daemon::run_daemon() {
            eprintln!("Error running daemon: {}", e);
            std::process::exit(1);
        }
        return;
    }

    if args.iter().any(|arg| arg == "--about") {
        let app = adw::Application::builder()
            .application_id("io.github.OleksiyM.GnomeLngSwitcher.About")
            .build();

        app.connect_activate(|app| {
            gui::show_about_window(Some(app), None);
        });

        app.run_with_args::<&str>(&[]);
        return;
    }

    let app = adw::Application::builder()
        .application_id("io.github.OleksiyM.GnomeLngSwitcher")
        .build();

    app.connect_activate(gui::build_ui);

    app.run_with_args::<&str>(&[]);
}
