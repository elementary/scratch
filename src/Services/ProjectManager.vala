/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
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
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Scratch.Services.ProjectManager : Object {
    public string project_path { get; set; }
    public string project_name {
        owned get {
            return Path.get_basename (project_path);
        }
    }
    public bool is_running { get; set; }
    public bool was_stopped { get; set; }

    public signal void on_standard_output (string line);
    public signal void on_standard_error (string line);
    public signal void on_clear ();

    private Pid command_pid;

    public FlatpakManifest? get_flatpak_manifest () {
        Dir dir;
        try {
            dir = Dir.open (project_path, 0);
        } catch (Error e) {
            warning ("Could not read Flatpak manifest: %s", e.message);
            return null;
        }

        string? name = null;
        while ((name = dir.read_name ()) != null) {
            string f = Path.build_filename (project_path, name);

            if (FileUtils.test (f, FileTest.IS_REGULAR)) {
                if (f.has_suffix (".yml") || f.has_suffix (".yaml")) {
                    try {
                        string content;
                        FileUtils.get_contents (f, out content);

                        var re_app_id = new Regex ("app-id:\\s*(?P<app_id>[A-Za-z0-9-\\.]+)");
                        var re_command = new Regex ("command:\\s*(?P<command>[A-Za-z0-9-\\.]+)");

                        var flatpak_manifest = new FlatpakManifest () {
                            manifest = f,
                            build_dir = Path.build_filename (project_path, "flatpak-build")
                        };

                        MatchInfo mi;
                        if (re_app_id.match (content, 0, out mi)) {
                            flatpak_manifest.app_id = mi.fetch_named ("app_id");
                        }

                        if (re_command.match (content, 0, out mi)) {
                            flatpak_manifest.command = mi.fetch_named ("command");
                        }

                        if (flatpak_manifest.app_id.length > 0 && flatpak_manifest.command.length > 0) {
                            return flatpak_manifest;
                        }
                    } catch (Error e) {
                        warning ("Could not read Flatpak manifest: %s", e.message);
                    }
                } else if (f.has_suffix (".json")) {
                    try {
                        string content;
                        FileUtils.get_contents (f, out content);

                        var parser = new Json.Parser ();
                        parser.load_from_data (content, -1);
                        var object = parser.get_root ().get_object ();

                        return new FlatpakManifest () {
                            manifest = f,
                            build_dir = Path.build_filename (project_path, "flatpak-build"),
                            app_id = object.get_string_member ("app-id"),
                            command = object.get_string_member ("command")
                        };
                    } catch (Error e) {
                        warning ("Could not read Flatpak manifest: %s", e.message);
                    }
                }
            }
        }

        return null;
    }

    public class FlatpakManifest : Object {
        public string manifest { get; set; }
        public string build_dir { get; set; }
        public string app_id { get; set; }
        public string command { get; set; }
    }

    private bool process_line (IOChannel channel, IOCondition condition, string stream_name) {
        if (condition == IOCondition.HUP) {
            return false;
        }

        try {
            string line;
            channel.read_line (out line, null, null);

            switch (stream_name) {
                case "stdout":
                    print (line);
                    on_standard_output (line);
                    break;
                case "stderr":
                    print (line);
                    on_standard_error (line);
                    break;
            }
        } catch (IOChannelError e) {
            warning ("%s: IOChannelError: %s", stream_name, e.message);
            return false;
        } catch (ConvertError e) {
            warning ("%s: ConvertError: %s", stream_name, e.message);
            return false;
        }

        return true;
    }

    private async bool run_command (string[] cmd) {
        MainLoop loop = new MainLoop ();
        bool exit_status = false;

        try {
            string[] spawn_args = cmd;
            string[] spawn_env = Environ.get ();

            int standard_input;
            int standard_output;
            int standard_error;

            Process.spawn_async_with_pipes (
                project_path,
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out command_pid,
                out standard_input,
                out standard_output,
                out standard_error
            );

            // stdout
            IOChannel output = new IOChannel.unix_new (standard_output);
            output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stdout");
            });

            // stderr
            IOChannel error = new IOChannel.unix_new (standard_error);
            error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stderr");
            });


            ChildWatch.add (command_pid, (pid, status) => {
                // Triggered when the child indicated by command_pid exits
                Process.close_pid (pid);
                exit_status = (status == 0);
                loop.quit ();
            });

            loop.run ();

            return exit_status;
        } catch (SpawnError e) {
            warning ("Could not run command: %s\n", e.message);
            return false;
        }
    }

    private async bool build_project () {
        var flatpak_manifest = get_flatpak_manifest ();
        if (flatpak_manifest != null) {
            return yield run_command ({
                "flatpak-builder",
                "--force-clean",
                flatpak_manifest.build_dir,
                flatpak_manifest.manifest
            });
        }

        return false;
    }

    private async bool run_project () {
        var flatpak_manifest = get_flatpak_manifest ();
        if (flatpak_manifest != null) {
            return yield run_command ({
                "flatpak-builder",
                "--run",
                flatpak_manifest.build_dir,
                flatpak_manifest.manifest,
                flatpak_manifest.command
            });
        }

        return false;
    }

    public async bool build () {
        if (is_running) {
            debug ("Project “%s“ is already running", project_path);
            return false;
        }

        was_stopped = false;
        on_clear ();

        is_running = true;
        var result = yield build_project ();
        is_running = false;

        return result;
    }

    public async bool build_install_run () {
        if (is_running) {
            debug ("Project “%s“ is already running", project_path);
            return false;
        }

        was_stopped = false;
        on_clear ();

        is_running = true;
        if (!yield build_project ()) {
            is_running = false;
            return false;
        }

        var result = yield run_project ();
        is_running = false;

        return result;
    }

    public bool stop () {
        if (!is_running) {
            debug ("Project “%s“ is not running", project_path);
            return true;
        }

        was_stopped = true;
        var result = Posix.kill (command_pid, Posix.Signal.TERM) == 0;
        is_running = !result;

        return result;
    }
}
