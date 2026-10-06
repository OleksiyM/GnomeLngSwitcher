// GnomeLngSwitcher Extension Preferences
// The "Settings" button in the Extensions app opens the GnomeLngSwitcher
// application window (the real settings live in the app, not in the extension).

import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import {ExtensionPreferences, gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const APP_BINARY = GLib.build_filenamev([
    GLib.get_home_dir(), 'Applications', 'GnomeLngSwitcher', 'gnome-lng-switcher',
]);

export default class GnomeLngSwitcherPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const launched = this._launchApp();
        if (launched) {
            // Nothing to show here: hand over to the app and close this window.
            GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                window.close();
                return GLib.SOURCE_REMOVE;
            });
            return;
        }

        const page = new Adw.PreferencesPage();
        const group = new Adw.PreferencesGroup({
            title: _('GnomeLngSwitcher app not found'),
            description: _(`Could not start ${APP_BINARY}. Install the app first: https://github.com/OleksiyM/GnomeLngSwitcher`),
        });
        page.add(group);
        window.add(page);
    }

    _launchApp() {
        try {
            if (!GLib.file_test(APP_BINARY, GLib.FileTest.IS_EXECUTABLE))
                return false;
            Gio.Subprocess.new([APP_BINARY], Gio.SubprocessFlags.NONE);
            return true;
        } catch (e) {
            console.error(`GnomeLngSwitcher Extension: failed to launch app: ${e}`);
            return false;
        }
    }
}
