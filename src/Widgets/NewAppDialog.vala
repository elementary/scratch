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

public class Scratch.Widgets.NewAppDialog : Granite.Dialog {
    private Granite.ValidatedEntry app_name_entry;
    private Granite.ValidatedEntry app_summary_entry;
    private Granite.ValidatedEntry app_description_entry;
    private Granite.ValidatedEntry your_name_entry;
    private Granite.ValidatedEntry your_email_entry;
    private Granite.ValidatedEntry your_github_entry;
    private Gtk.Button create_button;

    private string app_template_folder_path;

    public signal void open_folder (string path);

    public NewAppDialog (Gtk.Window parent) {
        Object (transient_for: parent);
    }

    construct {
        app_template_folder_path = Path.build_filename (
            Constants.DATADIR, Constants.PROJECT_NAME, "templates", "app"
        );

        var app_name_label = new Granite.HeaderLabel (_("App Name"));

        app_name_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var app_summary_label = new Granite.HeaderLabel (_("App Summary"));

        app_summary_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var app_description_label = new Granite.HeaderLabel (_("App Description"));

        app_description_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var license_label = new Granite.HeaderLabel (_("License Type"));

        var license_combobox = new Gtk.ComboBoxText ();
        license_combobox.append_text ("GNU General Public License v3.0");
        license_combobox.set_active (0);

        var location_label = new Granite.HeaderLabel (_("Location"));

        var location_chooser = new Gtk.FileChooserButton (_("Select the folder where your app should be located"), Gtk.FileChooserAction.SELECT_FOLDER) {
            hexpand = true
        };
        try {
            location_chooser.set_file (File.new_for_path (Environment.get_home_dir ()));
        } catch (Error e) {
            warning ("The folder path is invalid: %s", e.message);
        }

        var your_name_label = new Granite.HeaderLabel (_("Your Name"));

        your_name_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var your_email_label = new Granite.HeaderLabel (_("Your Email"));

        your_email_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var your_github_label = new Granite.HeaderLabel (_("Your GitHub Username"));

        your_github_entry = new Granite.ValidatedEntry () {
            hexpand = true
        };

        var link_button = new Gtk.LinkButton.with_label ("https://docs.elementary.io/develop/", _("Developer Documentation…")) {
            margin_top = 14
        };

        var form_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 3,
            valign = Gtk.Align.CENTER,
            vexpand = true
        };
        form_grid.margin_start = form_grid.margin_end = 12;
        form_grid.add (app_name_label);
        form_grid.add (app_name_entry);
        form_grid.add (app_summary_label);
        form_grid.add (app_summary_entry);
        form_grid.add (app_description_label);
        form_grid.add (app_description_entry);
        form_grid.add (license_label);
        form_grid.add (license_combobox);
        form_grid.add (location_label);
        form_grid.add (location_chooser);
        form_grid.add (your_name_label);
        form_grid.add (your_name_entry);
        form_grid.add (your_email_label);
        form_grid.add (your_email_entry);
        form_grid.add (your_github_label);
        form_grid.add (your_github_entry);
        form_grid.add (link_button);
        form_grid.show_all ();

        modal = true;
        resizable= false;
        width_request = 560;
        get_content_area ().add (form_grid);

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        create_button = (Gtk.Button) add_button (_("Create App"), Gtk.ResponseType.OK);
        create_button.can_default = true;
        create_button.sensitive = false;
        create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        app_name_entry.changed.connect (() => {
            app_name_entry.is_valid = check_is_valid (app_name_entry.text);
            update_create_button ();
        });

        app_summary_entry.changed.connect (() => {
            app_summary_entry.is_valid = check_is_valid (app_summary_entry.text);
            update_create_button ();
        });

        app_description_entry.changed.connect (() => {
            app_description_entry.is_valid = check_is_valid (app_description_entry.text);
            update_create_button ();
        });

        your_name_entry.changed.connect (() => {
            your_name_entry.is_valid = check_is_valid (your_name_entry.text);
            update_create_button ();
        });

