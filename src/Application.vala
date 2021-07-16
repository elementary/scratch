// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2011-2012 Giulio Collura <random.cpp@gmail.com>
*               2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch {
    public GLib.Settings saved_state;
    public GLib.Settings settings;
    public GLib.Settings service_settings;
    public GLib.Settings privacy_settings;
    public bool in_sandbox;

    public class Application : Gtk.Application {
        public string app_cmd_name { get { return _app_cmd_name; } }
        public string data_home_folder_unsaved { get { return _data_home_folder_unsaved; } }
        public string default_font { get; set; }
        public Xdp.Portal portal;
        private static string _app_cmd_name;
        private static string _data_home_folder_unsaved;
        private static bool create_new_tab = false;
        private static bool create_new_window = false;

        const OptionEntry[] ENTRIES = {
            { "new-tab", 't', 0, OptionArg.NONE, null, N_("New Tab"), null },
            { "new-window", 'n', 0, OptionArg.NONE, null, N_("New Window"), null },
            { "version", 'v', 0, OptionArg.NONE, null, N_("Print version info and exit"), null },
            { "set", 's', 0, OptionArg.STRING, ref _app_cmd_name, N_("Set of plugins"), N_("plugin") },
            { GLib.OPTION_REMAINING, 0, 0, OptionArg.FILENAME_ARRAY, null, null, N_("[FILE…]") },
            { null }
        };

        static construct {
            _app_cmd_name = "Code";

            // Init data home folder for unsaved text files
            _data_home_folder_unsaved = Path.build_filename (
                                            Environment.get_user_data_dir (), Constants.PROJECT_NAME, "unsaved"
                                        );
        }

        construct {
            flags |= ApplicationFlags.HANDLES_OPEN;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

            application_id = Constants.PROJECT_NAME;

            add_main_option_entries (ENTRIES);

            // Init settings
            default_font = new GLib.Settings ("org.gnome.desktop.interface").get_string ("monospace-font-name");
            saved_state = new GLib.Settings (Constants.PROJECT_NAME + ".saved-state");
            settings = new GLib.Settings (Constants.PROJECT_NAME + ".settings");
            service_settings = new GLib.Settings (Constants.PROJECT_NAME + ".services");
            privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
            in_sandbox = FileUtils.test ("/.flatpak-info", FileTest.EXISTS);

            if (in_sandbox) {
                portal = new Xdp.Portal ();
            }
        }

        public override int handle_local_options (VariantDict options) {
            if (options.contains ("version")) {
                stdout.printf ("Code %s\n", Constants.VERSION);
                return Posix.EXIT_SUCCESS;
            }

            return -1;
        }

        public override int command_line (GLib.ApplicationCommandLine command_line) {
            /* Only allow running with root privileges using pkexec, not using sudo */
            if (Posix.getuid () == 0 && GLib.Environment.get_variable ("PKEXEC_UID") == null) {
#if HAVE_PKEXEC
                warning ("Running Code using sudo is not possible. Use: pkexec io.elementary.code");
#endif
                quit ();
                return 1;
            };

            var options = command_line.get_options_dict ();

            if (options.contains ("new-tab")) {
                create_new_tab = true;
            }

            if (options.contains ("new-window")) {
                create_new_window = true;
            }

            activate ();

            if (options.contains (GLib.OPTION_REMAINING)) {
                File[] files = {};

                (unowned string)[] remaining = options.lookup_value (
                    GLib.OPTION_REMAINING,
                    VariantType.BYTESTRING_ARRAY
                ).get_bytestring_array ();

                for (int i = 0; i < remaining.length; i++) {
                    unowned string file = remaining[i];
                    files += command_line.create_file_for_arg (file);
                }

                open (files, "");
            }

            return Posix.EXIT_SUCCESS;
        }

        protected override void activate () {
            var window = get_last_window ();
            if (window != null && create_new_window) {
                create_new_window = false;
                this.new_window ();
            } else if (window == null) {
                window = this.new_window (); // Will restore documents if required
                window.show ();
            } else {
                window.present ();
            }

            // Create a new document if requested
            if (create_new_tab) {
                create_new_tab = false;
                Utils.action_from_group (MainWindow.ACTION_NEW_TAB, window.actions).activate (null);
            }
        }

        protected override void open (File[] files, string hint) {
            var window = get_last_window ();

            foreach (var file in files) {
                var type = file.query_file_type (FileQueryInfoFlags.NONE);
                if (type == FileType.DIRECTORY) {
                    window.open_folder (file);
                } else {
                    var doc = new Scratch.Services.Document (window.actions, file);
                    window.open_document (doc);
                }
            }
        }

        public MainWindow? get_last_window () {
            unowned List<Gtk.Window> windows = get_windows ();
            return windows.length () > 0 ? windows.last ().data as MainWindow : null;
        }

        public MainWindow new_window () {
            return new MainWindow (this);
        }

        public static int main (string[] args) {
            return new Application ().run (args);
        }
    }
}
