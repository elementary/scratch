/*
 * SPDX-License-Identifier: {{ license_spdx }}
 * SPDX-FileCopyrightText: {{ current_year }} {{ your_name }}
 */

public class MainWindow : Hdy.ApplicationWindow {
    private uint configure_id;

    public MainWindow (MyApp app) {
        Object (
            application: app,
            title: "{{ app_name }}"
        );
    }

    construct {
        Hdy.init ();

        var headerbar = new Hdy.HeaderBar () {
            show_close_button = true,
            title = "{{ app_name }}",
            hexpand = true
        };

        var main_layout = new Gtk.Grid ();
        main_layout.attach (headerbar, 0, 0);

        add (main_layout);
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                MyApp.settings.set_boolean ("window-maximized", true);
            } else {
                MyApp.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                MyApp.settings.set ("window-size", "(ii)", rect.width, rect.height);

                int root_x, root_y;
                get_position (out root_x, out root_y);
                MyApp.settings.set ("window-position", "(ii)", root_x, root_y);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