        your_email_entry.changed.connect (() => {
            your_email_entry.is_valid = check_is_valid (your_email_entry.text);
            update_create_button ();
        });

        your_github_entry.changed.connect (() => {
            your_github_entry.is_valid = check_is_valid (your_github_entry.text);
            update_create_button ();
        });

        your_name_entry.text = Environment.get_real_name ();

        your_github_entry.text = Environment.get_user_name ();

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.OK) {
                var context = new Gee.HashMap<string, string> ();
                context["app_name"] = app_name_entry.text;
                context["app_summary"] = app_summary_entry.text;
                context["app_description"] = app_description_entry.text;
                context["your_name"] = your_name_entry.text;
                context["your_email"] = your_email_entry.text;
                context["github_username"] = your_github_entry.text;
                context["github_repository"] = app_name_entry.text.down ().replace (" ", "-");
                context["license_code"] = "gpl-3.0";
                context["license_spdx"] = "GPL-3.0-or-later";
                context["current_year"] = "%d".printf (new DateTime.now_local ().get_year ());

                var src = app_template_folder_path;
                var dest = Path.build_filename (location_chooser.get_filename (), context["github_repository"]);
                copy_recursive_with_context.begin (src, dest, context, FileCopyFlags.NONE, null, (obj, res) => {
                    try {
                        copy_recursive_with_context.end (res);

                        open_folder (dest);

                        destroy ();
                    } catch (Error e) {
                        show_error_dialog (app_name_entry.text, e.message);
                    }
                });
            } else {
                destroy ();
            }
        });
    }

    private bool check_is_valid (string text) {
        return text.length > 0;
    }

    private void update_create_button () {
        if (app_name_entry.is_valid &&
            app_summary_entry.is_valid &&
            app_description_entry.is_valid &&
            your_name_entry.is_valid &&
            your_email_entry.is_valid &&
            your_github_entry.is_valid) {
            create_button.sensitive = true;
            create_button.has_default = true;
        } else {
            create_button.sensitive = false;
        }
    }

    private static async void copy_recursive_with_context (string src, string dest, Gee.HashMap<string, string> context, FileCopyFlags flags = FileCopyFlags.NONE, Cancellable? cancellable = null) throws Error {
        var template = new Services.AppTemplate (dest);
        var src_path = src;
        var dest_path = template.render (context);

        var src_file = File.new_for_path (src_path);
        var dest_file = File.new_for_path (dest_path);

        FileType src_type = src_file.query_file_type (FileQueryInfoFlags.NONE, cancellable);
        if (src_type == FileType.DIRECTORY) {
            yield dest_file.make_directory_async (GLib.Priority.DEFAULT, cancellable);
            src_file.copy_attributes (dest_file, flags, cancellable);

            FileEnumerator enumerator = src_file.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE, cancellable);
            for (FileInfo? info = enumerator.next_file (cancellable); info != null; info = enumerator.next_file (cancellable)) {
                yield copy_recursive_with_context (
                    Path.build_filename (src_path, info.get_name ()),
                    Path.build_filename (dest_path, info.get_name ()),
                    context,
                    flags,
                    cancellable
                );
            }
        } else if (src_type == FileType.REGULAR) {
            yield src_file.copy_async (dest_file, flags, GLib.Priority.DEFAULT, cancellable);

            uint8[] contents;
            string etag_out;

            yield src_file.load_contents_async (cancellable, out contents, out etag_out);

            template = new Services.AppTemplate ((string) contents);
            string new_content = template.render (context);

            yield dest_file.replace_contents_async (new_content.data, null, false, FileCreateFlags.NONE, cancellable, null);
        }
    }

    private void show_error_dialog (string app_name, string message) {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Could not create ”%s” from template").printf (app_name),
            "",
            "application-default-icon",
            Gtk.ButtonsType.CLOSE
        );
        message_dialog.badge_icon = new ThemedIcon ("dialog-error");
        message_dialog.transient_for = this.transient_for;

        message_dialog.show_error_details (message);

        message_dialog.show_all ();
        message_dialog.run ();
        message_dialog.destroy ();
    }
}
