/*
 * SPDX-License-Identifier: {{ license_spdx }}
 * SPDX-FileCopyrightText: {{ current_year }} {{ your_name }}
 */

public class MyApp : Gtk.Application {
    public static Settings settings;

    public MyApp () {
        Object (
            application_id: "com.github.{{ github_username }}.{{ github_repository }}",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    static construct {
        settings = new Settings ("com.github.{{ github_username }}.{{ github_repository }}");
    }

    protected override void activate () {
        var main_window = new MainWindow (this);

        int window_x, window_y;
        var rect = Gtk.Allocation ();

        settings.get ("window-position", "(ii)", out window_x, out window_y);
        settings.get ("window-size", "(ii)", out rect.width, out rect.height);

        if (window_x != -1 || window_y != -1) {
            main_window.move (window_x, window_y);
        }

        main_window.set_allocation (rect);

        if (settings.get_boolean ("window-maximized")) {
            main_window.maximize ();
        }

        main_window.show_all ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = (
            granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
        );

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = (
                granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK
            );
        });
    }

    public static int main (string[] args) {
        return new MyApp ().run (args);
    }
}
