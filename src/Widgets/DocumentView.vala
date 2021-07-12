// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

public class Scratch.Widgets.DocumentView : Granite.Widgets.DynamicNotebook {
    public signal void document_change (Services.Document? document, DocumentView parent);
    public signal void request_placeholder ();

    public unowned MainWindow window { get; construct set; }

    public Services.Document current_document {
        get {
            unowned Services.Document doc = null;
            if (current is Services.Document) {
                doc = (Services.Document) current;
            }
            return doc;
        }
        set {
            current = value;
        }
    }

    public GLib.List<Services.Document> docs;

    public bool is_closing = false;

    private Gtk.CssProvider style_provider;

    public DocumentView (MainWindow window) {
        base ();
        allow_restoring = true;
        allow_new_window = true;
        allow_drag = true;
        allow_duplication = true;
        group_name = Constants.PROJECT_NAME;
        this.window = window;
        expand = true;
    }

    construct {
        docs = new GLib.List<Services.Document> ();

        // Layout
        tab_added.connect (on_doc_added);
        tab_removed.connect (on_doc_removed);
        tab_reordered.connect (on_doc_reordered);
        tab_moved.connect (on_doc_moved);

        new_tab_requested.connect (() => {
            new_document ();
        });

        close_tab_requested.connect ((tab) => {
            var document = tab as Services.Document;
            if (!document.is_file_temporary && document.file != null) {
                tab.restore_data = document.get_uri ();
            }

            return document.do_close ();
        });

        tab_switched.connect ((old_tab, new_tab) => {
            /* The 'document_change' signal is emitted when the document is focused. We do not need to emit it here */
            save_focused_document_uri (new_tab as Services.Document);
        });

        tab_restored.connect ((label, restore_data, icon) => {
            var doc = new Services.Document (window.actions, File.new_for_uri (restore_data));
            open_document (doc);
        });

        tab_duplicated.connect ((tab) => {
            duplicate_document (tab as Services.Document);
        });

        style_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        update_inline_tab_colors ();
        Scratch.settings.changed["style-scheme"].connect (update_inline_tab_colors);
    }

    private void update_inline_tab_colors () {
        var sssm = Gtk.SourceStyleSchemeManager.get_default ();
        var style_scheme = Scratch.settings.get_string ("style-scheme");
        if (style_scheme in sssm.scheme_ids) {
            var theme = sssm.get_scheme (style_scheme);
            var text_color_data = theme.get_style ("text");

            // Default gtksourceview background color is white
            var color = "#FFFFFF";
            if (text_color_data != null) {
                // If the current style has a background color, use that
                color = text_color_data.background;
            }

            var define = "@define-color tab_base_color %s;".printf (color);
            try {
                style_provider.load_from_data (define);
            } catch (Error e) {
                critical ("Unable to set inline tab styling, going back to classic notebook tabs");
            }
        }
    }

    private string unsaved_file_path_builder (string extension = "txt") {
        var timestamp = new DateTime.now_local ();

        string new_text_file = _("Text file from %s:%d").printf (
                                    timestamp.format ("%Y-%m-%d %H:%M:%S"), timestamp.get_microsecond ()
                                );

        return Path.build_filename (window.app.data_home_folder_unsaved, new_text_file) + "." + extension;
    }

    private string unsaved_duplicated_file_path_builder (string original_filename) {
        string extension = "txt";
        string[] parts = original_filename.split (".", 2);
        if (parts.length > 1) {
            extension = parts[parts.length - 1];
        }

        return unsaved_file_path_builder (extension);
    }

