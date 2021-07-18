// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elemnetaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Scratch.Services {
    public enum DocumentStates {
        NORMAL,
        READONLY
    }

    public class Document : Granite.Widgets.Tab {
        private const uint LOAD_TIMEOUT_MSEC = 5000;

        public delegate void VoidFunc ();
        public signal void doc_opened ();
        public signal void doc_saved ();
        public signal void doc_closed ();

        // The parent window's actions
        private weak SimpleActionGroup _actions;
        public SimpleActionGroup actions {
            get {
                return _actions;
            }
            set {
                _actions = value;
            }
        }

        public bool is_file_temporary {
            get {
                return file.get_path ().has_prefix (
                    ((Scratch.Application) GLib.Application.get_default ()).data_home_folder_unsaved
                );
            }
        }

        private Gtk.SourceFile source_file;
        public GLib.File file {
            get {
                return source_file.location;
            }

            private set {
                source_file.set_location (value);
                source_view.location = value;
                file_changed ();
                tab_name = get_basename ();
            }
        }

        public string tab_name {
            set {
                label = value;
                tooltip = get_tab_tooltip ();
            }
        }

        private string? _mime_type = null;
        public string? mime_type {
            get {
                if (_mime_type == null) {
                    try {
                        var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                        var content_type = info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE);
                        _mime_type = ContentType.get_mime_type (content_type);
                        return _mime_type;
                    } catch (Error e) {
                        debug (e.message);
                    }
                }

                if (_mime_type == null) {
                    _mime_type = "undefined";
                }

                return _mime_type;
            }
        }

        public Gtk.Stack main_stack;
        public Scratch.Widgets.SourceView source_view;

        public string original_content;
        private string last_save_content;
        public bool saved = true;

        private Gtk.ScrolledWindow scroll;
        private Gtk.InfoBar info_bar;
        private Gtk.SourceMap source_map;
        private Gtk.Paned outline_widget_pane;

        private GLib.Cancellable save_cancellable;
        private GLib.Cancellable load_cancellable;
        private ulong onchange_handler_id = 0; // It is used to not mark files as changed on load
        private bool loaded = false;
        private bool mounted = true; // Mount state of the file
        private Mount mount;

        private static Pango.FontDescription? builder_blocks_font = null;
        private static Pango.FontMap? builder_font_map = null;

        public Document (SimpleActionGroup actions, File? file = null) {
            Object (actions: actions);

            this.file = file;
            page = main_stack;
        }

        static construct {
            var fontpath = Path.build_filename (
                Constants.DATADIR, Constants.PROJECT_NAME, "fonts", "BuilderBlocks.ttf"
            );

            unowned Fc.Config config = Fc.init ();
            if (!config.add_app_font (fontpath)) {
                warning ("Unable to load Builder Blocks font, SourceView map might not be pretty");
            } else {
                builder_font_map = Pango.CairoFontMap.new_for_font_type (Cairo.FontType.FT);
                PangoFc.attach_fontconfig_to_fontmap (builder_font_map, config);
                builder_blocks_font = Pango.FontDescription.from_string ("Builder Blocks 1");
            }
        }

        construct {
            main_stack = new Gtk.Stack ();
            source_view = new Scratch.Widgets.SourceView ();

            scroll = new Gtk.ScrolledWindow (null, null) {
                expand = true
            };
            scroll.add (source_view);
            info_bar = new Gtk.InfoBar ();
            source_file = new Gtk.SourceFile ();
            source_map = new Gtk.SourceMap ();
            outline_widget_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);

            if (builder_blocks_font != null && builder_font_map != null) {
                source_map.set_font_map (builder_font_map);
                source_map.font_desc = builder_blocks_font;
            }

            source_map.set_view (source_view);

            // Handle Drag-and-drop functionality on source-view
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.TargetEntry text = {"text/plain", 0, 0};
            Gtk.drag_dest_set (source_view, Gtk.DestDefaults.ALL, {uris, text}, Gdk.DragAction.COPY);

            hide_info_bar ();

            restore_settings ();

            settings.changed.connect (restore_settings);
            /* Block user editing while working */
            source_view.key_press_event.connect (() => {
                return working;
            });

            var source_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.HORIZONTAL,
                column_homogeneous = false
            };
            source_grid.add (scroll);
            source_grid.add (source_map);
            outline_widget_pane.pack1 (source_grid, true, false);

            var doc_grid = new Gtk.Grid ();
            doc_grid.orientation = Gtk.Orientation.VERTICAL;
            doc_grid.add (info_bar);
            doc_grid.add (outline_widget_pane);
            doc_grid.show_all ();

            main_stack.add_named (doc_grid, "content");

            this.source_view.buffer.create_tag ("highlight_search_all", "background", "yellow", null);

            toggle_changed_handlers (true);

            // Focus out event for SourceView
            this.source_view.focus_out_event.connect (() => {
                if (Scratch.settings.get_boolean ("autosave")) {
                    save.begin ();
                }

                return false;
            });

            source_view.buffer.changed.connect (() => {
                if (source_view.buffer.text != last_save_content) {
                    saved = false;
                    if (!Scratch.settings.get_boolean ("autosave")) {
                        set_saved_status (false);
                    }
                } else {
                    set_saved_status (true);
                }
            });

            /* Create as loaded - could be new document */
            loaded = true;
            ellipsize_mode = Pango.EllipsizeMode.MIDDLE;
        }

        public void toggle_changed_handlers (bool enabled) {
            if (enabled) {
                onchange_handler_id = this.source_view.buffer.changed.connect (() => {
                    if (onchange_handler_id != 0) {
                        this.source_view.buffer.disconnect (onchange_handler_id);
                    }

                    // Signals for SourceView
                    uint timeout_saving = 0;
                    check_undoable_actions ();
                    this.source_view.buffer.changed.connect (() => {
                        check_undoable_actions ();
                        // Save if autosave is ON
                        if (Scratch.settings.get_boolean ("autosave")) {
                            if (timeout_saving > 0) {
                                Source.remove (timeout_saving);
                                timeout_saving = 0;
                            }
                            timeout_saving = Timeout.add (1000, () => {
                                save.begin ();
                                timeout_saving = 0;
                                return false;
                            });
                        }
                     });
                });
            } else if (onchange_handler_id != 0) {
                this.source_view.buffer.disconnect (onchange_handler_id);
            }
        }

        private uint load_timout_id = 0;
        public async void open (bool force = false) {
            /* Loading improper files may hang so we cancel after a certain time as a fallback.
             * In most cases, an error will be thrown and caught. */
            if (load_cancellable != null) { /* just in case */
                load_cancellable.cancel ();
            }

            load_cancellable = new Cancellable ();

            // If it does not exists, let's create it!
            if (!exists (load_cancellable)) {
                try {
                    FileUtils.set_contents (file.get_path (), "");
                } catch (FileError e) {
                    warning ("Cannot create file \"%s\": %s", get_basename (), e.message);
                    return;
                }
            }

            source_view.sensitive = false;
            this.working = true;
            loaded = false;

            var content_type = ContentType.from_mime_type (mime_type);

            if (!force && !(ContentType.is_a (content_type, "text/plain"))) {
                var title = _("%s Is Not a Text File").printf (get_basename ());
                var description = _("Code will not load this type of file.");
                var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-warning");
                alert_view.show_action (_("Load Anyway"));
                alert_view.show_all ();
                main_stack.add_named (alert_view, "load_alert");
                main_stack.set_visible_child (alert_view);
                alert_view.action_activated.connect (() => {
                    open.begin (true);
                    alert_view.destroy ();
                });

                working = false;
                return;
            }

            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            var buffer = new Gtk.SourceBuffer (null); /* Faster to load into a separate buffer */

            load_timout_id = Timeout.add_seconds_full (GLib.Priority.HIGH, 5, () => {
                if (load_cancellable != null && !load_cancellable.is_cancelled ()) {
                    var title = _("Loading File \"%s\" Is Taking a Long Time").printf (get_basename ());
                    var description = _("Please wait while Code is loading the file.");
                    var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-information");
                    alert_view.show_action (_("Cancel Loading"));
                    alert_view.show_all ();
                    main_stack.add_named (alert_view, "wait_alert");
                    main_stack.set_visible_child (alert_view);
                    alert_view.action_activated.connect (() => {
                        load_cancellable.cancel ();
                        doc_closed ();
                    });
                    load_timout_id = 0;

                    return GLib.Source.REMOVE;
                }

                load_timout_id = 0;
                return GLib.Source.REMOVE;
            });

            try {
                var source_file_loader = new Gtk.SourceFileLoader (buffer, source_file);
                yield source_file_loader.load_async (GLib.Priority.LOW, load_cancellable, null);
                var source_buffer = source_view.buffer as Gtk.SourceBuffer;
                if (source_buffer != null) {
                    source_buffer.begin_not_undoable_action ();
                    source_buffer.text = buffer.text;
                    source_buffer.end_not_undoable_action ();
                } else {
                    source_view.buffer.text = buffer.text;
                }

                loaded = true;
            } catch (Error e) {
                critical (e.message);
                source_view.buffer.text = "";
                show_default_load_error_view ();
                working = false;
                return;
            } finally {
                load_cancellable = null;
                if (load_timout_id > 0) {
                    Source.remove (load_timout_id);
                }
            }

            // Focus in event for SourceView
            this.source_view.focus_in_event.connect (() => {
                check_file_status ();
                check_undoable_actions ();

                return false;
            });

            // Change syntax highlight
            this.source_view.change_syntax_highlight_from_file (this.file);

            source_view.buffer.set_modified (false);
            original_content = source_view.buffer.text;
            last_save_content = source_view.buffer.text;
            set_saved_status (true);

            doc_opened ();
            source_view.sensitive = true;

            /* Do not stop working (blocks editing) until idle
             * (large documents take time to format/display after loading)
             */
            Idle.add (() => {
                this.working = false;
                return false;
            });

            return;
        }

        public bool do_close (bool app_closing = false) {
            debug ("Closing \"%s\"", get_basename ());

            if (!loaded) {
                load_cancellable.cancel ();
                return true;
            }

            bool ret_value = true;
            if (Scratch.settings.get_boolean ("autosave") && !saved) {
                save_with_hold ();
            } else if (app_closing && is_file_temporary && !delete_temporary_file ()) {
                debug ("Save temporary file!");
                save_with_hold ();
            }
            // Check for unsaved changes
            else if (!this.saved || (!app_closing && is_file_temporary && !delete_temporary_file ())) {
                var parent_window = source_view.get_toplevel () as Gtk.Window;

                var dialog = new Granite.MessageDialog (
                    _("Save changes to \"%s\" before closing?").printf (this.get_basename ()),
                    _("If you don't save, changes will be permanently lost."),
                    new ThemedIcon ("dialog-warning"),
                    Gtk.ButtonsType.NONE
                );
                dialog.transient_for = parent_window;

                var no_save_button = (Gtk.Button) dialog.add_button (_("Close Without Saving"), Gtk.ResponseType.NO);
                no_save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

                dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
                dialog.add_button (_("Save"), Gtk.ResponseType.YES);
                dialog.set_default_response (Gtk.ResponseType.YES);

                int response = dialog.run ();
                switch (response) {
                    case Gtk.ResponseType.CANCEL:
                    case Gtk.ResponseType.DELETE_EVENT:
                        ret_value = false;
                        break;
                    case Gtk.ResponseType.YES:
                        if (this.is_file_temporary)
                            save_as_with_hold ();
                        else
                            save_with_hold ();
                        break;
                    case Gtk.ResponseType.NO:
                        if (this.is_file_temporary)
                            delete_temporary_file (true);
                        break;
                }
                dialog.destroy ();
            }

            if (ret_value) {
                // Delete backup copy file
                delete_backup ();
                doc_closed ();
            }

            return ret_value;
        }

        public bool save_with_hold (bool force = false) {
            GLib.Application.get_default ().hold ();
            bool result = false;
            save.begin (force, (obj, res) => {
                result = save.end (res);
                GLib.Application.get_default ().release ();
            });

            return result;
        }

        public bool save_as_with_hold () {
            GLib.Application.get_default ().hold ();
            bool result = false;
            save_as.begin ((obj, res) => {
                result = save_as.end (res);
                GLib.Application.get_default ().release ();
            });

            return result;
        }

        public async bool save (bool force = false) {
            if (!force && (source_view.buffer.get_modified () == false || this.loaded == false)) {
                return false;
            }

            this.create_backup ();

            // Replace old content with the new one
            save_cancellable.cancel ();
            save_cancellable = new GLib.Cancellable ();
            var source_file_saver = new Gtk.SourceFileSaver ((Gtk.SourceBuffer) source_view.buffer, source_file);
            try {
                yield source_file_saver.save_async (GLib.Priority.DEFAULT, save_cancellable, null);
            } catch (Error e) {
                // We don't need to send an error message at cancellation (corresponding to error code 19)
                if (e.code != 19)
                    warning ("Cannot save \"%s\": %s", get_basename (), e.message);
                return false;
            }

            source_view.buffer.set_modified (false);

            doc_saved ();
            this.set_saved_status (true);
            last_save_content = source_view.buffer.text;

            debug ("File \"%s\" saved successfully", get_basename ());

            return true;
        }

        public async bool save_as () {
            // New file
            if (!loaded) {
                return false;
            }

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_("All files"));
            all_files_filter.add_pattern ("*");

            var text_files_filter = new Gtk.FileFilter ();
            text_files_filter.set_filter_name (_("Text files"));
            text_files_filter.add_mime_type ("text/*");

            var file_chooser = new Gtk.FileChooserNative (
                _("Save File"),
                null,
                Gtk.FileChooserAction.SAVE,
                _("Save"),
                _("Cancel")
            );
            file_chooser.add_filter (all_files_filter);
            file_chooser.add_filter (text_files_filter);
            file_chooser.do_overwrite_confirmation = true;
            file_chooser.set_current_folder_uri (Utils.last_path ?? GLib.Environment.get_home_dir ());

            var success = false;
            var current_file = file.get_path ();
            var is_current_file_temporary = this.is_file_temporary;

            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                file = File.new_for_uri (file_chooser.get_uri ());
                // Update last visited path
                Utils.last_path = Path.get_dirname (file_chooser.get_file ().get_uri ());
                success = true;
            }

            if (success) {
                source_view.buffer.set_modified (true);
                var is_saved = yield save ();

                if (is_saved && is_current_file_temporary) {
                    try {
                        // Delete temporary file
                        File.new_for_path (current_file).delete ();
                    } catch (Error err) {
                        warning ("Temporary file cannot be deleted: %s", current_file);
                    }
                }

                delete_backup (current_file + "~");
                this.source_view.change_syntax_highlight_from_file (this.file);
            }

            /* We delay destruction of file chooser dialog til to avoid the document focussing in,
             * which triggers premature loading of overwritten content.
             */
            file_chooser.destroy ();
            return success;
        }

        public bool move (File new_dest) {
            this.file = new_dest;
            this.save.begin ();

            return true;
        }

        private void restore_settings () {
            if (Scratch.settings.get_boolean ("show-mini-map")) {
                source_map.show ();
                scroll.vscrollbar_policy = Gtk.PolicyType.EXTERNAL;
            } else {
                source_map.hide ();
                source_map.no_show_all = true;
                scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            }
        }

        // Focus the SourceView
        public new void focus () {
            source_view.grab_focus ();
        }

        // Get file uri
        public string get_uri () {
            return this.file.get_uri ();
        }

        // Get file name
        public string get_basename () {
            if (is_file_temporary) {
                return _("New Document");
            } else {
                return file.get_basename ();
            }
        }

        // Get full file path
        public string get_tab_tooltip () {
            if (is_file_temporary) {
                return _("New Document"); //No path for a new document
            } else {
                return file.get_path ();
            }
        }

        // Set InfoBars message
        public void set_message (Gtk.MessageType type, string label,
                                  string? button1 = null, owned VoidFunc? callback1 = null,
                                  string? button2 = null, owned VoidFunc? callback2 = null) {

            // Show InfoBar
            info_bar.no_show_all = false;
            info_bar.visible = true;

            // Clear from useless widgets
            info_bar.get_content_area ().get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            ((Gtk.Container) info_bar.get_action_area ()).get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            // Type
            info_bar.message_type = type;

            // Layout
            var l = new Gtk.Label (label);
            l.ellipsize = Pango.EllipsizeMode.END;
            l.use_markup = true;
            l.set_markup (label);
            ((Gtk.Box) info_bar.get_action_area ()).orientation = Gtk.Orientation.HORIZONTAL;
            var main = info_bar.get_content_area () as Gtk.Box;
            main.orientation = Gtk.Orientation.HORIZONTAL;
            main.pack_start (l, false, false, 0);
            if (button1 != null) {
                info_bar.add_button (button1, 0);
            } if (button2 != null) {
                info_bar.add_button (button2, 1);
            }

            // Response
            info_bar.response.connect ((id) => {
                if (id == 0) {
                    callback1 ();
                } else if (id == 1) {
                    callback2 ();
                }
            });

            // Show everything
            info_bar.show_all ();
        }

        // Hide InfoBar when not needed
        public void hide_info_bar () {
            info_bar.no_show_all = true;
            info_bar.visible = false;
        }

        // SourceView releated functions
        // Undo
        public void undo () {
            this.source_view.undo ();
            check_undoable_actions ();
        }

        // Redo
        public void redo () {
            this.source_view.redo ();
            check_undoable_actions ();
        }

        // Revert
        public void revert () {
            this.source_view.set_text (original_content, false);
            check_undoable_actions ();
        }

        // Get text
        public string get_text () {
            return this.source_view.buffer.text;
        }

        // Get selcted text
        public string get_selected_text () {
            return this.source_view.get_selected_text ();
        }

        // Get language name
        public string get_language_name () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            var lang = source_buffer.language;
            if (lang != null) {
                return lang.name;
            } else {
                return "";
            }
        }

        // Get language id
        public string get_language_id () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            var lang = source_buffer.language;
            if (lang != null) {
                return lang.id;
            } else {
                return "";
            }
        }

        // Duplicate selected text
        public void duplicate_selection () {
            this.source_view.duplicate_selection ();
        }

        // Show an error view which says "Hey, I cannot read that file!"
        private void show_default_load_error_view () {
            var title = _("File \"%s\" Cannot Be Read").printf (get_basename ());
            var description = _("It may be corrupt or you don't have permission to read it.");
            var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-error");
            alert_view.show_all ();
            main_stack.add_named (alert_view, "error_alert");
            main_stack.set_visible_child (alert_view);
        }

        // Check if the file was deleted/changed by an external source
        public void check_file_status () {
            // If the file does not exist anymore
            if (!exists ()) {
                if (mounted == false) {
                    string message = _(
                        "The location containing the file \"%s\" was unmounted. Do you want to save somewhere else?"
                    ).printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save As…"), () => {
                        this.save_as.begin ();
                        hide_info_bar ();
                    });
                } else {
                    string message = _(
                        "File \"%s\" was deleted. Do you want to save it anyway?"
                    ).printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save"), () => {
                        this.save.begin ();
                        hide_info_bar ();
                    });
                }

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = false;
                return;
            }

            // If the file can't be written
            if (!can_write ()) {
                string message = _(
                    "You cannot save changes to the file \"%s\". Do you want to save the changes somewhere else?"
                ).printf ("<b>%s</b>".printf (get_basename ()));

                set_message (Gtk.MessageType.WARNING, message, _("Save changes elsewhere"), () => {
                    this.save_as.begin ();
                    hide_info_bar ();
                });

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = !Scratch.settings.get_boolean ("autosave");
            } else {
                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (true);
                this.source_view.editable = true;
            }

            // Detect external changes
            if (loaded) {
                var new_buffer = new Gtk.SourceBuffer (null);
                var source_file_loader = new Gtk.SourceFileLoader (new_buffer, source_file);
                source_file_loader.load_async.begin (GLib.Priority.DEFAULT, null, null, (obj, res) => {
                    try {
                        source_file_loader.load_async.end (res);
                    } catch (Error e) {
                        critical (e.message);
                        show_default_load_error_view ();
                        return;
                    }

                    if (source_view.buffer.text == new_buffer.text) {
                        return;
                    }

                    if (!source_view.buffer.get_modified ()) {
                        if (Scratch.settings.get_boolean ("autosave")) {
                            source_view.set_text (new_buffer.text, false);
                        } else {
                            string message = _(
        "File \"%s\" was modified by an external application. Do you want to load it again or continue your editing?"
                            ).printf ("<b>%s</b>".printf (get_basename ()));

                            set_message (Gtk.MessageType.WARNING, message, _("Load"), () => {
                                this.source_view.set_text (new_buffer.text, false);
                                hide_info_bar ();
                            }, _("Continue"), () => {
                                hide_info_bar ();
                            });
                        }
                    }
                });
            }
        }

        // Set Undo/Redo action sensitive property
        public void check_undoable_actions () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            Utils.action_from_group (MainWindow.ACTION_UNDO, actions).set_enabled (source_buffer.can_undo);
            Utils.action_from_group (MainWindow.ACTION_REDO, actions).set_enabled (source_buffer.can_redo);
            Utils.action_from_group (MainWindow.ACTION_REVERT, actions).set_enabled (
                original_content != source_buffer.text
            );
        }

        // Set saved status
        public void set_saved_status (bool val) {
            this.saved = val;

            string unsaved_identifier = "* ";

            if (!val) {
                if (!(unsaved_identifier in this.label)) {
                    tab_name = unsaved_identifier + this.label;
                }
            } else {
                tab_name = this.label.replace (unsaved_identifier, "");
            }
        }

        // Backup functions
        private void create_backup () {
            if (!can_write ()) {
                return;
            }

            var backup = File.new_for_path (this.file.get_path () + "~");

            if (!backup.query_exists ()) {
                try {
                    file.copy (backup, FileCopyFlags.NONE);
                } catch (Error e) {
                    warning ("Cannot create backup copy for file \"%s\": %s", get_basename (), e.message);
                }
            }
        }

        private void delete_backup (string? backup_path = null) {
            string backup_file;

            if (backup_path == null) {
                backup_file = file.get_path () + "~";
            } else {
                backup_file = backup_path;
            }

            debug ("Backup file deleting: %s", backup_file);
            var backup = File.new_for_path (backup_file);
            if (backup == null || !backup.query_exists ()) {
                debug ("Backup file doesn't exists: %s", backup.get_path ());
                return;
            }

            try {
                backup.delete ();
                debug ("Backup file deleted: %s", backup_file);
            } catch (Error e) {
                warning ("Cannot delete backup for file \"%s\": %s", get_basename (), e.message);
            }
        }

        private bool delete_temporary_file (bool force = false) {
            if (!is_file_temporary || (get_text ().length > 0 && !force)) {
                return false;
            }

            try {
                file.delete ();
                return true;
            } catch (Error e) {
                warning ("Cannot delete temporary file \"%s\": %s", file.get_uri (), e.message);
            }

            return false;
        }

        // Return true if the file is writable
        public bool can_write () {
            FileInfo info;

            bool writable = false;

            try {
                info = this.file.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, null);
                writable = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
                return writable;
            } catch (Error e) {
                warning ("query_info failed, but filename appears to be correct, allowing as new file");
                writable = true;
                return writable;
            }
        }

        // Return true if the file exists
        public bool exists (Cancellable? cancellable = null) {
            return this.file.query_exists (cancellable); /* May block */
        }

        private void file_changed () {
            if (mount != null) {
                mount.unmounted.disconnect (unmounted_cb);
                mount = null;
            }

            try {
                mount = file.find_enclosing_mount ();
                mount.unmounted.connect (unmounted_cb);
            } catch (Error e) {
                debug ("Could not find mount location");
                return;
            }
            mounted = true;
        }

        private void unmounted_cb () {
            warning ("Folder containing the file was unmounted");
            mounted = false;
        }

        public bool add_outline_widget (Gtk.Widget extra) {
            if (has_outline_widget ()) {
                return false;
            } else {
                //TODO Style the extra widget to match the document.
                outline_widget_pane.pack2 (extra, false, false);
                var position = int.max (outline_widget_pane.get_allocated_width () * 4 / 5, 100);
                outline_widget_pane.set_position (position);
                return true;
            }
        }

        public bool remove_outline_widget () {
            if (!has_outline_widget ()) {
                return false;
            } else {
                outline_widget_pane.get_child2 ().destroy ();
                return true;
            }
        }

        public bool has_outline_widget () {
            return outline_widget_pane.get_child2 () != null;
        }
    }
}