    public void new_document () {
        var file = File.new_for_path (unsaved_file_path_builder ());
        try {
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);

            insert_tab (doc, -1);
            current_document = doc;

            doc.focus ();
            save_opened_files ();
        } catch (Error e) {
            critical (e.message);
        }
    }

    public void new_document_from_clipboard (string clipboard) {
        var file = File.new_for_path (unsaved_file_path_builder ());

        // Set clipboard content
        try {
            file.create (FileCreateFlags.PRIVATE);
            file.replace_contents (clipboard.data, null, false, 0, null);

            var doc = new Services.Document (window.actions, file);

            insert_tab (doc, -1);
            current_document = doc;

            doc.focus ();
            save_opened_files ();
        } catch (Error e) {
            critical ("Cannot insert clipboard: %s", clipboard);
        }
    }

    public void open_document (Services.Document doc, bool focus = true, int cursor_position = 0) {
        for (int n = 0; n <= docs.length (); n++) {
            var nth_doc = docs.nth_data (n);
            if (nth_doc == null) {
                continue;
            }

            if (nth_doc.file != null && nth_doc.file.get_uri () == doc.file.get_uri ()) {
                if (focus) {
                    current_document = nth_doc;
                }

                debug ("This Document was already opened! Not opening a duplicate!");
                return;
            }
        }

        insert_tab (doc, -1);
        if (focus) {
            current_document = doc;
        }

        Idle.add_full (GLib.Priority.LOW, () => { // This helps ensures new tab is drawn before opening document.
            doc.open.begin (false, (obj, res) => {
                doc.open.end (res);
                if (focus) {
                    doc.focus ();
                }

                if (cursor_position > 0) {
                    doc.source_view.cursor_position = cursor_position;
                }
                save_opened_files ();
            });

            return false;
        });
    }

    // Set a copy of content
    public void duplicate_document (Services.Document original) {
        try {
            var file = File.new_for_path (unsaved_duplicated_file_path_builder (original.file.get_basename ()));
            file.create (FileCreateFlags.PRIVATE);

            var doc = new Services.Document (window.actions, file);
            doc.source_view.set_text (original.get_text ());
            doc.source_view.language = original.source_view.language;
            if (Scratch.settings.get_boolean ("autosave")) {
                doc.save.begin (true);
            }

            insert_tab (doc, -1);
            current_document = doc;
            doc.focus ();
        } catch (Error e) {
            warning ("Cannot copy \"%s\": %s", original.get_basename (), e.message);
        }
    }

    public void next_document () {
        uint current_index = docs.index (current_document) + 1;
        if (current_index < docs.length ()) {
            var next_doc = docs.nth_data (current_index++);
            current_document = next_doc;
            next_doc.focus ();
        } else if (docs.length () > 0) {
            var next_doc = docs.nth_data (0);
            current_document = next_doc;
            next_doc.focus ();
        }
    }

    public void previous_document () {
        uint current_index = docs.index (current_document);
        if (current_index > 0) {
            var previous_doc = docs.nth_data (--current_index);
            current_document = previous_doc;
            previous_doc.focus ();
        } else if (docs.length () > 0) {
            var previous_doc = docs.nth_data (docs.length () - 1);
            current_document = previous_doc;
            previous_doc.focus ();
        }
    }

    public void close_document (Services.Document doc) {
        remove_tab (doc);
        doc.do_close ();
    }

    public void close_current_document () {
        var doc = current_document;
        if (doc != null) {
            if (close_tab_requested (doc)) {
                remove_tab (doc);
            }
        }
    }

    public void request_placeholder_if_empty () {
        if (docs.length () == 0) {
            request_placeholder ();
        }
    }

    public new void focus () {
        current_document.focus ();
    }

    private bool find_unique_path (File f1, File f2, out string? path1, out string? path2) {
        if (f1 == f2) {
            path1 = null;
            path2 = null;
            return false;
        }

        var f1_parent = f1.get_parent ();
        var f2_parent = f2.get_parent ();

        while (f1_parent.get_relative_path (f1) == f2_parent.get_relative_path (f2)) {
            f1_parent = f1_parent.get_parent ();
            f2_parent = f2_parent.get_parent ();
        }

        path1 = f1_parent.get_relative_path (f1);
        path2 = f2_parent.get_relative_path (f2);
        return true;
    }

    private void rename_tabs_with_same_title (Services.Document doc) {
        string doc_tab_name = doc.file.get_basename ();
        foreach (var d in docs) {
            string new_tabname_doc, new_tabname_d;

            if (find_unique_path (d.file, doc.file, out new_tabname_d, out new_tabname_doc)) {
                if (d.label.length < new_tabname_d.length) {
                    d.tab_name = new_tabname_d;
                }

                if (doc_tab_name.length < new_tabname_doc.length) {
                    doc_tab_name = new_tabname_doc;
                }
            }
        }

        doc.tab_name = doc_tab_name;
    }

    private void on_doc_added (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;
        doc.actions = window.actions;

        docs.append (doc);
        if (!doc.is_file_temporary) {
            rename_tabs_with_same_title (doc);
        }

        doc.source_view.focus_in_event.connect_after (on_focus_in_event);
        doc.source_view.drag_data_received.connect (drag_received);
    }

    private void on_doc_removed (Granite.Widgets.Tab tab) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        doc.source_view.focus_in_event.disconnect (on_focus_in_event);
        doc.source_view.drag_data_received.disconnect (drag_received);

        request_placeholder_if_empty ();

        if (docs.length () > 0) {
            if (!doc.is_file_temporary) {
                foreach (var d in docs) {
                    rename_tabs_with_same_title (d);
                }
            }
        }

        if (!is_closing) {
            save_opened_files ();
        }
    }

    private void on_doc_moved (Granite.Widgets.Tab tab, int x, int y) {
        var doc = tab as Services.Document;

        var other_window = window.app.new_window ();
        other_window.move (x, y);

        // We need to make sure switch back to the main thread
        // when we are modifiying Gtk widgets shared by two threads.
        Idle.add (() => {
            remove_tab (doc);
            other_window.document_view.insert_tab (doc, -1);

            return false;
        });
    }

    private void on_doc_reordered (Granite.Widgets.Tab tab, int new_pos) {
        var doc = tab as Services.Document;

        docs.remove (doc);
        docs.insert (doc, new_pos);

        doc.focus ();

        save_opened_files ();
    }

    private bool on_focus_in_event () {
        var doc = current_document;
        if (doc == null) {
            warning ("Focus event callback cannot get current document");
        } else {
            document_change (doc, this);
        }

        return false;
    }

    private void drag_received (Gtk.Widget w,
                                Gdk.DragContext ctx,
                                int x,
                                int y,
                                Gtk.SelectionData sel,
                                uint info,
                                uint time) {

        var uris = sel.get_uris ();
        foreach (var filename in uris) {
            var file = File.new_for_uri (filename);
            var doc = new Services.Document (window.actions, file);
            open_document (doc);
        }

       Gtk.drag_finish (ctx, true, false, time);
    }

    public void save_opened_files () {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var vb = new VariantBuilder (new VariantType ("a(si)"));
            tabs.foreach ((tab) => {
                var doc = (Scratch.Services.Document)tab;
                if (doc.file != null && doc.exists ()) {
                    vb.add ("(si)", doc.file.get_uri (), doc.source_view.cursor_position);
                }
            });

            Scratch.settings.set_value ("opened-files", vb.end ());
        }
    }

    private void save_focused_document_uri (Services.Document? current_document) {
        if (privacy_settings.get_boolean ("remember-recent-files")) {
            var file_uri = "";

            if (current_document != null) {
                file_uri = current_document.file.get_uri ();
            }

            Scratch.settings.set_string ("focused-document", file_uri);
        }
    }
}
